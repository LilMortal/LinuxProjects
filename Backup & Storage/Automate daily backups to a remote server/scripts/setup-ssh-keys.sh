#!/bin/bash

# SSH Key Setup Script for AutoBackup Pro
# ========================================

set -euo pipefail

readonly SCRIPT_NAME="AutoBackup SSH Setup"
readonly KEY_NAME="backup_key"
readonly KEY_PATH="$HOME/.ssh/$KEY_NAME"

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

show_help() {
    cat << EOF
$SCRIPT_NAME

USAGE:
    ./setup-ssh-keys.sh [REMOTE_HOST] [REMOTE_USER]

DESCRIPTION:
    Sets up SSH key authentication for AutoBackup Pro.
    Creates a dedicated SSH key pair and configures it for passwordless access.

ARGUMENTS:
    REMOTE_HOST    Remote backup server hostname or IP address
    REMOTE_USER    Username on the remote backup server

EXAMPLES:
    ./setup-ssh-keys.sh backup.example.com backupuser
    ./setup-ssh-keys.sh 192.168.1.100 ubuntu

EOF
}

create_ssh_key() {
    print_info "Creating SSH key pair..."
    
    if [[ -f "$KEY_PATH" ]]; then
        print_warning "SSH key already exists at $KEY_PATH"
        read -p "Overwrite existing key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing SSH key"
            return 0
        fi
    fi
    
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate SSH key
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "autobackup-$(hostname)-$(date +%Y%m%d)"
    
    chmod 600 "$KEY_PATH"
    chmod 644 "$KEY_PATH.pub"
    
    print_status "SSH key pair created successfully"
    print_info "Private key: $KEY_PATH"
    print_info "Public key: $KEY_PATH.pub"
}

copy_public_key() {
    local remote_host="$1"
    local remote_user="$2"
    
    print_info "Copying public key to remote server..."
    
    if ! ssh-copy-id -i "$KEY_PATH.pub" "$remote_user@$remote_host"; then
        print_error "Failed to copy public key to remote server"
        print_info "You may need to manually copy the public key:"
        print_info "cat $KEY_PATH.pub | ssh $remote_user@$remote_host 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'"
        return 1
    fi
    
    print_status "Public key copied to remote server"
}

test_connection() {
    local remote_host="$1"
    local remote_user="$2"
    
    print_info "Testing SSH connection..."
    
    if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=10 "$remote_user@$remote_host" "echo 'SSH connection successful'"; then
        print_status "SSH connection test successful"
        return 0
    else
        print_error "SSH connection test failed"
        return 1
    fi
}

create_ssh_config() {
    local remote_host="$1"
    local remote_user="$2"
    local ssh_config="$HOME/.ssh/config"
    
    print_info "Updating SSH configuration..."
    
    # Create backup of existing config
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "$ssh_config.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing SSH config"
    fi
    
    # Add backup server configuration
    cat >> "$ssh_config" << EOF

# AutoBackup Pro Configuration
Host backup-server
    HostName $remote_host
    User $remote_user
    Port 22
    IdentityFile $KEY_PATH
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
EOF
    
    chmod 600 "$ssh_config"
    print_status "SSH configuration updated"
    print_info "You can now connect using: ssh backup-server"
}

update_autobackup_config() {
    local remote_host="$1"
    local remote_user="$2"
    local config_file="/etc/autobackup/autobackup.conf"
    
    if [[ -f "$config_file" ]] && [[ -w "$config_file" ]]; then
        print_info "Updating AutoBackup configuration..."
        
        # Create backup
        sudo cp "$config_file" "$config_file.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Update configuration
        sudo sed -i "s/^REMOTE_HOST=.*/REMOTE_HOST=\"$remote_host\"/" "$config_file"
        sudo sed -i "s/^REMOTE_USER=.*/REMOTE_USER=\"$remote_user\"/" "$config_file"
        sudo sed -i "s|^SSH_KEY_PATH=.*|SSH_KEY_PATH=\"$KEY_PATH\"|" "$config_file"
        
        print_status "AutoBackup configuration updated"
    else
        print_warning "AutoBackup configuration not found or not writable"
        print_info "Manually update $config_file with:"
        print_info "  REMOTE_HOST=\"$remote_host\""
        print_info "  REMOTE_USER=\"$remote_user\""
        print_info "  SSH_KEY_PATH=\"$KEY_PATH\""
    fi
}

main() {
    print_colored "$BLUE" "$SCRIPT_NAME"
    print_colored "$BLUE" "$(printf '=%.0s' {1..30})"
    echo
    
    if [[ $# -ne 2 ]]; then
        show_help
        exit 1
    fi
    
    local remote_host="$1"
    local remote_user="$2"
    
    print_info "Setting up SSH key authentication"
    print_info "Remote host: $remote_host"
    print_info "Remote user: $remote_user"
    echo
    
    # Create SSH key
    create_ssh_key
    
    # Copy public key to remote server
    if ! copy_public_key "$remote_host" "$remote_user"; then
        print_error "Failed to set up SSH key authentication"
        exit 1
    fi
    
    # Test connection
    if ! test_connection "$remote_host" "$remote_user"; then
        print_error "SSH connection test failed"
        exit 1
    fi
    
    # Create SSH config
    create_ssh_config "$remote_host" "$remote_user"
    
    # Update AutoBackup configuration
    update_autobackup_config "$remote_host" "$remote_user"
    
    echo
    print_status "SSH key setup completed successfully!"
    print_info "You can now run: autobackup --dry-run"
    print_info "To test your backup configuration"
}

# Handle help option
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

main "$@"