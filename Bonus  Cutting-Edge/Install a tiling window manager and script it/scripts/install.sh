#!/bin/bash

#
# TilingWM Manager - Installation Script
# 
# This script installs and configures the i3 tiling window manager
# with all necessary dependencies and automation services.
#
# Usage: sudo ./install.sh [--minimal|--full|--help]
#
# Author: TilingWM Manager Project
# License: MIT
#

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="/var/log/tilingwm-install.log"
readonly CONFIG_DIR="$HOME/.config/tilingwm"
readonly DATA_DIR="$HOME/.local/share/tilingwm"
readonly BACKUP_DIR="$DATA_DIR/backups"
readonly LOG_DIR="$DATA_DIR/logs"

# Installation modes
INSTALL_MODE="full"
SKIP_SYSTEMD=false
DRY_RUN=false

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$level] $message" | tee -a "$LOG_FILE"
    
    case "$level" in
        ERROR)
            logger -t "tilingwm-install" -p user.err "$message"
            ;;
        WARN)
            logger -t "tilingwm-install" -p user.warning "$message"
            ;;
        INFO)
            logger -t "tilingwm-install" -p user.info "$message"
            ;;
    esac
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Installation failed with exit code $exit_code"
        log_info "Check log file: $LOG_FILE"
    fi
}

trap cleanup EXIT

# System detection
detect_system() {
    log_info "Detecting system information..."
    
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot detect operating system"
    fi
    
    source /etc/os-release
    log_info "Detected OS: $NAME $VERSION"
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        log_warn "systemd not detected, skipping service installation"
        SKIP_SYSTEMD=true
    fi
    
    # Check if we're running in X11
    if [[ -z "${DISPLAY:-}" ]]; then
        log_warn "No X11 display detected. Make sure to run this after starting X11."
    fi
}

# Dependency installation
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Update package cache
    if ! apt-get update; then
        error_exit "Failed to update package cache"
    fi
    
    # Core i3 packages
    local packages=(
        "i3"
        "i3status"
        "i3lock"
        "dmenu"
        "feh"           # wallpaper setting
        "compton"       # compositor
        "rofi"          # application launcher
        "terminology"   # terminal emulator
        "firefox"       # web browser
    )
    
    # Additional packages for full installation
    if [[ "$INSTALL_MODE" == "full" ]]; then
        packages+=(
            "thunar"        # file manager
            "volumeicon"    # volume control
            "nm-applet"     # network manager
            "blueman"       # bluetooth manager
            "redshift"      # blue light filter
            "scrot"         # screenshot tool
            "xrandr"        # display configuration
        )
    fi
    
    log_info "Installing packages: ${packages[*]}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! apt-get install -y "${packages[@]}"; then
            error_exit "Failed to install required packages"
        fi
    else
        log_info "[DRY RUN] Would install: ${packages[*]}"
    fi
    
    log_info "Dependencies installed successfully"
}

# Directory creation
create_directories() {
    log_info "Creating directory structure..."
    
    local directories=(
        "$CONFIG_DIR"
        "$DATA_DIR"
        "$BACKUP_DIR"
        "$LOG_DIR"
        "$HOME/.config/i3"
        "$HOME/.config/i3status"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$dir"
            chmod 750 "$dir"
        else
            log_info "[DRY RUN] Would create: $dir"
        fi
    done
    
    log_info "Directory structure created"
}

# Configuration file installation
install_configs() {
    log_info "Installing configuration files..."
    
    # Copy i3 config
    if [[ -f "$PROJECT_ROOT/configs/i3-config" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$PROJECT_ROOT/configs/i3-config" "$HOME/.config/i3/config"
            chmod 644 "$HOME/.config/i3/config"
        fi
        log_info "Installed i3 configuration"
    else
        log_warn "i3 config template not found, using default"
    fi
    
    # Copy i3status config
    if [[ -f "$PROJECT_ROOT/configs/i3status.conf" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$PROJECT_ROOT/configs/i3status.conf" "$HOME/.config/i3status/config"
            chmod 644 "$HOME/.config/i3status/config"
        fi
        log_info "Installed i3status configuration"
    fi
    
    # Copy main tilingwm config
    if [[ -f "$PROJECT_ROOT/configs/config.yaml" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$PROJECT_ROOT/configs/config.yaml" "$CONFIG_DIR/"
            chmod 644 "$CONFIG_DIR/config.yaml"
        fi
        log_info "Installed TilingWM configuration"
    fi
    
    # Copy workspace configuration
    if [[ -f "$PROJECT_ROOT/configs/workspaces.conf" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$PROJECT_ROOT/configs/workspaces.conf" "$CONFIG_DIR/"
            chmod 644 "$CONFIG_DIR/workspaces.conf"
        fi
        log_info "Installed workspace configuration"
    fi
}

# Binary installation
install_binaries() {
    log_info "Installing TilingWM Manager binaries..."
    
    local bin_dir="/usr/local/bin"
    
    # Make main script executable and install
    if [[ -f "$PROJECT_ROOT/scripts/tilingwm.sh" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            chmod +x "$PROJECT_ROOT/scripts/tilingwm.sh"
            cp "$PROJECT_ROOT/scripts/tilingwm.sh" "$bin_dir/tilingwm"
        fi
        log_info "Installed tilingwm command to $bin_dir/tilingwm"
    else
        error_exit "Main tilingwm script not found"
    fi
    
    # Install automation script
    if [[ -f "$PROJECT_ROOT/scripts/automation.sh" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            chmod +x "$PROJECT_ROOT/scripts/automation.sh"
            cp "$PROJECT_ROOT/scripts/automation.sh" "$bin_dir/tilingwm-automation"
        fi
        log_info "Installed automation script"
    fi
}

# Systemd service installation
install_systemd_service() {
    if [[ "$SKIP_SYSTEMD" == "true" ]]; then
        log_info "Skipping systemd service installation"
        return
    fi
    
    log_info "Installing systemd service..."
    
    local service_file="$PROJECT_ROOT/configs/tilingwm-automation.service"
    local target_dir="/etc/systemd/system"
    
    if [[ -f "$service_file" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$service_file" "$target_dir/"
            systemctl daemon-reload
            log_info "Systemd service installed. Enable with: systemctl enable tilingwm-automation.service"
        else
            log_info "[DRY RUN] Would install systemd service"
        fi
    else
        log_warn "Systemd service file not found"
    fi
}

# X11 session configuration
configure_x11_session() {
    log_info "Configuring X11 session..."
    
    # Create .xsession file for display managers
    local xsession_file="$HOME/.xsession"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$xsession_file" << 'EOF'
#!/bin/bash
# TilingWM Manager X11 session startup

# Start compositor
compton -b &

# Set wallpaper
if [[ -f "$HOME/.config/tilingwm/wallpaper.jpg" ]]; then
    feh --bg-scale "$HOME/.config/tilingwm/wallpaper.jpg" &
fi

# Start network manager applet
nm-applet &

# Start volume control
volumeicon &

# Start i3 window manager
exec i3
EOF
        chmod +x "$xsession_file"
        log_info "Created X11 session file: $xsession_file"
    else
        log_info "[DRY RUN] Would create X11 session configuration"
    fi
}

# Post-installation setup
post_install_setup() {
    log_info "Running post-installation setup..."
    
    # Create initial backup
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v tilingwm &> /dev/null; then
            tilingwm backup --name "post-install-$(date +%Y%m%d-%H%M%S)" || true
        fi
    fi
    
    # Set up log rotation
    local logrotate_config="/etc/logrotate.d/tilingwm"
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$logrotate_config" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
        log_info "Configured log rotation"
    fi
}

# Usage information
show_usage() {
    cat << EOF
TilingWM Manager Installation Script

Usage: sudo ./install.sh [OPTIONS]

OPTIONS:
    --minimal       Install only core i3 packages
    --full          Install i3 with additional utilities (default)
    --dry-run       Show what would be done without making changes
    --skip-systemd  Skip systemd service installation
    --help          Show this help message

EXAMPLES:
    sudo ./install.sh                    # Full installation
    sudo ./install.sh --minimal          # Minimal installation
    sudo ./install.sh --dry-run          # Preview installation steps

EOF
}

# Argument parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --minimal)
                INSTALL_MODE="minimal"
                shift
                ;;
            --full)
                INSTALL_MODE="full"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-systemd)
                SKIP_SYSTEMD=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Main installation function
main() {
    parse_arguments "$@"
    
    log_info "TilingWM Manager Installation Starting..."
    log_info "Installation mode: $INSTALL_MODE"
    log_info "Dry run: $DRY_RUN"
    
    check_root
    detect_system
    create_directories
    install_dependencies
    install_configs
    install_binaries
    install_systemd_service
    configure_x11_session
    post_install_setup
    
    log_info "Installation completed successfully!"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        echo "Next steps:"
        echo "1. Log out and select 'i3' from your display manager"
        echo "2. Enable automation: systemctl enable tilingwm-automation.service"
        echo "3. Start automation: systemctl start tilingwm-automation.service"
        echo "4. Check status: tilingwm status"
        echo ""
        echo "For help: tilingwm help"
    fi
}

# Run main function with all arguments
main "$@"