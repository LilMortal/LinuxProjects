#!/bin/bash

#
# TilingWM Manager - Main Command Interface
#
# This is the main command-line interface for managing the i3 tiling
# window manager installation, configuration, and automation.
#
# Usage: tilingwm <command> [options]
#
# Author: TilingWM Manager Project
# License: MIT
#

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="tilingwm"
readonly VERSION="1.0.0"
readonly CONFIG_DIR="$HOME/.config/tilingwm"
readonly DATA_DIR="$HOME/.local/share/tilingwm"
readonly LOG_DIR="$DATA_DIR/logs"
readonly BACKUP_DIR="$DATA_DIR/backups"
readonly LOG_FILE="$LOG_DIR/tilingwm.log"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR)
            echo "ERROR: $message" >&2
            logger -t "$SCRIPT_NAME" -p user.err "$message" 2>/dev/null || true
            ;;
        WARN)
            echo "WARNING: $message" >&2
            logger -t "$SCRIPT_NAME" -p user.warning "$message" 2>/dev/null || true
            ;;
        INFO)
            echo "$message"
            logger -t "$SCRIPT_NAME" -p user.info "$message" 2>/dev/null || true
            ;;
        DEBUG)
            if [[ "${TILINGWM_LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
                echo "DEBUG: $message" >&2
            fi
            logger -t "$SCRIPT_NAME" -p user.debug "$message" 2>/dev/null || true
            ;;
    esac
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { log "DEBUG" "$@"; }

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check if i3 is running
check_i3_running() {
    if ! pgrep -x "i3" > /dev/null; then
        return 1
    fi
    return 0
}

# Get i3 socket path
get_i3_socket() {
    i3 --get-socketpath 2>/dev/null || echo "/tmp/i3-socket"
}

# Send command to i3
i3_command() {
    local cmd="$1"
    local socket=$(get_i3_socket)
    
    if [[ -S "$socket" ]]; then
        echo "$cmd" | socat - "UNIX-CONNECT:$socket" 2>/dev/null || {
            log_warn "Failed to send command to i3: $cmd"
            return 1
        }
    else
        log_error "i3 socket not found: $socket"
        return 1
    fi
}

# Workspace management
workspace_switch() {
    local workspace="$1"
    log_debug "Switching to workspace: $workspace"
    
    if check_i3_running; then
        i3_command "workspace $workspace" || error_exit "Failed to switch to workspace $workspace"
        log_info "Switched to workspace: $workspace"
    else
        error_exit "i3 is not running"
    fi
}

workspace_list() {
    if check_i3_running; then
        i3-msg -t get_workspaces | jq -r '.[] | "\(.num): \(.name) (\(.focused // false | if . then "focused" else "inactive" end))"'
    else
        error_exit "i3 is not running"
    fi
}

workspace_reset_empty() {
    log_info "Resetting empty workspaces..."
    
    if ! check_i3_running; then
        error_exit "i3 is not running"
    fi
    
    # Get list of workspaces with no windows
    local empty_workspaces
    empty_workspaces=$(i3-msg -t get_workspaces | jq -r '.[] | select(.windows == 0) | .name')
    
    for ws in $empty_workspaces; do
        # Skip workspace 1 (usually default)
        if [[ "$ws" != "1" ]]; then
            log_debug "Removing empty workspace: $ws"
            i3_command "workspace $ws; workspace 1" || log_warn "Failed to reset workspace $ws"
        fi
    done
    
    log_info "Empty workspace reset completed"
}

# Window management
window_focus() {
    local direction="$1"
    
    case "$direction" in
        left|right|up|down)
            i3_command "focus $direction" || error_exit "Failed to focus $direction"
            log_debug "Focused $direction"
            ;;
        *)
            error_exit "Invalid focus direction: $direction"
            ;;
    esac
}

window_move() {
    local direction="$1"
    
    case "$direction" in
        left|right|up|down)
            i3_command "move $direction" || error_exit "Failed to move window $direction"
            log_info "Moved window $direction"
            ;;
        *)
            error_exit "Invalid move direction: $direction"
            ;;
    esac
}

# Layout management
layout_set() {
    local layout="$1"
    
    case "$layout" in
        default|stacking|tabbed)
            i3_command "layout $layout" || error_exit "Failed to set layout to $layout"
            log_info "Set layout to: $layout"
            ;;
        toggle)
            i3_command "layout toggle split" || error_exit "Failed to toggle layout"
            log_info "Toggled layout"
            ;;
        *)
            error_exit "Invalid layout: $layout"
            ;;
    esac
}

# Configuration management
config_reload() {
    log_info "Reloading i3 configuration..."
    
    if check_i3_running; then
        i3_command "reload" || error_exit "Failed to reload i3 configuration"
        log_info "i3 configuration reloaded"
    else
        log_warn "i3 is not running, cannot reload configuration"
    fi
}

config_backup() {
    local backup_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "Creating backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup i3 config
    if [[ -f "$HOME/.config/i3/config" ]]; then
        cp "$HOME/.config/i3/config" "$backup_path/i3-config"
    fi
    
    # Backup i3status config
    if [[ -f "$HOME/.config/i3status/config" ]]; then
        cp "$HOME/.config/i3status/config" "$backup_path/i3status-config"
    fi
    
    # Backup tilingwm configs
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR"/* "$backup_path/" 2>/dev/null || true
    fi
    
    # Create backup metadata
    cat > "$backup_path/metadata.txt" << EOF
Backup Name: $backup_name
Created: $(date)
i3 Version: $(i3 --version 2>/dev/null || echo "Not available")
System: $(uname -a)
EOF
    
    log_info "Backup created: $backup_path"
}

config_restore() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ ! -d "$backup_path" ]]; then
        error_exit "Backup not found: $backup_name"
    fi
    
    log_info "Restoring from backup: $backup_name"
    
    # Create current backup before restore
    config_backup "pre-restore-$(date +%Y%m%d-%H%M%S)"
    
    # Restore i3 config
    if [[ -f "$backup_path/i3-config" ]]; then
        cp "$backup_path/i3-config" "$HOME/.config/i3/config"
        log_debug "Restored i3 configuration"
    fi
    
    # Restore i3status config
    if [[ -f "$backup_path/i3status-config" ]]; then
        mkdir -p "$HOME/.config/i3status"
        cp "$backup_path/i3status-config" "$HOME/.config/i3status/config"
        log_debug "Restored i3status configuration"
    fi
    
    # Restore tilingwm configs
    if [[ -f "$backup_path/config.yaml" ]]; then
        mkdir -p "$CONFIG_DIR"
        cp "$backup_path"/*.yaml "$CONFIG_DIR/" 2>/dev/null || true
        cp "$backup_path"/*.conf "$CONFIG_DIR/" 2>/dev/null || true
        log_debug "Restored tilingwm configuration"
    fi
    
    log_info "Configuration restored from: $backup_name"
    log_info "Run 'tilingwm configure --reload' to apply changes"
}

# Status reporting
show_status() {
    echo "TilingWM Manager Status:"
    echo "========================"
    
    # i3 status
    if check_i3_running; then
        local i3_pid=$(pgrep -x "i3")
        echo "WM Status: i3 running (PID: $i3_pid)"
    else
        echo "WM Status: i3 not running"
    fi
    
    # Configuration status
    if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
        echo "Config: $CONFIG_DIR/config.yaml (loaded)"
    else
        echo "Config: not found"
    fi
    
    # Automation service status
    if systemctl --user is-active tilingwm-automation.service &>/dev/null; then
        echo "Automation: enabled (systemd service active)"
    else
        echo "Automation: disabled or not installed"
    fi
    
    # Workspace information
    if check_i3_running; then
        local workspace_info
        workspace_info=$(i3-msg -t get_workspaces | jq -r 'length as $total | map(select(.focused)) | .[0] | "Current Workspace: \(.num) (\(.name // "unnamed")), Total: \($total)"')
        echo "$workspace_info"
    fi
    
    # Backup information
    local latest_backup
    latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -o -name "*-$(date +%Y%m%d)*" 2>/dev/null | sort | tail -1)
    if [[ -n "$latest_backup" ]]; then
        local backup_name=$(basename "$latest_backup")
        local backup_date=$(stat -c %y "$latest_backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || echo "unknown")
        echo "Last Backup: $backup_date"
    else
        echo "Last Backup: none found"
    fi
    
    # Log level
    echo "Log Level: ${TILINGWM_LOG_LEVEL:-INFO}"
}

# Automation management
automation_start() {
    log_info "Starting automation service..."
    
    if systemctl --user start tilingwm-automation.service 2>/dev/null; then
        log_info "Automation service started"
    else
        log_warn "Failed to start automation service via systemd, trying direct execution"
        if command -v tilingwm-automation &>/dev/null; then
            nohup tilingwm-automation &>/dev/null &
            log_info "Automation started in background"
        else
            error_exit "Automation service not available"
        fi
    fi
}

automation_stop() {
    log_info "Stopping automation service..."
    
    if systemctl --user stop tilingwm-automation.service 2>/dev/null; then
        log_info "Automation service stopped"
    else
        # Try to kill the process directly
        if pkill -f "tilingwm-automation"; then
            log_info "Automation process terminated"
        else
            log_warn "No automation process found to stop"
        fi
    fi
}

# Help system
show_help() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        cat << EOF
TilingWM Manager v$VERSION

USAGE:
    tilingwm <command> [options]

COMMANDS:
    status                          Show system status
    workspace <subcommand>          Workspace management
    window <subcommand>             Window management
    layout <subcommand>             Layout management
    configure <subcommand>          Configuration management
    backup [name]                   Create configuration backup
    restore <backup-name>           Restore from backup
    automation <subcommand>         Automation control
    help [command]                  Show help for specific command

EXAMPLES:
    tilingwm status                 # Show current status
    tilingwm workspace --name "Development"
    tilingwm backup "pre-update"
    tilingwm automation start

For detailed help on a command: tilingwm help <command>
EOF
    else
        case "$command" in
            workspace)
                cat << EOF
WORKSPACE MANAGEMENT:
    tilingwm workspace --name <name>        Switch to workspace by name
    tilingwm workspace --number <num>       Switch to workspace by number
    tilingwm workspace --list               List all workspaces
    tilingwm workspace --reset-empty        Remove empty workspaces
EOF
                ;;
            window)
                cat << EOF
WINDOW MANAGEMENT:
    tilingwm window --focus <direction>     Focus window (left/right/up/down)
    tilingwm window --move <direction>      Move window (left/right/up/down)
EOF
                ;;
            layout)
                cat << EOF
LAYOUT MANAGEMENT:
    tilingwm layout --set <layout>          Set layout (default/stacking/tabbed)
    tilingwm layout --toggle                Toggle split layout
EOF
                ;;
            configure)
                cat << EOF
CONFIGURATION MANAGEMENT:
    tilingwm configure --reload             Reload i3 configuration
EOF
                ;;
            automation)
                cat << EOF
AUTOMATION CONTROL:
    tilingwm automation start               Start automation service
    tilingwm automation stop                Stop automation service
EOF
                ;;
            *)
                log_error "No help available for: $command"
                ;;
        esac
    fi
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        status)
            show_status
            ;;
        workspace)
            case "${1:-}" in
                --name)
                    [[ $# -ge 2 ]] || error_exit "Workspace name required"
                    workspace_switch "$2"
                    ;;
                --number)
                    [[ $# -ge 2 ]] || error_exit "Workspace number required"
                    workspace_switch "$2"
                    ;;
                --list)
                    workspace_list
                    ;;
                --reset-empty)
                    workspace_reset_empty
                    ;;
                *)
                    log_error "Unknown workspace command: ${1:-}"
                    show_help workspace
                    exit 1
                    ;;
            esac
            ;;
        window)
            case "${1:-}" in
                --focus)
                    [[ $# -ge 2 ]] || error_exit "Focus direction required"
                    window_focus "$2"
                    ;;
                --move)
                    [[ $# -ge 2 ]] || error_exit "Move direction required"
                    window_move "$2"
                    ;;
                *)
                    log_error "Unknown window command: ${1:-}"
                    show_help window
                    exit 1
                    ;;
            esac
            ;;
        layout)
            case "${1:-}" in
                --set)
                    [[ $# -ge 2 ]] || error_exit "Layout type required"
                    layout_set "$2"
                    ;;
                --toggle)
                    layout_set "toggle"
                    ;;
                *)
                    log_error "Unknown layout command: ${1:-}"
                    show_help layout
                    exit 1
                    ;;
            esac
            ;;
        configure)
            case "${1:-}" in
                --reload)
                    config_reload
                    ;;
                *)
                    log_error "Unknown configure command: ${1:-}"
                    show_help configure
                    exit 1
                    ;;
            esac
            ;;
        backup)
            config_backup "${1:-}"
            ;;
        restore)
            [[ $# -ge 1 ]] || error_exit "Backup name required"
            config_restore "$1"
            ;;
        automation)
            case "${1:-}" in
                start)
                    automation_start
                    ;;
                stop)
                    automation_stop
                    ;;
                *)
                    log_error "Unknown automation command: ${1:-}"
                    show_help automation
                    exit 1
                    ;;
            esac
            ;;
        help)
            show_help "${1:-}"
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"