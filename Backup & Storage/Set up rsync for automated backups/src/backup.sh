#!/bin/bash

#======================================================================
# RSYNC BACKUP TOOL
# A comprehensive backup solution using rsync with automation support
#======================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script metadata
readonly SCRIPT_NAME="rsync-backup-tool"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
readonly DEFAULT_CONFIG="$PROJECT_ROOT/config/backup.conf"
readonly DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"
readonly DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/backup.log"

# Global variables
CONFIG_FILE="$DEFAULT_CONFIG"
LOG_FILE="$DEFAULT_LOG_FILE"
DRY_RUN=false
VERBOSE=false
FORCE=false
BACKUP_NAME=""

#======================================================================
# LOGGING FUNCTIONS
#======================================================================

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Log message with timestamp
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Also log to syslog
    case "$level" in
        "ERROR") logger -t "$SCRIPT_NAME" -p user.err "$message" ;;
        "WARN")  logger -t "$SCRIPT_NAME" -p user.warning "$message" ;;
        "INFO")  logger -t "$SCRIPT_NAME" -p user.info "$message" ;;
        "DEBUG") [[ "$VERBOSE" == true ]] && logger -t "$SCRIPT_NAME" -p user.debug "$message" ;;
    esac
}

log_info() { log_message "INFO" "$@"; }
log_warn() { log_message "WARN" "$@"; }
log_error() { log_message "ERROR" "$@"; }
log_debug() { [[ "$VERBOSE" == true ]] && log_message "DEBUG" "$@"; }

#======================================================================
# UTILITY FUNCTIONS
#======================================================================

# Display usage information
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Automated Rsync Backup Tool

USAGE:
    $0 [OPTIONS] [BACKUP_NAME]

OPTIONS:
    -c, --config FILE       Use custom configuration file (default: $DEFAULT_CONFIG)
    -l, --log FILE          Use custom log file (default: $DEFAULT_LOG_FILE)
    -n, --dry-run           Show what would be done without actually doing it
    -v, --verbose           Enable verbose output and debug logging
    -f, --force             Force backup even if recent backup exists
    -h, --help              Show this help message
    --version               Show version information

BACKUP_NAME:
    Name of the backup job to run (from config file)
    If not specified, all configured backups will be executed

EXAMPLES:
    $0                      # Run all configured backups
    $0 home-backup          # Run only the 'home-backup' job
    $0 -n documents         # Dry-run the 'documents' backup job
    $0 -v --config /etc/backup.conf  # Use custom config with verbose output

CONFIGURATION:
    Edit $DEFAULT_CONFIG to configure your backup jobs.

LOGS:
    Check logs at: $DEFAULT_LOG_FILE
    Or use: journalctl -t $SCRIPT_NAME

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            -*|--*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$BACKUP_NAME" ]]; then
                    BACKUP_NAME="$1"
                else
                    log_error "Multiple backup names specified: '$BACKUP_NAME' and '$1'"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Check if required commands are available
check_dependencies() {
    local deps=("rsync" "logger" "date")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install them using: sudo apt-get install ${missing[*]}"
        exit 1
    fi
}

# Validate configuration file
validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_error "Please create the configuration file or specify a different one with -c"
        exit 1
    fi
    
    if [[ ! -r "$CONFIG_FILE" ]]; then
        log_error "Cannot read configuration file: $CONFIG_FILE"
        exit 1
    fi
    
    log_debug "Using configuration file: $CONFIG_FILE"
}

#======================================================================
# BACKUP FUNCTIONS
#======================================================================

# Read configuration for a specific backup job
read_backup_config() {
    local job_name="$1"
    local config_section="[backup:$job_name]"
    local in_section=false
    
    # Initialize variables
    unset SOURCE DESTINATION EXCLUDE_FILE EXCLUDE_PATTERNS RSYNC_OPTIONS RETENTION_DAYS REMOTE_HOST REMOTE_USER
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            if [[ "$line" == "$config_section" ]]; then
                in_section=true
                continue
            else
                in_section=false
                continue
            fi
        fi
        
        # Process configuration lines in the correct section
        if [[ "$in_section" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*([^=]+)=[[:space:]]*(.*)$ ]]; then
                local key="${BASH_REMATCH[1]// /}"
                local value="${BASH_REMATCH[2]}"
                
                case "$key" in
                    "source") SOURCE="$value" ;;
                    "destination") DESTINATION="$value" ;;
                    "exclude_file") EXCLUDE_FILE="$value" ;;
                    "exclude_patterns") EXCLUDE_PATTERNS="$value" ;;
                    "rsync_options") RSYNC_OPTIONS="$value" ;;
                    "retention_days") RETENTION_DAYS="$value" ;;
                    "remote_host") REMOTE_HOST="$value" ;;
                    "remote_user") REMOTE_USER="$value" ;;
                esac
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Validate required settings
    if [[ -z "${SOURCE:-}" || -z "${DESTINATION:-}" ]]; then
        log_error "Backup job '$job_name': SOURCE and DESTINATION must be specified"
        return 1
    fi
    
    return 0
}

# Get list of all backup jobs from config
get_backup_jobs() {
    grep -o '\[backup:[^]]*\]' "$CONFIG_FILE" | sed 's/\[backup://g' | sed 's/\]//g'
}

# Perform the actual backup using rsync
perform_backup() {
    local job_name="$1"
    
    log_info "Starting backup job: $job_name"
    
    # Read configuration for this job
    if ! read_backup_config "$job_name"; then
        log_error "Failed to read configuration for backup job: $job_name"
        return 1
    fi
    
    # Build rsync command
    local rsync_cmd="rsync"
    local rsync_args="-avz --progress --stats"
    
    # Add custom rsync options if specified
    if [[ -n "${RSYNC_OPTIONS:-}" ]]; then
        rsync_args="$rsync_args $RSYNC_OPTIONS"
    fi
    
    # Add dry-run option if requested
    if [[ "$DRY_RUN" == true ]]; then
        rsync_args="$rsync_args --dry-run"
        log_info "DRY RUN MODE: No files will be modified"
    fi
    
    # Handle exclude patterns
    if [[ -n "${EXCLUDE_FILE:-}" && -f "$EXCLUDE_FILE" ]]; then
        rsync_args="$rsync_args --exclude-from=$EXCLUDE_FILE"
        log_debug "Using exclude file: $EXCLUDE_FILE"
    fi
    
    if [[ -n "${EXCLUDE_PATTERNS:-}" ]]; then
        IFS=',' read -ra patterns <<< "$EXCLUDE_PATTERNS"
        for pattern in "${patterns[@]}"; do
            rsync_args="$rsync_args --exclude=${pattern// /}"
        done
        log_debug "Using exclude patterns: $EXCLUDE_PATTERNS"
    fi
    
    # Build full destination path
    local full_destination="$DESTINATION"
    if [[ -n "${REMOTE_HOST:-}" ]]; then
        local remote_user="${REMOTE_USER:-$USER}"
        full_destination="$remote_user@$REMOTE_HOST:$DESTINATION"
        log_info "Remote backup to: $full_destination"
    else
        log_info "Local backup to: $full_destination"
        # Create destination directory if it doesn't exist
        mkdir -p "$DESTINATION"
    fi
    
    # Execute rsync
    local start_time=$(date '+%s')
    log_info "Executing: $rsync_cmd $rsync_args $SOURCE $full_destination"
    
    if $rsync_cmd $rsync_args "$SOURCE" "$full_destination" 2>&1 | tee -a "$LOG_FILE"; then
        local end_time=$(date '+%s')
        local duration=$((end_time - start_time))
        log_info "Backup job '$job_name' completed successfully in ${duration}s"
        
        # Cleanup old backups if retention is specified
        if [[ -n "${RETENTION_DAYS:-}" && "$DRY_RUN" != true ]]; then
            cleanup_old_backups "$job_name" "$RETENTION_DAYS"
        fi
        
        return 0
    else
        log_error "Backup job '$job_name' failed"
        return 1
    fi
}

# Cleanup old backup directories based on retention policy
cleanup_old_backups() {
    local job_name="$1"
    local retention_days="$2"
    
    log_info "Cleaning up backups older than $retention_days days for job: $job_name"
    
    # This is a simple implementation - in practice, you might want more sophisticated cleanup
    # For incremental backups with timestamps, you could implement date-based cleanup here
    log_debug "Retention cleanup not implemented for basic rsync backups"
}

# Send notification (can be extended to support email, Slack, etc.)
send_notification() {
    local status="$1"
    local job_name="$2"
    local message="$3"
    
    # Log to syslog
    case "$status" in
        "success") logger -t "$SCRIPT_NAME" -p user.info "Backup SUCCESS: $job_name - $message" ;;
        "failure") logger -t "$SCRIPT_NAME" -p user.err "Backup FAILURE: $job_name - $message" ;;
    esac
    
    # Here you could add email notifications, webhook calls, etc.
    log_debug "Notification sent: $status for $job_name"
}

#======================================================================
# MAIN EXECUTION
#======================================================================

main() {
    # Initialize
    init_logging
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Validate environment
    check_dependencies
    validate_config
    
    # Determine which backup jobs to run
    local jobs_to_run=()
    if [[ -n "$BACKUP_NAME" ]]; then
        jobs_to_run=("$BACKUP_NAME")
    else
        readarray -t jobs_to_run < <(get_backup_jobs)
    fi
    
    if [[ ${#jobs_to_run[@]} -eq 0 ]]; then
        log_error "No backup jobs found in configuration"
        exit 1
    fi
    
    log_info "Found ${#jobs_to_run[@]} backup job(s) to execute: ${jobs_to_run[*]}"
    
    # Execute backup jobs
    local success_count=0
    local failure_count=0
    
    for job in "${jobs_to_run[@]}"; do
        if perform_backup "$job"; then
            send_notification "success" "$job" "Backup completed successfully"
            ((success_count++))
        else
            send_notification "failure" "$job" "Backup failed"
            ((failure_count++))
        fi
        
        # Add a small delay between jobs
        sleep 2
    done
    
    # Summary
    log_info "Backup execution completed: $success_count successful, $failure_count failed"
    
    if [[ $failure_count -gt 0 ]]; then
        log_error "Some backup jobs failed. Check the logs for details."
        exit 1
    else
        log_info "All backup jobs completed successfully"
        exit 0
    fi
}

# Error handling
trap 'log_error "Script interrupted or failed at line $LINENO"' ERR
trap 'log_info "Script execution finished"' EXIT

# Execute main function with all arguments
main "$@"