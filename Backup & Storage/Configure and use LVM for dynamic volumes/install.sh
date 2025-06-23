#!/bin/bash

#===============================================================================
# LVM Dynamic Volume Manager - Installation Script
# 
# This script installs the LVM Manager and sets up the required components
# including configuration files, systemd services, and directory structure.
#
# Usage: sudo ./install.sh [OPTIONS]
#
# Author: System Administration Team
# Version: 1.0.0
# License: MIT
#===============================================================================

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="lvm-manager-install"
readonly INSTALL_PREFIX="/usr/local"
readonly CONFIG_DIR="/etc"
readonly LOG_DIR="/var/log/lvm-manager"
readonly BACKUP_DIR="/var/backup/lvm"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation options
FORCE_INSTALL=false
SKIP_SERVICE=false
SKIP_CONFIG=false
DRY_RUN=false

#===============================================================================
# Utility Functions
#===============================================================================

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_info() {
    print_color "$BLUE" "[INFO] $*"
}

print_success() {
    print_color "$GREEN" "[SUCCESS] $*"
}

print_warning() {
    print_color "$YELLOW" "[WARNING] $*"
}

print_error() {
    print_color "$RED" "[ERROR] $*" >&2
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_info "Checking system requirements..."
    
    # Check for required commands
    local required_commands=("systemctl" "tar" "cp" "mkdir" "chmod" "chown")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Check for LVM tools
    if ! command -v "lvm" &> /dev/null; then
        print_warning "LVM tools not found. Installing lvm2 package..."
        if command -v "apt-get" &> /dev/null; then
            apt-get update && apt-get install -y lvm2
        elif command -v "yum" &> /dev/null; then
            yum install -y lvm2
        elif command -v "dnf" &> /dev/null; then
            dnf install -y lvm2
        else
            print_error "Cannot install lvm2 package. Please install manually."
            exit 1
        fi
    fi
    
    print_success "System requirements check passed"
}

# Create required directories
create_directories() {
    print_info "Creating directory structure..."
    
    local directories=(
        "$LOG_DIR"
        "$BACKUP_DIR"
        "/etc/lvm-manager"
        "/etc/lvm-manager/hooks"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "Would create directory: $dir"
        else
            mkdir -p "$dir"
            chmod 755 "$dir"
            chown root:root "$dir"
            print_info "Created directory: $dir"
        fi
    done
    
    # Set specific permissions for log directory
    if [[ "$DRY_RUN" == "false" ]]; then
        chmod 755 "$LOG_DIR"
        chown root:root "$LOG_DIR"
    fi
}

# Install main script
install_script() {
    local source_script="src/lvm-manager.sh"
    local target_script="$INSTALL_PREFIX/bin/lvm-manager"
    
    if [[ ! -f "$source_script" ]]; then
        print_error "Source script not found: $source_script"
        exit 1
    fi
    
    print_info "Installing main script..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would install: $source_script -> $target_script"
    else
        cp "$source_script" "$target_script"
        chmod 755 "$target_script"
        chown root:root "$target_script"
        print_success "Installed script: $target_script"
    fi
}

# Install configuration file
install_config() {
    local source_config="config/lvm-manager.conf"
    local target_config="$CONFIG_DIR/lvm-manager.conf"
    
    if [[ "$SKIP_CONFIG" == "true" ]]; then
        print_info "Skipping configuration file installation"
        return 0
    fi
    
    if [[ ! -f "$source_config" ]]; then
        print_error "Source configuration not found: $source_config"
        exit 1
    fi
    
    print_info "Installing configuration file..."
    
    # Check if config already exists
    if [[ -f "$target_config" ]] && [[ "$FORCE_INSTALL" == "false" ]]; then
        print_warning "Configuration file already exists: $target_config"
        print_warning "Use --force to overwrite or --skip-config to skip"
        
        # Create backup of existing config
        local backup_config="$target_config.backup.$(date +%Y%m%d-%H%M%S)"
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$target_config" "$backup_config"
            print_info "Backed up existing config to: $backup_config"
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would install: $source_config -> $target_config"
    else
        cp "$source_config" "$target_config"
        chmod 600 "$target_config"
        chown root:root "$target_config"
        print_success "Installed configuration: $target_config"
    fi
}

# Install systemd service
install_service() {
    local source_service="systemd/lvm-monitor.service"
    local target_service="$SYSTEMD_DIR/lvm-monitor.service"
    
    if [[ "$SKIP_SERVICE" == "true" ]]; then
        print_info "Skipping systemd service installation"
        return 0
    fi
    
    if [[ ! -f "$source_service" ]]; then
        print_error "Source service file not found: $source_service"
        exit 1
    fi
    
    print_info "Installing systemd service..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would install: $source_service -> $target_service"
        print_info "Would reload systemd daemon"
    else
        cp "$source_service" "$target_service"
        chmod 644 "$target_service"
        chown root:root "$target_service"
        
        # Reload systemd daemon
        systemctl daemon-reload
        
        print_success "Installed systemd service: $target_service"
        print_info "Service can be enabled with: systemctl enable lvm-monitor.service"
        print_info "Service can be started with: systemctl start lvm-monitor.service"
    fi
}

# Create sample hook scripts
create_sample_hooks() {
    local hooks_dir="/etc/lvm-manager/hooks"
    
    print_info "Creating sample hook scripts..."
    
    # Pre-operation hook
    local pre_hook="$hooks_dir/pre-operation.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would create: $pre_hook"
    else
        cat > "$pre_hook" << 'EOF'
#!/bin/bash
# Pre-operation hook for LVM Manager
# This script is executed before any LVM operation
#
# Arguments:
#   $1 - Operation type (create-pv, create-vg, create-lv, etc.)
#   $2 - Target (device, volume group, logical volume, etc.)
#
# Exit codes:
#   0 - Continue with operation
#   1 - Abort operation

OPERATION="$1"
TARGET="$2"

# Log the operation
logger -t lvm-manager-hook "Pre-operation: $OPERATION on $TARGET"

# Example: Prevent operations on specific devices
if [[ "$TARGET" == "/dev/sda"* ]]; then
    echo "ERROR: Operations on /dev/sda* are not allowed"
    exit 1
fi

# Example: Send notification
# notify-send "LVM Operation" "Starting $OPERATION on $TARGET"

exit 0
EOF
        chmod 755 "$pre_hook"
        chown root:root "$pre_hook"
    fi
    
    # Post-operation hook
    local post_hook="$hooks_dir/post-operation.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would create: $post_hook"
    else
        cat > "$post_hook" << 'EOF'
#!/bin/bash
# Post-operation hook for LVM Manager
# This script is executed after any successful LVM operation
#
# Arguments:
#   $1 - Operation type
#   $2 - Target
#   $3 - Result (success/failure)

OPERATION="$1"
TARGET="$2"
RESULT="$3"

# Log the result
logger -t lvm-manager-hook "Post-operation: $OPERATION on $TARGET - $RESULT"

# Example: Update monitoring system
# curl -X POST "http://monitoring.local/api/lvm-event" \
#      -d "operation=$OPERATION&target=$TARGET&result=$RESULT"

# Example: Send notification
if [[ "$RESULT" == "success" ]]; then
    # notify-send "LVM Operation Complete" "$OPERATION on $TARGET completed successfully"
    :
else
    # notify-send "LVM Operation Failed" "$OPERATION on $TARGET failed"
    :
fi

exit 0
EOF
        chmod 755 "$post_hook"
        chown root:root "$post_hook"
    fi
}

# Setup logrotate configuration
setup_logrotate() {
    local logrotate_config="/etc/logrotate.d/lvm-manager"
    
    print_info "Setting up log rotation..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would create: $logrotate_config"
    else
        cat > "$logrotate_config" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /usr/bin/systemctl reload-or-restart lvm-monitor.service > /dev/null 2>&1 || true
    endscript
}
EOF
        chmod 644 "$logrotate_config"
        chown root:root "$logrotate_config"
        print_success "Created logrotate configuration: $logrotate_config"
    fi
}

# Display installation summary
show_summary() {
    print_success "Installation completed successfully!"
    echo
    print_info "Installation Summary:"
    echo "  Script: $INSTALL_PREFIX/bin/lvm-manager"
    echo "  Configuration: $CONFIG_DIR/lvm-manager.conf"
    echo "  Log directory: $LOG_DIR"
    echo "  Backup directory: $BACKUP_DIR"
    
    if [[ "$SKIP_SERVICE" == "false" ]]; then
        echo "  Systemd service: $SYSTEMD_DIR/lvm-monitor.service"
    fi
    
    echo
    print_info "Next steps:"
    echo "  1. Review and customize the configuration file"
    echo "  2. Test the installation: lvm-manager --help"
    
    if [[ "$SKIP_SERVICE" == "false" ]]; then
        echo "  3. Enable the monitoring service: systemctl enable lvm-monitor.service"
        echo "  4. Start the monitoring service: systemctl start lvm-monitor.service"
    fi
    
    echo "  5. Check the logs: tail -f $LOG_DIR/lvm-manager.log"
    echo
    print_warning "Remember to backup your LVM configuration before performing operations!"
}

# Display usage information
show_usage() {
    cat << EOF
LVM Manager Installation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force                 Force installation, overwrite existing files
    --skip-service         Skip systemd service installation
    --skip-config          Skip configuration file installation
    --dry-run              Show what would be done without executing
    --help                 Show this help message

EXAMPLES:
    # Standard installation
    sudo $0
    
    # Force installation (overwrite existing files)
    sudo $0 --force
    
    # Skip service installation
    sudo $0 --skip-service
    
    # Dry run (show what would be done)
    sudo $0 --dry-run

EOF
}

#===============================================================================
# Main Function
#===============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --skip-service)
                SKIP_SERVICE=true
                shift
                ;;
            --skip-config)
                SKIP_CONFIG=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Show header
    print_info "LVM Dynamic Volume Manager - Installation Script"
    echo
    
    # Perform checks
    if [[ "$DRY_RUN" == "false" ]]; then
        check_root
    fi
    check_requirements
    
    # Installation steps
    create_directories
    install_script
    install_config
    install_service
    create_sample_hooks
    setup_logrotate
    
    # Show completion summary
    if [[ "$DRY_RUN" == "false" ]]; then
        show_summary
    else
        print_info "Dry run completed. No changes were made."
    fi
}

# Execute main function with all arguments
main "$@"