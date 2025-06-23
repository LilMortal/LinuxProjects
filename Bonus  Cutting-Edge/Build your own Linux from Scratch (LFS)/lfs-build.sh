#!/bin/bash

# Linux From Scratch (LFS) Main Build Script
# Version: 1.0.0
# License: MIT
# 
# This script automates the complete LFS build process with comprehensive
# error handling, logging, and progress tracking.

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# =============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
# =============================================================================

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="1.0.0"

# Default configuration
DEFAULT_CONFIG="/opt/lfs-toolkit/config/lfs.conf"
DEFAULT_LOG_DIR="/var/log/lfs-build"
LFS_TOOLKIT_DIR="/opt/lfs-toolkit"

# Build phases
declare -A BUILD_PHASES=(
    ["host-prep"]="Host system preparation"
    ["partitions"]="Partition and filesystem setup"  
    ["cross-tools"]="Cross-compilation toolchain"
    ["temp-system"]="Temporary system build"
    ["final-system"]="Final LFS system build"
    ["system-config"]="System configuration"
    ["bootloader"]="Bootloader installation"
)

# Global state variables
CONFIG_FILE=""
LOG_DIR=""
PHASE=""
RESUME_FROM=""
PACKAGE_LIST=""
FULL_BUILD=false
DRY_RUN=false
VERBOSE=false

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging function with timestamps and levels
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Color codes for different log levels
    local color=""
    case "$level" in
        "ERROR")   color="\033[31m" ;;  # Red
        "WARN")    color="\033[33m" ;;  # Yellow
        "INFO")    color="\033[32m" ;;  # Green
        "DEBUG")   color="\033[36m" ;;  # Cyan
        *)         color="\033[0m"  ;;  # Default
    esac
    
    local reset="\033[0m"
    
    # Log to file
    echo "[$timestamp] $level: $message" >> "$LOG_DIR/main.log"
    
    # Log to console with colors
    echo -e "${color}[$timestamp] $level: $message${reset}"
    
    # Log errors to separate error log
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] ERROR: $message" >> "$LOG_DIR/errors.log"
    fi
}

# Error handler function
error_handler() {
    local exit_code=$?
    local line_number=$1
    
    log "ERROR" "Script failed at line $line_number with exit code $exit_code"
    log "ERROR" "Command: ${BASH_COMMAND}"
    
    # Cleanup on error
    cleanup_on_error
    
    exit $exit_code
}

# Cleanup function for error scenarios
cleanup_on_error() {
    log "INFO" "Performing cleanup after error..."
    
    # Unmount any mounted filesystems
    if mountpoint -q "$LFS" 2>/dev/null; then
        log "INFO" "Unmounting $LFS"
        sudo umount -R "$LFS" || true
    fi
    
    # Save build state for potential resume
    save_build_state "ERROR"
}

# Function to display script usage
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Linux From Scratch (LFS) Automation Toolkit v$SCRIPT_VERSION

OPTIONS:
    --full                    Run complete LFS build process
    --phase=PHASE            Run specific build phase
    --config=FILE            Use custom configuration file
    --log-dir=DIR            Set custom log directory
    --resume-from=PACKAGE    Resume build from specific package
    --package-list=FILE      Use custom package list
    --dry-run                Show what would be done without executing
    --verbose                Enable verbose output
    --help                   Show this help message

PHASES:
    host-prep               Host system preparation
    partitions              Partition and filesystem setup
    cross-tools             Cross-compilation toolchain
    temp-system             Temporary system build
    final-system            Final LFS system build
    system-config           System configuration
    bootloader              Bootloader installation

EXAMPLES:
    # Full automated build
    sudo $SCRIPT_NAME --full

    # Build specific phase
    sudo $SCRIPT_NAME --phase=cross-tools

    # Resume from specific package
    sudo $SCRIPT_NAME --resume-from=gcc-pass2

    # Dry run to see what would be done
    $SCRIPT_NAME --full --dry-run

EOF
}

# Function to validate system requirements
validate_system() {
    log "INFO" "Validating system requirements..."
    
    # Check if running as root when needed
    if [[ $EUID -ne 0 ]] && [[ "$DRY_RUN" == false ]]; then
        log "ERROR" "This script must be run with sudo for actual builds"
        exit 1
    fi
    
    # Check required commands
    local required_commands=(
        "gcc" "make" "patch" "awk" "wget" "tar" "gzip" "bzip2" "xz"
        "python3" "git" "rsync" "parted" "mkfs.ext4"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required command not found: $cmd"
            log "INFO" "Please install missing dependencies"
            exit 1
        fi
    done
    
    # Check disk space
    local available_space=$(df "$PWD" | tail -1 | awk '{print $4}')
    local required_space=20971520  # 20GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log "ERROR" "Insufficient disk space. Required: 20GB, Available: $((available_space/1024/1024))GB"
        exit 1
    fi
    
    # Run host validation script
    if [[ -f "$LFS_TOOLKIT_DIR/scripts/validate-host.py" ]]; then
        log "INFO" "Running comprehensive host validation..."
        python3 "$LFS_TOOLKIT_DIR/scripts/validate-host.py" || {
            log "ERROR" "Host validation failed"
            exit 1
        }
    fi
    
    log "INFO" "System validation completed successfully"
}

# Function to load configuration
load_config() {
    local config_file="${CONFIG_FILE:-$DEFAULT_CONFIG}"
    
    if [[ ! -f "$config_file" ]]; then
        log "ERROR" "Configuration file not found: $config_file"
        exit 1
    fi
    
    log "INFO" "Loading configuration from: $config_file"
    source "$config_file"
    
    # Validate required configuration variables
    local required_vars=("LFS" "LFS_TGT" "LFS_VERSION")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "ERROR" "Required configuration variable not set: $var"
            exit 1
        fi
    done
    
    # Export configuration for child processes
    export LFS LFS_TGT LFS_VERSION MAKEFLAGS
    
    log "INFO" "Configuration loaded - LFS: $LFS, Target: $LFS_TGT, Version: $LFS_VERSION"
}

# Function to setup logging
setup_logging() {
    local log_dir="${LOG_DIR:-$DEFAULT_LOG_DIR}"
    
    # Create log directory
    sudo mkdir -p "$log_dir"
    sudo chown "$USER:$USER" "$log_dir"
    
    export LOG_DIR="$log_dir"
    
    # Initialize log files
    : > "$log_dir/main.log"
    : > "$log_dir/errors.log"
    
    log "INFO" "Logging initialized - Directory: $log_dir"
}

# Function to save build state for resume capability
save_build_state() {
    local state="$1"
    local state_file="$LOG_DIR/build-state.json"
    
    cat > "$state_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "phase": "${PHASE:-unknown}",
    "state": "$state",
    "lfs_version": "${LFS_VERSION:-unknown}",
    "current_package": "${CURRENT_PACKAGE:-unknown}"
}
EOF
    
    log "DEBUG" "Build state saved: $state"
}

# =============================================================================
# BUILD PHASE FUNCTIONS
# =============================================================================

# Phase 1: Host system preparation
phase_host_prep() {
    log "INFO" "Starting Phase 1: Host system preparation"
    save_build_state "host-prep-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would prepare host system"
        return 0
    fi
    
    # Create LFS user if it doesn't exist
    if ! id "lfs" &>/dev/null; then
        log "INFO" "Creating LFS user"
        sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
        echo 'lfs:lfs' | sudo chpasswd
    fi
    
    # Set up environment for LFS user
    sudo -u lfs bash << EOF
cat > ~/.bash_profile << "EOL"
exec env -i HOME=\$HOME TERM=\$TERM PS1='\u:\w\$ ' /bin/bash
EOL

cat > ~/.bashrc << "EOL"
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$LFS_TGT
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\$LFS/tools/bin:\$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOL
EOF
    
    log "INFO" "Phase 1 completed successfully"
    save_build_state "host-prep-complete"
}

# Phase 2: Partition and filesystem setup
phase_partitions() {
    log "INFO" "Starting Phase 2: Partition and filesystem setup"
    save_build_state "partitions-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would set up partitions and filesystems"
        return 0
    fi
    
    # Create mount point
    sudo mkdir -p "$LFS"
    
    # Check if disk is specified and exists
    if [[ -n "${LFS_DISK:-}" ]] && [[ -b "$LFS_DISK" ]]; then
        log "WARN" "Disk partitioning is dangerous and requires manual intervention"
        log "INFO" "Please manually partition $LFS_DISK and mount to $LFS"
        log "INFO" "Example commands:"
        log "INFO" "  sudo parted $LFS_DISK mklabel gpt"
        log "INFO" "  sudo parted $LFS_DISK mkpart primary ext4 1MiB 100%"
        log "INFO" "  sudo mkfs.ext4 ${LFS_DISK}1"
        log "INFO" "  sudo mount ${LFS_DISK}1 $LFS"
    else
        log "INFO" "Using existing mount point: $LFS"
    fi
    
    # Verify mount point is available
    if ! mountpoint -q "$LFS" 2>/dev/null; then
        log "WARN" "LFS directory is not a mount point: $LFS"
        log "INFO" "Assuming build-in-place (not recommended for production)"
    fi
    
    # Create basic directory structure
    sudo mkdir -p "$LFS"/{etc,var,usr,home,mnt,opt,srv}
    sudo mkdir -p "$LFS"/usr/{bin,lib,sbin}
    sudo mkdir -p "$LFS"/var/{log,lib,cache,tmp}
    
    log "INFO" "Phase 2 completed successfully"
    save_build_state "partitions-complete"
}

# Phase 3: Cross-compilation toolchain
phase_cross_tools() {
    log "INFO" "Starting Phase 3: Cross-compilation toolchain"
    save_build_state "cross-tools-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would build cross-compilation toolchain"
        return 0
    fi
    
    # Create tools directory
    sudo mkdir -p "$LFS/tools"
    sudo ln -sf "$LFS/tools" /
    
    # Build cross-compilation tools
    local cross_packages=(
        "binutils-2.41"
        "gcc-13.2.0-pass1"
        "linux-6.1.11-api-headers"
        "glibc-2.38"
        "libstdc++-13.2.0"
    )
    
    for package in "${cross_packages[@]}"; do
        log "INFO" "Building cross-tool: $package"
        export CURRENT_PACKAGE="$package"
        
        # Call individual package build script
        if [[ -f "$LFS_TOOLKIT_DIR/scripts/build-$package.sh" ]]; then
            bash "$LFS_TOOLKIT_DIR/scripts/build-$package.sh" 2>&1 | tee "$LOG_DIR/build-$package.log"
        else
            log "WARN" "Build script not found for $package, using generic builder"
            bash "$LFS_TOOLKIT_DIR/scripts/generic-builder.sh" "$package" 2>&1 | tee "$LOG_DIR/build-$package.log"
        fi
        
        log "INFO" "Completed building: $package"
    done
    
    log "INFO" "Phase 3 completed successfully"
    save_build_state "cross-tools-complete"
}

# Phase 4: Temporary system build
phase_temp_system() {
    log "INFO" "Starting Phase 4: Temporary system build"
    save_build_state "temp-system-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would build temporary system"
        return 0
    fi
    
    # Switch to LFS user for building
    sudo -u lfs bash << 'EOF'
# Source LFS environment
source ~/.bashrc

# Build temporary system packages
TEMP_PACKAGES=(
    "m4-1.4.19"
    "ncurses-6.4"
    "bash-5.2.15"
    "coreutils-9.3"
    "diffutils-3.10"
    "file-5.45"
    "findutils-4.9.0"
    "gawk-5.2.2"
    "grep-3.11"
    "gzip-1.12"
    "make-4.4.1"
    "patch-2.7.6"
    "sed-4.9"
    "tar-1.35"
    "xz-5.4.4"
    "binutils-2.41-pass2"
    "gcc-13.2.0-pass2"
)

for package in "${TEMP_PACKAGES[@]}"; do
    echo "Building temporary package: $package"
    export CURRENT_PACKAGE="$package"
    
    # Build each package
    if [[ -f "/opt/lfs-toolkit/scripts/build-temp-$package.sh" ]]; then
        bash "/opt/lfs-toolkit/scripts/build-temp-$package.sh"
    else
        bash "/opt/lfs-toolkit/scripts/generic-temp-builder.sh" "$package"
    fi
done
EOF
    
    log "INFO" "Phase 4 completed successfully"
    save_build_state "temp-system-complete"
}

# Phase 5: Final LFS system build
phase_final_system() {
    log "INFO" "Starting Phase 5: Final LFS system build"
    save_build_state "final-system-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would build final LFS system"
        return 0
    fi
    
    # Enter chroot environment and build final system
    log "INFO" "Entering chroot environment for final system build"
    
    # Prepare for chroot
    sudo mount --bind /dev "$LFS/dev"
    sudo mount -t devpts devpts "$LFS/dev/pts" -o gid=5,mode=620
    sudo mount -t proc proc "$LFS/proc"
    sudo mount -t sysfs sysfs "$LFS/sys"
    sudo mount -t tmpfs tmpfs "$LFS/run"
    
    # Copy build scripts into chroot
    sudo cp -r "$LFS_TOOLKIT_DIR/scripts" "$LFS/tmp/"
    
    # Enter chroot and build final system
    sudo chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM="$TERM" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin \
        /bin/bash << 'EOF'
# Build final system packages
source /tmp/scripts/final-system-packages.sh
build_final_system_packages
EOF
    
    log "INFO" "Phase 5 completed successfully"
    save_build_state "final-system-complete"
}

# Phase 6: System configuration
phase_system_config() {
    log "INFO" "Starting Phase 6: System configuration"
    save_build_state "system-config-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would configure system"
        return 0
    fi
    
    # Configure system in chroot
    sudo chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM="$TERM" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin \
        /bin/bash << 'EOF'
# Configure system
bash /tmp/scripts/configure-system.sh
EOF
    
    log "INFO" "Phase 6 completed successfully"
    save_build_state "system-config-complete"
}

# Phase 7: Bootloader installation
phase_bootloader() {
    log "INFO" "Starting Phase 7: Bootloader installation"
    save_build_state "bootloader-start"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would install bootloader"
        return 0
    fi
    
    # Install bootloader
    sudo chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM="$TERM" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin \
        /bin/bash << 'EOF'
# Install and configure GRUB
bash /tmp/scripts/install-bootloader.sh
EOF
    
    log "INFO" "Phase 7 completed successfully"
    save_build_state "bootloader-complete"
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

# Function to run a specific build phase
run_phase() {
    local phase="$1"
    
    case "$phase" in
        "host-prep")
            phase_host_prep
            ;;
        "partitions")
            phase_partitions
            ;;
        "cross-tools")
            phase_cross_tools
            ;;
        "temp-system")
            phase_temp_system
            ;;
        "final-system")
            phase_final_system
            ;;
        "system-config")
            phase_system_config
            ;;
        "bootloader")
            phase_bootloader
            ;;
        *)
            log "ERROR" "Unknown build phase: $phase"
            exit 1
            ;;
    esac
}

# Function to run full build process
run_full_build() {
    log "INFO" "Starting full LFS build process"
    local start_time=$(date +%s)
    
    save_build_state "full-build-start"
    
    # Run all phases in sequence
    for phase in "host-prep" "partitions" "cross-tools" "temp-system" "final-system" "system-config" "bootloader"; do
        log "INFO" "Executing phase: $phase - ${BUILD_PHASES[$phase]}"
        run_phase "$phase"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    log "INFO" "Full LFS build completed successfully!"
    log "INFO" "Total build time: ${hours}h ${minutes}m ${seconds}s"
    log "INFO" "LFS system ready at: $LFS"
    
    save_build_state "full-build-complete"
}

# =============================================================================
# COMMAND LINE ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                FULL_BUILD=true
                shift
                ;;
            --phase=*)
                PHASE="${1#*=}"
                shift
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            --log-dir=*)
                LOG_DIR="${1#*=}"
                shift
                ;;
            --resume-from=*)
                RESUME_FROM="${1#*=}"
                shift
                ;;
            --package-list=*)
                PACKAGE_LIST="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate arguments
    if [[ "$FULL_BUILD" == false ]] && [[ -z "$PHASE" ]]; then
        log "ERROR" "Either --full or --phase must be specified"
        show_usage
        exit 1
    fi
    
    if [[ "$FULL_BUILD" == true ]] && [[ -n "$PHASE" ]]; then
        log "ERROR" "Cannot specify both --full and --phase"
        exit 1
    fi
    
    if [[ -n "$PHASE" ]] && [[ ! "${BUILD_PHASES[$PHASE]:-}" ]]; then
        log "ERROR" "Invalid phase: $PHASE"
        log "INFO" "Valid phases: ${!BUILD_PHASES[*]}"
        exit 1
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    # Set up error handling
    trap 'error_handler $LINENO' ERR
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize logging
    setup_logging
    
    log "INFO" "LFS Build Script v$SCRIPT_VERSION starting..."
    log "INFO" "Invoked as: $0 $*"
    
    # Load configuration
    load_config
    
    # Validate system
    validate_system
    
    # Execute requested build
    if [[ "$FULL_BUILD" == true ]]; then
        run_full_build
    else
        run_phase "$PHASE"
    fi
    
    log "INFO" "Build script completed successfully"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi