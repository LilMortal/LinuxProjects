import React, { useState } from 'react';
import { Server, Shield, Download, FileText, Terminal, Settings, Eye, Copy, Check } from 'lucide-react';

interface ProjectFile {
  name: string;
  path: string;
  content: string;
  type: 'bash' | 'config' | 'service' | 'markdown' | 'text';
}

const projectFiles: ProjectFile[] = [
  {
    name: 'wireguard-setup.sh',
    path: 'wireguard-vpn-server/wireguard-setup.sh',
    type: 'bash',
    content: `#!/bin/bash

# WireGuard VPN Server Setup and Management Script
# Compatible with Ubuntu 22.04+ and other systemd-based Linux distributions
# Author: System Administrator
# License: MIT

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="\${SCRIPT_DIR}/wireguard.conf"
LOG_FILE="/var/log/wireguard-setup.log"
WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

# Logging function
log() {
    local level="\$1"
    shift
    local message="\$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[\${timestamp}] [\${level}] \${message}" | tee -a "\${LOG_FILE}"
    
    case "\${level}" in
        "ERROR")
            echo -e "\${RED}[\${level}] \${message}\${NC}" >&2
            ;;
        "SUCCESS")
            echo -e "\${GREEN}[\${level}] \${message}\${NC}"
            ;;
        "WARNING")
            echo -e "\${YELLOW}[\${level}] \${message}\${NC}"
            ;;
        "INFO")
            echo -e "\${BLUE}[\${level}] \${message}\${NC}"
            ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "\$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ \$EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Check system compatibility
check_system() {
    log "INFO" "Checking system compatibility..."
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        error_exit "systemd is required but not found"
    fi
    
    # Check if we're on a supported distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "\$ID" in
            ubuntu|debian|centos|rhel|fedora)
                log "SUCCESS" "Detected supported OS: \$PRETTY_NAME"
                ;;
            *)
                log "WARNING" "Untested OS detected: \$PRETTY_NAME. Proceeding anyway..."
                ;;
        esac
    fi
}

# Install WireGuard
install_wireguard() {
    log "INFO" "Installing WireGuard..."
    
    # Update package lists
    if command -v apt &> /dev/null; then
        apt update
        apt install -y wireguard wireguard-tools iptables-persistent
    elif command -v yum &> /dev/null; then
        yum install -y epel-release
        yum install -y wireguard-tools iptables-services
    elif command -v dnf &> /dev/null; then
        dnf install -y wireguard-tools iptables-services
    else
        error_exit "Unsupported package manager. Please install WireGuard manually."
    fi
    
    log "SUCCESS" "WireGuard installed successfully"
}

# Generate server keys
generate_server_keys() {
    log "INFO" "Generating server keys..."
    
    # Create WireGuard directory if it doesn't exist
    mkdir -p "\${WG_CONFIG_DIR}"
    cd "\${WG_CONFIG_DIR}"
    
    # Generate private and public keys
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    
    # Set secure permissions
    chmod 600 server_private.key
    chmod 644 server_public.key
    
    log "SUCCESS" "Server keys generated successfully"
}

# Create server configuration
create_server_config() {
    log "INFO" "Creating server configuration..."
    
    local server_private_key
    server_private_key=$(cat "\${WG_CONFIG_DIR}/server_private.key")
    
    # Load custom configuration if exists
    if [[ -f "\${CONFIG_FILE}" ]]; then
        log "INFO" "Loading configuration from \${CONFIG_FILE}"
        source "\${CONFIG_FILE}"
    fi
    
    # Create WireGuard server configuration
    cat > "\${WG_CONFIG_DIR}/\${WG_INTERFACE}.conf" << EOF
[Interface]
# Server configuration
PrivateKey = \${server_private_key}
Address = \${WG_SERVER_IP}/24
ListenPort = \${WG_PORT}
SaveConfig = false

# Enable IP forwarding and NAT
PostUp = echo 1 > /proc/sys/net/ipv4/ip_forward
PostUp = iptables -A FORWARD -i \${WG_INTERFACE} -j ACCEPT
PostUp = iptables -A FORWARD -o \${WG_INTERFACE} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i \${WG_INTERFACE} -j ACCEPT
PostDown = iptables -D FORWARD -o \${WG_INTERFACE} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configurations will be added here
EOF
    
    chmod 600 "\${WG_CONFIG_DIR}/\${WG_INTERFACE}.conf"
    log "SUCCESS" "Server configuration created"
}

# Add client configuration
add_client() {
    local client_name="\$1"
    local client_ip="\$2"
    
    if [[ -z "\${client_name}" || -z "\${client_ip}" ]]; then
        error_exit "Usage: add_client <client_name> <client_ip>"
    fi
    
    log "INFO" "Adding client: \${client_name} with IP: \${client_ip}"
    
    # Generate client keys
    cd "\${WG_CONFIG_DIR}"
    wg genkey | tee "\${client_name}_private.key" | wg pubkey > "\${client_name}_public.key"
    chmod 600 "\${client_name}_private.key"
    chmod 644 "\${client_name}_public.key"
    
    local client_private_key client_public_key server_public_key
    client_private_key=$(cat "\${client_name}_private.key")
    client_public_key=$(cat "\${client_name}_public.key")
    server_public_key=$(cat "server_public.key")
    
    # Create client configuration file
    cat > "\${client_name}.conf" << EOF
[Interface]
PrivateKey = \${client_private_key}
Address = \${client_ip}/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = \${server_public_key}
Endpoint = YOUR_SERVER_IP:\${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    # Add client to server configuration
    cat >> "\${WG_INTERFACE}.conf" << EOF

# Client: \${client_name}
[Peer]
PublicKey = \${client_public_key}
AllowedIPs = \${client_ip}/32
EOF
    
    log "SUCCESS" "Client \${client_name} added successfully"
    log "INFO" "Client configuration saved to: \${WG_CONFIG_DIR}/\${client_name}.conf"
}

# Remove client configuration
remove_client() {
    local client_name="\$1"
    
    if [[ -z "\${client_name}" ]]; then
        error_exit "Usage: remove_client <client_name>"
    fi
    
    log "INFO" "Removing client: \${client_name}"
    
    # Remove client files
    cd "\${WG_CONFIG_DIR}"
    rm -f "\${client_name}_private.key" "\${client_name}_public.key" "\${client_name}.conf"
    
    # Remove client from server config (this is a simplified approach)
    # In production, you might want a more sophisticated method
    local client_public_key
    if [[ -f "\${client_name}_public.key" ]]; then
        client_public_key=$(cat "\${client_name}_public.key")
        # Remove the peer section (this is basic - consider using a proper config parser)
        sed -i "/# Client: \${client_name}/,/^$/d" "\${WG_INTERFACE}.conf"
    fi
    
    log "SUCCESS" "Client \${client_name} removed successfully"
}

# Start WireGuard service
start_service() {
    log "INFO" "Starting WireGuard service..."
    
    # Enable and start WireGuard
    systemctl enable "wg-quick@\${WG_INTERFACE}"
    systemctl start "wg-quick@\${WG_INTERFACE}"
    
    # Check status
    if systemctl is-active --quiet "wg-quick@\${WG_INTERFACE}"; then
        log "SUCCESS" "WireGuard service started successfully"
    else
        error_exit "Failed to start WireGuard service"
    fi
}

# Stop WireGuard service
stop_service() {
    log "INFO" "Stopping WireGuard service..."
    
    systemctl stop "wg-quick@\${WG_INTERFACE}"
    systemctl disable "wg-quick@\${WG_INTERFACE}"
    
    log "SUCCESS" "WireGuard service stopped"
}

# Show service status
show_status() {
    log "INFO" "WireGuard service status:"
    systemctl status "wg-quick@\${WG_INTERFACE}" --no-pager
    
    echo ""
    log "INFO" "WireGuard interface status:"
    wg show
}

# Show help
show_help() {
    cat << EOF
WireGuard VPN Server Setup and Management Script

Usage: \$0 [OPTION]

Options:
    install                 Install WireGuard and set up server
    add-client <name> <ip>  Add a new client configuration
    remove-client <name>    Remove a client configuration
    start                   Start WireGuard service
    stop                    Stop WireGuard service
    restart                 Restart WireGuard service
    status                  Show service and interface status
    help                    Show this help message

Examples:
    \$0 install
    \$0 add-client john 10.0.0.2
    \$0 remove-client john
    \$0 status

Log file: \${LOG_FILE}
Config directory: \${WG_CONFIG_DIR}
EOF
}

# Main function
main() {
    # Create log file if it doesn't exist
    touch "\${LOG_FILE}"
    
    # Load configuration
    if [[ -f "\${CONFIG_FILE}" ]]; then
        source "\${CONFIG_FILE}"
    fi
    
    case "\${1:-help}" in
        "install")
            check_root
            check_system
            install_wireguard
            generate_server_keys
            create_server_config
            start_service
            log "SUCCESS" "WireGuard VPN server installation complete!"
            log "INFO" "Don't forget to:"
            log "INFO" "1. Configure your firewall to allow port \${WG_PORT}/udp"
            log "INFO" "2. Replace 'YOUR_SERVER_IP' in client configs with your actual server IP"
            log "INFO" "3. Add clients using: \$0 add-client <name> <ip>"
            ;;
        "add-client")
            check_root
            add_client "\$2" "\$3"
            systemctl reload "wg-quick@\${WG_INTERFACE}" 2>/dev/null || true
            ;;
        "remove-client")
            check_root
            remove_client "\$2"
            systemctl reload "wg-quick@\${WG_INTERFACE}" 2>/dev/null || true
            ;;
        "start")
            check_root
            start_service
            ;;
        "stop")
            check_root
            stop_service
            ;;
        "restart")
            check_root
            stop_service
            sleep 2
            start_service
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "\$@"`
  },
  {
    name: 'wireguard.conf',
    path: 'wireguard-vpn-server/wireguard.conf',
    type: 'config',
    content: `# WireGuard VPN Server Configuration File
# This file contains customizable settings for the WireGuard setup script

# Network Configuration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"

# Logging Configuration
LOG_FILE="/var/log/wireguard-setup.log"
WG_CONFIG_DIR="/etc/wireguard"

# DNS Servers for clients (comma-separated)
CLIENT_DNS="8.8.8.8, 8.8.4.4"

# Network Interface for NAT (usually eth0, but might be different)
# Change this to match your server's internet-facing interface
EXTERNAL_INTERFACE="eth0"

# Client IP Pool (for automatic IP assignment)
# First available IP for clients
CLIENT_IP_START="10.0.0.2"
CLIENT_IP_END="10.0.0.254"

# Security Settings
# Enable/disable IP forwarding persistence
ENABLE_IP_FORWARD="true"

# Firewall rules
# Set to "true" to automatically configure iptables rules
AUTO_CONFIGURE_FIREWALL="true"

# Keep alive interval for clients (seconds)
KEEPALIVE_INTERVAL="25"

# Server endpoints
# Leave empty to auto-detect, or set your public IP/domain
# SERVER_ENDPOINT="your-server-ip-or-domain.com"

# Backup configuration
BACKUP_DIR="/etc/wireguard/backups"
ENABLE_BACKUP="true"`
  },
  {
    name: 'wireguard-vpn.service',
    path: 'wireguard-vpn-server/wireguard-vpn.service',
    type: 'service',
    content: `[Unit]
Description=WireGuard VPN Server Management Service
Documentation=https://www.wireguard.com/
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/wireguard-setup.sh start
ExecStop=/usr/local/bin/wireguard-setup.sh stop
ExecReload=/usr/local/bin/wireguard-setup.sh restart

# Security settings
User=root
Group=root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=wireguard-vpn

# Resource limits
LimitNOFILE=65536
LimitNPROC=65536

# Restart policy
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target`
  },
  {
    name: 'wireguard-monitor.sh',
    path: 'wireguard-vpn-server/scripts/wireguard-monitor.sh',
    type: 'bash',
    content: `#!/bin/bash

# WireGuard VPN Server Monitoring Script
# This script monitors the WireGuard service and sends alerts if issues are detected

set -euo pipefail

# Configuration
WG_INTERFACE="wg0"
LOG_FILE="/var/log/wireguard-monitor.log"
ALERT_EMAIL=""  # Set your email for alerts
CHECK_INTERVAL=60  # Check every 60 seconds

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

# Logging function
log() {
    local level="\$1"
    shift
    local message="\$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[\${timestamp}] [\${level}] \${message}" | tee -a "\${LOG_FILE}"
}

# Check if WireGuard service is running
check_service() {
    if systemctl is-active --quiet "wg-quick@\${WG_INTERFACE}"; then
        return 0
    else
        return 1
    fi
}

# Check if WireGuard interface exists
check_interface() {
    if ip link show "\${WG_INTERFACE}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get connected clients count
get_connected_clients() {
    wg show "\${WG_INTERFACE}" peers 2>/dev/null | wc -l
}

# Get interface statistics
get_interface_stats() {
    if check_interface; then
        echo "Interface: \${WG_INTERFACE}"
        echo "Status: UP"
        echo "Connected clients: $(get_connected_clients)"
        echo "Detailed peer info:"
        wg show "\${WG_INTERFACE}"
    else
        echo "Interface: \${WG_INTERFACE}"
        echo "Status: DOWN"
    fi
}

# Send alert (placeholder for email/webhook integration)
send_alert() {
    local message="\$1"
    log "ALERT" "\${message}"
    
    # Uncomment and configure for email alerts
    # if [[ -n "\${ALERT_EMAIL}" ]]; then
    #     echo "\${message}" | mail -s "WireGuard VPN Alert" "\${ALERT_EMAIL}"
    # fi
}

# Main monitoring loop
monitor() {
    log "INFO" "Starting WireGuard monitoring..."
    
    while true; do
        if ! check_service; then
            send_alert "WireGuard service is not running on \$(hostname)"
            log "ERROR" "WireGuard service is down"
        elif ! check_interface; then
            send_alert "WireGuard interface \${WG_INTERFACE} is not available on \$(hostname)"
            log "ERROR" "WireGuard interface is down"
        else
            log "INFO" "WireGuard is running normally. Connected clients: $(get_connected_clients)"
        fi
        
        sleep "\${CHECK_INTERVAL}"
    done
}

# Show current status
status() {
    echo "WireGuard VPN Server Status"
    echo "=========================="
    echo
    
    if check_service; then
        echo -e "\${GREEN}Service Status: RUNNING\${NC}"
    else
        echo -e "\${RED}Service Status: STOPPED\${NC}"
    fi
    
    echo
    get_interface_stats
}

# Show help
show_help() {
    cat << EOF
WireGuard VPN Server Monitoring Script

Usage: \$0 [OPTION]

Options:
    monitor     Start continuous monitoring (run as daemon)
    status      Show current status
    help        Show this help message

Examples:
    \$0 monitor   # Start monitoring
    \$0 status    # Check current status

Log file: \${LOG_FILE}
EOF
}

# Main function
main() {
    case "\${1:-help}" in
        "monitor")
            monitor
            ;;
        "status")
            status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "\$@"`
  },
  {
    name: 'install.sh',
    path: 'wireguard-vpn-server/install.sh',
    type: 'bash',
    content: `#!/bin/bash

# WireGuard VPN Server Installation Script
# This script installs the WireGuard VPN server management tools

set -euo pipefail

# Configuration
INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

echo -e "\${GREEN}WireGuard VPN Server Installation\${NC}"
echo "=================================="
echo

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
    echo -e "\${RED}Error: This script must be run as root (use sudo)\${NC}"
    exit 1
fi

# Install main script
echo "Installing WireGuard setup script..."
cp "\${SCRIPT_DIR}/wireguard-setup.sh" "\${INSTALL_DIR}/"
chmod +x "\${INSTALL_DIR}/wireguard-setup.sh"

# Install monitoring script
echo "Installing monitoring script..."
mkdir -p "\${INSTALL_DIR}"
cp "\${SCRIPT_DIR}/scripts/wireguard-monitor.sh" "\${INSTALL_DIR}/"
chmod +x "\${INSTALL_DIR}/wireguard-monitor.sh"

# Install systemd service
echo "Installing systemd service..."
cp "\${SCRIPT_DIR}/wireguard-vpn.service" "\${SERVICE_DIR}/"
systemctl daemon-reload

# Create configuration file
if [[ ! -f "/etc/wireguard-vpn/wireguard.conf" ]]; then
    echo "Creating configuration directory..."
    mkdir -p "/etc/wireguard-vpn"
    cp "\${SCRIPT_DIR}/wireguard.conf" "/etc/wireguard-vpn/"
    echo -e "\${YELLOW}Configuration file created at: /etc/wireguard-vpn/wireguard.conf\${NC}"
    echo -e "\${YELLOW}Please review and modify the configuration as needed.\${NC}"
fi

echo
echo -e "\${GREEN}Installation completed successfully!\${NC}"
echo
echo "Available commands:"
echo "  wireguard-setup.sh install          - Install and configure WireGuard"
echo "  wireguard-setup.sh add-client       - Add a new client"
echo "  wireguard-setup.sh status           - Check service status"
echo "  wireguard-monitor.sh status         - Check detailed status"
echo
echo "To start the installation:"
echo "  sudo wireguard-setup.sh install"
echo
echo -e "\${YELLOW}Remember to configure your firewall and update the server IP in client configs!\${NC}"`
  },
  {
    name: 'README.md',
    path: 'wireguard-vpn-server/README.md',
    type: 'markdown',
    content: `# WireGuard VPN Server

A comprehensive, production-ready WireGuard VPN server setup and management solution for Linux systems.

## Overview

This project provides a complete WireGuard VPN server solution with automated setup, client management, monitoring, and maintenance capabilities. It's designed for system administrators who need a secure, reliable, and easy-to-manage VPN infrastructure.

The solution includes automated installation scripts, comprehensive logging, systemd service integration, and monitoring capabilities to ensure your VPN server runs smoothly in production environments.

## Features

- **Automated Installation**: One-command setup of WireGuard VPN server
- **Client Management**: Easy addition and removal of VPN clients
- **Security-First Design**: Secure key generation and permission management
- **Comprehensive Logging**: Detailed logging to files and syslog
- **Systemd Integration**: Proper service management with auto-start capabilities
- **Monitoring**: Built-in monitoring and alerting capabilities
- **Firewall Configuration**: Automatic iptables rules for NAT and forwarding
- **Cross-Distribution Support**: Works on Ubuntu, Debian, CentOS, RHEL, and Fedora
- **Configuration Management**: Centralized configuration file for easy customization
- **Backup Support**: Automatic configuration backup capabilities

## Requirements

### System Requirements
- **Operating System**: Ubuntu 22.04+ (recommended), Debian 11+, CentOS 8+, RHEL 8+, or Fedora 35+
- **Architecture**: x86_64 (AMD64) or ARM64
- **Memory**: Minimum 512MB RAM (1GB+ recommended)
- **Storage**: At least 100MB free space for installation and logs
- **Network**: Public IP address and UDP port 51820 accessible from the internet

### Software Dependencies
- **systemd**: For service management
- **iptables**: For firewall rules and NAT
- **WireGuard**: Automatically installed by the script
- **Standard Linux utilities**: bash, curl, wget, grep, sed, awk

### Privileges
- Root access (sudo) required for installation and configuration

## Installation

### Quick Start
1. **Clone the repository**:
   \`\`\`bash
   git clone https://github.com/yourusername/wireguard-vpn-server.git
   cd wireguard-vpn-server
   \`\`\`

2. **Run the installation script**:
   \`\`\`bash
   sudo ./install.sh
   \`\`\`

3. **Install and configure WireGuard**:
   \`\`\`bash
   sudo wireguard-setup.sh install
   \`\`\`

### Manual Installation
1. **Download the project files**:
   \`\`\`bash
   wget https://github.com/yourusername/wireguard-vpn-server/archive/main.zip
   unzip main.zip
   cd wireguard-vpn-server-main
   \`\`\`

2. **Make scripts executable**:
   \`\`\`bash
   chmod +x *.sh scripts/*.sh
   \`\`\`

3. **Copy files to system directories**:
   \`\`\`bash
   sudo cp wireguard-setup.sh /usr/local/bin/
   sudo cp scripts/wireguard-monitor.sh /usr/local/bin/
   sudo cp wireguard-vpn.service /etc/systemd/system/
   sudo systemctl daemon-reload
   \`\`\`

## Configuration

### Main Configuration File
The main configuration is stored in \`/etc/wireguard-vpn/wireguard.conf\`:

\`\`\`bash
# Network Configuration
WG_INTERFACE="wg0"              # WireGuard interface name
WG_PORT="51820"                 # UDP port for WireGuard
WG_NETWORK="10.0.0.0/24"        # VPN network subnet
WG_SERVER_IP="10.0.0.1"         # Server IP within VPN network

# External Interface (for NAT)
EXTERNAL_INTERFACE="eth0"        # Your server's internet interface

# DNS Servers for clients
CLIENT_DNS="8.8.8.8, 8.8.4.4"  # DNS servers for VPN clients

# Logging
LOG_FILE="/var/log/wireguard-setup.log"
\`\`\`

### Environment Variables
You can also use environment variables to override configuration:

\`\`\`bash
export WG_PORT=51820
export WG_NETWORK="10.0.0.0/24"
export LOG_FILE="/var/log/wireguard.log"
\`\`\`

### Firewall Configuration
The script automatically configures iptables rules. For custom firewall setups:

\`\`\`bash
# Allow WireGuard port
sudo ufw allow 51820/udp

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
\`\`\`

## Usage

### Basic Commands

**Install WireGuard VPN server**:
\`\`\`bash
sudo wireguard-setup.sh install
\`\`\`

**Add a new client**:
\`\`\`bash
sudo wireguard-setup.sh add-client john 10.0.0.2
\`\`\`

**Remove a client**:
\`\`\`bash
sudo wireguard-setup.sh remove-client john
\`\`\`

**Check service status**:
\`\`\`bash
sudo wireguard-setup.sh status
\`\`\`

**Start/Stop/Restart service**:
\`\`\`bash
sudo wireguard-setup.sh start
sudo wireguard-setup.sh stop
sudo wireguard-setup.sh restart
\`\`\`

### Advanced Usage

**Monitor VPN server continuously**:
\`\`\`bash
sudo wireguard-monitor.sh monitor
\`\`\`

**Check detailed status**:
\`\`\`bash
sudo wireguard-monitor.sh status
\`\`\`

**View active connections**:
\`\`\`bash
sudo wg show
\`\`\`

**View server configuration**:
\`\`\`bash
sudo cat /etc/wireguard/wg0.conf
\`\`\`

### Client Setup
After adding a client, you'll find the client configuration file at:
\`/etc/wireguard/[client-name].conf\`

**Copy this file to your client device and import it into your WireGuard client application.**

## Automation

### Systemd Service
The VPN server can be managed as a systemd service:

\`\`\`bash
# Enable auto-start on boot
sudo systemctl enable wireguard-vpn

# Start the service
sudo systemctl start wireguard-vpn

# Check service status
sudo systemctl status wireguard-vpn
\`\`\`

### Cron Jobs
For automated monitoring and maintenance:

\`\`\`bash
# Add to root's crontab
sudo crontab -e

# Check VPN status every 5 minutes
*/5 * * * * /usr/local/bin/wireguard-monitor.sh status >> /var/log/wireguard-cron.log 2>&1

# Restart service daily at 3 AM (optional)
0 3 * * * /usr/local/bin/wireguard-setup.sh restart >> /var/log/wireguard-cron.log 2>&1
\`\`\`

### Automated Backup
Create a backup script and schedule it:

\`\`\`bash
#!/bin/bash
# Backup WireGuard configuration
tar -czf "/backup/wireguard-backup-$(date +%Y%m%d).tar.gz" /etc/wireguard/
\`\`\`

Add to crontab:
\`\`\`bash
# Backup configurations weekly
0 2 * * 0 /usr/local/bin/backup-wireguard.sh
\`\`\`

## Logging

### Log Files
- **Main log**: \`/var/log/wireguard-setup.log\`
- **System log**: \`journalctl -u wg-quick@wg0\`
- **Monitor log**: \`/var/log/wireguard-monitor.log\`

### Viewing Logs

**View recent activity**:
\`\`\`bash
sudo tail -f /var/log/wireguard-setup.log
\`\`\`

**View systemd service logs**:
\`\`\`bash
sudo journalctl -u wg-quick@wg0 -f
\`\`\`

**View all WireGuard-related logs**:
\`\`\`bash
sudo journalctl | grep -i wireguard
\`\`\`

### Log Rotation
Configure logrotate for WireGuard logs:

\`\`\`bash
sudo tee /etc/logrotate.d/wireguard << EOF
/var/log/wireguard-*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
\`\`\`

## Security Tips

### Key Management
- **Private keys** are stored with 600 permissions (readable only by root)
- **Never share private keys** between clients
- **Regularly rotate keys** for enhanced security
- **Backup keys securely** using encrypted storage

### Network Security
- **Use strong firewall rules** to limit access to the WireGuard port
- **Consider changing the default port** (51820) for security through obscurity
- **Monitor failed connection attempts** in the logs
- **Use fail2ban** to block repeated failed attempts

### Server Hardening
\`\`\`bash
# Disable SSH password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload ssh

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Install and configure fail2ban
sudo apt install fail2ban
\`\`\`

### Client Security
- **Use full-tunnel routing** (0.0.0.0/0) for maximum security
- **Enable kill switch** in client applications
- **Use DNS filtering** services like Cloudflare for Families (1.1.1.3)
- **Regularly update** WireGuard client applications

## Example Output

### Successful Installation
\`\`\`
[2024-01-15 10:30:15] [INFO] Checking system compatibility...
[2024-01-15 10:30:15] [SUCCESS] Detected supported OS: Ubuntu 22.04.3 LTS
[2024-01-15 10:30:16] [INFO] Installing WireGuard...
[2024-01-15 10:30:45] [SUCCESS] WireGuard installed successfully
[2024-01-15 10:30:45] [INFO] Generating server keys...
[2024-01-15 10:30:46] [SUCCESS] Server keys generated successfully
[2024-01-15 10:30:46] [INFO] Creating server configuration...
[2024-01-15 10:30:46] [SUCCESS] Server configuration created
[2024-01-15 10:30:46] [INFO] Starting WireGuard service...
[2024-01-15 10:30:47] [SUCCESS] WireGuard service started successfully
[2024-01-15 10:30:47] [SUCCESS] WireGuard VPN server installation complete!
\`\`\`

### Client Addition
\`\`\`
[2024-01-15 10:35:20] [INFO] Adding client: john with IP: 10.0.0.2
[2024-01-15 10:35:20] [SUCCESS] Client john added successfully
[2024-01-15 10:35:20] [INFO] Client configuration saved to: /etc/wireguard/john.conf
\`\`\`

### Status Check
\`\`\`
WireGuard VPN Server Status
==========================

Service Status: RUNNING

Interface: wg0
Status: UP
Connected clients: 2
Detailed peer info:
peer: ABC123DEF456...
  endpoint: 192.168.1.100:54321
  allowed ips: 10.0.0.2/32
  latest handshake: 1 minute, 23 seconds ago
  transfer: 15.2 MiB received, 128.5 MiB sent
\`\`\`

## Author and License

### Author
**System Administrator**  
Email: admin@example.com  
GitHub: https://github.com/yourusername

### Contributors
- Initial development and testing
- Documentation and examples
- Security review and hardening

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

\`\`\`
MIT License

Copyright (c) 2024 WireGuard VPN Server Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
\`\`\`

### Support
For support, please:
1. Check the documentation and examples above
2. Review the logs for error messages
3. Open an issue on GitHub with detailed information
4. Join our community discussions for help and tips

### Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with proper documentation
4. Add tests if applicable
5. Submit a pull request

---

**⚠️ Important Security Note**: Always keep your server updated and monitor the logs regularly. VPN servers are critical infrastructure components that require ongoing maintenance and security attention.`
  }
];

const projectStructure = `
wireguard-vpn-server/
├── README.md                    # Comprehensive documentation
├── install.sh                   # Installation script
├── wireguard-setup.sh          # Main VPN server management script
├── wireguard.conf              # Configuration file
├── wireguard-vpn.service       # Systemd service file
└── scripts/
    └── wireguard-monitor.sh    # Monitoring and alerting script
`;

function App() {
  const [selectedFile, setSelectedFile] = useState<ProjectFile | null>(null);
  const [copiedFile, setCopiedFile] = useState<string | null>(null);

  const copyToClipboard = async (content: string, fileName: string) => {
    try {
      await navigator.clipboard.writeText(content);
      setCopiedFile(fileName);
      setTimeout(() => setCopiedFile(null), 2000);
    } catch (err) {
      console.error('Failed to copy: ', err);
    }
  };

  const getFileIcon = (type: string) => {
    switch (type) {
      case 'bash':
        return <Terminal className="w-4 h-4" />;
      case 'config':
        return <Settings className="w-4 h-4" />;
      case 'service':
        return <Server className="w-4 h-4" />;
      case 'markdown':
        return <FileText className="w-4 h-4" />;
      default:
        return <FileText className="w-4 h-4" />;
    }
  };

  const getLanguage = (type: string) => {
    switch (type) {
      case 'bash':
        return 'bash';
      case 'config':
        return 'ini';
      case 'service':
        return 'ini';
      case 'markdown':
        return 'markdown';
      default:
        return 'text';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900">
      {/* Header */}
      <header className="bg-slate-800/50 backdrop-blur-sm border-b border-slate-700/50 sticky top-0 z-50">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 text-blue-400">
              <Shield className="w-8 h-8" />
              <Server className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">WireGuard VPN Server</h1>
              <p className="text-slate-300 text-sm">Production-ready Linux VPN solution</p>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-6 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Project Overview */}
          <div className="lg:col-span-1 space-y-6">
            {/* Quick Info */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl p-6 border border-slate-700/50">
              <h2 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-blue-400" />
                Project Overview
              </h2>
              <div className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-slate-400">Language:</span>
                  <span className="text-white font-medium">Bash</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Platform:</span>
                  <span className="text-white font-medium">Linux</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Compatibility:</span>
                  <span className="text-white font-medium">Ubuntu 22.04+</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Service:</span>
                  <span className="text-white font-medium">systemd</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">License:</span>
                  <span className="text-white font-medium">MIT</span>
                </div>
              </div>
            </div>

            {/* Project Structure */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl p-6 border border-slate-700/50">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <FileText className="w-5 h-5 text-green-400" />
                Project Structure
              </h3>
              <pre className="text-sm text-slate-300 font-mono bg-slate-900/50 p-4 rounded-lg overflow-x-auto">
                {projectStructure}
              </pre>
            </div>

            {/* Quick Actions */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl p-6 border border-slate-700/50">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <Terminal className="w-5 h-5 text-yellow-400" />
                Quick Start
              </h3>
              <div className="space-y-3">
                <div className="bg-slate-900/50 p-3 rounded-lg">
                  <code className="text-sm text-green-400 font-mono">
                    sudo ./install.sh
                  </code>
                </div>
                <div className="bg-slate-900/50 p-3 rounded-lg">
                  <code className="text-sm text-blue-400 font-mono">
                    sudo wireguard-setup.sh install
                  </code>
                </div>
                <div className="bg-slate-900/50 p-3 rounded-lg">
                  <code className="text-sm text-purple-400 font-mono">
                    sudo wireguard-setup.sh add-client john 10.0.0.2
                  </code>
                </div>
              </div>
            </div>
          </div>

          {/* File Browser and Viewer */}
          <div className="lg:col-span-2">
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700/50 overflow-hidden">
              {/* File List */}
              <div className="border-b border-slate-700/50">
                <div className="p-4 bg-slate-900/30">
                  <h2 className="text-xl font-semibold text-white flex items-center gap-2">
                    <FileText className="w-5 h-5 text-blue-400" />
                    Project Files
                  </h2>
                </div>
                <div className="max-h-48 overflow-y-auto">
                  {projectFiles.map((file) => (
                    <button
                      key={file.name}
                      onClick={() => setSelectedFile(file)}
                      className={`w-full text-left px-4 py-3 hover:bg-slate-700/30 transition-colors border-b border-slate-700/20 flex items-center gap-3 \${
                        selectedFile?.name === file.name ? 'bg-blue-900/30 border-blue-500/50' : ''
                      }`}
                    >
                      <div className="text-slate-400">
                        {getFileIcon(file.type)}
                      </div>
                      <div className="flex-1">
                        <div className="text-white font-medium">{file.name}</div>
                        <div className="text-xs text-slate-400">{file.path}</div>
                      </div>
                      <div className="text-xs text-slate-500 uppercase tracking-wide">
                        {file.type}
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              {/* File Content */}
              <div className="p-6">
                {selectedFile ? (
                  <div>
                    <div className="flex items-center justify-between mb-4">
                      <div className="flex items-center gap-3">
                        <div className="text-slate-400">
                          {getFileIcon(selectedFile.type)}
                        </div>
                        <div>
                          <h3 className="text-lg font-semibold text-white">{selectedFile.name}</h3>
                          <p className="text-sm text-slate-400">{selectedFile.path}</p>
                        </div>
                      </div>
                      <button
                        onClick={() => copyToClipboard(selectedFile.content, selectedFile.name)}
                        className="flex items-center gap-2 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors text-sm"
                      >
                        {copiedFile === selectedFile.name ? (
                          <>
                            <Check className="w-4 h-4" />
                            Copied!
                          </>
                        ) : (
                          <>
                            <Copy className="w-4 h-4" />
                            Copy
                          </>
                        )}
                      </button>
                    </div>
                    <div className="bg-slate-900 rounded-lg p-4 overflow-x-auto">
                      <pre className="text-sm text-slate-300 font-mono whitespace-pre-wrap">
                        {selectedFile.content}
                      </pre>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-12">
                    <Eye className="w-12 h-12 text-slate-600 mx-auto mb-4" />
                    <p className="text-slate-400 text-lg">Select a file to view its contents</p>
                    <p className="text-slate-500 text-sm mt-2">
                      Click on any file from the list above to view and copy its content
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Features Grid */}
        <div className="mt-12 grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            {
              icon: <Shield className="w-6 h-6" />,
              title: "Security First",
              description: "Secure key generation, proper permissions, and automated firewall rules"
            },
            {
              icon: <Server className="w-6 h-6" />,
              title: "systemd Integration",
              description: "Proper service management with auto-start and monitoring capabilities"
            },
            {
              icon: <Terminal className="w-6 h-6" />,
              title: "Easy Management",
              description: "Simple CLI commands for installation, client management, and monitoring"
            },
            {
              icon: <FileText className="w-6 h-6" />,
              title: "Comprehensive Docs",
              description: "Detailed documentation with examples and security best practices"
            }
          ].map((feature, index) => (
            <div key={index} className="bg-slate-800/50 backdrop-blur-sm rounded-xl p-6 border border-slate-700/50">
              <div className="text-blue-400 mb-3">
                {feature.icon}
              </div>
              <h3 className="text-white font-semibold mb-2">{feature.title}</h3>
              <p className="text-slate-400 text-sm">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Footer */}
      <footer className="bg-slate-900/50 backdrop-blur-sm border-t border-slate-700/50 mt-12">
        <div className="container mx-auto px-6 py-8">
          <div className="text-center">
            <p className="text-slate-400 mb-2">
              WireGuard VPN Server - Production-ready Linux VPN solution
            </p>
            <p className="text-slate-500 text-sm">
              Compatible with Ubuntu 22.04+, systemd-based distributions • MIT License
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;