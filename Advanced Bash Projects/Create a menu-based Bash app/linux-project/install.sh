#!/bin/bash

# =============================================================================
# System Admin Menu - Installation Script
# =============================================================================
# This script installs the System Admin Menu application on your system.
# It copies files to appropriate locations and sets up permissions.
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
readonly BIN_DIR="/usr/local/bin"
readonly SYSTEMD_DIR="/etc/systemd/system"
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root. Use: sudo $0"
    fi
}

# Check system requirements
check_requirements() {
    print_info "Checking system requirements..."
    
    # Check if we're on a supported system
    if ! command -v systemctl &> /dev/null; then
        print_error "systemd is required but not found"
    fi
    
    # Check required commands
    local required_commands=("bash" "awk" "grep" "sed" "cut" "tail" "head" "sort")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command '$cmd' not found"
        fi
    done
    
    print_success "System requirements check passed"
}

# Create installation directories
create_directories() {
    print_info "Creating installation directories..."
    
    local directories=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/bin"
        "$INSTALL_DIR/config"
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/systemd"
        "$DOC_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_info "Created directory: $dir"
        fi
    done
}

# Copy files to installation directory
copy_files() {
    print_info "Copying files to installation directory..."
    
    # Copy main script
    cp "bin/sysadmin-menu" "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/sysadmin-menu"
    
    # Copy configuration file
    cp "config/sysadmin-menu.conf" "$INSTALL_DIR/config/"
    
    # Copy systemd service file
    cp "systemd/sysadmin-menu.service" "$INSTALL_DIR/systemd/"
    
    # Copy documentation
    cp "README.md" "$DOC_DIR/"
    
    print_success "Files copied successfully"
}

# Create symbolic link
create_symlink() {
    print_info "Creating symbolic link..."
    
    if [[ -L "$BIN_DIR/sysadmin-menu" ]]; then
        rm "$BIN_DIR/sysadmin-menu"
    fi
    
    ln -s "$INSTALL_DIR/bin/sysadmin-menu" "$BIN_DIR/sysadmin-menu"
    print_success "Symbolic link created: $BIN_DIR/sysadmin-menu"
}

# Install systemd service
install_systemd_service() {
    print_info "Installing systemd service..."
    
    cp "$INSTALL_DIR/systemd/sysadmin-menu.service" "$SYSTEMD_DIR/"
    systemctl daemon-reload
    
    print_success "Systemd service installed"
    print_info "To enable the service: sudo systemctl enable sysadmin-menu"
    print_info "To start the service: sudo systemctl start sysadmin-menu"
}

# Set file permissions
set_permissions() {
    print_info "Setting file permissions..."
    
    # Set ownership
    chown -R root:root "$INSTALL_DIR"
    
    # Set directory permissions
    find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    
    # Make script executable
    chmod +x "$INSTALL_DIR/bin/sysadmin-menu"
    
    # Make logs directory writable
    chmod 755 "$INSTALL_DIR/logs"
    
    print_success "File permissions set"
}

# Main installation function
main() {
    print_color "$YELLOW" "=== System Admin Menu Installation ==="
    echo
    
    # Check if running as root
    check_root
    
    # Check system requirements
    check_requirements
    
    # Create directories
    create_directories
    
    # Copy files
    copy_files
    
    # Create symbolic link
    create_symlink
    
    # Install systemd service
    install_systemd_service
    
    # Set permissions
    set_permissions
    
    echo
    print_success "Installation completed successfully!"
    echo
    print_info "You can now run the System Admin Menu with: sysadmin-menu"
    print_info "Configuration file location: $INSTALL_DIR/config/sysadmin-menu.conf"
    print_info "Log file location: $INSTALL_DIR/logs/sysadmin-menu.log"
    print_info "Documentation: $DOC_DIR/README.md"
    echo
    print_info "To enable the systemd service:"
    print_info "  sudo systemctl enable sysadmin-menu"
    print_info "  sudo systemctl start sysadmin-menu"
    echo
}

# Run main function
main "$@"