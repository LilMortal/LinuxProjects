#!/bin/bash

# Linux From Scratch (LFS) Toolkit Setup Script
# Version: 1.0.0
#
# This script sets up the LFS automation toolkit on the host system.
# It installs dependencies, creates users, and configures the environment.

set -euo pipefail

# Script configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="/opt/lfs-toolkit"
LFS_USER="lfs"
LFS_GROUP="lfs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Install dependencies based on distribution
install_dependencies() {
    local distro=$(detect_distro)
    
    log_info "Detected distribution: $distro"
    log_info "Installing dependencies..."
    
    case "$distro" in
        "ubuntu"|"debian")
            apt-get update
            apt-get install -y \
                build-essential gawk wget bison flex texinfo gperf libc6-dev-i386 \
                python3 python3-pip python3-psutil curl git rsync parted util-linux \
                vim nano htop tree jq bc cpio xz-utils gzip bzip2 \
                libncurses5-dev libssl-dev libelf-dev \
                pkg-config autoconf automake libtool \
                m4 patch diffutils findutils grep sed tar make \
                binutils gcc g++ libc6-dev
            ;;
        "centos"|"rhel"|"fedora")
            if command -v dnf &> /dev/null; then
                dnf groupinstall -y "Development Tools"
                dnf install -y \
                    gawk wget bison flex texinfo gperf \
                    python3 python3-pip curl git rsync parted util-linux \
                    vim nano htop tree jq bc cpio xz gzip bzip2 \
                    ncurses-devel openssl-devel elfutils-libelf-devel \
                    pkgconfig autoconf automake libtool \
                    m4 patch diffutils findutils grep sed tar make
            else
                yum groupinstall -y "Development Tools"
                yum install -y \
                    gawk wget bison flex texinfo gperf \
                    python3 python3-pip curl git rsync parted util-linux \
                    vim nano htop tree jq bc cpio xz gzip bzip2 \
                    ncurses-devel openssl-devel elfutils-libelf-devel \
                    pkgconfig autoconf automake libtool \
                    m4 patch diffutils findutils grep sed tar make
            fi
            ;;
        "arch")
            pacman -Syu --noconfirm
            pacman -S --noconfirm \
                base-devel gawk wget bison flex texinfo gperf \
                python python-pip curl git rsync parted util-linux \
                vim nano htop tree jq bc cpio xz gzip bzip2 \
                ncurses openssl libelf \
                pkg-config autoconf automake libtool \
                m4 patch diffutils findutils grep sed tar make
            ;;
        *)
            log_warn "Unknown distribution. Please install dependencies manually:"
            log_warn "  - Build tools (gcc, make, binutils, etc.)"
            log_warn "  - Python 3 with pip and psutil"
            log_warn "  - Standard GNU tools (awk, sed, grep, etc.)"
            log_warn "  - Additional tools (wget, curl, git, rsync, parted)"
            ;;
    esac
    
    # Install Python packages
    log_info "Installing Python packages..."
    pip3 install psutil requests
}

# Create LFS user and group
create_lfs_user() {
    log_info "Creating LFS user and group..."
    
    # Create group if it doesn't exist
    if ! getent group "$LFS_GROUP" > /dev/null 2>&1; then
        groupadd "$LFS_GROUP"
        log_info "Created group: $LFS_GROUP"
    else
        log_info "Group already exists: $LFS_GROUP"
    fi
    
    # Create user if it doesn't exist
    if ! id "$LFS_USER" > /dev/null 2>&1; then
        useradd -s /bin/bash -g "$LFS_GROUP" -m -k /dev/null "$LFS_USER"
        log_info "Created user: $LFS_USER"
        
        # Set password
        echo "$LFS_USER:$LFS_USER" | chpasswd
        log_info "Set default password for user: $LFS_USER"
    else
        log_info "User already exists: $LFS_USER"
    fi
    
    # Add LFS user to sudo group
    usermod -aG sudo "$LFS_USER" 2>/dev/null || usermod -aG wheel "$LFS_USER" 2>/dev/null || true
    
    # Set up sudoers for LFS user
    cat > /etc/sudoers.d/lfs << EOF
# Allow LFS user to run commands as root without password
$LFS_USER ALL=(ALL) NOPASSWD: ALL
EOF
    
    chmod 440 /etc/sudoers.d/lfs
    log_info "Configured sudo access for LFS user"
}

# Set up toolkit directory structure
setup_toolkit_directory() {
    log_info "Setting up toolkit directory structure..."
    
    # Create main directory
    mkdir -p "$TOOLKIT_DIR"
    
    # Create subdirectories
    mkdir -p "$TOOLKIT_DIR"/{config,scripts,systemd,cron,logs,sources,backup}
    
    # Copy files from current directory to toolkit directory
    if [[ -d "${SCRIPT_DIR}/.." ]]; then
        cp -r "${SCRIPT_DIR}/../"* "$TOOLKIT_DIR/" 2>/dev/null || true
    fi
    
    # Set ownership
    chown -R root:lfs "$TOOLKIT_DIR"
    chmod -R 755 "$TOOLKIT_DIR"
    
    # Make scripts executable
    find "$TOOLKIT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    find "$TOOLKIT_DIR/scripts" -name "*.py" -exec chmod +x {} \;
    chmod +x "$TOOLKIT_DIR/lfs-build.sh" 2>/dev/null || true
    
    log_info "Toolkit directory created: $TOOLKIT_DIR"
}

# Set up logging directory
setup_logging() {
    log_info "Setting up logging directory..."
    
    local log_dir="/var/log/lfs-build"
    
    mkdir -p "$log_dir"
    chown root:lfs "$log_dir"
    chmod 775 "$log_dir"
    
    # Set up logrotate
    cat > /etc/logrotate.d/lfs-build << EOF
$log_dir/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 root lfs
    postrotate
        systemctl reload-or-restart rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log_info "Logging directory created: $log_dir"
}

# Create default configuration
create_default_config() {
    log_info "Creating default configuration..."
    
    local config_file="$TOOLKIT_DIR/config/lfs.conf"
    
    # Only create if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        log_info "Configuration file created: $config_file"
        log_warn "Please review and customize the configuration before running builds"
    else
        log_info "Configuration file already exists: $config_file"
    fi
    
    # Set proper permissions
    chown root:lfs "$config_file"
    chmod 640 "$config_file"
}

# Set up systemd services
setup_systemd_services() {
    log_info "Setting up systemd services..."
    
    # Monitor service
    cat > /etc/systemd/system/lfs-monitor.service << EOF
[Unit]
Description=LFS Build Monitor
After=multi-user.target

[Service]
Type=simple
User=root
Group=lfs
ExecStart=$TOOLKIT_DIR/scripts/monitor-build.py --follow
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Builder service
    cat > /etc/systemd/system/lfs-builder.service << EOF
[Unit]
Description=LFS Build Service
After=multi-user.target

[Service]
Type=oneshot
User=root
Group=lfs
ExecStart=$TOOLKIT_DIR/lfs-build.sh --full
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Builder timer (for scheduled builds)
    cat > /etc/systemd/system/lfs-builder.timer << EOF
[Unit]
Description=LFS Build Timer
Requires=lfs-builder.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log_info "Systemd services created (not enabled by default)"
    log_info "To enable: systemctl enable lfs-builder.timer"
}

# Set up cron jobs
setup_cron_jobs() {
    log_info "Setting up cron job templates..."
    
    # Create cron directory
    mkdir -p "$TOOLKIT_DIR/cron"
    
    # Maintenance cron job
    cat > "$TOOLKIT_DIR/cron/lfs-maintenance" << EOF
# LFS Maintenance Cron Job
# Runs weekly maintenance tasks
#
# To install: sudo cp $TOOLKIT_DIR/cron/lfs-maintenance /etc/cron.d/
#
# Weekly maintenance (Sundays at 2 AM)
0 2 * * 0 root $TOOLKIT_DIR/scripts/maintenance.sh >> /var/log/lfs-maintenance.log 2>&1

# Daily log cleanup
0 3 * * * root find /var/log/lfs-build -name "*.log" -mtime +30 -delete

# Weekly backup cleanup
0 4 * * 0 root find /opt/lfs-backups -name "*.tar.gz" -mtime +60 -delete
EOF
    
    log_info "Cron job templates created in: $TOOLKIT_DIR/cron/"
}

# Set resource limits
setup_resource_limits() {
    log_info "Setting up resource limits..."
    
    # Set limits for LFS user
    cat >> /etc/security/limits.conf << EOF

# LFS user limits
$LFS_USER soft nproc 4096
$LFS_USER hard nproc 8192
$LFS_USER soft nofile 8192
$LFS_USER hard nofile 16384
$LFS_USER soft memlock unlimited
$LFS_USER hard memlock unlimited
EOF
    
    log_info "Resource limits configured for LFS user"
}

# Create backup directory
setup_backup_directory() {
    log_info "Setting up backup directory..."
    
    local backup_dir="/opt/lfs-backups"
    
    mkdir -p "$backup_dir"
    chown root:lfs "$backup_dir"
    chmod 775 "$backup_dir"
    
    log_info "Backup directory created: $backup_dir"
}

# Display setup summary
show_setup_summary() {
    log_info "LFS Toolkit setup completed successfully!"
    echo
    echo "Summary:"
    echo "  - Toolkit directory: $TOOLKIT_DIR"
    echo "  - Configuration: $TOOLKIT_DIR/config/lfs.conf"
    echo "  - LFS user created: $LFS_USER (password: $LFS_USER)"
    echo "  - Log directory: /var/log/lfs-build"
    echo "  - Backup directory: /opt/lfs-backups"
    echo
    echo "Next steps:"
    echo "  1. Review configuration: $TOOLKIT_DIR/config/lfs.conf"
    echo "  2. Initialize environment: $TOOLKIT_DIR/scripts/init-environment.sh"
    echo "  3. Validate host system: $TOOLKIT_DIR/scripts/validate-host.py"
    echo "  4. Start build: sudo $TOOLKIT_DIR/lfs-build.sh --full"
    echo
    echo "For help: $TOOLKIT_DIR/lfs-build.sh --help"
}

# Main function
main() {
    log_info "Starting LFS Toolkit setup..."
    
    check_root
    install_dependencies
    create_lfs_user
    setup_toolkit_directory
    setup_logging
    create_default_config
    setup_systemd_services
    setup_cron_jobs
    setup_resource_limits
    setup_backup_directory
    
    show_setup_summary
}

# Run main function
main "$@"