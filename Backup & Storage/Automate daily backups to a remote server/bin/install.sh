#!/bin/bash

# AutoBackup Pro Installation Script
# ==================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

print_status() {
    print_colored "$GREEN" "✓ $1"
}

print_warning() {
    print_colored "$YELLOW" "⚠ $1"
}

print_error() {
    print_colored "$RED" "✗ $1"
}

print_info() {
    print_colored "$BLUE" "ℹ $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

install_files() {
    print_info "Installing AutoBackup Pro files..."
    
    # Create directories
    mkdir -p /etc/autobackup
    mkdir -p /var/lib/autobackup
    mkdir -p /var/log/autobackup
    mkdir -p /usr/share/doc/autobackup
    
    # Install main script
    cp "$PROJECT_ROOT/bin/autobackup.sh" /usr/local/bin/autobackup
    chmod 755 /usr/local/bin/autobackup
    print_status "Installed main script to /usr/local/bin/autobackup"
    
    # Install configuration
    if [[ ! -f /etc/autobackup/autobackup.conf ]]; then
        cp "$PROJECT_ROOT/config/autobackup.conf" /etc/autobackup/
        chmod 600 /etc/autobackup/autobackup.conf
        print_status "Installed configuration to /etc/autobackup/autobackup.conf"
    else
        print_warning "Configuration file already exists, not overwriting"
        print_info "Backup existing config and copy new template if needed"
    fi
    
    # Install systemd files
    cp "$PROJECT_ROOT/systemd/autobackup.service" /etc/systemd/system/
    cp "$PROJECT_ROOT/systemd/autobackup.timer" /etc/systemd/system/
    print_status "Installed systemd service and timer files"
    
    # Install documentation
    cp "$PROJECT_ROOT/README.md" /usr/share/doc/autobackup/
    print_status "Installed documentation to /usr/share/doc/autobackup/"
    
    # Set permissions
    chown -R root:root /etc/autobackup
    chown -R "$SUDO_USER:$SUDO_USER" /var/lib/autobackup /var/log/autobackup
    chmod 750 /var/lib/autobackup /var/log/autobackup
    
    print_status "Set appropriate file permissions"
}

setup_systemd() {
    print_info "Setting up systemd service..."
    
    # Reload systemd
    systemctl daemon-reload
    print_status "Reloaded systemd daemon"
    
    # Enable timer (but don't start yet)
    systemctl enable autobackup.timer
    print_status "Enabled autobackup timer"
    
    print_info "To start the backup timer, run: sudo systemctl start autobackup.timer"
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    local deps=("rsync" "tar" "ssh" "find" "date")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Install them with: apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    print_status "All dependencies are installed"
}

create_sample_ssh_config() {
    local ssh_dir="/home/$SUDO_USER/.ssh"
    local ssh_config="$ssh_dir/config"
    
    if [[ -n "${SUDO_USER:-}" ]] && [[ ! -f "$ssh_config" ]]; then
        print_info "Creating sample SSH configuration..."
        
        mkdir -p "$ssh_dir"
        cat > "$ssh_config" << 'EOF'
# AutoBackup Pro SSH Configuration
Host backup-server
    HostName backup.example.com
    User backupuser
    Port 22
    IdentityFile ~/.ssh/backup_key
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        
        chown -R "$SUDO_USER:$SUDO_USER" "$ssh_dir"
        chmod 700 "$ssh_dir"
        chmod 600 "$ssh_config"
        
        print_status "Created sample SSH config at $ssh_config"
        print_info "Edit this file to match your backup server configuration"
    fi
}

show_next_steps() {
    print_info "Installation completed successfully!"
    echo
    print_colored "$YELLOW" "Next Steps:"
    echo "1. Edit configuration: sudo nano /etc/autobackup/autobackup.conf"
    echo "2. Set up SSH key authentication for your backup server"
    echo "3. Test the backup: autobackup --dry-run"
    echo "4. Start the timer: sudo systemctl start autobackup.timer"
    echo "5. Check status: autobackup --status"
    echo
    print_info "For detailed instructions, see: /usr/share/doc/autobackup/README.md"
}

main() {
    print_colored "$BLUE" "AutoBackup Pro Installation"
    print_colored "$BLUE" "=========================="
    echo
    
    check_root
    check_dependencies
    install_files
    setup_systemd
    create_sample_ssh_config
    show_next_steps
}

main "$@"