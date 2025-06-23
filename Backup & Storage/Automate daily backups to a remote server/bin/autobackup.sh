#!/bin/bash

# AutoBackup Pro - Automated Linux Backup System
# Version: 1.0.0
# Author: Your Name
# License: MIT

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Script information
readonly SCRIPT_NAME="AutoBackup Pro"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
readonly DEFAULT_CONFIG="/etc/autobackup/autobackup.conf"
readonly DEFAULT_LOG_DIR="/var/log/autobackup"
readonly DEFAULT_BACKUP_DIR="/var/lib/autobackup"

# Global variables
CONFIG_FILE="$DEFAULT_CONFIG"
VERBOSE=false
DRY_RUN=false
FORCE_BACKUP=false
SHOW_STATUS=false

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#######################################
# Print colored output to stderr
# Arguments:
#   $1: Color code
#   $2: Message
#######################################
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}" >&2
}

#######################################
# Log message with timestamp and level
# Arguments:
#   $1: Log level (DEBUG, INFO, WARN, ERROR)
#   $2: Message
#######################################
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file if directory exists
    if [[ -d "$DEFAULT_LOG_DIR" ]]; then
        echo "[$timestamp] $level: $message" >> "$DEFAULT_LOG_DIR/autobackup.log"
        
        # Write errors to separate error log
        if [[ "$level" == "ERROR" ]]; then
            echo "[$timestamp] ERROR: $message" >> "$DEFAULT_LOG_DIR/error.log"
        fi
    fi
    
    # Also log to syslog
    logger -t "autobackup" "$level: $message"
    
    # Print to console if verbose mode
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "ERROR" ]]; then
        case "$level" in
            "DEBUG") print_colored "$BLUE" "DEBUG: $message" ;;
            "INFO")  print_colored "$GREEN" "INFO: $message" ;;
            "WARN")  print_colored "$YELLOW" "WARN: $message" ;;
            "ERROR") print_colored "$RED" "ERROR: $message" ;;
        esac
    fi
}

#######################################
# Display script usage information
#######################################
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    autobackup [OPTIONS]

DESCRIPTION:
    Automated backup system for Linux that creates compressed archives
    of specified directories and transfers them to a remote server.

OPTIONS:
    -v, --verbose         Enable verbose output
    -d, --dry-run         Perform dry run without actual backup
    -c, --config FILE     Use custom configuration file
    -f, --force           Force backup even if recent backup exists
    -s, --status          Show backup status and statistics
    -h, --help            Show this help message
        --version         Show version information

EXAMPLES:
    autobackup                           # Run backup with default settings
    autobackup --verbose                 # Run with verbose output
    autobackup --dry-run                 # Test backup without execution
    autobackup --config /path/to/conf    # Use custom configuration
    autobackup --status                  # Show backup statistics

CONFIGURATION:
    Default config file: $DEFAULT_CONFIG
    Log directory: $DEFAULT_LOG_DIR
    Backup directory: $DEFAULT_BACKUP_DIR

For more information, see the README.md file.
EOF
}

#######################################
# Display version information
#######################################
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

#######################################
# Load and validate configuration file
# Arguments:
#   $1: Configuration file path
#######################################
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_message "ERROR" "Configuration file not found: $config_file"
        exit 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "$config_file"
    
    # Validate required configuration variables
    local required_vars=(
        "BACKUP_DIRS"
        "REMOTE_HOST"
        "REMOTE_USER"
        "REMOTE_PATH"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_message "ERROR" "Required configuration variable not set: $var"
            exit 1
        fi
    done
    
    # Set default values for optional variables
    LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
    BACKUP_NAME_PREFIX="${BACKUP_NAME_PREFIX:-backup-$(hostname)}"
    RETENTION_DAYS="${RETENTION_DAYS:-30}"
    ENABLE_COMPRESSION="${ENABLE_COMPRESSION:-true}"
    COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"
    ENABLE_EMAIL_ALERTS="${ENABLE_EMAIL_ALERTS:-false}"
    SSH_PORT="${SSH_PORT:-22}"
    LOG_LEVEL="${LOG_LEVEL:-INFO}"
    
    log_message "INFO" "Configuration loaded from $config_file"
}

#######################################
# Check if required tools are available
#######################################
check_dependencies() {
    local required_commands=("rsync" "tar" "ssh" "find" "date")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required commands: ${missing_commands[*]}"
        log_message "ERROR" "Please install missing dependencies"
        exit 1
    fi
    
    # Check for optional email command
    if [[ "$ENABLE_EMAIL_ALERTS" == true ]]; then
        if ! command -v "mail" &> /dev/null && ! command -v "sendmail" &> /dev/null; then
            log_message "WARN" "Email alerts enabled but no mail command found"
            log_message "WARN" "Install mailutils or sendmail for email notifications"
        fi
    fi
}

#######################################
# Create necessary directories
#######################################
create_directories() {
    local dirs=("$LOCAL_BACKUP_DIR" "$DEFAULT_LOG_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                mkdir -p "$dir" || {
                    log_message "ERROR" "Failed to create directory: $dir"
                    exit 1
                }
                log_message "INFO" "Created directory: $dir"
            else
                log_message "INFO" "DRY-RUN: Would create directory: $dir"
            fi
        fi
    done
}

#######################################
# Test SSH connection to remote server
#######################################
test_ssh_connection() {
    local ssh_cmd="ssh"
    
    # Add SSH key if specified
    if [[ -n "${SSH_KEY_PATH:-}" ]]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY_PATH"
    fi
    
    # Add port if not default
    if [[ "$SSH_PORT" != "22" ]]; then
        ssh_cmd="$ssh_cmd -p $SSH_PORT"
    fi
    
    # Add connection options
    ssh_cmd="$ssh_cmd -o ConnectTimeout=10 -o BatchMode=yes"
    
    log_message "INFO" "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST"
    
    if [[ "$DRY_RUN" == false ]]; then
        if ! $ssh_cmd "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection successful'" &>/dev/null; then
            log_message "ERROR" "SSH connection failed to $REMOTE_USER@$REMOTE_HOST"
            log_message "ERROR" "Check SSH key configuration and network connectivity"
            return 1
        fi
    else
        log_message "INFO" "DRY-RUN: Would test SSH connection"
    fi
    
    log_message "INFO" "SSH connection test successful"
    return 0
}

#######################################
# Create backup archive
# Returns:
#   0 on success, 1 on failure
#######################################
create_backup_archive() {
    local timestamp
    timestamp=$(date '+%Y%m%d-%H%M%S')
    local archive_name="${BACKUP_NAME_PREFIX}-${timestamp}.tar"
    local archive_path="$LOCAL_BACKUP_DIR/$archive_name"
    
    # Add compression extension if enabled
    if [[ "$ENABLE_COMPRESSION" == true ]]; then
        archive_name="${archive_name}.gz"
        archive_path="${archive_path}.gz"
    fi
    
    log_message "INFO" "Creating backup archive: $archive_name"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Create tar command
        local tar_cmd="tar -cf"
        local tar_options=""
        
        # Add compression if enabled
        if [[ "$ENABLE_COMPRESSION" == true ]]; then
            tar_cmd="tar -czf"
            export GZIP="-$COMPRESSION_LEVEL"
        fi
        
        # Add verbose option if needed
        if [[ "$VERBOSE" == true ]]; then
            tar_options="v"
        fi
        
        # Create the archive
        if ! $tar_cmd "$archive_path" $tar_options $BACKUP_DIRS 2>/dev/null; then
            log_message "ERROR" "Failed to create backup archive"
            return 1
        fi
        
        # Check if archive was created successfully
        if [[ ! -f "$archive_path" ]]; then
            log_message "ERROR" "Backup archive was not created: $archive_path"
            return 1
        fi
        
        # Get archive size
        local archive_size
        archive_size=$(stat -c%s "$archive_path" 2>/dev/null || echo "0")
        local archive_size_human
        archive_size_human=$(numfmt --to=iec-i --suffix=B "$archive_size" 2>/dev/null || echo "${archive_size} bytes")
        
        log_message "INFO" "Archive created successfully ($archive_size_human)"
        
        # Store archive path for transfer
        BACKUP_ARCHIVE_PATH="$archive_path"
        BACKUP_ARCHIVE_NAME="$archive_name"
    else
        log_message "INFO" "DRY-RUN: Would create archive $archive_name from: $BACKUP_DIRS"
        BACKUP_ARCHIVE_PATH="$archive_path"
        BACKUP_ARCHIVE_NAME="$archive_name"
    fi
    
    return 0
}

#######################################
# Transfer backup to remote server
# Returns:
#   0 on success, 1 on failure
#######################################
transfer_backup() {
    local remote_target="$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
    local scp_cmd="scp"
    
    # Add SSH key if specified
    if [[ -n "${SSH_KEY_PATH:-}" ]]; then
        scp_cmd="$scp_cmd -i $SSH_KEY_PATH"
    fi
    
    # Add port if not default
    if [[ "$SSH_PORT" != "22" ]]; then
        scp_cmd="$scp_cmd -P $SSH_PORT"
    fi
    
    # Add options
    scp_cmd="$scp_cmd -o ConnectTimeout=30 -o BatchMode=yes"
    
    log_message "INFO" "Starting remote transfer to $REMOTE_HOST"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Ensure remote directory exists
        local ssh_cmd="ssh"
        if [[ -n "${SSH_KEY_PATH:-}" ]]; then
            ssh_cmd="$ssh_cmd -i $SSH_KEY_PATH"
        fi
        if [[ "$SSH_PORT" != "22" ]]; then
            ssh_cmd="$ssh_cmd -p $SSH_PORT"
        fi
        ssh_cmd="$ssh_cmd -o ConnectTimeout=10 -o BatchMode=yes"
        
        if ! $ssh_cmd "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_PATH'" 2>/dev/null; then
            log_message "ERROR" "Failed to create remote directory: $REMOTE_PATH"
            return 1
        fi
        
        # Transfer the backup
        if ! $scp_cmd "$BACKUP_ARCHIVE_PATH" "$remote_target" 2>/dev/null; then
            log_message "ERROR" "Failed to transfer backup to remote server"
            return 1
        fi
        
        log_message "INFO" "Transfer completed successfully"
    else
        log_message "INFO" "DRY-RUN: Would transfer $BACKUP_ARCHIVE_NAME to $remote_target"
    fi
    
    return 0
}

#######################################
# Clean up old backups based on retention policy
#######################################
cleanup_old_backups() {
    log_message "INFO" "Cleaning up old backups (retention: $RETENTION_DAYS days)"
    
    # Clean up local backups
    local deleted_count=0
    
    if [[ "$DRY_RUN" == false ]]; then
        # Find and delete old local backups
        while IFS= read -r -d '' old_backup; do
            rm -f "$old_backup"
            ((deleted_count++))
            log_message "INFO" "Deleted old backup: $(basename "$old_backup")"
        done < <(find "$LOCAL_BACKUP_DIR" -name "${BACKUP_NAME_PREFIX}-*.tar*" -type f -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
        
        # Clean up old remote backups
        local ssh_cmd="ssh"
        if [[ -n "${SSH_KEY_PATH:-}" ]]; then
            ssh_cmd="$ssh_cmd -i $SSH_KEY_PATH"
        fi
        if [[ "$SSH_PORT" != "22" ]]; then
            ssh_cmd="$ssh_cmd -p $SSH_PORT"
        fi
        ssh_cmd="$ssh_cmd -o ConnectTimeout=10 -o BatchMode=yes"
        
        local remote_cleanup_cmd="find '$REMOTE_PATH' -name '${BACKUP_NAME_PREFIX}-*.tar*' -type f -mtime +$RETENTION_DAYS -delete"
        if $ssh_cmd "$REMOTE_USER@$REMOTE_HOST" "$remote_cleanup_cmd" 2>/dev/null; then
            log_message "INFO" "Remote cleanup completed"
        else
            log_message "WARN" "Failed to clean up remote backups"
        fi
    else
        # Dry run - just count what would be deleted
        while IFS= read -r -d '' old_backup; do
            ((deleted_count++))
            log_message "INFO" "DRY-RUN: Would delete old backup: $(basename "$old_backup")"
        done < <(find "$LOCAL_BACKUP_DIR" -name "${BACKUP_NAME_PREFIX}-*.tar*" -type f -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
    fi
    
    if [[ $deleted_count -gt 0 ]]; then
        log_message "INFO" "Removed $deleted_count old backup files"
    else
        log_message "INFO" "No old backups to remove"
    fi
}

#######################################
# Clean up temporary files
#######################################
cleanup_temp_files() {
    if [[ -n "${BACKUP_ARCHIVE_PATH:-}" ]] && [[ -f "$BACKUP_ARCHIVE_PATH" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            rm -f "$BACKUP_ARCHIVE_PATH"
            log_message "INFO" "Cleaned up temporary backup file"
        else
            log_message "INFO" "DRY-RUN: Would clean up temporary backup file"
        fi
    fi
}

#######################################
# Send email notification
# Arguments:
#   $1: Subject
#   $2: Message body
#######################################
send_email_notification() {
    local subject="$1"
    local body="$2"
    
    if [[ "$ENABLE_EMAIL_ALERTS" != true ]]; then
        return 0
    fi
    
    if [[ -z "${EMAIL_RECIPIENT:-}" ]]; then
        log_message "WARN" "Email alerts enabled but no recipient specified"
        return 1
    fi
    
    local email_subject="${EMAIL_SUBJECT:-AutoBackup Alert} - $subject"
    
    if command -v mail &> /dev/null; then
        echo "$body" | mail -s "$email_subject" "$EMAIL_RECIPIENT"
        log_message "INFO" "Email notification sent to $EMAIL_RECIPIENT"
    elif command -v sendmail &> /dev/null; then
        {
            echo "To: $EMAIL_RECIPIENT"
            echo "Subject: $email_subject"
            echo ""
            echo "$body"
        } | sendmail "$EMAIL_RECIPIENT"
        log_message "INFO" "Email notification sent to $EMAIL_RECIPIENT"
    else
        log_message "WARN" "No mail command available for email notifications"
        return 1
    fi
}

#######################################
# Show backup status and statistics
#######################################
show_backup_status() {
    echo "=== AutoBackup Pro Status ==="
    echo
    
    # Configuration information
    echo "Configuration:"
    echo "  Config file: $CONFIG_FILE"
    echo "  Backup directories: $BACKUP_DIRS"
    echo "  Remote host: $REMOTE_USER@$REMOTE_HOST"
    echo "  Remote path: $REMOTE_PATH"
    echo "  Local backup dir: $LOCAL_BACKUP_DIR"
    echo "  Retention days: $RETENTION_DAYS"
    echo
    
    # Recent backup information
    echo "Recent Backups:"
    if [[ -d "$LOCAL_BACKUP_DIR" ]]; then
        local backup_count
        backup_count=$(find "$LOCAL_BACKUP_DIR" -name "${BACKUP_NAME_PREFIX}-*.tar*" -type f | wc -l)
        echo "  Local backups: $backup_count"
        
        if [[ $backup_count -gt 0 ]]; then
            echo "  Latest backups:"
            find "$LOCAL_BACKUP_DIR" -name "${BACKUP_NAME_PREFIX}-*.tar*" -type f -printf "    %TY-%Tm-%Td %TH:%TM  %s bytes  %f\n" | sort -r | head -5
        fi
    else
        echo "  Local backup directory not found"
    fi
    echo
    
    # Log information
    echo "Logs:"
    if [[ -f "$DEFAULT_LOG_DIR/autobackup.log" ]]; then
        local log_lines
        log_lines=$(wc -l < "$DEFAULT_LOG_DIR/autobackup.log")
        echo "  Main log: $DEFAULT_LOG_DIR/autobackup.log ($log_lines lines)"
        
        echo "  Recent log entries:"
        tail -5 "$DEFAULT_LOG_DIR/autobackup.log" | sed 's/^/    /'
    else
        echo "  Log file not found"
    fi
    
    # Service status
    echo
    echo "Service Status:"
    if systemctl is-active autobackup.service &>/dev/null; then
        echo "  Service: Active"
    else
        echo "  Service: Inactive"
    fi
    
    if systemctl is-enabled autobackup.timer &>/dev/null; then
        echo "  Timer: Enabled"
        echo "  Next run: $(systemctl list-timers autobackup.timer --no-pager --no-legend | awk '{print $1, $2}')"
    else
        echo "  Timer: Disabled"
    fi
}

#######################################
# Main backup function
#######################################
run_backup() {
    local start_time
    start_time=$(date +%s)
    
    log_message "INFO" "Starting backup process"
    
    # Check dependencies
    check_dependencies
    
    # Create necessary directories
    create_directories
    
    # Test SSH connection
    if ! test_ssh_connection; then
        log_message "ERROR" "SSH connection test failed"
        send_email_notification "Backup Failed" "SSH connection to $REMOTE_HOST failed. Please check your SSH configuration."
        exit 1
    fi
    
    # Create backup archive
    if ! create_backup_archive; then
        log_message "ERROR" "Failed to create backup archive"
        send_email_notification "Backup Failed" "Failed to create backup archive. Check disk space and permissions."
        exit 1
    fi
    
    # Transfer backup to remote server
    if ! transfer_backup; then
        log_message "ERROR" "Failed to transfer backup"
        cleanup_temp_files
        send_email_notification "Backup Failed" "Failed to transfer backup to $REMOTE_HOST. Check network connectivity and remote server."
        exit 1
    fi
    
    # Clean up old backups
    cleanup_old_backups
    
    # Clean up temporary files
    cleanup_temp_files
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_human
    duration_human=$(printf '%dm %ds' $((duration/60)) $((duration%60)))
    
    log_message "INFO" "Backup completed successfully"
    log_message "INFO" "Total time: $duration_human"
    
    # Send success notification if configured
    if [[ "$ENABLE_EMAIL_ALERTS" == true ]] && [[ -n "${EMAIL_SUCCESS_NOTIFICATIONS:-}" ]]; then
        send_email_notification "Backup Successful" "Backup completed successfully in $duration_human."
    fi
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                VERBOSE=true  # Enable verbose for dry run
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_BACKUP=true
                shift
                ;;
            -s|--status)
                SHOW_STATUS=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
}

#######################################
# Main function
#######################################
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show status if requested
    if [[ "$SHOW_STATUS" == true ]]; then
        load_config "$CONFIG_FILE"
        show_backup_status
        exit 0
    fi
    
    # Load configuration
    load_config "$CONFIG_FILE"
    
    # Show dry run notice
    if [[ "$DRY_RUN" == true ]]; then
        log_message "INFO" "DRY-RUN MODE: No actual backup will be performed"
    fi
    
    # Run the backup
    run_backup
}

# Trap signals for cleanup
trap cleanup_temp_files EXIT INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi