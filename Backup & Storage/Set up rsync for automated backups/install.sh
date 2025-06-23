#!/bin/bash

#======================================================================
# RSYNC BACKUP TOOL INSTALLER
# Installs the rsync backup tool system-wide
#======================================================================

set -euo pipefail

readonly SCRIPT_NAME="rsync-backup-tool-installer"
readonly INSTALL_DIR="/opt/rsync-backup-tool"
readonly SERVICE_USER="backup"
readonly SERVICE_GROUP="backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $*"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Create backup user and group
create_backup_user() {
    log_info "Creating backup user and group..."
    
    if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
        groupadd --system "$SERVICE_GROUP"
        log_info "Created group: $SERVICE_GROUP"
    fi
    
    if ! getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
        useradd --system --gid "$SERVICE_GROUP" --shell /bin/bash \
                --home-dir "/var/lib/$SERVICE_USER" --create-home \
                --comment "Rsync Backup Service User" "$SERVICE_USER"
        log_info "Created user: $SERVICE_USER"
    fi
}

# Install the application files
install_files() {
    log_info "Installing application files to $INSTALL_DIR..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy files
    cp -r src config systemd examples "$INSTALL_DIR/"
    cp README.md "$INSTALL_DIR/"
    
    # Create logs directory
    mkdir -p "$INSTALL_DIR/logs"
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/src/backup.sh"
    
    log_info "Files installed successfully"
}

# Install systemd service files
install_systemd_service() {
    log_info "Installing systemd service and timer..."
    
    # Copy service files
    cp "$INSTALL_DIR/systemd/rsync-backup.service" /etc/systemd/system/
    cp "$INSTALL_DIR/systemd/rsync-backup.timer" /etc/systemd/system/
    
    # Update systemd
    systemctl daemon-reload
    
    log_info "Systemd service installed"
}

# Create backup directories
create_backup_dirs() {
    log_info "Creating backup directories..."
    
    mkdir -p /backup
    chown "$SERVICE_USER:$SERVICE_GROUP" /backup
    chmod 755 /backup
    
    log_info "Backup directories created"
}

# Install dependencies
install_dependencies() {
    log_info "Checking and installing dependencies..."
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y rsync cron
    
    log_info "Dependencies installed"
}

# Configure the service
configure_service() {
    log_info "Configuring the backup service..."
    
    # Create a sample exclude file
    cat > "/home/$SERVICE_USER/.backup_exclude" << EOF
# Sample exclude patterns for rsync backups
# Add patterns here to exclude files/directories from backups

.cache/
.tmp/
*.log
*.swp
*~
.DS_Store
Thumbs.db
node_modules/
EOF
    
    chown "$SERVICE_USER:$SERVICE_GROUP" "/home/$SERVICE_USER/.backup_exclude"
    
    log_info "Service configured"
}

# Main installation function
main() {
    log_info "Starting rsync-backup-tool installation..."
    
    # Check prerequisites
    check_root
    
    # Install dependencies first
    install_dependencies
    
    # Create user and group
    create_backup_user
    
    # Install application files
    install_files
    
    # Create backup directories
    create_backup_dirs
    
    # Install systemd service
    install_systemd_service
    
    # Configure the service
    configure_service
    
    log_info "Installation completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Edit the configuration file: $INSTALL_DIR/config/backup.conf"
    echo "2. Test the backup: sudo -u $SERVICE_USER $INSTALL_DIR/src/backup.sh -n"
    echo "3. Enable the timer: sudo systemctl enable --now rsync-backup.timer"
    echo "4. Check status: sudo systemctl status rsync-backup.timer"
    echo
    log_info "For manual execution: sudo -u $SERVICE_USER $INSTALL_DIR/src/backup.sh"
    log_info "View logs: journalctl -u rsync-backup.service -f"
}

# Error handling
trap 'log_error "Installation failed at line $LINENO"' ERR

# Execute main function
main "$@"