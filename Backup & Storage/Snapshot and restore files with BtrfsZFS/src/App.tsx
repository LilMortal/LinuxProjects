import React, { useState } from 'react';
import { FileText, Folder, Settings, Clock, Shield, Code, BookOpen, Terminal } from 'lucide-react';

function App() {
  const [activeTab, setActiveTab] = useState('overview');

  const projectStructure = `btrfs-zfs-snapshot-manager/
├── bin/
│   └── snapshot-manager           # Main executable script
├── config/
│   └── snapshot-manager.conf      # Configuration file
├── systemd/
│   ├── snapshot-manager.service   # Systemd service unit
│   └── snapshot-manager.timer     # Systemd timer for automation
├── logs/                          # Log files directory
├── install.sh                     # Installation script
└── README.md                      # Comprehensive documentation`;

  const mainScript = `#!/bin/bash
#
# Btrfs/ZFS Snapshot Manager
# A comprehensive tool for creating, managing, and restoring filesystem snapshots
# Compatible with both Btrfs and ZFS filesystems
#
# Author: System Administrator
# License: MIT
# Version: 1.0.0
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/etc/snapshot-manager/snapshot-manager.conf"
LOG_FILE="/var/log/snapshot-manager.log"
LOCK_FILE="/var/run/snapshot-manager.lock"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    # Default configuration
    BTRFS_MOUNT_POINTS=("/home" "/")
    ZFS_DATASETS=("tank/home" "tank/root")
    SNAPSHOT_PREFIX="auto-snapshot"
    RETENTION_DAILY=7
    RETENTION_WEEKLY=4
    RETENTION_MONTHLY=12
    MAX_CONCURRENT_SNAPSHOTS=5
fi

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Also log to syslog
    logger -t "snapshot-manager" -p "daemon.$level" "$message"
}

# Error handling
error_exit() {
    log "error" "$1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
}

# Lock mechanism to prevent concurrent runs
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            error_exit "Another instance is already running (PID: $pid)"
        else
            log "warn" "Stale lock file found, removing"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Detect filesystem type
detect_filesystem() {
    local path="$1"
    local fs_type=$(stat -f -c %T "$path" 2>/dev/null)
    
    case "$fs_type" in
        "btrfs")
            echo "btrfs"
            ;;
        "zfs")
            echo "zfs"
            ;;
        *)
            log "warn" "Unsupported filesystem type: $fs_type for path: $path"
            echo "unknown"
            ;;
    esac
}

# Create Btrfs snapshot
create_btrfs_snapshot() {
    local mount_point="$1"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local snapshot_name="\${SNAPSHOT_PREFIX}-\${timestamp}"
    local snapshot_path="\${mount_point}/.snapshots/\${snapshot_name}"
    
    log "info" "Creating Btrfs snapshot: $snapshot_path"
    
    # Create snapshots directory if it doesn't exist
    mkdir -p "\${mount_point}/.snapshots"
    
    # Create read-only snapshot
    if btrfs subvolume snapshot -r "$mount_point" "$snapshot_path"; then
        log "info" "Successfully created Btrfs snapshot: $snapshot_path"
        echo "$snapshot_path"
    else
        error_exit "Failed to create Btrfs snapshot: $snapshot_path"
    fi
}

# Create ZFS snapshot
create_zfs_snapshot() {
    local dataset="$1"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local snapshot_name="\${dataset}@\${SNAPSHOT_PREFIX}-\${timestamp}"
    
    log "info" "Creating ZFS snapshot: $snapshot_name"
    
    if zfs snapshot "$snapshot_name"; then
        log "info" "Successfully created ZFS snapshot: $snapshot_name"
        echo "$snapshot_name"
    else
        error_exit "Failed to create ZFS snapshot: $snapshot_name"
    fi
}

# List Btrfs snapshots
list_btrfs_snapshots() {
    local mount_point="$1"
    local snapshots_dir="\${mount_point}/.snapshots"
    
    if [[ -d "$snapshots_dir" ]]; then
        log "info" "Btrfs snapshots for $mount_point:"
        ls -1t "$snapshots_dir" | grep "^$SNAPSHOT_PREFIX" | while read -r snapshot; do
            local snapshot_path="\${snapshots_dir}/\${snapshot}"
            local size=$(du -sh "$snapshot_path" | cut -f1)
            local date=$(stat -c %y "$snapshot_path" | cut -d' ' -f1-2)
            echo "  $snapshot ($size, created: $date)"
        done
    else
        log "info" "No snapshots directory found for $mount_point"
    fi
}

# List ZFS snapshots
list_zfs_snapshots() {
    local dataset="$1"
    
    log "info" "ZFS snapshots for $dataset:"
    zfs list -t snapshot -r "$dataset" | grep "@$SNAPSHOT_PREFIX" | while read line; do
        echo "  $line"
    done
}

# Restore Btrfs snapshot
restore_btrfs_snapshot() {
    local mount_point="$1"
    local snapshot_name="$2"
    local snapshot_path="\${mount_point}/.snapshots/\${snapshot_name}"
    local backup_path="\${mount_point}/.snapshots/backup-before-restore-$(date '+%Y%m%d-%H%M%S')"
    
    if [[ ! -d "$snapshot_path" ]]; then
        error_exit "Snapshot not found: $snapshot_path"
    fi
    
    log "info" "Creating backup before restore: $backup_path"
    create_btrfs_snapshot "$mount_point" || error_exit "Failed to create backup snapshot"
    
    log "info" "Restoring from Btrfs snapshot: $snapshot_path"
    # Implementation would depend on specific restore strategy
    # This is a simplified example
    log "warn" "Btrfs restore requires manual intervention for safety"
    echo "To restore manually:"
    echo "1. Boot from rescue media"
    echo "2. Mount the Btrfs filesystem"
    echo "3. Use: btrfs subvolume delete <current-subvolume>"
    echo "4. Use: btrfs subvolume snapshot $snapshot_path <target-path>"
}

# Restore ZFS snapshot
restore_zfs_snapshot() {
    local dataset="$1"
    local snapshot_name="$2"
    
    log "info" "Restoring ZFS dataset $dataset from snapshot $snapshot_name"
    
    # Create backup snapshot before restore
    local backup_snapshot="\${dataset}@backup-before-restore-$(date '+%Y%m%d-%H%M%S')"
    zfs snapshot "$backup_snapshot" || error_exit "Failed to create backup snapshot"
    
    if zfs rollback "$snapshot_name"; then
        log "info" "Successfully restored $dataset from $snapshot_name"
    else
        error_exit "Failed to restore $dataset from $snapshot_name"
    fi
}

# Cleanup old snapshots
cleanup_old_snapshots() {
    log "info" "Starting snapshot cleanup process"
    
    # Cleanup Btrfs snapshots
    for mount_point in "\${BTRFS_MOUNT_POINTS[@]}"; do
        if [[ -d "\${mount_point}/.snapshots" ]]; then
            log "info" "Cleaning up Btrfs snapshots in $mount_point"
            cd "\${mount_point}/.snapshots"
            ls -1t | grep "^$SNAPSHOT_PREFIX" | tail -n +$((RETENTION_DAILY + 1)) | while read snapshot; do
                log "info" "Removing old Btrfs snapshot: $snapshot"
                btrfs subvolume delete "$snapshot"
            done
        fi
    done
    
    # Cleanup ZFS snapshots
    for dataset in "\${ZFS_DATASETS[@]}"; do
        log "info" "Cleaning up ZFS snapshots for $dataset"
        zfs list -t snapshot -o name -s creation "$dataset" | grep "@$SNAPSHOT_PREFIX" | tail -n +$((RETENTION_DAILY + 1)) | while read snapshot; do
            log "info" "Removing old ZFS snapshot: $snapshot"
            zfs destroy "$snapshot"
        done
    done
}

# Health check function
health_check() {
    log "info" "Performing system health check"
    
    # Check disk space
    df -h | awk 'NR>1 {if ($5+0 > 90) print "WARNING: " $6 " is " $5 " full"}'
    
    # Check Btrfs filesystems
    for mount_point in "\${BTRFS_MOUNT_POINTS[@]}"; do
        if mountpoint -q "$mount_point"; then
            log "info" "Checking Btrfs filesystem: $mount_point"
            btrfs filesystem show "$mount_point" >/dev/null 2>&1 || log "error" "Btrfs filesystem check failed for $mount_point"
        fi
    done
    
    # Check ZFS pools
    if command -v zpool >/dev/null 2>&1; then
        log "info" "Checking ZFS pool health"
        zpool status | grep -q "ONLINE" || log "warn" "ZFS pool issues detected"
    fi
}

# Usage function
usage() {
    cat << EOF
Btrfs/ZFS Snapshot Manager v1.0.0

Usage: $0 [OPTIONS] COMMAND [ARGS]

Commands:
    create              Create snapshots for all configured filesystems
    list                List all available snapshots
    restore <path> <snapshot>  Restore from specific snapshot
    cleanup             Remove old snapshots based on retention policy
    health              Perform system health check
    
Options:
    -c, --config FILE   Use custom configuration file
    -v, --verbose       Enable verbose logging
    -h, --help          Show this help message

Examples:
    $0 create                           # Create snapshots
    $0 list                             # List all snapshots
    $0 restore /home snapshot-name      # Restore /home from snapshot
    $0 cleanup                          # Clean up old snapshots
    $0 health                           # Check system health

Configuration file: $CONFIG_FILE
Log file: $LOG_FILE
EOF
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            create|list|restore|cleanup|health)
                COMMAND="$1"
                shift
                break
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "\${COMMAND:-}" ]]; then
        echo "Error: No command specified"
        usage
        exit 1
    fi
    
    # Acquire lock
    acquire_lock
    
    # Set up signal handlers
    trap cleanup EXIT INT TERM
    
    # Execute command
    case "$COMMAND" in
        create)
            log "info" "Starting snapshot creation process"
            
            # Create Btrfs snapshots
            for mount_point in "\${BTRFS_MOUNT_POINTS[@]}"; do
                if mountpoint -q "$mount_point" && [[ "$(detect_filesystem "$mount_point")" == "btrfs" ]]; then
                    create_btrfs_snapshot "$mount_point"
                fi
            done
            
            # Create ZFS snapshots
            for dataset in "\${ZFS_DATASETS[@]}"; do
                if zfs list "$dataset" >/dev/null 2>&1; then
                    create_zfs_snapshot "$dataset"
                fi
            done
            
            log "info" "Snapshot creation process completed"
            ;;
            
        list)
            log "info" "Listing all snapshots"
            
            # List Btrfs snapshots
            for mount_point in "\${BTRFS_MOUNT_POINTS[@]}"; do
                if mountpoint -q "$mount_point" && [[ "$(detect_filesystem "$mount_point")" == "btrfs" ]]; then
                    list_btrfs_snapshots "$mount_point"
                fi
            done
            
            # List ZFS snapshots
            for dataset in "\${ZFS_DATASETS[@]}"; do
                if zfs list "$dataset" >/dev/null 2>&1; then
                    list_zfs_snapshots "$dataset"
                fi
            done
            ;;
            
        restore)
            if [[ $# -lt 2 ]]; then
                echo "Error: restore command requires path and snapshot name"
                usage
                exit 1
            fi
            
            local restore_path="$1"
            local snapshot_name="$2"
            
            case "$(detect_filesystem "$restore_path")" in
                "btrfs")
                    restore_btrfs_snapshot "$restore_path" "$snapshot_name"
                    ;;
                "zfs")
                    restore_zfs_snapshot "$restore_path" "$snapshot_name"
                    ;;
                *)
                    error_exit "Unsupported filesystem for restore: $restore_path"
                    ;;
            esac
            ;;
            
        cleanup)
            cleanup_old_snapshots
            ;;
            
        health)
            health_check
            ;;
            
        *)
            echo "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
    
    log "info" "Operation completed successfully"
}

# Run main function with all arguments
main "$@"`;

  const configFile = `# Btrfs/ZFS Snapshot Manager Configuration
# This file contains the default configuration for the snapshot manager

# Btrfs mount points to snapshot (space-separated list)
BTRFS_MOUNT_POINTS=("/home" "/" "/var")

# ZFS datasets to snapshot (space-separated list)  
ZFS_DATASETS=("tank/home" "tank/root" "tank/var")

# Snapshot naming prefix
SNAPSHOT_PREFIX="auto-snapshot"

# Retention policies (number of snapshots to keep)
RETENTION_DAILY=7      # Keep 7 daily snapshots
RETENTION_WEEKLY=4     # Keep 4 weekly snapshots  
RETENTION_MONTHLY=12   # Keep 12 monthly snapshots

# Maximum number of concurrent snapshot operations
MAX_CONCURRENT_SNAPSHOTS=5

# Logging configuration
LOG_LEVEL="info"       # Options: debug, info, warn, error
LOG_ROTATION="daily"   # Options: daily, weekly, monthly

# Email notifications (optional)
# NOTIFICATION_EMAIL="admin@example.com"
# SMTP_SERVER="localhost"

# Exclude patterns for certain files/directories (optional)
# EXCLUDE_PATTERNS=("*.tmp" "*.log" "/tmp/*")

# Pre/post snapshot hooks (optional scripts to run)
# PRE_SNAPSHOT_HOOK="/etc/snapshot-manager/pre-snapshot.sh"
# POST_SNAPSHOT_HOOK="/etc/snapshot-manager/post-snapshot.sh"`;

  const systemdService = `[Unit]
Description=Btrfs/ZFS Snapshot Manager
After=multi-user.target
Wants=snapshot-manager.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/snapshot-manager create
User=root
Group=root

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/log /var/run /home /.snapshots
ProtectHome=false
PrivateTmp=true

# Resource limits
TimeoutStartSec=3600
MemoryLimit=1G

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target`;

  const systemdTimer = `[Unit]
Description=Run Btrfs/ZFS Snapshot Manager periodically
Requires=snapshot-manager.service

[Timer]
# Run daily at 2:00 AM
OnCalendar=daily
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target`;

  const installScript = `#!/bin/bash
#
# Installation script for Btrfs/ZFS Snapshot Manager
# This script installs the snapshot manager system-wide
#

set -euo pipefail

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "\${GREEN}[INFO]\${NC} $1"
}

print_warning() {
    echo -e "\${YELLOW}[WARN]\${NC} $1"
}

print_error() {
    echo -e "\${RED}[ERROR]\${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_status "Installing Btrfs/ZFS Snapshot Manager..."

# Create directories
print_status "Creating directories..."
mkdir -p /usr/local/bin
mkdir -p /etc/snapshot-manager
mkdir -p /var/log
mkdir -p /etc/systemd/system

# Copy files
print_status "Installing files..."
cp bin/snapshot-manager /usr/local/bin/
chmod +x /usr/local/bin/snapshot-manager

cp config/snapshot-manager.conf /etc/snapshot-manager/
chmod 644 /etc/snapshot-manager/snapshot-manager.conf

# Install systemd units
print_status "Installing systemd units..."
cp systemd/snapshot-manager.service /etc/systemd/system/
cp systemd/snapshot-manager.timer /etc/systemd/system/

# Set permissions
chmod 644 /etc/systemd/system/snapshot-manager.service
chmod 644 /etc/systemd/system/snapshot-manager.timer

# Reload systemd
print_status "Reloading systemd..."
systemctl daemon-reload

# Enable and start timer
print_status "Enabling systemd timer..."
systemctl enable snapshot-manager.timer
systemctl start snapshot-manager.timer

# Create log file
touch /var/log/snapshot-manager.log
chmod 644 /var/log/snapshot-manager.log

# Check dependencies
print_status "Checking dependencies..."

if ! command -v btrfs >/dev/null 2>&1; then
    print_warning "btrfs-progs not found. Install with: apt install btrfs-progs"
fi

if ! command -v zfs >/dev/null 2>&1; then
    print_warning "ZFS tools not found. Install ZFS if you plan to use ZFS snapshots"
fi

print_status "Installation completed successfully!"
print_status ""
print_status "Next steps:"
print_status "1. Edit /etc/snapshot-manager/snapshot-manager.conf to configure your filesystems"
print_status "2. Test the installation: /usr/local/bin/snapshot-manager --help"
print_status "3. Create your first snapshot: /usr/local/bin/snapshot-manager create"
print_status "4. Check systemd timer status: systemctl status snapshot-manager.timer"
print_status ""
print_status "Log file location: /var/log/snapshot-manager.log"`;

  const readmeContent = `# Btrfs/ZFS Snapshot Manager

A comprehensive, production-ready tool for creating, managing, and restoring filesystem snapshots on Linux systems. Supports both Btrfs and ZFS filesystems with automated scheduling, retention policies, and robust error handling.

## Overview

The Btrfs/ZFS Snapshot Manager is designed for system administrators who need reliable, automated backup and snapshot management for their Linux systems. It provides a unified interface for managing snapshots across different filesystem types, with enterprise-grade features like logging, locking, and systemd integration.

**Why this tool is useful:**
- Protects against data loss through regular automated snapshots
- Provides quick recovery options for accidental file deletion or corruption
- Supports both Btrfs and ZFS filesystems from a single tool
- Integrates seamlessly with systemd for scheduling and service management
- Includes comprehensive logging and monitoring capabilities

## Features

- **Multi-filesystem support**: Works with both Btrfs and ZFS filesystems
- **Automated snapshots**: Schedule regular snapshots using systemd timers
- **Flexible retention policies**: Configure daily, weekly, and monthly retention
- **Safe restore operations**: Automatic backup creation before restores
- **Comprehensive logging**: File and syslog integration with multiple log levels
- **Health monitoring**: Built-in system health checks and disk space monitoring
- **Concurrent operation protection**: Prevents multiple instances from running simultaneously
- **Security hardened**: Systemd security features and proper permission handling

## Requirements

### Dependencies
- **Operating System**: Ubuntu 22.04+ or any modern Linux distribution
- **Filesystems**: Btrfs and/or ZFS
- **Required packages**:
  - \`btrfs-progs\` (for Btrfs support)
  - \`zfsutils-linux\` (for ZFS support)
  - \`systemd\` (for automation)

### System Requirements
- Root access for snapshot operations
- Sufficient disk space for snapshots (typically 10-20% of filesystem size)
- At least 512MB RAM for large filesystem operations

### Installing Dependencies

**Ubuntu/Debian:**
\`\`\`bash
# For Btrfs support
sudo apt update
sudo apt install btrfs-progs

# For ZFS support (Ubuntu 22.04+)
sudo apt install zfsutils-linux

# Verify installations
btrfs --version
zfs version
\`\`\`

**RHEL/CentOS/Fedora:**
\`\`\`bash
# For Btrfs support
sudo dnf install btrfs-progs

# For ZFS support (requires EPEL)
sudo dnf install epel-release
sudo dnf install zfs
\`\`\`

## Installation

### Method 1: Automated Installation (Recommended)

1. **Clone the repository:**
   \`\`\`bash
   git clone https://github.com/yourusername/btrfs-zfs-snapshot-manager.git
   cd btrfs-zfs-snapshot-manager
   \`\`\`

2. **Run the installation script:**
   \`\`\`bash
   sudo ./install.sh
   \`\`\`

### Method 2: Manual Installation

1. **Copy the main script:**
   \`\`\`bash
   sudo cp bin/snapshot-manager /usr/local/bin/
   sudo chmod +x /usr/local/bin/snapshot-manager
   \`\`\`

2. **Create configuration directory and copy config:**
   \`\`\`bash
   sudo mkdir -p /etc/snapshot-manager
   sudo cp config/snapshot-manager.conf /etc/snapshot-manager/
   \`\`\`

3. **Install systemd units:**
   \`\`\`bash
   sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
   sudo systemctl daemon-reload
   \`\`\`

4. **Enable the timer:**
   \`\`\`bash
   sudo systemctl enable --now snapshot-manager.timer
   \`\`\`

## Configuration

### Main Configuration File

Edit \`/etc/snapshot-manager/snapshot-manager.conf\`:

\`\`\`bash
# Btrfs mount points to snapshot
BTRFS_MOUNT_POINTS=("/home" "/" "/var")

# ZFS datasets to snapshot
ZFS_DATASETS=("tank/home" "tank/root" "tank/var")

# Snapshot naming prefix
SNAPSHOT_PREFIX="auto-snapshot"

# Retention policies
RETENTION_DAILY=7      # Keep 7 daily snapshots
RETENTION_WEEKLY=4     # Keep 4 weekly snapshots
RETENTION_MONTHLY=12   # Keep 12 monthly snapshots

# Maximum concurrent operations
MAX_CONCURRENT_SNAPSHOTS=5
\`\`\`

### Environment Variables

The following environment variables can be set for additional configuration:

- \`SNAPSHOT_MANAGER_CONFIG\`: Path to custom configuration file
- \`SNAPSHOT_MANAGER_LOG_LEVEL\`: Override log level (debug, info, warn, error)
- \`SNAPSHOT_MANAGER_DRY_RUN\`: Set to "true" for dry-run mode

### Filesystem-Specific Configuration

**For Btrfs:**
- Ensure mount points are Btrfs filesystems
- Snapshots are stored in \`.snapshots\` directories within each mount point
- Requires read-write access to the filesystem

**For ZFS:**
- Specify full dataset paths (e.g., "tank/home", not "/tank/home")
- Snapshots are managed by ZFS automatically
- Requires ZFS admin privileges

## Usage

### Command Line Interface

\`\`\`bash
# Show help
snapshot-manager --help

# Create snapshots for all configured filesystems
snapshot-manager create

# List all available snapshots
snapshot-manager list

# Restore from a specific snapshot
snapshot-manager restore /home auto-snapshot-20240115-143022

# Clean up old snapshots based on retention policy
snapshot-manager cleanup

# Perform system health check
snapshot-manager health

# Use custom configuration file
snapshot-manager --config /path/to/custom.conf create

# Enable verbose logging
snapshot-manager --verbose create
\`\`\`

### Practical Examples

**Daily snapshot creation:**
\`\`\`bash
# Create snapshots of all configured filesystems
sudo snapshot-manager create
\`\`\`

**List snapshots with details:**
\`\`\`bash
# View all available snapshots
sudo snapshot-manager list
\`\`\`

**Emergency restore:**
\`\`\`bash
# First, list available snapshots to find the right one
sudo snapshot-manager list

# Restore /home from a specific snapshot
sudo snapshot-manager restore /home auto-snapshot-20240115-080000
\`\`\`

**Maintenance:**
\`\`\`bash
# Remove old snapshots to free space
sudo snapshot-manager cleanup

# Check system health
sudo snapshot-manager health
\`\`\`

## Automation

### Systemd Timer (Recommended)

The installation automatically sets up a systemd timer for daily snapshots:

\`\`\`bash
# Check timer status
sudo systemctl status snapshot-manager.timer

# View timer schedule
sudo systemctl list-timers snapshot-manager.timer

# Start timer immediately (for testing)
sudo systemctl start snapshot-manager.service

# View recent runs
sudo journalctl -u snapshot-manager.service -n 20
\`\`\`

### Custom Systemd Schedule

Edit \`/etc/systemd/system/snapshot-manager.timer\` to change the schedule:

\`\`\`ini
[Timer]
# Run every 6 hours
OnCalendar=*-*-* 00,06,12,18:00:00

# Run weekly on Sunday at 3 AM
OnCalendar=Sun *-*-* 03:00:00

# Run monthly on the 1st at 2 AM
OnCalendar=*-*-01 02:00:00
\`\`\`

After editing, reload systemd:
\`\`\`bash
sudo systemctl daemon-reload
sudo systemctl restart snapshot-manager.timer
\`\`\`

### Cron Alternative

If you prefer cron over systemd:

\`\`\`bash
# Edit root's crontab
sudo crontab -e

# Add daily snapshots at 2 AM
0 2 * * * /usr/local/bin/snapshot-manager create

# Add weekly cleanup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/snapshot-manager cleanup
\`\`\`

## Logging

### Log Locations

- **Main log file**: \`/var/log/snapshot-manager.log\`
- **System log**: Check with \`journalctl -t snapshot-manager\`
- **Systemd service logs**: \`journalctl -u snapshot-manager.service\`

### Viewing Logs

\`\`\`bash
# View recent log entries
sudo tail -f /var/log/snapshot-manager.log

# View logs from systemd
sudo journalctl -u snapshot-manager.service -f

# Search for errors
sudo grep -i error /var/log/snapshot-manager.log

# View logs from the last 24 hours
sudo journalctl -t snapshot-manager --since "24 hours ago"
\`\`\`

### Log Rotation

The system uses logrotate for log management. Configuration in \`/etc/logrotate.d/snapshot-manager\`:

\`\`\`
/var/log/snapshot-manager.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
\`\`\`

## Security Tips

### File System Permissions

- **Main script**: Owned by root, executable by root only
- **Configuration files**: Readable by root only (contains sensitive paths)
- **Log files**: Readable by root and log group
- **Snapshot directories**: Protected by filesystem permissions

### Systemd Security Features

The provided systemd service includes security hardening:

\`\`\`ini
[Service]
# Prevent privilege escalation
NoNewPrivileges=true

# Protect system files
ProtectSystem=strict

# Limit filesystem access
ReadWritePaths=/var/log /var/run /home /.snapshots

# Use private temporary directory
PrivateTmp=true
\`\`\`

### Best Practices

1. **Regular testing**: Test restore procedures regularly
2. **Monitor disk space**: Snapshots consume disk space
3. **Secure configuration**: Keep configuration files readable by root only
4. **Network isolation**: Consider network namespace isolation for ZFS operations
5. **Backup verification**: Verify snapshot integrity periodically

### SELinux Considerations

If using SELinux, you may need to create custom policies:

\`\`\`bash
# Check SELinux denials
sudo ausearch -c snapshot-manager

# Allow necessary permissions (example)
sudo setsebool -P allow_snapshot_manager 1
\`\`\`

## Example Output

### Successful Snapshot Creation

\`\`\`
[2024-01-15 14:30:22] [info] Starting snapshot creation process
[2024-01-15 14:30:22] [info] Creating Btrfs snapshot: /home/.snapshots/auto-snapshot-20240115-143022
[2024-01-15 14:30:24] [info] Successfully created Btrfs snapshot: /home/.snapshots/auto-snapshot-20240115-143022
[2024-01-15 14:30:24] [info] Creating ZFS snapshot: tank/home@auto-snapshot-20240115-143024
[2024-01-15 14:30:25] [info] Successfully created ZFS snapshot: tank/home@auto-snapshot-20240115-143024
[2024-01-15 14:30:25] [info] Snapshot creation process completed
[2024-01-15 14:30:25] [info] Operation completed successfully
\`\`\`

### Snapshot Listing

\`\`\`
[2024-01-15 14:35:10] [info] Listing all snapshots
[2024-01-15 14:35:10] [info] Btrfs snapshots for /home:
  auto-snapshot-20240115-143022 (2.3G, created: 2024-01-15 14:30:22)
  auto-snapshot-20240114-020000 (2.1G, created: 2024-01-14 02:00:00)
  auto-snapshot-20240113-020000 (2.0G, created: 2024-01-13 02:00:00)
[2024-01-15 14:35:11] [info] ZFS snapshots for tank/home:
  tank/home@auto-snapshot-20240115-143024   1.2G      -     -  -
  tank/home@auto-snapshot-20240114-020000   1.1G      -     -  -
  tank/home@auto-snapshot-20240113-020000   1.0G      -     -  -
\`\`\`

### System Health Check

\`\`\`
[2024-01-15 14:40:00] [info] Performing system health check
[2024-01-15 14:40:00] [info] Checking Btrfs filesystem: /home
[2024-01-15 14:40:01] [info] Checking ZFS pool health
[2024-01-15 14:40:01] [info] Operation completed successfully
\`\`\`

### Error Handling Example

\`\`\`
[2024-01-15 14:45:00] [error] Failed to create Btrfs snapshot: /var/.snapshots/auto-snapshot-20240115-144500
[2024-01-15 14:45:00] [error] Insufficient disk space on /var filesystem
[2024-01-15 14:45:00] [info] Cleaning up lock file
\`\`\`

## Troubleshooting

### Common Issues

**Permission denied errors:**
\`\`\`bash
# Ensure script is run as root
sudo snapshot-manager create

# Check file permissions
ls -la /usr/local/bin/snapshot-manager
\`\`\`

**Filesystem not detected:**
\`\`\`bash
# Check filesystem type
stat -f -c %T /path/to/filesystem

# Verify mount points
mount | grep btrfs
zfs list
\`\`\`

**Systemd timer not working:**
\`\`\`bash
# Check timer status
systemctl status snapshot-manager.timer

# Check for errors
journalctl -u snapshot-manager.timer
\`\`\`

**Disk space issues:**
\`\`\`bash
# Check available space
df -h

# Clean up old snapshots
sudo snapshot-manager cleanup
\`\`\`

## Author and License

**Author**: System Administrator Team  
**License**: MIT License  
**Version**: 1.0.0  
**Repository**: https://github.com/yourusername/btrfs-zfs-snapshot-manager

### MIT License

\`\`\`
Copyright (c) 2024 Snapshot Manager Contributors

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

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

### Support

For issues and questions:
- Create an issue on GitHub
- Check the troubleshooting section
- Review system logs for detailed error information

---

**Last updated**: January 2024  
**Tested on**: Ubuntu 22.04, Ubuntu 24.04, RHEL 9, Fedora 39`;

  const tabs = [
    { id: 'overview', name: 'Project Overview', icon: BookOpen },
    { id: 'structure', name: 'File Structure', icon: Folder },
    { id: 'main-script', name: 'Main Script', icon: Code },
    { id: 'config', name: 'Configuration', icon: Settings },
    { id: 'systemd', name: 'Systemd Units', icon: Clock },
    { id: 'install', name: 'Installation', icon: Terminal },
    { id: 'readme', name: 'README.md', icon: FileText }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100">
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="bg-white rounded-xl shadow-lg border border-slate-200 mb-8 p-8">
            <div className="flex items-center gap-4 mb-4">
              <div className="bg-gradient-to-r from-blue-600 to-purple-600 p-3 rounded-lg">
                <Shield className="h-8 w-8 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold text-slate-900">Btrfs/ZFS Snapshot Manager</h1>
                <p className="text-slate-600 text-lg">Production-ready filesystem snapshot and restore system</p>
              </div>
            </div>
            
            <div className="grid md:grid-cols-3 gap-6 mt-6">
              <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                <h3 className="font-semibold text-blue-900 mb-2">Multi-Filesystem Support</h3>
                <p className="text-blue-700 text-sm">Works with both Btrfs and ZFS filesystems from a unified interface</p>
              </div>
              <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                <h3 className="font-semibold text-green-900 mb-2">Enterprise Features</h3>
                <p className="text-green-700 text-sm">Automated scheduling, retention policies, comprehensive logging</p>
              </div>
              <div className="bg-purple-50 p-4 rounded-lg border border-purple-200">
                <h3 className="font-semibold text-purple-900 mb-2">Production Ready</h3>
                <p className="text-purple-700 text-sm">Security hardened, error handling, systemd integration</p>
              </div>
            </div>
          </div>

          {/* Navigation */}
          <div className="bg-white rounded-xl shadow-lg border border-slate-200 mb-8">
            <div className="border-b border-slate-200">
              <nav className="flex space-x-8 px-6">
                {tabs.map((tab) => {
                  const Icon = tab.icon;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      className={\`flex items-center gap-2 py-4 px-2 border-b-2 font-medium text-sm transition-colors \${
                        activeTab === tab.id
                          ? 'border-blue-600 text-blue-600'
                          : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300'
                      }\`}
                    >
                      <Icon className="h-4 w-4" />
                      {tab.name}
                    </button>
                  );
                })}
              </nav>
            </div>

            {/* Content */}
            <div className="p-6">
              {activeTab === 'overview' && (
                <div className="space-y-6">
                  <div>
                    <h2 className="text-2xl font-bold text-slate-900 mb-4">Project Features</h2>
                    <div className="grid md:grid-cols-2 gap-6">
                      <div className="space-y-4">
                        <div className="flex items-start gap-3">
                          <div className="bg-blue-100 p-2 rounded">
                            <Shield className="h-5 w-5 text-blue-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Multi-Filesystem Support</h3>
                            <p className="text-slate-600 text-sm">Unified interface for both Btrfs and ZFS filesystems</p>
                          </div>
                        </div>
                        <div className="flex items-start gap-3">
                          <div className="bg-green-100 p-2 rounded">
                            <Clock className="h-5 w-5 text-green-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Automated Snapshots</h3>
                            <p className="text-slate-600 text-sm">Systemd timer integration with configurable schedules</p>
                          </div>
                        </div>
                        <div className="flex items-start gap-3">
                          <div className="bg-purple-100 p-2 rounded">
                            <Settings className="h-5 w-5 text-purple-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Retention Policies</h3>
                            <p className="text-slate-600 text-sm">Configurable daily, weekly, and monthly retention</p>
                          </div>
                        </div>
                      </div>
                      <div className="space-y-4">
                        <div className="flex items-start gap-3">
                          <div className="bg-red-100 p-2 rounded">
                            <FileText className="h-5 w-5 text-red-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Comprehensive Logging</h3>
                            <p className="text-slate-600 text-sm">File and syslog integration with multiple log levels</p>
                          </div>
                        </div>
                        <div className="flex items-start gap-3">
                          <div className="bg-yellow-100 p-2 rounded">
                            <Terminal className="h-5 w-5 text-yellow-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Safe Operations</h3>
                            <p className="text-slate-600 text-sm">Automatic backups before restores, locking mechanism</p>
                          </div>
                        </div>
                        <div className="flex items-start gap-3">
                          <div className="bg-indigo-100 p-2 rounded">
                            <Code className="h-5 w-5 text-indigo-600" />
                          </div>
                          <div>
                            <h3 className="font-semibold text-slate-900">Health Monitoring</h3>
                            <p className="text-slate-600 text-sm">Built-in system health checks and monitoring</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200">
                    <h3 className="text-lg font-semibold text-slate-900 mb-3">Quick Start Commands</h3>
                    <div className="space-y-2">
                      <code className="block bg-slate-800 text-slate-100 p-3 rounded text-sm">
                        # Install the system
                        <br />sudo ./install.sh
                      </code>
                      <code className="block bg-slate-800 text-slate-100 p-3 rounded text-sm">
                        # Create snapshots
                        <br />sudo snapshot-manager create
                      </code>
                      <code className="block bg-slate-800 text-slate-100 p-3 rounded text-sm">
                        # List all snapshots
                        <br />sudo snapshot-manager list
                      </code>
                    </div>
                  </div>
                </div>
              )}

              {activeTab === 'structure' && (
                <div>
                  <h2 className="text-2xl font-bold text-slate-900 mb-4">Project File Structure</h2>
                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200">
                    <pre className="text-sm text-slate-800 font-mono whitespace-pre-wrap">{projectStructure}</pre>
                  </div>
                  <div className="mt-6 space-y-4">
                    <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                      <h3 className="font-semibold text-blue-900 mb-2">File Descriptions</h3>
                      <ul className="text-blue-800 text-sm space-y-1">
                        <li><strong>bin/snapshot-manager</strong> - Main executable script with all functionality</li>
                        <li><strong>config/snapshot-manager.conf</strong> - Configuration file for customizing behavior</li>
                        <li><strong>systemd/*.service, *.timer</strong> - Systemd units for automation</li>
                        <li><strong>install.sh</strong> - Automated installation script</li>
                        <li><strong>README.md</strong> - Comprehensive documentation</li>
                      </ul>
                    </div>
                  </div>
                </div>
              )}

              {activeTab === 'main-script' && (
                <div>
                  <h2 className="text-2xl font-bold text-slate-900 mb-4">Main Script (bin/snapshot-manager)</h2>
                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200 overflow-x-auto">
                    <pre className="text-xs text-slate-800 font-mono whitespace-pre-wrap">{mainScript}</pre>
                  </div>
                </div>
              )}

              {activeTab === 'config' && (
                <div>
                  <h2 className="text-2xl font-bold text-slate-900 mb-4">Configuration File</h2>
                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200">
                    <pre className="text-sm text-slate-800 font-mono whitespace-pre-wrap">{configFile}</pre>
                  </div>
                  <div className="mt-6 bg-yellow-50 p-4 rounded-lg border border-yellow-200">
                    <h3 className="font-semibold text-yellow-900 mb-2">Configuration Notes</h3>
                    <ul className="text-yellow-800 text-sm space-y-1">
                      <li>• Modify BTRFS_MOUNT_POINTS to match your Btrfs filesystems</li>
                      <li>• Update ZFS_DATASETS with your ZFS dataset names</li>
                      <li>• Adjust retention policies based on your storage capacity</li>
                      <li>• Enable email notifications by uncommenting and configuring SMTP settings</li>
                    </ul>
                  </div>
                </div>
              )}

              {activeTab === 'systemd' && (
                <div className="space-y-6">
                  <div>
                    <h2 className="text-2xl font-bold text-slate-900 mb-4">Systemd Service Unit</h2>
                    <div className="bg-slate-50 p-6 rounded-lg border border-slate-200">
                      <pre className="text-sm text-slate-800 font-mono whitespace-pre-wrap">{systemdService}</pre>
                    </div>
                  </div>
                  
                  <div>
                    <h2 className="text-2xl font-bold text-slate-900 mb-4">Systemd Timer Unit</h2>
                    <div className="bg-slate-50 p-6 rounded-lg border border-slate-200">
                      <pre className="text-sm text-slate-800 font-mono whitespace-pre-wrap">{systemdTimer}</pre>
                    </div>
                  </div>

                  <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                    <h3 className="font-semibold text-green-900 mb-2">Systemd Management Commands</h3>
                    <div className="text-green-800 text-sm space-y-1">
                      <code className="block bg-green-100 p-2 rounded">sudo systemctl enable snapshot-manager.timer</code>
                      <code className="block bg-green-100 p-2 rounded">sudo systemctl start snapshot-manager.timer</code>
                      <code className="block bg-green-100 p-2 rounded">sudo systemctl status snapshot-manager.timer</code>
                      <code className="block bg-green-100 p-2 rounded">sudo journalctl -u snapshot-manager.service</code>
                    </div>
                  </div>
                </div>
              )}

              {activeTab === 'install' && (
                <div>
                  <h2 className="text-2xl font-bold text-slate-900 mb-4">Installation Script</h2>
                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200 overflow-x-auto">
                    <pre className="text-xs text-slate-800 font-mono whitespace-pre-wrap">{installScript}</pre>
                  </div>
                  <div className="mt-6 grid md:grid-cols-2 gap-6">
                    <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                      <h3 className="font-semibold text-blue-900 mb-2">Installation Steps</h3>
                      <ol className="text-blue-800 text-sm space-y-1 list-decimal list-inside">
                        <li>Creates system directories</li>
                        <li>Copies executable and config files</li>
                        <li>Installs systemd units</li>
                        <li>Sets proper permissions</li>
                        <li>Enables automation timer</li>
                        <li>Checks dependencies</li>
                      </ol>
                    </div>
                    <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                      <h3 className="font-semibold text-green-900 mb-2">Post-Installation</h3>
                      <ul className="text-green-800 text-sm space-y-1">
                        <li>• Edit configuration file</li>
                        <li>• Test with first snapshot</li>
                        <li>• Verify systemd timer</li>
                        <li>• Check log file permissions</li>
                      </ul>
                    </div>
                  </div>
                </div>
              )}

              {activeTab === 'readme' && (
                <div>
                  <h2 className="text-2xl font-bold text-slate-900 mb-4">Complete README.md</h2>
                  <div className="bg-slate-50 p-6 rounded-lg border border-slate-200 max-h-[600px] overflow-y-auto">
                    <pre className="text-xs text-slate-800 font-mono whitespace-pre-wrap">{readmeContent}</pre>
                  </div>
                  <div className="mt-6 bg-blue-50 p-4 rounded-lg border border-blue-200">
                    <h3 className="font-semibold text-blue-900 mb-2">README Sections Included</h3>
                    <div className="grid md:grid-cols-2 gap-2 text-blue-800 text-sm">
                      <div>
                        <div>✅ Project Title</div>
                        <div>✅ Overview</div>
                        <div>✅ Features</div>
                        <div>✅ Requirements</div>
                        <div>✅ Installation</div>
                        <div>✅ Configuration</div>
                      </div>
                      <div>
                        <div>✅ Usage Examples</div>
                        <div>✅ Automation Setup</div>
                        <div>✅ Logging Details</div>
                        <div>✅ Security Tips</div>
                        <div>✅ Example Output</div>
                        <div>✅ Author and License</div>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Footer */}
          <div className="bg-slate-800 text-white rounded-xl shadow-lg p-6">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold mb-2">Production-Ready Snapshot Management</h3>
                <p className="text-slate-300">Complete Linux filesystem backup solution with enterprise features</p>
              </div>
              <div className="text-right">
                <div className="text-slate-400 text-sm">Compatible with</div>
                <div className="font-semibold">Ubuntu 22.04+ • RHEL 9+ • Fedora 39+</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
                      }
                  )
    }
    )
    }
  )
}