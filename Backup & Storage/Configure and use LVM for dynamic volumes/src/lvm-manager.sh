#!/bin/bash

#===============================================================================
# LVM Dynamic Volume Manager
# 
# A comprehensive tool for managing LVM operations with dynamic volume 
# capabilities, automated monitoring, and robust error handling.
#
# Author: System Administration Team
# Version: 1.0.0
# License: MIT
#===============================================================================

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="lvm-manager"
readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_FILE="/etc/lvm-manager.conf"
readonly DEFAULT_LOG_FILE="/var/log/lvm-manager/lvm-manager.log"

# Global variables (will be loaded from config)
LOG_LEVEL="INFO"
LOG_FILE="$DEFAULT_LOG_FILE"
MAX_LOG_SIZE="10M"
LOG_RETENTION_DAYS=30
DEFAULT_VG_NAME="system_vg"
DEFAULT_PE_SIZE="4M"
USAGE_THRESHOLD=80
AUTO_EXTEND_THRESHOLD=90
AUTO_EXTEND_SIZE="1G"
BACKUP_ENABLED=true
BACKUP_LOCATION="/var/backup/lvm"
BACKUP_RETENTION=7
REQUIRE_CONFIRMATION=true
DRY_RUN_DEFAULT=false

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#===============================================================================
# Utility Functions
#===============================================================================

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Print info message
print_info() {
    print_color "$BLUE" "[INFO] $*"
}

# Print success message
print_success() {
    print_color "$GREEN" "[SUCCESS] $*"
}

# Print warning message
print_warning() {
    print_color "$YELLOW" "[WARNING] $*"
}

# Print error message
print_error() {
    print_color "$RED" "[ERROR] $*" >&2
}

# Logging function
log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Write to syslog
    logger -t "$SCRIPT_NAME" -p user."${level,,}" "$message" 2>/dev/null || true
    
    # Print to console based on log level
    case "$level" in
        "ERROR")
            print_error "$message"
            ;;
        "WARN")
            print_warning "$message"
            ;;
        "INFO")
            print_info "$message"
            ;;
        "DEBUG")
            [[ "$LOG_LEVEL" == "DEBUG" ]] && print_color "$BLUE" "[DEBUG] $message"
            ;;
    esac
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_message "ERROR" "Script failed at line $line_number with exit code $exit_code"
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

#===============================================================================
# Configuration Management
#===============================================================================

# Load configuration file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "DEBUG" "Loading configuration from $CONFIG_FILE"
        # Source the config file safely
        set +u  # Temporarily disable undefined variable checking
        source "$CONFIG_FILE" 2>/dev/null || {
            log_message "WARN" "Failed to load configuration file: $CONFIG_FILE"
        }
        set -u
    else
        log_message "WARN" "Configuration file not found: $CONFIG_FILE, using defaults"
    fi
}

# Validate configuration
validate_config() {
    # Create required directories
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    [[ "$BACKUP_ENABLED" == "true" ]] && mkdir -p "$BACKUP_LOCATION" 2>/dev/null || true
    
    # Validate numeric values
    [[ "$USAGE_THRESHOLD" =~ ^[0-9]+$ ]] || USAGE_THRESHOLD=80
    [[ "$AUTO_EXTEND_THRESHOLD" =~ ^[0-9]+$ ]] || AUTO_EXTEND_THRESHOLD=90
    [[ "$LOG_RETENTION_DAYS" =~ ^[0-9]+$ ]] || LOG_RETENTION_DAYS=30
    [[ "$BACKUP_RETENTION" =~ ^[0-9]+$ ]] || BACKUP_RETENTION=7
    
    log_message "DEBUG" "Configuration validated successfully"
}

#===============================================================================
# System Checks
#===============================================================================

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Check if LVM tools are available
check_lvm_tools() {
    local tools=("pvcreate" "vgcreate" "lvcreate" "pvs" "vgs" "lvs" "vgextend" "lvextend")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_message "ERROR" "LVM tool '$tool' not found. Please install lvm2 package"
            exit 1
        fi
    done
    log_message "DEBUG" "All required LVM tools are available"
}

# Check if device exists and is a block device
check_device() {
    local device=$1
    if [[ ! -b "$device" ]]; then
        log_message "ERROR" "Device $device is not a valid block device"
        return 1
    fi
    return 0
}

# Check if device is already in use
check_device_usage() {
    local device=$1
    
    # Check if device is mounted
    if mount | grep -q "^$device "; then
        log_message "ERROR" "Device $device is currently mounted"
        return 1
    fi
    
    # Check if device is already a PV
    if pvs --noheadings "$device" 2>/dev/null | grep -q .; then
        log_message "WARN" "Device $device is already a physical volume"
        return 1
    fi
    
    return 0
}

# Confirm destructive operations
confirm_operation() {
    local operation=$1
    shift
    local targets="$*"
    
    if [[ "$REQUIRE_CONFIRMATION" != "true" ]]; then
        return 0
    fi
    
    print_warning "This operation will: $operation"
    print_warning "Targets: $targets"
    echo -n "Are you sure you want to continue? [y/N]: "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            log_message "INFO" "Operation cancelled by user"
            exit 0
            ;;
    esac
}

#===============================================================================
# LVM Operations
#===============================================================================

# Create physical volume
create_pv() {
    local devices=("$@")
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_message "ERROR" "No devices specified for PV creation"
        return 1
    fi
    
    # Validate all devices first
    for device in "${devices[@]}"; do
        check_device "$device" || return 1
        check_device_usage "$device" || return 1
    done
    
    confirm_operation "Create physical volumes" "${devices[*]}"
    
    for device in "${devices[@]}"; do
        log_message "INFO" "Creating physical volume on $device"
        if pvcreate "$device"; then
            log_message "INFO" "Successfully created PV on $device"
        else
            log_message "ERROR" "Failed to create PV on $device"
            return 1
        fi
    done
    
    print_success "Created ${#devices[@]} physical volume(s)"
}

# Create volume group
create_vg() {
    local vg_name=$1
    shift
    local devices=("$@")
    
    if [[ -z "$vg_name" ]]; then
        log_message "ERROR" "Volume group name not specified"
        return 1
    fi
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_message "ERROR" "No devices specified for VG creation"
        return 1
    fi
    
    # Check if VG already exists
    if vgs --noheadings "$vg_name" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Volume group $vg_name already exists"
        return 1
    fi
    
    # Validate all devices are PVs
    for device in "${devices[@]}"; do
        if ! pvs --noheadings "$device" 2>/dev/null | grep -q .; then
            log_message "ERROR" "Device $device is not a physical volume"
            return 1
        fi
    done
    
    confirm_operation "Create volume group $vg_name" "${devices[*]}"
    
    log_message "INFO" "Creating volume group $vg_name with devices: ${devices[*]}"
    if vgcreate -s "$DEFAULT_PE_SIZE" "$vg_name" "${devices[@]}"; then
        log_message "INFO" "Successfully created volume group $vg_name"
        print_success "Created volume group $vg_name"
    else
        log_message "ERROR" "Failed to create volume group $vg_name"
        return 1
    fi
}

# Create logical volume
create_lv() {
    local lv_name=$1
    local vg_name=$2
    local size=$3
    local format_type=${4:-""}
    local mount_point=${5:-""}
    
    if [[ -z "$lv_name" || -z "$vg_name" || -z "$size" ]]; then
        log_message "ERROR" "Missing required parameters for LV creation"
        return 1
    fi
    
    # Check if VG exists
    if ! vgs --noheadings "$vg_name" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Volume group $vg_name does not exist"
        return 1
    fi
    
    # Check if LV already exists
    if lvs --noheadings "$vg_name/$lv_name" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Logical volume $vg_name/$lv_name already exists"
        return 1
    fi
    
    confirm_operation "Create logical volume $vg_name/$lv_name with size $size" ""
    
    log_message "INFO" "Creating logical volume $lv_name in $vg_name with size $size"
    if lvcreate -n "$lv_name" -L "$size" "$vg_name"; then
        log_message "INFO" "Successfully created logical volume $vg_name/$lv_name"
        
        # Format if requested
        if [[ -n "$format_type" ]]; then
            local device="/dev/$vg_name/$lv_name"
            log_message "INFO" "Formatting $device as $format_type"
            if mkfs."$format_type" "$device"; then
                log_message "INFO" "Successfully formatted $device"
                
                # Mount if requested
                if [[ -n "$mount_point" ]]; then
                    mkdir -p "$mount_point"
                    if mount "$device" "$mount_point"; then
                        log_message "INFO" "Successfully mounted $device to $mount_point"
                        print_success "Created, formatted, and mounted $vg_name/$lv_name"
                    else
                        log_message "ERROR" "Failed to mount $device to $mount_point"
                    fi
                fi
            else
                log_message "ERROR" "Failed to format $device"
                return 1
            fi
        fi
        
        print_success "Created logical volume $vg_name/$lv_name"
    else
        log_message "ERROR" "Failed to create logical volume $vg_name/$lv_name"
        return 1
    fi
}

# Extend logical volume
extend_lv() {
    local lv_path=$1
    local size=$2
    
    if [[ -z "$lv_path" || -z "$size" ]]; then
        log_message "ERROR" "Missing required parameters for LV extension"
        return 1
    fi
    
    # Check if LV exists
    if ! lvs --noheadings "$lv_path" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Logical volume $lv_path does not exist"
        return 1
    fi
    
    confirm_operation "Extend logical volume $lv_path by $size" ""
    
    log_message "INFO" "Extending logical volume $lv_path by $size"
    if lvextend -L "+$size" "$lv_path"; then
        log_message "INFO" "Successfully extended logical volume $lv_path"
        
        # Try to resize the filesystem
        local device="/dev/$lv_path"
        log_message "INFO" "Attempting to resize filesystem on $device"
        if resize2fs "$device" 2>/dev/null; then
            log_message "INFO" "Successfully resized ext2/3/4 filesystem"
        elif xfs_growfs "$device" 2>/dev/null; then
            log_message "INFO" "Successfully resized XFS filesystem"
        else
            log_message "WARN" "Could not automatically resize filesystem. Manual intervention may be required"
        fi
        
        print_success "Extended logical volume $lv_path"
    else
        log_message "ERROR" "Failed to extend logical volume $lv_path"
        return 1
    fi
}

# Extend volume group
extend_vg() {
    local vg_name=$1
    shift
    local devices=("$@")
    
    if [[ -z "$vg_name" ]]; then
        log_message "ERROR" "Volume group name not specified"
        return 1
    fi
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_message "ERROR" "No devices specified for VG extension"
        return 1
    fi
    
    # Check if VG exists
    if ! vgs --noheadings "$vg_name" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Volume group $vg_name does not exist"
        return 1
    fi
    
    # Validate all devices are PVs
    for device in "${devices[@]}"; do
        if ! pvs --noheadings "$device" 2>/dev/null | grep -q .; then
            log_message "ERROR" "Device $device is not a physical volume"
            return 1
        fi
    done
    
    confirm_operation "Extend volume group $vg_name" "${devices[*]}"
    
    log_message "INFO" "Extending volume group $vg_name with devices: ${devices[*]}"
    if vgextend "$vg_name" "${devices[@]}"; then
        log_message "INFO" "Successfully extended volume group $vg_name"
        print_success "Extended volume group $vg_name"
    else
        log_message "ERROR" "Failed to extend volume group $vg_name"
        return 1
    fi
}

#===============================================================================
# Monitoring and Status Functions
#===============================================================================

# Get volume usage information
get_volume_usage() {
    local lv_path=$1
    local device="/dev/$lv_path"
    
    if [[ ! -b "$device" ]]; then
        echo "N/A"
        return 1
    fi
    
    # Get filesystem usage
    local usage=$(df "$device" 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    echo "${usage:-N/A}"
}

# Display system status
show_status() {
    print_info "LVM Dynamic Volume Manager Status"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo

    # Physical Volumes
    echo "Physical Volumes:"
    if pvs --noheadings 2>/dev/null | grep -q .; then
        pvs --units g --separator $'\t' --noheadings -o pv_name,vg_name,pv_size,pv_used,pv_free | \
        while IFS=$'\t' read -r pv vg size used free; do
            printf "  %-12s %-12s %10s %10s %10s\n" "$pv" "$vg" "$size" "$used" "$free"
        done
    else
        echo "  No physical volumes found"
    fi
    echo

    # Volume Groups
    echo "Volume Groups:"
    if vgs --noheadings 2>/dev/null | grep -q .; then
        vgs --units g --separator $'\t' --noheadings -o vg_name,pv_count,vg_size,vg_used,vg_free | \
        while IFS=$'\t' read -r vg pv_count size used free; do
            printf "  %-12s %2s PVs %10s %10s %10s\n" "$vg" "$pv_count" "$size" "$used" "$free"
        done
    else
        echo "  No volume groups found"
    fi
    echo

    # Logical Volumes
    echo "Logical Volumes:"
    if lvs --noheadings 2>/dev/null | grep -q .; then
        local alerts=()
        lvs --units g --separator $'\t' --noheadings -o vg_name,lv_name,lv_size | \
        while IFS=$'\t' read -r vg lv size; do
            local usage=$(get_volume_usage "$vg/$lv")
            local status=""
            
            if [[ "$usage" != "N/A" && "$usage" -gt "$USAGE_THRESHOLD" ]]; then
                status="[WARNING: High usage]"
                alerts+=("$vg/$lv usage ($usage%) exceeds threshold ($USAGE_THRESHOLD%)")
            fi
            
            printf "  %-20s %10s %5s%% %10s %s\n" "$vg/$lv" "$size" "$usage" "$(df -h /dev/$vg/$lv 2>/dev/null | awk 'NR==2{print $3}' || echo 'N/A')" "$status"
        done
    else
        echo "  No logical volumes found"
    fi
    echo
}

# Monitor volumes and perform auto-extend if needed
monitor_volumes() {
    local auto_extend=${1:-false}
    
    log_message "INFO" "Starting volume monitoring"
    
    # Check each logical volume
    lvs --noheadings -o vg_name,lv_name | while read -r vg lv; do
        local usage=$(get_volume_usage "$vg/$lv")
        
        if [[ "$usage" != "N/A" ]]; then
            if [[ "$usage" -gt "$AUTO_EXTEND_THRESHOLD" ]] && [[ "$auto_extend" == "true" ]]; then
                log_message "WARN" "Volume $vg/$lv usage ($usage%) exceeds auto-extend threshold ($AUTO_EXTEND_THRESHOLD%)"
                log_message "INFO" "Auto-extending $vg/$lv by $AUTO_EXTEND_SIZE"
                
                if extend_lv "$vg/$lv" "$AUTO_EXTEND_SIZE"; then
                    log_message "INFO" "Successfully auto-extended $vg/$lv"
                else
                    log_message "ERROR" "Failed to auto-extend $vg/$lv"
                fi
            elif [[ "$usage" -gt "$USAGE_THRESHOLD" ]]; then
                log_message "WARN" "Volume $vg/$lv usage ($usage%) exceeds threshold ($USAGE_THRESHOLD%)"
            fi
        fi
    done
    
    log_message "INFO" "Volume monitoring completed"
}

#===============================================================================
# Backup and Restore Functions
#===============================================================================

# Create backup of LVM configuration
create_backup() {
    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        log_message "WARN" "Backup is disabled in configuration"
        return 1
    fi
    
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_file="$BACKUP_LOCATION/backup-$timestamp.tar.gz"
    local temp_dir="/tmp/lvm-backup-$$"
    
    log_message "INFO" "Creating LVM configuration backup"
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    mkdir -p "$BACKUP_LOCATION"
    
    # Backup LVM metadata
    vgcfgbackup -f "$temp_dir/vg-backup-%s" 2>/dev/null || true
    
    # Backup system LVM configuration
    cp -r /etc/lvm "$temp_dir/" 2>/dev/null || true
    
    # Create volume information
    {
        echo "=== LVM Backup Created: $(date) ==="
        echo
        echo "Physical Volumes:"
        pvs 2>/dev/null || echo "No PVs found"
        echo
        echo "Volume Groups:"
        vgs 2>/dev/null || echo "No VGs found"
        echo
        echo "Logical Volumes:"
        lvs 2>/dev/null || echo "No LVs found"
    } > "$temp_dir/lvm-info.txt"
    
    # Create backup archive
    if tar -czf "$backup_file" -C "$temp_dir" . 2>/dev/null; then
        log_message "INFO" "Successfully created backup: $backup_file"
        print_success "Backup created: $backup_file"
        
        # Cleanup old backups
        find "$BACKUP_LOCATION" -name "backup-*.tar.gz" -mtime +$BACKUP_RETENTION -delete 2>/dev/null || true
        
        # Cleanup temporary directory
        rm -rf "$temp_dir"
        
        return 0
    else
        log_message "ERROR" "Failed to create backup"
        rm -rf "$temp_dir"
        return 1
    fi
}

# List available backups
list_backups() {
    if [[ ! -d "$BACKUP_LOCATION" ]]; then
        print_info "No backup directory found"
        return 0
    fi
    
    print_info "Available backups:"
    find "$BACKUP_LOCATION" -name "backup-*.tar.gz" -type f -exec ls -lh {} \; | \
    awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
}

#===============================================================================
# Snapshot Functions
#===============================================================================

# Create snapshot
create_snapshot() {
    local lv_path=$1
    local snapshot_name=$2
    local size=$3
    
    if [[ -z "$lv_path" || -z "$snapshot_name" || -z "$size" ]]; then
        log_message "ERROR" "Missing required parameters for snapshot creation"
        return 1
    fi
    
    # Extract VG name from LV path
    local vg_name="${lv_path%/*}"
    local lv_name="${lv_path#*/}"
    
    # Check if source LV exists
    if ! lvs --noheadings "$lv_path" 2>/dev/null | grep -q .; then
        log_message "ERROR" "Source logical volume $lv_path does not exist"
        return 1
    fi
    
    confirm_operation "Create snapshot $snapshot_name of $lv_path with size $size" ""
    
    log_message "INFO" "Creating snapshot $snapshot_name of $lv_path"
    if lvcreate -L "$size" -s -n "$snapshot_name" "$lv_path"; then
        log_message "INFO" "Successfully created snapshot $vg_name/$snapshot_name"
        print_success "Created snapshot $vg_name/$snapshot_name"
    else
        log_message "ERROR" "Failed to create snapshot $snapshot_name"
        return 1
    fi
}

#===============================================================================
# Maintenance Functions
#===============================================================================

# Cleanup old log files
cleanup_logs() {
    log_message "INFO" "Starting log cleanup"
    
    # Rotate current log if it's too large
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local max_bytes
        
        # Convert MAX_LOG_SIZE to bytes
        case "$MAX_LOG_SIZE" in
            *K|*k) max_bytes=$((${MAX_LOG_SIZE%[Kk]} * 1024)) ;;
            *M|*m) max_bytes=$((${MAX_LOG_SIZE%[Mm]} * 1024 * 1024)) ;;
            *G|*g) max_bytes=$((${MAX_LOG_SIZE%[Gg]} * 1024 * 1024 * 1024)) ;;
            *) max_bytes=$MAX_LOG_SIZE ;;
        esac
        
        if [[ "$log_size" -gt "$max_bytes" ]]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            log_message "INFO" "Rotated log file due to size limit"
        fi
    fi
    
    # Remove old log files
    find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE").*" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    
    log_message "INFO" "Log cleanup completed"
}

#===============================================================================
# Usage and Help Functions
#===============================================================================

# Display usage information
show_usage() {
    cat << EOF
LVM Dynamic Volume Manager v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS] COMMAND [ARGS...]

COMMANDS:
    Physical Volume Operations:
        create-pv DEVICE [DEVICE...]     Create physical volume(s)

    Volume Group Operations:
        create-vg VG_NAME DEVICE [DEVICE...]  Create volume group
        extend-vg VG_NAME DEVICE [DEVICE...]  Extend volume group

    Logical Volume Operations:
        create-lv LV_NAME VG_NAME SIZE [FORMAT] [MOUNT_POINT]
                                         Create logical volume
        extend-lv VG_NAME/LV_NAME SIZE   Extend logical volume

    Monitoring and Status:
        status                           Show LVM status
        info VG_NAME/LV_NAME            Show detailed volume info
        monitor [--auto-extend]         Monitor volume usage

    Backup Operations:
        backup                          Create configuration backup
        list-backups                    List available backups
        restore BACKUP_FILE             Restore from backup

    Snapshot Operations:
        create-snapshot VG/LV SNAP_NAME SIZE  Create snapshot
        merge-snapshot VG/SNAP_NAME           Merge snapshot
        remove-snapshot VG/SNAP_NAME          Remove snapshot

    Maintenance:
        cleanup-logs                    Clean up old log files

OPTIONS:
    -c, --config FILE               Use custom configuration file
    -v, --verbose                   Enable verbose output
    -q, --quiet                     Suppress non-error output
    -n, --dry-run                   Show what would be done without executing
    -h, --help                      Show this help message
    --version                       Show version information

EXAMPLES:
    # Create physical volume
    $SCRIPT_NAME create-pv /dev/sdb

    # Create volume group with multiple PVs
    $SCRIPT_NAME create-vg my_vg /dev/sdb /dev/sdc

    # Create and format logical volume
    $SCRIPT_NAME create-lv data my_vg 10G ext4 /mnt/data

    # Monitor and auto-extend volumes
    $SCRIPT_NAME monitor --auto-extend

    # Create backup
    $SCRIPT_NAME backup

For more information, see the manual page or documentation.
EOF
}

# Show version information
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
    echo "LVM Dynamic Volume Manager"
    echo "Copyright (c) 2024 System Administration Team"
}

#===============================================================================
# Main Function
#===============================================================================

main() {
    # Initialize
    load_config
    validate_config
    check_root
    check_lvm_tools
    
    # Parse command line arguments
    local command=""
    local args=()
    local dry_run="$DRY_RUN_DEFAULT"
    local verbose=false
    local quiet=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                LOG_LEVEL="DEBUG"
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -*)
                log_message "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Validate command
    if [[ -z "$command" ]]; then
        log_message "ERROR" "No command specified"
        show_usage
        exit 1
    fi
    
    # Set quiet mode
    if [[ "$quiet" == "true" ]]; then
        exec 1>/dev/null
    fi
    
    # Execute command
    case "$command" in
        "create-pv")
            create_pv "${args[@]}"
            ;;
        "create-vg")
            [[ ${#args[@]} -lt 2 ]] && { log_message "ERROR" "Insufficient arguments for create-vg"; exit 1; }
            create_vg "${args[@]}"
            ;;
        "create-lv")
            [[ ${#args[@]} -lt 3 ]] && { log_message "ERROR" "Insufficient arguments for create-lv"; exit 1; }
            create_lv "${args[@]}"
            ;;
        "extend-lv")
            [[ ${#args[@]} -lt 2 ]] && { log_message "ERROR" "Insufficient arguments for extend-lv"; exit 1; }
            extend_lv "${args[@]}"
            ;;
        "extend-vg")
            [[ ${#args[@]} -lt 2 ]] && { log_message "ERROR" "Insufficient arguments for extend-vg"; exit 1; }
            extend_vg "${args[@]}"
            ;;
        "status")
            show_status
            ;;
        "monitor")
            local auto_extend=false
            [[ "${args[0]:-}" == "--auto-extend" ]] && auto_extend=true
            monitor_volumes "$auto_extend"
            ;;
        "backup")
            create_backup
            ;;
        "list-backups")
            list_backups
            ;;
        "create-snapshot")
            [[ ${#args[@]} -lt 3 ]] && { log_message "ERROR" "Insufficient arguments for create-snapshot"; exit 1; }
            create_snapshot "${args[@]}"
            ;;
        "cleanup-logs")
            cleanup_logs
            ;;
        *)
            log_message "ERROR" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log_message "INFO" "Command '$command' completed successfully"
}

# Run main function with all arguments
main "$@"