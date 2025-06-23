# Btrfs/ZFS Snapshot Manager

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
  - `btrfs-progs` (for Btrfs support)
  - `zfsutils-linux` (for ZFS support)
  - `systemd` (for automation)

### System Requirements
- Root access for snapshot operations
- Sufficient disk space for snapshots (typically 10-20% of filesystem size)
- At least 512MB RAM for large filesystem operations

### Installing Dependencies

**Ubuntu/Debian:**
```bash
# For Btrfs support
sudo apt update
sudo apt install btrfs-progs

# For ZFS support (Ubuntu 22.04+)
sudo apt install zfsutils-linux

# Verify installations
btrfs --version
zfs version
```

**RHEL/CentOS/Fedora:**
```bash
# For Btrfs support
sudo dnf install btrfs-progs

# For ZFS support (requires EPEL)
sudo dnf install epel-release
sudo dnf install zfs
```

## Installation

### Method 1: Automated Installation (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/btrfs-zfs-snapshot-manager.git
   cd btrfs-zfs-snapshot-manager
   ```

2. **Run the installation script:**
   ```bash
   sudo ./install.sh
   ```

### Method 2: Manual Installation

1. **Copy the main script:**
   ```bash
   sudo cp bin/snapshot-manager /usr/local/bin/
   sudo chmod +x /usr/local/bin/snapshot-manager
   ```

2. **Create configuration directory and copy config:**
   ```bash
   sudo mkdir -p /etc/snapshot-manager
   sudo cp config/snapshot-manager.conf /etc/snapshot-manager/
   ```

3. **Install systemd units:**
   ```bash
   sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

4. **Enable the timer:**
   ```bash
   sudo systemctl enable --now snapshot-manager.timer
   ```

## Configuration

### Main Configuration File

Edit `/etc/snapshot-manager/snapshot-manager.conf`:

```bash
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
```

### Environment Variables

The following environment variables can be set for additional configuration:

- `SNAPSHOT_MANAGER_CONFIG`: Path to custom configuration file
- `SNAPSHOT_MANAGER_LOG_LEVEL`: Override log level (debug, info, warn, error)
- `SNAPSHOT_MANAGER_DRY_RUN`: Set to "true" for dry-run mode

### Filesystem-Specific Configuration

**For Btrfs:**
- Ensure mount points are Btrfs filesystems
- Snapshots are stored in `.snapshots` directories within each mount point
- Requires read-write access to the filesystem

**For ZFS:**
- Specify full dataset paths (e.g., "tank/home", not "/tank/home")
- Snapshots are managed by ZFS automatically
- Requires ZFS admin privileges

## Usage

### Command Line Interface

```bash
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
```

### Practical Examples

**Daily snapshot creation:**
```bash
# Create snapshots of all configured filesystems
sudo snapshot-manager create
```

**List snapshots with details:**
```bash
# View all available snapshots
sudo snapshot-manager list
```

**Emergency restore:**
```bash
# First, list available snapshots to find the right one
sudo snapshot-manager list

# Restore /home from a specific snapshot
sudo snapshot-manager restore /home auto-snapshot-20240115-080000
```

**Maintenance:**
```bash
# Remove old snapshots to free space
sudo snapshot-manager cleanup

# Check system health
sudo snapshot-manager health
```

## Automation

### Systemd Timer (Recommended)

The installation automatically sets up a systemd timer for daily snapshots:

```bash
# Check timer status
sudo systemctl status snapshot-manager.timer

# View timer schedule
sudo systemctl list-timers snapshot-manager.timer

# Start timer immediately (for testing)
sudo systemctl start snapshot-manager.service

# View recent runs
sudo journalctl -u snapshot-manager.service -n 20
```

### Custom Systemd Schedule

Edit `/etc/systemd/system/snapshot-manager.timer` to change the schedule:

```ini
[Timer]
# Run every 6 hours
OnCalendar=*-*-* 00,06,12,18:00:00

# Run weekly on Sunday at 3 AM
OnCalendar=Sun *-*-* 03:00:00

# Run monthly on the 1st at 2 AM
OnCalendar=*-*-01 02:00:00
```

After editing, reload systemd:
```bash
sudo systemctl daemon-reload
sudo systemctl restart snapshot-manager.timer
```

### Cron Alternative

If you prefer cron over systemd:

```bash
# Edit root's crontab
sudo crontab -e

# Add daily snapshots at 2 AM
0 2 * * * /usr/local/bin/snapshot-manager create

# Add weekly cleanup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/snapshot-manager cleanup
```

## Logging

### Log Locations

- **Main log file**: `/var/log/snapshot-manager.log`
- **System log**: Check with `journalctl -t snapshot-manager`
- **Systemd service logs**: `journalctl -u snapshot-manager.service`

### Viewing Logs

```bash
# View recent log entries
sudo tail -f /var/log/snapshot-manager.log

# View logs from systemd
sudo journalctl -u snapshot-manager.service -f

# Search for errors
sudo grep -i error /var/log/snapshot-manager.log

# View logs from the last 24 hours
sudo journalctl -t snapshot-manager --since "24 hours ago"
```

### Log Rotation

The system uses logrotate for log management. Configuration in `/etc/logrotate.d/snapshot-manager`:

```
/var/log/snapshot-manager.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

## Security Tips

### File System Permissions

- **Main script**: Owned by root, executable by root only
- **Configuration files**: Readable by root only (contains sensitive paths)
- **Log files**: Readable by root and log group
- **Snapshot directories**: Protected by filesystem permissions

### Systemd Security Features

The provided systemd service includes security hardening:

```ini
[Service]
# Prevent privilege escalation
NoNewPrivileges=true

# Protect system files
ProtectSystem=strict

# Limit filesystem access
ReadWritePaths=/var/log /var/run /home /.snapshots

# Use private temporary directory
PrivateTmp=true
```

### Best Practices

1. **Regular testing**: Test restore procedures regularly
2. **Monitor disk space**: Snapshots consume disk space
3. **Secure configuration**: Keep configuration files readable by root only
4. **Network isolation**: Consider network namespace isolation for ZFS operations
5. **Backup verification**: Verify snapshot integrity periodically

### SELinux Considerations

If using SELinux, you may need to create custom policies:

```bash
# Check SELinux denials
sudo ausearch -c snapshot-manager

# Allow necessary permissions (example)
sudo setsebool -P allow_snapshot_manager 1
```

## Example Output

### Successful Snapshot Creation

```
[2024-01-15 14:30:22] [info] Starting snapshot creation process
[2024-01-15 14:30:22] [info] Creating Btrfs snapshot: /home/.snapshots/auto-snapshot-20240115-143022
[2024-01-15 14:30:24] [info] Successfully created Btrfs snapshot: /home/.snapshots/auto-snapshot-20240115-143022
[2024-01-15 14:30:24] [info] Creating ZFS snapshot: tank/home@auto-snapshot-20240115-143024
[2024-01-15 14:30:25] [info] Successfully created ZFS snapshot: tank/home@auto-snapshot-20240115-143024
[2024-01-15 14:30:25] [info] Snapshot creation process completed
[2024-01-15 14:30:25] [info] Operation completed successfully
```

### Snapshot Listing

```
[2024-01-15 14:35:10] [info] Listing all snapshots
[2024-01-15 14:35:10] [info] Btrfs snapshots for /home:
  auto-snapshot-20240115-143022 (2.3G, created: 2024-01-15 14:30:22)
  auto-snapshot-20240114-020000 (2.1G, created: 2024-01-14 02:00:00)
  auto-snapshot-20240113-020000 (2.0G, created: 2024-01-13 02:00:00)
[2024-01-15 14:35:11] [info] ZFS snapshots for tank/home:
  tank/home@auto-snapshot-20240115-143024   1.2G      -     -  -
  tank/home@auto-snapshot-20240114-020000   1.1G      -     -  -
  tank/home@auto-snapshot-20240113-020000   1.0G      -     -  -
```

### System Health Check

```
[2024-01-15 14:40:00] [info] Performing system health check
[2024-01-15 14:40:00] [info] Checking Btrfs filesystem: /home
[2024-01-15 14:40:01] [info] Checking ZFS pool health
[2024-01-15 14:40:01] [info] Operation completed successfully
```

### Error Handling Example

```
[2024-01-15 14:45:00] [error] Failed to create Btrfs snapshot: /var/.snapshots/auto-snapshot-20240115-144500
[2024-01-15 14:45:00] [error] Insufficient disk space on /var filesystem
[2024-01-15 14:45:00] [info] Cleaning up lock file
```

## Troubleshooting

### Common Issues

**Permission denied errors:**
```bash
# Ensure script is run as root
sudo snapshot-manager create

# Check file permissions
ls -la /usr/local/bin/snapshot-manager
```

**Filesystem not detected:**
```bash
# Check filesystem type
stat -f -c %T /path/to/filesystem

# Verify mount points
mount | grep btrfs
zfs list
```

**Systemd timer not working:**
```bash
# Check timer status
systemctl status snapshot-manager.timer

# Check for errors
journalctl -u snapshot-manager.timer
```

**Disk space issues:**
```bash
# Check available space
df -h

# Clean up old snapshots
sudo snapshot-manager cleanup
```

## Author and License

**Author**: System Administrator Team  
**License**: MIT License  
**Version**: 1.0.0  
**Repository**: https://github.com/yourusername/btrfs-zfs-snapshot-manager

### MIT License

```
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
```

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
**Tested on**: Ubuntu 22.04, Ubuntu 24.04, RHEL 9, Fedora 39