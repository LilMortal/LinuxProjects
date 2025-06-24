#!/bin/bash

# PodManager Installation Script
# Installs and configures PodManager on Ubuntu/Debian systems

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log/podmanager"
SERVICE_USER="podmanager"

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "$RED" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system compatibility
check_system() {
    print_status "$BLUE" "Checking system compatibility..."
    
    if ! command -v apt >/dev/null 2>&1; then
        print_status "$RED" "This installer currently supports Ubuntu/Debian systems only"
        exit 1
    fi
    
    # Check Ubuntu/Debian version
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        print_status "$GREEN" "Detected: $PRETTY_NAME"
    fi
}

# Install dependencies
install_dependencies() {
    print_status "$BLUE" "Installing dependencies..."
    
    apt update
    apt install -y \
        podman \
        curl \
        jq \
        rsync \
        systemd \
        logrotate
    
    print_status "$GREEN" "Dependencies installed successfully"
}

# Create service user
create_user() {
    print_status "$BLUE" "Creating service user..."
    
    if ! id "$SERVICE_USER" >/dev/null 2>&1; then
        useradd -r -s /bin/false -d /var/lib/podmanager "$SERVICE_USER"
        print_status "$GREEN" "User $SERVICE_USER created"
    else
        print_status "$YELLOW" "User $SERVICE_USER already exists"
    fi
}

# Install files
install_files() {
    print_status "$BLUE" "Installing PodManager files..."
    
    # Install main script
    cp bin/podmanager "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/podmanager"
    
    # Install daemon script
    cp systemd/podmanager-daemon "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/podmanager-daemon"
    
    # Install configuration
    cp config/podmanager.conf "$CONFIG_DIR/"
    chmod 644 "$CONFIG_DIR/podmanager.conf"
    
    # Install systemd service
    cp systemd/podmanager.service "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/podmanager.service"
    
    print_status "$GREEN" "Files installed successfully"
}

# Create directories
create_directories() {
    print_status "$BLUE" "Creating directories..."
    
    # Log directory
    mkdir -p "$LOG_DIR"
    chown "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Runtime directory
    mkdir -p /var/run/podmanager
    chown "$SERVICE_USER:$SERVICE_USER" /var/run/podmanager
    chmod 755 /var/run/podmanager
    
    # Library directory
    mkdir -p /var/lib/podmanager
    chown "$SERVICE_USER:$SERVICE_USER" /var/lib/podmanager
    chmod 755 /var/lib/podmanager
    
    print_status "$GREEN" "Directories created successfully"
}

# Setup log rotation
setup_logrotate() {
    print_status "$BLUE" "Setting up log rotation..."
    
    cat > /etc/logrotate.d/podmanager << 'EOF'
/var/log/podmanager/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 podmanager podmanager
    postrotate
        systemctl reload podmanager.service >/dev/null 2>&1 || true
    endscript
}
EOF
    
    print_status "$GREEN" "Log rotation configured"
}

# Configure systemd
configure_systemd() {
    print_status "$BLUE" "Configuring systemd service..."
    
    systemctl daemon-reload
    systemctl enable podmanager.service
    
    print_status "$GREEN" "Systemd service configured"
}

# Setup Podman for service user
setup_podman() {
    print_status "$BLUE" "Configuring Podman for service user..."
    
    # Enable lingering for service user
    loginctl enable-linger "$SERVICE_USER"
    
    # Configure subuid/subgid
    if ! grep -q "^$SERVICE_USER:" /etc/subuid; then
        echo "$SERVICE_USER:100000:65536" >> /etc/subuid
    fi
    
    if ! grep -q "^$SERVICE_USER:" /etc/subgid; then
        echo "$SERVICE_USER:100000:65536" >> /etc/subgid
    fi
    
    print_status "$GREEN" "Podman configured for service user"
}

# Create shell completion
setup_completion() {
    print_status "$BLUE" "Setting up shell completion..."
    
    # Create bash completion
    mkdir -p /etc/bash_completion.d
    cat > /etc/bash_completion.d/podmanager << 'EOF'
# PodManager bash completion

_podmanager() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="pull run ps stop start restart rm logs exec inspect images build tag rmi image-prune push volume network health-check stats scan-security stop-all cleanup --help --version --debug"
    
    case "${prev}" in
        podmanager)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        volume)
            COMPREPLY=( $(compgen -W "create ls rm inspect" -- ${cur}) )
            return 0
            ;;
        network)
            COMPREPLY=( $(compgen -W "create ls rm connect" -- ${cur}) )
            return 0
            ;;
    esac
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}

complete -F _podmanager podmanager
EOF
    
    print_status "$GREEN" "Shell completion installed"
}

# Final configuration
final_setup() {
    print_status "$BLUE" "Performing final setup..."
    
    # Test installation
    if "$INSTALL_DIR/podmanager" --version >/dev/null 2>&1; then
        print_status "$GREEN" "Installation test passed"
    else
        print_status "$RED" "Installation test failed"
        exit 1
    fi
    
    # Start service
    if systemctl start podmanager.service; then
        print_status "$GREEN" "PodManager service started"
    else
        print_status "$YELLOW" "Service start failed (this is normal if no containers are running)"
    fi
}

# Show post-install information
show_info() {
    print_status "$GREEN" "Installation completed successfully!"
    echo
    print_status "$BLUE" "Next steps:"
    echo "1. Test the installation: podmanager --help"
    echo "2. Pull an image: podmanager pull nginx:latest"
    echo "3. Run a container: podmanager run --name test -d nginx:latest"
    echo "4. Check status: systemctl status podmanager.service"
    echo
    print_status "$BLUE" "Configuration:"
    echo "- Main config: /etc/podmanager.conf"
    echo "- Logs: /var/log/podmanager/"
    echo "- Service: systemctl {start|stop|restart} podmanager.service"
    echo
    print_status "$BLUE" "Documentation:"
    echo "- README: https://github.com/username/podmanager"
    echo "- Help: podmanager --help"
}

# Main installation function
main() {
    print_status "$GREEN" "PodManager Installation Script"
    echo "=============================="
    echo
    
    check_root
    check_system
    install_dependencies
    create_user
    install_files
    create_directories
    setup_logrotate
    configure_systemd
    setup_podman
    setup_completion
    final_setup
    
    echo
    show_info
}

# Run installation
main "$@"