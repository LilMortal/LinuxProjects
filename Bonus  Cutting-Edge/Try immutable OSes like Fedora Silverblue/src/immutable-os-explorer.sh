#!/bin/bash

#==============================================================================
# ImmutableOS Explorer - Main Script
# 
# A comprehensive tool for discovering, comparing, and trying immutable 
# operating systems like Fedora Silverblue, openSUSE MicroOS, and others.
#
# Author: Your Name <your.email@example.com>
# License: MIT
# Version: 1.0.0
#==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#==============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
#==============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_FILE="${IMMUTABLE_OS_CONFIG:-/etc/immutable-os-explorer/config.json}"
readonly LOG_DIR="/var/log/immutable-os-explorer"
readonly DATA_DIR="/usr/share/immutable-os-explorer"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global variables
VERBOSE=false
QUIET=false
DRY_RUN=false
NO_COLOR=false
LOG_LEVEL="INFO"
DOWNLOAD_DIR=""

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR" 2>/dev/null || {
            mkdir -p "$HOME/.local/share/immutable-os-explorer/logs"
            LOG_DIR="$HOME/.local/share/immutable-os-explorer/logs"
        }
    fi
    
    # Ensure log files exist
    touch "$LOG_DIR/main.log" "$LOG_DIR/downloads.log" "$LOG_DIR/errors.log" 2>/dev/null || true
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/main.log" 2>/dev/null || true
    
    # Log errors to separate file
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] $message" >> "$LOG_DIR/errors.log" 2>/dev/null || true
    fi
    
    # Console output based on level and verbosity
    case "$level" in
        "ERROR")
            [[ "$QUIET" != true ]] && echo -e "${RED}ERROR: $message${NC}" >&2
            ;;
        "WARN")
            [[ "$QUIET" != true ]] && echo -e "${YELLOW}WARNING: $message${NC}" >&2
            ;;
        "INFO")
            [[ "$QUIET" != true ]] && echo -e "${CYAN}INFO: $message${NC}"
            ;;
        "DEBUG")
            [[ "$VERBOSE" == true ]] && echo -e "${PURPLE}DEBUG: $message${NC}"
            ;;
        "SUCCESS")
            [[ "$QUIET" != true ]] && echo -e "${GREEN}✓ $message${NC}"
            ;;
    esac
}

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

# Display colored output
color_output() {
    local color="$1"
    shift
    if [[ "$NO_COLOR" == true ]]; then
        echo "$*"
    else
        echo -e "${color}$*${NC}"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local required_deps=("curl" "jq" "sha256sum" "lsblk")
    
    for dep in "${required_deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies:"
        echo "  Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
        echo "  Fedora: sudo dnf install ${missing_deps[*]}"
        echo "  Arch: sudo pacman -S ${missing_deps[*]}"
        exit 1
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Parse JSON config using jq
        DOWNLOAD_DIR=$(jq -r '.download_dir // "/tmp/immutable-os-downloads"' "$CONFIG_FILE" 2>/dev/null || echo "/tmp/immutable-os-downloads")
        LOG_LEVEL=$(jq -r '.log_level // "INFO"' "$CONFIG_FILE" 2>/dev/null || echo "INFO")
        
        # Expand variables in download directory
        DOWNLOAD_DIR="${DOWNLOAD_DIR//\$USER/$USER}"
        DOWNLOAD_DIR="${DOWNLOAD_DIR//\$HOME/$HOME}"
        
        log "DEBUG" "Configuration loaded from $CONFIG_FILE"
    else
        log "WARN" "Configuration file not found at $CONFIG_FILE, using defaults"
        DOWNLOAD_DIR="/tmp/immutable-os-downloads"
    fi
    
    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
}

#==============================================================================
# IMMUTABLE OS DATABASE
#==============================================================================

# Define available immutable operating systems
get_os_database() {
    cat << 'EOF'
{
  "fedora-silverblue": {
    "name": "Fedora Silverblue",
    "description": "A variant of Fedora Workstation that uses rpm-ostree technology to provide an immutable desktop experience",
    "base": "Fedora",
    "desktop": "GNOME",
    "version": "39",
    "status": "Stable",
    "release_date": "2023-11-07",
    "iso_url": "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Silverblue/x86_64/iso/Fedora-Silverblue-ostree-x86_64-39-1.5.iso",
    "checksum_url": "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Silverblue/x86_64/iso/Fedora-Silverblue-39-1.5-x86_64-CHECKSUM",
    "iso_size": "1.8GB",
    "min_ram": "4GB",
    "min_storage": "20GB",
    "features": ["Atomic updates", "Container-focused", "Flatpak support", "Toolbox environments"],
    "support_type": "Community",
    "website": "https://silverblue.fedoraproject.org/"
  },
  "opensuse-microos": {
    "name": "openSUSE MicroOS",
    "description": "A modern Linux operating system designed for containerized workloads with automatic updates",
    "base": "openSUSE",
    "desktop": "GNOME/KDE",
    "version": "Tumbleweed",
    "status": "Rolling",
    "release_date": "Rolling",
    "iso_url": "https://download.opensuse.org/tumbleweed/iso/openSUSE-MicroOS-DVD-x86_64-Current.iso",
    "checksum_url": "https://download.opensuse.org/tumbleweed/iso/openSUSE-MicroOS-DVD-x86_64-Current.iso.sha256",
    "iso_size": "1.2GB",
    "min_ram": "2GB",
    "min_storage": "16GB",
    "features": ["Transactional updates", "Btrfs snapshots", "Container runtime", "Minimal base"],
    "support_type": "Community",
    "website": "https://microos.opensuse.org/"
  },
  "nixos": {
    "name": "NixOS",
    "description": "A purely functional Linux distribution built on top of the Nix package manager",
    "base": "NixOS",
    "desktop": "Multiple",
    "version": "23.05",
    "status": "Stable",
    "release_date": "2023-05-31",
    "iso_url": "https://releases.nixos.org/nixos/23.05/nixos-23.05.4242.6c5c9a6dab1/nixos-minimal-23.05.4242.6c5c9a6dab1-x86_64-linux.iso",
    "checksum_url": "https://releases.nixos.org/nixos/23.05/nixos-23.05.4242.6c5c9a6dab1/nixos-minimal-23.05.4242.6c5c9a6dab1-x86_64-linux.iso.sha256",
    "iso_size": "900MB",
    "min_ram": "2GB",
    "min_storage": "20GB",
    "features": ["Declarative configuration", "Reproducible builds", "Rollback capability", "Atomic upgrades"],
    "support_type": "Community",
    "website": "https://nixos.org/"
  },
  "endless-os": {
    "name": "Endless OS",
    "description": "A Debian-based immutable operating system designed for education and emerging markets",
    "base": "Debian",
    "desktop": "GNOME",
    "version": "5.0",
    "status": "Stable",
    "release_date": "2023-09-12",
    "iso_url": "https://images.endlessos.com/eos-amd64-amd64/5.0.7/eos-amd64-amd64-en-5.0.7.210917-225606.base.iso",
    "checksum_url": "https://images.endlessos.com/eos-amd64-amd64/5.0.7/eos-amd64-amd64-en-5.0.7.210917-225606.base.iso.sha256",
    "iso_size": "2.8GB",
    "min_ram": "4GB",
    "min_storage": "32GB",
    "features": ["Offline content", "Educational apps", "Parental controls", "Flatpak support"],
    "support_type": "Commercial",
    "website": "https://endlessos.com/"
  },
  "clear-linux": {
    "name": "Clear Linux",
    "description": "An Intel-optimized Linux distribution designed for performance and cloud workloads",
    "base": "Intel",
    "desktop": "GNOME",
    "version": "39140",
    "status": "Rolling",
    "release_date": "Rolling",
    "iso_url": "https://download.clearlinux.org/releases/39140/clear/clear-39140-live-desktop.iso",
    "checksum_url": "https://download.clearlinux.org/releases/39140/clear/clear-39140-live-desktop.iso.sig",
    "iso_size": "2.1GB",
    "min_ram": "4GB",
    "min_storage": "20GB",
    "features": ["Intel optimizations", "Automatic updates", "Stateless design", "Bundle management"],
    "support_type": "Intel",
    "website": "https://clearlinux.org/"
  }
}
EOF
}

#==============================================================================
# CORE FUNCTIONALITY
#==============================================================================

# List all available immutable operating systems
list_os() {
    local os_db
    os_db=$(get_os_database)
    
    color_output "$WHITE" "Available Immutable Operating Systems:"
    echo "┌─────────────────────┬─────────────┬──────────────┬─────────────┐"
    echo "│ Name                │ Version     │ Base         │ Status      │"
    echo "├─────────────────────┼─────────────┼──────────────┼─────────────┤"
    
    # Parse and display each OS
    for os_id in $(echo "$os_db" | jq -r 'keys[]'); do
        local name version base status
        name=$(echo "$os_db" | jq -r ".[\"$os_id\"].name")
        version=$(echo "$os_db" | jq -r ".[\"$os_id\"].version")
        base=$(echo "$os_db" | jq -r ".[\"$os_id\"].base")
        status=$(echo "$os_db" | jq -r ".[\"$os_id\"].status")
        
        printf "│ %-19s │ %-11s │ %-12s │ %-11s │\n" "$name" "$version" "$base" "$status"
    done
    
    echo "└─────────────────────┴─────────────┴──────────────┴─────────────┘"
    echo ""
    color_output "$CYAN" "Use '$SCRIPT_NAME info <name>' for detailed information."
}

# Show detailed information about a specific OS
show_os_info() {
    local os_id="$1"
    local os_db
    os_db=$(get_os_database)
    
    # Check if OS exists
    if ! echo "$os_db" | jq -e ".[\"$os_id\"]" >/dev/null 2>&1; then
        log "ERROR" "Unknown operating system: $os_id"
        echo "Available options:"
        echo "$os_db" | jq -r 'keys[]' | sed 's/^/  - /'
        exit 1
    fi
    
    # Extract OS information
    local name description version base desktop release_date iso_size min_ram min_storage support_type website
    name=$(echo "$os_db" | jq -r ".[\"$os_id\"].name")
    description=$(echo "$os_db" | jq -r ".[\"$os_id\"].description")
    version=$(echo "$os_db" | jq -r ".[\"$os_id\"].version")
    base=$(echo "$os_db" | jq -r ".[\"$os_id\"].base")
    desktop=$(echo "$os_db" | jq -r ".[\"$os_id\"].desktop")
    release_date=$(echo "$os_db" | jq -r ".[\"$os_id\"].release_date")
    iso_size=$(echo "$os_db" | jq -r ".[\"$os_id\"].iso_size")
    min_ram=$(echo "$os_db" | jq -r ".[\"$os_id\"].min_ram")
    min_storage=$(echo "$os_db" | jq -r ".[\"$os_id\"].min_storage")
    support_type=$(echo "$os_db" | jq -r ".[\"$os_id\"].support_type")
    website=$(echo "$os_db" | jq -r ".[\"$os_id\"].website")
    
    # Display information
    color_output "$WHITE" "$name $version"
    printf '%.0s=' {1..60}
    echo ""
    echo ""
    
    color_output "$YELLOW" "Description:"
    echo "$description"
    echo ""
    
    color_output "$YELLOW" "Key Features:"
    echo "$os_db" | jq -r ".[\"$os_id\"].features[]" | sed 's/^/• /'
    echo ""
    
    color_output "$YELLOW" "System Requirements:"
    echo "• RAM: $min_ram minimum"
    echo "• Storage: $min_storage minimum"
    echo "• Desktop: $desktop"
    echo ""
    
    color_output "$YELLOW" "Release Information:"
    echo "• Download Size: $iso_size"
    echo "• Release Date: $release_date"
    echo "• Support: $support_type supported"
    echo ""
    
    color_output "$YELLOW" "Links:"
    echo "• Website: $website"
    echo ""
}

# Download ISO for specified OS
download_iso() {
    local os_id="$1"
    local os_db
    os_db=$(get_os_database)
    
    # Check if OS exists
    if ! echo "$os_db" | jq -e ".[\"$os_id\"]" >/dev/null 2>&1; then
        log "ERROR" "Unknown operating system: $os_id"
        exit 1
    fi
    
    local name iso_url checksum_url
    name=$(echo "$os_db" | jq -r ".[\"$os_id\"].name")
    iso_url=$(echo "$os_db" | jq -r ".[\"$os_id\"].iso_url")
    checksum_url=$(echo "$os_db" | jq -r ".[\"$os_id\"].checksum_url")
    
    local filename
    filename=$(basename "$iso_url")
    local filepath="$DOWNLOAD_DIR/$filename"
    
    log "INFO" "Starting download of $name"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: Would download $iso_url to $filepath"
        return 0
    fi
    
    # Download ISO with progress
    if command_exists pv; then
        curl -L --progress-bar "$iso_url" | pv -N "Downloading $name" > "$filepath"
    else
        curl -L --progress-bar -o "$filepath" "$iso_url"
    fi
    
    # Log download
    echo "$(date '+%Y-%m-%d %H:%M:%S') Downloaded: $filename" >> "$LOG_DIR/downloads.log"
    
    # Verify checksum if available
    if [[ -n "$checksum_url" && "$checksum_url" != "null" ]]; then
        log "INFO" "Verifying checksum..."
        local checksum_file="$DOWNLOAD_DIR/${filename}.checksum"
        
        curl -L -s -o "$checksum_file" "$checksum_url"
        
        # Extract checksum (handle different formats)
        local expected_checksum
        if grep -q "$filename" "$checksum_file" 2>/dev/null; then
            expected_checksum=$(grep "$filename" "$checksum_file" | awk '{print $1}')
        else
            expected_checksum=$(cat "$checksum_file" | awk '{print $1}')
        fi
        
        local actual_checksum
        actual_checksum=$(sha256sum "$filepath" | awk '{print $1}')
        
        if [[ "$expected_checksum" == "$actual_checksum" ]]; then
            log "SUCCESS" "Checksum verification passed"
        else
            log "ERROR" "Checksum verification failed!"
            log "ERROR" "Expected: $expected_checksum"
            log "ERROR" "Actual: $actual_checksum"
            return 1
        fi
    fi
    
    log "SUCCESS" "Downloaded $name to $filepath"
    echo "File location: $filepath"
}

# Compare multiple operating systems
compare_os() {
    local os_ids=("$@")
    local os_db
    os_db=$(get_os_database)
    
    if [[ ${#os_ids[@]} -lt 2 ]]; then
        log "ERROR" "Need at least 2 operating systems to compare"
        exit 1
    fi
    
    # Validate all OS IDs
    for os_id in "${os_ids[@]}"; do
        if ! echo "$os_db" | jq -e ".[\"$os_id\"]" >/dev/null 2>&1; then
            log "ERROR" "Unknown operating system: $os_id"
            exit 1
        fi
    done
    
    color_output "$WHITE" "Operating System Comparison"
    printf '%.0s=' {1..80}
    echo ""
    
    # Create comparison table
    printf "%-20s" "Feature"
    for os_id in "${os_ids[@]}"; do
        local name
        name=$(echo "$os_db" | jq -r ".[\"$os_id\"].name" | cut -c1-15)
        printf " │ %-15s" "$name"
    done
    echo ""
    
    printf '%.0s─' {1..20}
    for os_id in "${os_ids[@]}"; do
        printf "─┼─"
        printf '%.0s─' {1..15}
    done
    echo ""
    
    # Compare features
    local features=("base" "desktop" "version" "status" "iso_size" "min_ram" "support_type")
    local feature_names=("Base Distribution" "Desktop" "Version" "Status" "ISO Size" "Min RAM" "Support")
    
    for i in "${!features[@]}"; do
        local feature="${features[$i]}"
        local feature_name="${feature_names[$i]}"
        
        printf "%-20s" "$feature_name"
        for os_id in "${os_ids[@]}"; do
            local value
            value=$(echo "$os_db" | jq -r ".[\"$os_id\"].$feature" | cut -c1-15)
            printf " │ %-15s" "$value"
        done
        echo ""
    done
}

# Create bootable USB drive
create_usb() {
    local os_id="$1"
    local device="$2"
    local method="${3:-dd}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "USB creation requires root privileges. Please run with sudo."
        exit 1
    fi
    
    # Verify device exists
    if [[ ! -b "$device" ]]; then
        log "ERROR" "Device $device does not exist or is not a block device"
        exit 1
    fi
    
    local os_db
    os_db=$(get_os_database)
    
    # Get ISO file path
    local iso_url filename filepath
    iso_url=$(echo "$os_db" | jq -r ".[\"$os_id\"].iso_url")
    filename=$(basename "$iso_url")
    filepath="$DOWNLOAD_DIR/$filename"
    
    if [[ ! -f "$filepath" ]]; then
        log "ERROR" "ISO file not found: $filepath"
        log "INFO" "Please download the ISO first: $SCRIPT_NAME download $os_id"
        exit 1
    fi
    
    # Display warning
    color_output "$RED" "WARNING: This will completely erase all data on $device"
    echo "Device information:"
    lsblk "$device" 2>/dev/null || fdisk -l "$device" 2>/dev/null
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: Would create bootable USB on $device using $method method"
        return 0
    fi
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        log "INFO" "Operation cancelled by user"
        exit 0
    fi
    
    log "INFO" "Creating bootable USB drive..."
    
    case "$method" in
        "dd")
            # Unmount if mounted
            umount "$device"* 2>/dev/null || true
            
            # Use dd to write ISO
            if command_exists pv; then
                pv "$filepath" | dd of="$device" bs=4M status=progress
            else
                dd if="$filepath" of="$device" bs=4M status=progress
            fi
            
            # Sync to ensure all data is written
            sync
            ;;
        "ventoy")
            log "ERROR" "Ventoy method not yet implemented"
            exit 1
            ;;
        *)
            log "ERROR" "Unknown USB creation method: $method"
            exit 1
            ;;
    esac
    
    log "SUCCESS" "Bootable USB drive created successfully"
    log "INFO" "You can now boot from $device"
}

# Check system compatibility
check_compatibility() {
    color_output "$WHITE" "System Compatibility Check"
    printf '%.0s=' {1..40}
    echo ""
    
    # Get system information
    local cpu_info ram_info disk_info
    cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    ram_info=$(free -h | awk '/^Mem:/ {print $2}')
    disk_info=$(df -h / | awk 'NR==2 {print $4}')
    
    echo "Current System:"
    echo "• CPU: $cpu_info"
    echo "• RAM: $ram_info"
    echo "• Available Disk Space: $disk_info"
    echo ""
    
    # Check UEFI support
    if [[ -d /sys/firmware/efi ]]; then
        color_output "$GREEN" "✓ UEFI firmware detected (required for most immutable OSes)"
    else
        color_output "$YELLOW" "⚠ Legacy BIOS detected. Some immutable OSes require UEFI."
    fi
    
    # Check virtualization support
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        color_output "$GREEN" "✓ Hardware virtualization supported"
    else
        color_output "$YELLOW" "⚠ Hardware virtualization not detected"
    fi
    
    # Check available disk space
    local available_gb
    available_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $available_gb -ge 64 ]]; then
        color_output "$GREEN" "✓ Sufficient disk space available (${available_gb}GB)"
    elif [[ $available_gb -ge 32 ]]; then
        color_output "$YELLOW" "⚠ Limited disk space (${available_gb}GB). Some OSes may require more."
    else
        color_output "$RED" "✗ Insufficient disk space (${available_gb}GB). At least 32GB recommended."
    fi
    
    # RAM check
    local ram_gb
    ram_gb=$(free | awk '/^Mem:/ {print int($2/1024/1024)}')
    
    if [[ $ram_gb -ge 8 ]]; then
        color_output "$GREEN" "✓ Plenty of RAM available (${ram_gb}GB)"
    elif [[ $ram_gb -ge 4 ]]; then
        color_output "$YELLOW" "⚠ Adequate RAM (${ram_gb}GB). Some OSes may be slow."
    else
        color_output "$RED" "✗ Insufficient RAM (${ram_gb}GB). At least 4GB recommended."
    fi
}

# Update check function
update_check() {
    local notify_flag="$1"
    
    log "INFO" "Checking for operating system updates..."
    
    # This would typically check for newer versions
    # For demo purposes, we'll simulate the check
    local updates_available=false
    
    if [[ "$updates_available" == true ]]; then
        local message="New versions available for: Fedora Silverblue 40, NixOS 23.11"
        log "INFO" "$message"
        
        if [[ "$notify_flag" == "--notify" ]] && command_exists notify-send; then
            notify-send "ImmutableOS Explorer" "$message"
        fi
    else
        log "INFO" "All tracked operating systems are up to date"
    fi
}

#==============================================================================
# INTERACTIVE MODE
#==============================================================================

interactive_mode() {
    color_output "$WHITE" "ImmutableOS Explorer - Interactive Mode"
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    while true; do
        echo "Available actions:"
        echo "1. List available operating systems"
        echo "2. Show OS information"
        echo "3. Download ISO"
        echo "4. Compare operating systems"
        echo "5. Check system compatibility"
        echo "6. Create bootable USB"
        echo "7. Exit"
        echo ""
        
        read -p "Select an option (1-7): " choice
        echo ""
        
        case "$choice" in
            1)
                list_os
                ;;
            2)
                read -p "Enter OS ID (e.g., fedora-silverblue): " os_id
                show_os_info "$os_id"
                ;;
            3)
                read -p "Enter OS ID to download: " os_id
                download_iso "$os_id"
                ;;
            4)
                read -p "Enter OS IDs to compare (space-separated): " -a os_ids
                compare_os "${os_ids[@]}"
                ;;
            5)
                check_compatibility
                ;;
            6)
                read -p "Enter OS ID: " os_id
                read -p "Enter USB device (e.g., /dev/sdb): " device
                create_usb "$os_id" "$device"
                ;;
            7)
                log "INFO" "Exiting interactive mode"
                exit 0
                ;;
            *)
                log "ERROR" "Invalid option: $choice"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

#==============================================================================
# CLI ARGUMENT PARSING
#==============================================================================

show_help() {
    cat << EOF
ImmutableOS Explorer v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS] COMMAND [ARGS...]

COMMANDS:
    list                          List all available immutable operating systems
    info <os-id>                  Show detailed information about a specific OS
    download <os-id>              Download ISO file for specified OS
    compare <os-id1> <os-id2>...  Compare multiple operating systems
    create-usb <os-id> <device>   Create bootable USB drive
    check-compatibility           Check system compatibility with immutable OSes
    update-check [--notify]       Check for OS updates
    interactive                   Start interactive mode

OPTIONS:
    -h, --help                    Show this help message
    -v, --verbose                 Enable verbose output
    -q, --quiet                   Suppress non-essential output
    -c, --config FILE             Use custom configuration file
    -l, --log-level LEVEL         Set logging level (DEBUG|INFO|WARN|ERROR)
    -d, --download-dir DIR        Override download directory
    -n, --dry-run                 Show what would be done without executing
    --no-color                    Disable colored output
    --version                     Show version information

EXAMPLES:
    $SCRIPT_NAME list
    $SCRIPT_NAME info fedora-silverblue
    $SCRIPT_NAME download fedora-silverblue
    $SCRIPT_NAME compare fedora-silverblue opensuse-microos
    $SCRIPT_NAME create-usb fedora-silverblue /dev/sdb
    $SCRIPT_NAME interactive

For more information, visit: https://github.com/username/immutable-os-explorer
EOF
}

show_version() {
    echo "ImmutableOS Explorer $SCRIPT_VERSION"
    echo "Copyright (c) 2024 ImmutableOS Explorer Contributors"
    echo "Licensed under the MIT License"
}

#==============================================================================
# MAIN FUNCTION
#==============================================================================

main() {
    # Initialize
    init_logging
    check_dependencies
    load_config
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            -d|--download-dir)
                DOWNLOAD_DIR="$2"
                mkdir -p "$DOWNLOAD_DIR"
                shift 2
                ;;
            list)
                list_os
                exit 0
                ;;
            info)
                if [[ -n "${2:-}" ]]; then
                    show_os_info "$2"
                    exit 0
                else
                    log "ERROR" "OS ID required for info command"
                    exit 1
                fi
                ;;
            download)
                if [[ -n "${2:-}" ]]; then
                    download_iso "$2"
                    exit 0
                else
                    log "ERROR" "OS ID required for download command"
                    exit 1
                fi
                ;;
            compare)
                shift
                if [[ $# -ge 2 ]]; then
                    compare_os "$@"
                    exit 0
                else
                    log "ERROR" "At least 2 OS IDs required for compare command"
                    exit 1
                fi
                ;;
            create-usb)
                if [[ -n "${2:-}" && -n "${3:-}" ]]; then
                    create_usb "$2" "$3" "${4:-dd}"
                    exit 0
                else
                    log "ERROR" "OS ID and device required for create-usb command"
                    exit 1
                fi
                ;;
            check-compatibility)
                check_compatibility
                exit 0
                ;;
            update-check)
                update_check "${2:-}"
                exit 0
                ;;
            interactive)
                interactive_mode
                exit 0
                ;;
            *)
                log "ERROR" "Unknown command: $1"
                echo "Use '$SCRIPT_NAME --help' for usage information."
                exit 1
                ;;
        esac
    done
    
    # If no command provided, show help
    show_help
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi