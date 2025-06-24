#!/bin/bash

#
# TilingWM Manager - Automation Service
#
# This script provides automated workspace management, time-based switching,
# and system event handling for the i3 tiling window manager.
#
# Usage: ./automation.sh [--daemon|--once|--help]
#
# Author: TilingWM Manager Project
# License: MIT
#

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="tilingwm-automation"
readonly CONFIG_DIR="$HOME/.config/tilingwm"
readonly DATA_DIR="$HOME/.local/share/tilingwm"
readonly LOG_DIR="$DATA_DIR/logs"
readonly LOG_FILE="$LOG_DIR/automation.log"
readonly PID_FILE="$DATA_DIR/automation.pid"
readonly WORKSPACE_CONFIG="$CONFIG_DIR/workspaces.conf"

# Runtime variables
DAEMON_MODE=false
CHECK_INTERVAL=30
MAX_IDLE_TIME=300
WORKSPACE_TIMEOUT=60

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$DAEMON_MODE" == "false" ]]; then
        case "$level" in
            ERROR)
                echo "ERROR: $message" >&2
                ;;
            WARN)
                echo "WARNING: $message" >&2
                ;;
            INFO)
                echo "$message"
                ;;
        esac
    fi
    
    # Send to syslog
    case "$level" in
        ERROR)
            logger -t "$SCRIPT_NAME" -p user.err "$message" 2>/dev/null || true
            ;;
        WARN)
            logger -t "$SCRIPT_NAME" -p user.warning "$message" 2>/dev/null || true
            ;;
        INFO)
            logger -t "$SCRIPT_NAME" -p user.info "$message" 2>/dev/null || true
            ;;
    esac
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# Error handling
error_exit() {
    log_error "$1"
    cleanup
    exit 1
}

cleanup() {
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Configuration loading
load_config() {
    # Load default configuration
    CHECK_INTERVAL=${TILINGWM_CHECK_INTERVAL:-30}
    MAX_IDLE_TIME=${TILINGWM_MAX_IDLE_TIME:-300}
    WORKSPACE_TIMEOUT=${TILINGWM_WORKSPACE_TIMEOUT:-60}
    
    # Load workspace configuration if available
    if [[ -f "$WORKSPACE_CONFIG" ]]; then
        source "$WORKSPACE_CONFIG" 2>/dev/null || {
            log_warn "Failed to load workspace configuration: $WORKSPACE_CONFIG"
        }
    fi
    
    log_info "Configuration loaded - Check interval: ${CHECK_INTERVAL}s, Idle timeout: ${MAX_IDLE_TIME}s"
}

# System state detection
get_idle_time() {
    # Get idle time in milliseconds, convert to seconds
    if command -v xprintidle &>/dev/null; then
        local idle_ms=$(xprintidle 2>/dev/null || echo "0")
        echo $((idle_ms / 1000))
    else
        # Fallback: check last activity from /proc/stat
        local uptime=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "0")
        local last_activity=$(stat -c %Y /dev/console 2>/dev/null || echo "$uptime")
        echo $((uptime - last_activity))
    fi
}

get_battery_status() {
    local battery_dir="/sys/class/power_supply"
    local status="Unknown"
    local level=100
    
    if [[ -d "$battery_dir" ]]; then
        for bat in "$battery_dir"/BAT*; do
            if [[ -d "$bat" ]]; then
                status=$(cat "$bat/status" 2>/dev/null || echo "Unknown")
                level=$(cat "$bat/capacity" 2>/dev/null || echo "100")
                break
            fi
        done
    fi
    
    echo "$status:$level"
}

get_current_time_slot() {
    local hour=$(date +%H)
    local hour_num=$((10#$hour))  # Convert to decimal to avoid octal interpretation
    
    case $hour_num in
        0[0-8])
            echo "night"
            ;;
        0[9-9]|1[0-1])
            echo "morning"
            ;;
        1[2-7])
            echo "afternoon"
            ;;
        1[8-9]|2[0-3])
            echo "evening"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# i3 interaction
check_i3_running() {
    pgrep -x "i3" > /dev/null
}

get_current_workspace() {
    if check_i3_running; then
        i3-msg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.focused) | .name' || echo "1"
    else
        echo "1"
    fi
}

get_workspace_windows() {
    local workspace="$1"
    if check_i3_running; then
        i3-msg -t get_tree 2>/dev/null | jq -r ".nodes[] | .nodes[] | select(.name == \"$workspace\") | .nodes | length" || echo "0"
    else
        echo "0"
    fi
}

switch_workspace() {
    local workspace="$1"
    local reason="$2"
    
    if check_i3_running; then
        local current_ws=$(get_current_workspace)
        
        if [[ "$current_ws" != "$workspace" ]]; then
            log_info "Switching to workspace '$workspace' ($reason)"
            i3-msg "workspace $workspace" &>/dev/null || {
                log_warn "Failed to switch to workspace: $workspace"
                return 1
            }
        fi
    else
        log_warn "Cannot switch workspace: i3 not running"
        return 1
    fi
}

# Workspace automation rules
apply_time_based_rules() {
    local time_slot=$(get_current_time_slot)
    local target_workspace=""
    
    case "$time_slot" in
        morning)
            target_workspace="1"  # Default workspace for morning
            ;;
        afternoon)
            target_workspace="2"  # Work workspace
            ;;
        evening)
            target_workspace="3"  # Personal workspace
            ;;
        night)
            target_workspace="10" # Background workspace
            ;;
    esac
    
    if [[ -n "$target_workspace" ]]; then
        switch_workspace "$target_workspace" "time-based rule: $time_slot"
    fi
}

apply_idle_rules() {
    local idle_time=$(get_idle_time)
    
    if [[ $idle_time -gt $MAX_IDLE_TIME ]]; then
        local current_ws=$(get_current_workspace)
        local window_count=$(get_workspace_windows "$current_ws")
        
        # Only switch if current workspace has no windows or is not workspace 10
        if [[ $window_count -eq 0 || "$current_ws" != "10" ]]; then
            switch_workspace "10" "idle timeout: ${idle_time}s"
        fi
    fi
}

apply_battery_rules() {
    local battery_info=$(get_battery_status)
    local status=$(echo "$battery_info" | cut -d: -f1)
    local level=$(echo "$battery_info" | cut -d: -f2)
    
    # Switch to power-saving workspace when battery is low
    if [[ "$status" == "Discharging" && $level -lt 20 ]]; then
        switch_workspace "9" "low battery: ${level}%"
    fi
}

# Window management automation
manage_empty_workspaces() {
    if ! check_i3_running; then
        return
    fi
    
    # Get list of workspaces with no windows (except workspace 1 and 10)
    local empty_workspaces
    empty_workspaces=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.windows == 0 and .num != 1 and .num != 10) | .name')
    
    for ws in $empty_workspaces; do
        # Remove empty workspace by switching to it then back to workspace 1
        log_info "Removing empty workspace: $ws"
        i3-msg "workspace $ws; workspace 1" &>/dev/null || true
    done
}

# Application-specific rules
apply_application_rules() {
    if ! check_i3_running; then
        return
    fi
    
    # Move specific applications to designated workspaces
    # Firefox to workspace 2
    if pgrep -x firefox > /dev/null; then
        i3-msg '[class="Firefox"] move to workspace 2' &>/dev/null || true
    fi
    
    # Terminal applications to workspace 1
    i3-msg '[class="Gnome-terminal|Xterm|URxvt"] move to workspace 1' &>/dev/null || true
    
    # Media applications to workspace 8
    i3-msg '[class="vlc|mpv|spotify"] move to workspace 8' &>/dev/null || true
}

# Main automation loop
automation_cycle() {
    local cycle_count=0
    
    log_info "Starting automation cycle..."
    
    while true; do
        cycle_count=$((cycle_count + 1))
        
        # Apply automation rules
        apply_time_based_rules
        apply_idle_rules
        apply_battery_rules
        apply_application_rules
        
        # Periodic maintenance
        if [[ $((cycle_count % 10)) -eq 0 ]]; then
            manage_empty_workspaces
        fi
        
        # Log status every hour
        if [[ $((cycle_count % 120)) -eq 0 ]]; then
            local current_ws=$(get_current_workspace)
            local idle_time=$(get_idle_time)
            local time_slot=$(get_current_time_slot)
            log_info "Status - Workspace: $current_ws, Idle: ${idle_time}s, Time: $time_slot"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Daemon management
start_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            error_exit "Automation daemon already running (PID: $existing_pid)"
        else
            log_warn "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi
    
    # Create PID file
    echo $$ > "$PID_FILE"
    
    log_info "Starting TilingWM automation daemon (PID: $$)"
    
    # Run automation cycle
    automation_cycle
}

run_once() {
    log_info "Running automation cycle once..."
    
    apply_time_based_rules
    apply_idle_rules
    apply_battery_rules
    apply_application_rules
    manage_empty_workspaces
    
    log_info "Single automation cycle completed"
}

# Usage information
show_usage() {
    cat << EOF
TilingWM Automation Service

Usage: $0 [OPTIONS]

OPTIONS:
    --daemon        Run as daemon (background service)
    --once          Run automation rules once and exit
    --help          Show this help message

EXAMPLES:
    $0 --daemon     # Start background automation
    $0 --once       # Run rules once

CONFIGURATION:
    Edit $WORKSPACE_CONFIG to customize workspace rules
    
ENVIRONMENT VARIABLES:
    TILINGWM_CHECK_INTERVAL     Check interval in seconds (default: 30)
    TILINGWM_MAX_IDLE_TIME      Idle timeout in seconds (default: 300)
    TILINGWM_WORKSPACE_TIMEOUT  Workspace switch timeout (default: 60)

EOF
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --daemon)
                DAEMON_MODE=true
                shift
                ;;
            --once)
                shift
                load_config
                run_once
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Load configuration
    load_config
    
    # Check if i3 is running
    if ! check_i3_running; then
        error_exit "i3 window manager is not running"
    fi
    
    # Start daemon or show usage
    if [[ "$DAEMON_MODE" == "true" ]]; then
        start_daemon
    else
        show_usage
        exit 1
    fi
}

# Run main function
main "$@"