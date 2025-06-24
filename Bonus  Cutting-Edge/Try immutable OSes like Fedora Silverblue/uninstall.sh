#!/bin/bash

#==============================================================================
# ImmutableOS Explorer - Uninstallation Script
# 
# This script removes ImmutableOS Explorer from the system.
#
# Author: Your Name <your.email@example.com>
# License: MIT
# Version: 1.0.0
#==============================================================================

set -euo pipefail

readonly INSTALL_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/immutable-os-explorer"
readonly LOG_DIR="/var/log/immutable-os-explorer"
readonly DATA_DIR="/usr/share/immutable-os-explorer"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}ERROR: $message${NC}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}WARNING: $message${NC}" >&2
            ;;
        "INFO")
            echo -e "${BLUE}INFO: $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✓ $message${NC}"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Stop and disable systemd services
remove_systemd() {
    log "INFO" "Removing systemd services..."
    
    # Stop and disable timer
    if systemctl is-active --quiet immutable-os-explorer.timer 2>/dev/null; then
        systemctl stop immutable-os-explorer.timer
        log "SUCCESS" "Stopped systemd timer"
    fi
    
    if systemctl is-enabled --quiet immutable-os-explorer.timer 2>/dev/null; then
        systemctl disable immutable-os-explorer.timer
        log "SUCCESS" "Disabled systemd timer"
    fi
    
    # Remove service files
    if [[ -f "$SYSTEMD_DIR/immutable-os-explorer.service" ]]; then
        rm -f "$SYSTEMD_DIR/immutable-os-explorer.service"
        log "SUCCESS" "Removed systemd service file"
    fi
    
    if [[ -f "$SYSTEMD_DIR/immutable-os-explorer.timer" ]]; then
        rm -f "$SYSTEMD_DIR/immutable-os-explorer.timer"
        log "SUCCESS" "Removed systemd timer file"
    fi
    
    # Reload systemd
    systemctl daemon-reload
}

# Remove main script
remove_script() {
    log "INFO" "Removing main script..."
    
    if [[ -f "$INSTALL_DIR/immutable-os-explorer" ]]; then
        rm -f "$INSTALL_DIR/immutable-os-explorer"
        log "SUCCESS" "Removed main script"
    else
        log "WARN" "Main script not found"
    fi
}

# Remove configuration (with user confirmation)
remove_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        log "WARN" "Configuration directory contains: $CONFIG_DIR"
        read -p "Remove configuration files? This will delete your settings. (y/N): " remove_conf
        
        if [[ "${remove_conf,,}" =~ ^(y|yes)$ ]]; then
            rm -rf "$CONFIG_DIR"
            log "SUCCESS" "Removed configuration directory"
        else
            log "INFO" "Keeping configuration directory"
        fi
    fi
}

# Remove logs (with user confirmation)
remove_logs() {
    if [[ -d "$LOG_DIR" ]]; then
        echo ""
        log "WARN" "Log directory contains: $LOG_DIR"
        read -p "Remove log files? This will delete all logs. (y/N): " remove_logs
        
        if [[ "${remove_logs,,}" =~ ^(y|yes)$ ]]; then
            rm -rf "$LOG_DIR"
            log "SUCCESS" "Removed log directory"
        else
            log "INFO" "Keeping log directory"
        fi
    fi
}

# Remove data directory
remove_data() {
    log "INFO" "Removing data directory..."
    
    if [[ -d "$DATA_DIR" ]]; then
        rm -rf "$DATA_DIR"
        log "SUCCESS" "Removed data directory"
    else
        log "WARN" "Data directory not found"
    fi
}

# Remove logrotate configuration
remove_logrotate() {
    log "INFO" "Removing logrotate configuration..."
    
    if [[ -f "/etc/logrotate.d/immutable-os-explorer" ]]; then
        rm -f "/etc/logrotate.d/immutable-os-explorer"
        log "SUCCESS" "Removed logrotate configuration"
    else
        log "WARN" "Logrotate configuration not found"
    fi
}

# Remove man page
remove_man_page() {
    log "INFO" "Removing man page..."
    
    local man_file="/usr/local/share/man/man1/immutable-os-explorer.1"
    if [[ -f "$man_file" ]]; then
        rm -f "$man_file"
        log "SUCCESS" "Removed man page"
        
        # Update man database if mandb is available
        if command -v mandb >/dev/null 2>&1; then
            mandb -q 2>/dev/null || true
        fi
    else
        log "WARN" "Man page not found"
    fi
}

# Remove bash completion
remove_bash_completion() {
    log "INFO" "Removing bash completion..."
    
    if [[ -f "/etc/bash_completion.d/immutable-os-explorer" ]]; then
        rm -f "/etc/bash_completion.d/immutable-os-explorer"
        log "SUCCESS" "Removed bash completion"
    else
        log "WARN" "Bash completion not found"
    fi
}

# Main uninstallation function
main() {
    echo "ImmutableOS Explorer Uninstallation Script"
    echo "=========================================="
    echo ""
    
    check_root
    
    log "WARN" "This will remove ImmutableOS Explorer from your system."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
        log "INFO" "Uninstallation cancelled"
        exit 0
    fi
    
    echo ""
    log "INFO" "Starting uninstallation..."
    
    remove_systemd
    remove_script
    remove_data
    remove_logrotate
    remove_man_page
    remove_bash_completion
    remove_config
    remove_logs
    
    echo ""
    log "SUCCESS" "Uninstallation completed!"
    echo ""
    
    # Check if there are any remaining files
    local remaining_files=()
    
    [[ -f "$INSTALL_DIR/immutable-os-explorer" ]] && remaining_files+=("$INSTALL_DIR/immutable-os-explorer")
    [[ -d "$CONFIG_DIR" ]] && remaining_files+=("$CONFIG_DIR")
    [[ -d "$LOG_DIR" ]] && remaining_files+=("$LOG_DIR")
    [[ -d "$DATA_DIR" ]] && remaining_files+=("$DATA_DIR")
    
    if [[ ${#remaining_files[@]} -gt 0 ]]; then
        log "INFO" "Some files were preserved:"
        for file in "${remaining_files[@]}"; do
            echo "  - $file"
        done
        echo ""
        echo "You can manually remove them if needed."
    else
        log "SUCCESS" "All files have been removed."
    fi
    
    echo ""
    echo "Thank you for using ImmutableOS Explorer!"
}

# Run main function
main "$@"