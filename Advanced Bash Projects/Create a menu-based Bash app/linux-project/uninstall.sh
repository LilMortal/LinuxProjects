#!/bin/bash

# =============================================================================
# System Admin Menu - Uninstallation Script
# =============================================================================
# This script removes the System Admin Menu application from your system.
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation paths
readonly INSTALL_DIR="/opt/sysadmin-menu"
readonly BIN_LINK="/usr/local/bin/sysadmin-menu"
readonly SYSTEMD_SERVICE="/etc/systemd/system/sysadmin-menu.service"
readonly DOC_DIR="/usr/local/share/doc/sysadmin-menu"

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Print error message and exit
print_error() {
    print_color "$RED" "ERROR: $1" >&2
    exit 1
}

# Print success message
print_success() {
    print_color "$GREEN" "SUCCESS: $1"
}

# Print info message
print_info() {
    print_color "$BLUE" "INFO: $1"
}

# Print warning message
print_warning() {
    print_color "$YELLOW" "WARNING: $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root. Use: sudo $0"
    fi
}

# Stop and disable systemd service
stop_service() {
    print_info "Stopping and disabling systemd service..."
    
    if systemctl is-active --quiet sysadmin-menu; then
        systemctl stop sysadmin-menu
        print_info "Service stopped"
    fi
    
    if systemctl is-enabled --quiet sysadmin-menu; then
        systemctl disable sysadmin-menu
        print_info "Service disabled"
    fi
}

# Remove systemd service file
remove_service_file() {
    print_info "Removing systemd service file..."
    
    if [[ -f "$SYSTEMD_SERVICE" ]]; then
        rm "$SYSTEMD_SERVICE"
        systemctl daemon-reload
        print_success "Systemd service file removed"
    else
        print_info "Systemd service file not found"
    fi
}

# Remove symbolic link
remove_symlink() {
    print_info "Removing symbolic link..."
    
    if [[ -L "$BIN_LINK" ]]; then
        rm "$BIN_LINK"
        print_success "Symbolic link removed"
    else
        print_info "Symbolic link not found"
    fi
}

# Remove installation directory
remove_install_dir() {
    print_info "Removing installation directory..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        # Ask for confirmation before removing logs
        if [[ -d "$INSTALL_DIR/logs" ]] && [[ -n "$(ls -A "$INSTALL_DIR/logs" 2>/dev/null)" ]]; then
            print_warning "Log files found in $INSTALL_DIR/logs"
            read -p "Do you want to remove log files? (y/N): " remove_logs
            
            if [[ "$remove_logs" =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
                print_success "Installation directory removed (including logs)"
            else
                # Remove everything except logs
                find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name "logs" -exec rm -rf {} \;
                print_success "Installation directory removed (logs preserved)"
                print_info "Logs preserved in: $INSTALL_DIR/logs"
            fi
        else
            rm -rf "$INSTALL_DIR"
            print_success "Installation directory removed"
        fi
    else
        print_info "Installation directory not found"
    fi
}

# Remove documentation directory
remove_doc_dir() {
    print_info "Removing documentation directory..."
    
    if [[ -d "$DOC_DIR" ]]; then
        rm -rf "$DOC_DIR"
        print_success "Documentation directory removed"
    else
        print_info "Documentation directory not found"
    fi
}

# Main uninstallation function
main() {
    print_color "$YELLOW" "=== System Admin Menu Uninstallation ==="
    echo
    
    # Check if running as root
    check_root
    
    # Confirm uninstallation
    print_warning "This will completely remove System Admin Menu from your system."
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo
    
    # Stop and disable service
    stop_service
    
    # Remove systemd service file
    remove_service_file
    
    # Remove symbolic link
    remove_symlink
    
    # Remove installation directory
    remove_install_dir
    
    # Remove documentation directory
    remove_doc_dir
    
    echo
    print_success "Uninstallation completed successfully!"
    echo
    print_info "System Admin Menu has been removed from your system."
    
    # Check if logs were preserved
    if [[ -d "$INSTALL_DIR/logs" ]]; then
        print_info "Log files preserved in: $INSTALL_DIR/logs"
        print_info "You can remove them manually if no longer needed."
    fi
    
    echo
}

# Run main function
main "$@"