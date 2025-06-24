#!/bin/bash

#==============================================================================
# ImmutableOS Explorer - Installation Script
# 
# This script installs ImmutableOS Explorer system-wide with proper 
# permissions, logging, and systemd integration.
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

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local required_deps=("curl" "jq" "sha256sum" "lsblk")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies first:"
        
        # Detect package manager and provide appropriate command
        if command -v apt >/dev/null 2>&1; then
            echo "  sudo apt update && sudo apt install ${missing_deps[*]}"
        elif command -v dnf >/dev/null 2>&1; then
            echo "  sudo dnf install ${missing_deps[*]}"
        elif command -v yum >/dev/null 2>&1; then
            echo "  sudo yum install ${missing_deps[*]}"
        elif command -v pacman >/dev/null 2>&1; then
            echo "  sudo pacman -S ${missing_deps[*]}"
        elif command -v zypper >/dev/null 2>&1; then
            echo "  sudo zypper install ${missing_deps[*]}"
        else
            echo "  Please install using your distribution's package manager"
        fi
        
        exit 1
    fi
}

# Create necessary directories
create_directories() {
    log "INFO" "Creating directory structure..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/guides"
    
    # Set appropriate permissions
    chown root:root "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    
    # Make log directory writable by users
    chown root:adm "$LOG_DIR" 2>/dev/null || chown root:root "$LOG_DIR"
    chmod 775 "$LOG_DIR"
    
    chown root:root "$DATA_DIR"
    chmod 755 "$DATA_DIR"
    
    log "SUCCESS" "Directories created"
}

# Install main script
install_script() {
    log "INFO" "Installing main script..."
    
    if [[ ! -f "src/immutable-os-explorer.sh" ]]; then
        log "ERROR" "Main script not found. Please run from project directory."
        exit 1
    fi
    
    cp "src/immutable-os-explorer.sh" "$INSTALL_DIR/immutable-os-explorer"
    chmod +x "$INSTALL_DIR/immutable-os-explorer"
    chown root:root "$INSTALL_DIR/immutable-os-explorer"
    
    log "SUCCESS" "Main script installed to $INSTALL_DIR/immutable-os-explorer"
}

# Install configuration
install_config() {
    log "INFO" "Installing configuration..."
    
    if [[ ! -f "config/config.json" ]]; then
        log "ERROR" "Configuration file not found."
        exit 1
    fi
    
    cp "config/config.json" "$CONFIG_DIR/config.json"
    chmod 644 "$CONFIG_DIR/config.json"
    chown root:root "$CONFIG_DIR/config.json"
    
    log "SUCCESS" "Configuration installed to $CONFIG_DIR/config.json"
}

# Install systemd service and timer
install_systemd() {
    log "INFO" "Installing systemd service and timer..."
    
    if [[ -f "systemd/immutable-os-explorer.service" ]]; then
        cp "systemd/immutable-os-explorer.service" "$SYSTEMD_DIR/"
        chmod 644 "$SYSTEMD_DIR/immutable-os-explorer.service"
        chown root:root "$SYSTEMD_DIR/immutable-os-explorer.service"
        log "SUCCESS" "Systemd service installed"
    fi
    
    if [[ -f "systemd/immutable-os-explorer.timer" ]]; then
        cp "systemd/immutable-os-explorer.timer" "$SYSTEMD_DIR/"
        chmod 644 "$SYSTEMD_DIR/immutable-os-explorer.timer"
        chown root:root "$SYSTEMD_DIR/immutable-os-explorer.timer"
        log "SUCCESS" "Systemd timer installed"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Ask user if they want to enable the timer
    echo ""
    read -p "Enable automatic weekly update checks? (y/N): " enable_timer
    if [[ "${enable_timer,,}" =~ ^(y|yes)$ ]]; then
        systemctl enable immutable-os-explorer.timer
        systemctl start immutable-os-explorer.timer
        log "SUCCESS" "Automatic update checks enabled"
    fi
}

# Install logrotate configuration
install_logrotate() {
    log "INFO" "Setting up log rotation..."
    
    cat > /etc/logrotate.d/immutable-os-explorer << 'EOF'
/var/log/immutable-os-explorer/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0664 root adm
    postrotate
        # Send SIGHUP to any running processes if needed
        /bin/true
    endscript
}
EOF
    
    chmod 644 /etc/logrotate.d/immutable-os-explorer
    log "SUCCESS" "Log rotation configured"
}

# Create man page
install_man_page() {
    log "INFO" "Installing man page..."
    
    local man_dir="/usr/local/share/man/man1"
    mkdir -p "$man_dir"
    
    cat > "$man_dir/immutable-os-explorer.1" << 'EOF'
.TH IMMUTABLE-OS-EXPLORER 1 "2024" "Version 1.0.0" "User Commands"
.SH NAME
immutable-os-explorer \- discover, compare, and try immutable operating systems
.SH SYNOPSIS
.B immutable-os-explorer
[\fIOPTIONS\fR] \fICOMMAND\fR [\fIARGS\fR...]
.SH DESCRIPTION
ImmutableOS Explorer is a comprehensive command-line tool for discovering,
comparing, and trying immutable operating systems like Fedora Silverblue,
openSUSE MicroOS, and others.
.SH COMMANDS
.TP
.B list
List all available immutable operating systems
.TP
.B info \fIos-id\fR
Show detailed information about a specific OS
.TP
.B download \fIos-id\fR
Download ISO file for specified OS
.TP
.B compare \fIos-id1\fR \fIos-id2\fR...
Compare multiple operating systems
.TP
.B create-usb \fIos-id\fR \fIdevice\fR
Create bootable USB drive (requires root)
.TP
.B check-compatibility
Check system compatibility with immutable OSes
.TP
.B update-check
Check for OS updates
.TP
.B interactive
Start interactive mode
.SH OPTIONS
.TP
.B \-h, \-\-help
Show help message
.TP
.B \-v, \-\-verbose
Enable verbose output
.TP
.B \-q, \-\-quiet
Suppress non-essential output
.TP
.B \-n, \-\-dry-run
Show what would be done without executing
.TP
.B \-\-version
Show version information
.SH FILES
.TP
.I /etc/immutable-os-explorer/config.json
Main configuration file
.TP
.I /var/log/immutable-os-explorer/
Log directory
.SH EXAMPLES
.TP
List available operating systems:
.B immutable-os-explorer list
.TP
Get information about Fedora Silverblue:
.B immutable-os-explorer info fedora-silverblue
.TP
Download Fedora Silverblue ISO:
.B immutable-os-explorer download fedora-silverblue
.SH SEE ALSO
.BR systemctl (1),
.BR journalctl (1)
.SH AUTHOR
Written by Your Name.
.SH REPORTING BUGS
Report bugs to: https://github.com/username/immutable-os-explorer/issues
EOF
    
    chmod 644 "$man_dir/immutable-os-explorer.1"
    
    # Update man database if mandb is available
    if command -v mandb >/dev/null 2>&1; then
        mandb -q 2>/dev/null || true
    fi
    
    log "SUCCESS" "Man page installed"
}

# Set up bash completion
install_bash_completion() {
    log "INFO" "Setting up bash completion..."
    
    local completion_dir="/etc/bash_completion.d"
    
    if [[ -d "$completion_dir" ]]; then
        cat > "$completion_dir/immutable-os-explorer" << 'EOF'
# Bash completion for immutable-os-explorer

_immutable_os_explorer() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="list info download compare create-usb check-compatibility update-check interactive"
    
    # OS IDs (simplified list)
    local os_ids="fedora-silverblue opensuse-microos nixos endless-os clear-linux"
    
    # Options
    local opts="-h --help -v --verbose -q --quiet -n --dry-run --no-color --version -c --config -l --log-level -d --download-dir"
    
    case "${prev}" in
        info|download)
            COMPREPLY=( $(compgen -W "${os_ids}" -- ${cur}) )
            return 0
            ;;
        compare)
            COMPREPLY=( $(compgen -W "${os_ids}" -- ${cur}) )
            return 0
            ;;
        create-usb)
            if [[ ${#COMP_WORDS[@]} -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "${os_ids}" -- ${cur}) )
            elif [[ ${#COMP_WORDS[@]} -eq 4 ]]; then
                COMPREPLY=( $(compgen -W "/dev/sdb /dev/sdc /dev/sdd" -- ${cur}) )
            fi
            return 0
            ;;
        --config|-c)
            COMPREPLY=( $(compgen -f -- ${cur}) )
            return 0
            ;;
        --log-level|-l)
            COMPREPLY=( $(compgen -W "DEBUG INFO WARN ERROR" -- ${cur}) )
            return 0
            ;;
        --download-dir|-d)
            COMPREPLY=( $(compgen -d -- ${cur}) )
            return 0
            ;;
    esac
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    
    COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    return 0
}

complete -F _immutable_os_explorer immutable-os-explorer
EOF
        
        chmod 644 "$completion_dir/immutable-os-explorer"
        log "SUCCESS" "Bash completion installed"
    else
        log "WARN" "Bash completion directory not found, skipping"
    fi
}

# Verify installation
verify_installation() {
    log "INFO" "Verifying installation..."
    
    # Check if script is executable and in PATH
    if command -v immutable-os-explorer >/dev/null 2>&1; then
        log "SUCCESS" "Main script is accessible in PATH"
    else
        log "ERROR" "Main script not found in PATH"
        return 1
    fi
    
    # Check configuration
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        log "SUCCESS" "Configuration file exists"
    else
        log "ERROR" "Configuration file missing"
        return 1
    fi
    
    # Check log directory
    if [[ -d "$LOG_DIR" ]]; then
        log "SUCCESS" "Log directory exists"
    else
        log "ERROR" "Log directory missing"
        return 1
    fi
    
    # Test basic functionality
    if immutable-os-explorer --version >/dev/null 2>&1; then
        log "SUCCESS" "Basic functionality test passed"
    else
        log "ERROR" "Basic functionality test failed"
        return 1
    fi
    
    log "SUCCESS" "Installation verification completed"
}

# Main installation function
main() {
    echo "ImmutableOS Explorer Installation Script"
    echo "========================================"
    echo ""
    
    check_root
    check_dependencies
    
    log "INFO" "Starting installation..."
    
    create_directories
    install_script
    install_config
    install_systemd
    install_logrotate
    install_man_page
    install_bash_completion
    
    echo ""
    log "INFO" "Running installation verification..."
    verify_installation
    
    echo ""
    log "SUCCESS" "Installation completed successfully!"
    echo ""
    echo "You can now use 'immutable-os-explorer' command."
    echo "Try 'immutable-os-explorer --help' to get started."
    echo ""
    echo "To enable bash completion, run: source /etc/bash_completion.d/immutable-os-explorer"
    echo "Or start a new shell session."
    echo ""
    
    # Show some usage examples
    echo "Quick start examples:"
    echo "  immutable-os-explorer list"
    echo "  immutable-os-explorer info fedora-silverblue"
    echo "  immutable-os-explorer interactive"
    echo ""
}

# Run main function
main "$@"