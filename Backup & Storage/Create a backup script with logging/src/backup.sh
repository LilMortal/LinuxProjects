#!/bin/bash

#
# Linux Backup Manager
# A comprehensive backup script with logging, rotation, and automation
#
# Author: [Your Name]
# Version: 1.0.0
# License: MIT
#

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Script configuration
SCRIPT_NAME="backup-manager"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"

# Default configuration
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/../config/backup.conf"
CONFIG_FILE="${BACKUP_CONFIG:-$DEFAULT_CONFIG_FILE}"
DRY_RUN=false
VERBOSE=false
FORCE_NOTIFY=false

# Logging setup
LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR")
LOG_LEVEL="${BACKUP_LOG_LEVEL:-INFO}"
LOG_FILE=""
SYSLOG_TAG="backup-manager"

# Default backup settings (can be overridden by config file)
BACKUP_SOURCES=""
BACKUP_DESTINATION=""
BACKUP_PREFIX="backup"
COMPRESSION="gzip"
RETENTION_DAYS=30
VERIFY_CHECKSUMS=true
ENABLE_EMAIL_NOTIFICATIONS=false
EMAIL_RECIPIENT=""

# Runtime variables
START_TIME=""
BACKUP_FILE=""
BACKUP_SIZE=""
TEMP_DIR=""

#
# Logging functions
#

log_level_to_number() {
    case "$1" in
        "DEBUG") echo 0 ;;
        "INFO")  echo 1 ;;
        "WARN")  echo 2 ;;
        "ERROR") echo 3 ;;
        *) echo 1 ;;
    esac
}

should_log() {
    local level="$1"
    local current_level_num=$(log_level_to_number "$LOG_LEVEL")
    local message_level_num=$(log_level_to_number "$level")
    
    [ "$message_level_num" -ge "$current_level_num" ]
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] $level: $message"
    
    # Only log if level is appropriate
    if ! should_log "$level"; then
        return 0
    fi
    
    # Console output (if verbose or error/warning)
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "ERROR" ]] || [[ "$level" == "WARN" ]]; then
        echo "$log_entry" >&2
    fi
    
    # File logging
    if [[ -n "$LOG_FILE" ]] && [[ -w "$(dirname "$LOG_FILE")" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
    
    # Syslog integration
    local syslog_priority
    case "$level" in
        "DEBUG") syslog_priority="debug" ;;
        "INFO")  syslog_priority="info" ;;
        "WARN")  syslog_priority="warning" ;;
        "ERROR") syslog_priority="err" ;;
    esac
    logger -t "$SYSLOG_TAG" -p "user.$syslog_priority" "$message" 2>/dev/null || true
}

log_debug() { log_message "DEBUG" "$1"; }
log_info()  { log_message "INFO" "$1"; }
log_warn()  { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }

#
# Utility functions
#

cleanup() {
    local exit_code=$?
    
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        log_debug "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" || true
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
        send_notification "FAILURE" "Backup failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

create_temp_dir() {
    TEMP_DIR=$(mktemp -d -t "${SCRIPT_NAME}.XXXXXX")
    log_debug "Created temporary directory: $TEMP_DIR"
}

human_readable_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0
    local size=$bytes
    
    while (( size > 1024 && unit_index < ${#units[@]}-1 )); do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    echo "${size} ${units[unit_index]}"
}

check_dependencies() {
    local missing_deps=()
    local required_commands=("tar" "sha256sum" "date" "logger")
    
    # Add compression tools based on configuration
    case "$COMPRESSION" in
        "gzip")  required_commands+=("gzip") ;;
        "bzip2") required_commands+=("bzip2") ;;
        "xz")    required_commands+=("xz") ;;
    esac
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing packages and try again"
        exit 1
    fi
    
    log_debug "All dependencies are available"
}

#
# Configuration functions
#

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "Loading configuration from: $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        log_warn "Configuration file not found: $CONFIG_FILE"
        log_warn "Using default configuration"
    fi
    
    # Validate required configuration
    if [[ -z "$BACKUP_SOURCES" ]]; then
        log_error "BACKUP_SOURCES not specified in configuration"
        exit 1
    fi
    
    if [[ -z "$BACKUP_DESTINATION" ]]; then
        log_error "BACKUP_DESTINATION not specified in configuration"
        exit 1
    fi
    
    # Ensure log directory exists
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir=$(dirname "$LOG_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" || {
                log_warn "Could not create log directory: $log_dir"
                LOG_FILE=""
            }
        fi
    fi
}

validate_config() {
    log_debug "Validating configuration"
    
    # Check if source directories exist
    local missing_sources=()
    for source in $BACKUP_SOURCES; do
        if [[ ! -e "$source" ]]; then
            missing_sources+=("$source")
        fi
    done
    
    if [[ ${#missing_sources[@]} -gt 0 ]]; then
        log_warn "Some backup sources do not exist: ${missing_sources[*]}"
    fi
    
    # Check/create destination directory
    if [[ ! -d "$BACKUP_DESTINATION" ]]; then
        log_info "Creating backup destination directory: $BACKUP_DESTINATION"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$BACKUP_DESTINATION" || {
                log_error "Could not create backup destination: $BACKUP_DESTINATION"
                exit 1
            }
        fi
    fi
    
    # Validate compression method
    case "$COMPRESSION" in
        "gzip"|"bzip2"|"xz"|"none") ;;
        *) 
            log_error "Invalid compression method: $COMPRESSION"
            log_error "Supported methods: gzip, bzip2, xz, none"
            exit 1
            ;;
    esac
    
    # Validate retention days
    if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$RETENTION_DAYS" -lt 1 ]]; then
        log_error "Invalid retention days: $RETENTION_DAYS (must be positive integer)"
        exit 1
    fi
    
    log_debug "Configuration validation completed"
}

#
# Backup functions
#

calculate_source_size() {
    local total_size=0
    
    log_debug "Calculating source size"
    
    for source in $BACKUP_SOURCES; do
        if [[ -e "$source" ]]; then
            local size=$(du -sb "$source" 2>/dev/null | cut -f1 || echo "0")
            total_size=$((total_size + size))
            log_debug "Source $source: $(human_readable_size $size)"
        fi
    done
    
    log_debug "Total source size: $(human_readable_size $total_size)"
    echo "$total_size"
}

generate_backup_filename() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local extension=""
    
    case "$COMPRESSION" in
        "gzip")  extension=".tar.gz" ;;
        "bzip2") extension=".tar.bz2" ;;
        "xz")    extension=".tar.xz" ;;
        "none")  extension=".tar" ;;
    esac
    
    echo "${BACKUP_PREFIX}_${timestamp}${extension}"
}

create_backup() {
    local backup_filename=$(generate_backup_filename)
    BACKUP_FILE="$BACKUP_DESTINATION/$backup_filename"
    
    log_info "Creating backup: $backup_filename"
    
    if [[ "$DRY_RUN" == true ]]; then
        local estimated_size=$(calculate_source_size)
        # Rough estimation: compressed size is typically 30-70% of original
        local estimated_compressed=$((estimated_size * 50 / 100))
        log_info "[DRY RUN] Would create backup: $BACKUP_FILE"
        log_info "[DRY RUN] Estimated compressed size: $(human_readable_size $estimated_compressed)"
        return 0
    fi
    
    # Create tar command based on compression
    local tar_cmd="tar -cf"
    case "$COMPRESSION" in
        "gzip")  tar_cmd="tar -czf" ;;
        "bzip2") tar_cmd="tar -cjf" ;;
        "xz")    tar_cmd="tar -cJf" ;;
        "none")  tar_cmd="tar -cf" ;;
    esac
    
    # Add verbose flag if enabled
    if [[ "$VERBOSE" == true ]]; then
        tar_cmd="${tar_cmd}v"
    fi
    
    # Execute backup
    log_debug "Executing: $tar_cmd \"$BACKUP_FILE\" $BACKUP_SOURCES"
    
    if $tar_cmd "$BACKUP_FILE" $BACKUP_SOURCES 2>&1 | while IFS= read -r line; do
        log_debug "tar: $line"
    done; then
        BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
        log_info "Backup created successfully ($(human_readable_size $BACKUP_SIZE))"
    else
        log_error "Backup creation failed"
        exit 1
    fi
}

generate_checksum() {
    if [[ "$VERIFY_CHECKSUMS" != true ]] || [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    log_info "Generating SHA256 checksum"
    
    local checksum_file="${BACKUP_FILE}.sha256"
    local checksum=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
    
    echo "$checksum  $(basename "$BACKUP_FILE")" > "$checksum_file"
    log_info "Checksum: $checksum"
    log_debug "Checksum file created: $checksum_file"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups (retention: $RETENTION_DAYS days)"
    
    if [[ "$DRY_RUN" == true ]]; then
        local old_files=$(find "$BACKUP_DESTINATION" -name "${BACKUP_PREFIX}_*" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
        log_info "[DRY RUN] Would remove $old_files old backup files"
        return 0
    fi
    
    local removed_count=0
    local removed_size=0
    
    # Find and remove old backup files
    while IFS= read -r -d '' file; do
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        removed_size=$((removed_size + file_size))
        
        log_debug "Removing old backup: $(basename "$file")"
        rm -f "$file"
        
        # Also remove associated checksum file
        rm -f "${file}.sha256" 2>/dev/null || true
        
        ((removed_count++))
    done < <(find "$BACKUP_DESTINATION" -name "${BACKUP_PREFIX}_*" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    if [[ $removed_count -gt 0 ]]; then
        log_info "Removed $removed_count old backup files ($(human_readable_size $removed_size))"
    else
        log_debug "No old backups to remove"
    fi
}

#
# Notification functions
#

send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ "$ENABLE_EMAIL_NOTIFICATIONS" != true ]] && [[ "$FORCE_NOTIFY" != true ]]; then
        return 0
    fi
    
    if [[ -z "$EMAIL_RECIPIENT" ]]; then
        log_warn "Email notifications enabled but no recipient specified"
        return 0
    fi
    
    local subject="Backup $status - $(hostname)"
    local body="$message

Backup Details:
- Host: $(hostname)
- Timestamp: $(date)
- Sources: $BACKUP_SOURCES
- Destination: $BACKUP_DESTINATION"
    
    if [[ "$status" == "SUCCESS" ]] && [[ -n "$BACKUP_FILE" ]]; then
        body="$body
- Backup File: $(basename "$BACKUP_FILE")
- Backup Size: $(human_readable_size ${BACKUP_SIZE:-0})"
    fi
    
    # Try to send email using available mail command
    if command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null || {
            log_warn "Failed to send email notification"
        }
    elif command -v sendmail >/dev/null 2>&1; then
        {
            echo "To: $EMAIL_RECIPIENT"
            echo "Subject: $subject"
            echo ""
            echo "$body"
        } | sendmail "$EMAIL_RECIPIENT" 2>/dev/null || {
            log_warn "Failed to send email notification"
        }
    else
        log_warn "No mail command available for notifications"
    fi
}

#
# Main backup workflow
#

run_backup() {
    START_TIME=$(date +%s)
    
    log_info "Starting backup operation"
    log_info "Backup sources: $BACKUP_SOURCES"
    log_info "Backup destination: $BACKUP_DESTINATION"
    log_info "Compression: $COMPRESSION"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual backup will be performed"
        
        # Show what would be backed up
        echo "[DRY RUN] Would backup the following sources:"
        local total_size=0
        for source in $BACKUP_SOURCES; do
            if [[ -e "$source" ]]; then
                local size=$(du -sb "$source" 2>/dev/null | cut -f1 || echo "0")
                total_size=$((total_size + size))
                echo "  - $source ($(human_readable_size $size))"
            else
                echo "  - $source (NOT FOUND)"
            fi
        done
        
        local backup_filename=$(generate_backup_filename)
        echo "[DRY RUN] Destination: $BACKUP_DESTINATION/$backup_filename"
        
        local estimated_compressed=$((total_size * 50 / 100))
        echo "[DRY RUN] Estimated compressed size: $(human_readable_size $estimated_compressed)"
    fi
    
    # Perform backup steps
    create_temp_dir
    create_backup
    generate_checksum
    cleanup_old_backups
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] No actual backup was performed"
    else
        log_info "Backup completed successfully"
        log_info "Total backup time: $duration seconds"
        send_notification "SUCCESS" "Backup completed successfully in $duration seconds"
    fi
}

#
# Command line argument parsing
#

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Linux Backup Manager

Usage: $0 [OPTIONS]

Options:
  -c, --config FILE        Use custom configuration file
  -d, --destination DIR    Override backup destination
  -s, --source DIRS        Override backup sources (space-separated)
  -r, --retention DAYS     Override retention period
  --compression TYPE       Compression type (gzip|bzip2|xz|none)
  --dry-run               Show what would be backed up without doing it
  -v, --verbose           Enable verbose output
  --no-checksum           Skip checksum verification
  --notify                Force email notification
  -h, --help              Display this help message

Examples:
  $0 -c /etc/backup.conf
  $0 --dry-run -v
  $0 -d /mnt/external/backups -r 14
  $0 -s "/home/user /var/www" --compression bzip2

Configuration File:
  Default: $DEFAULT_CONFIG_FILE
  Override with: BACKUP_CONFIG environment variable

For more information, see the README.md file.
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--destination)
                BACKUP_DESTINATION="$2"
                shift 2
                ;;
            -s|--source)
                BACKUP_SOURCES="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --compression)
                COMPRESSION="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-checksum)
                VERIFY_CHECKSUMS=false
                shift
                ;;
            --notify)
                FORCE_NOTIFY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_error "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

#
# Main function
#

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load configuration
    load_config
    
    # Set log file after config is loaded
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="/var/log/${SCRIPT_NAME}/${SCRIPT_NAME}.log"
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    fi
    
    # Log startup information
    log_info "$SCRIPT_NAME v$SCRIPT_VERSION starting"
    log_debug "Script path: $SCRIPT_PATH"
    log_debug "Configuration file: $CONFIG_FILE"
    log_debug "Log level: $LOG_LEVEL"
    
    # Validate configuration
    validate_config
    
    # Check dependencies
    check_dependencies
    
    # Run the backup
    run_backup
    
    log_info "$SCRIPT_NAME completed successfully"
}

# Execute main function with all arguments
main "$@"