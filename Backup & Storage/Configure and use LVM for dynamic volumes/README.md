# LVM Dynamic Volume Manager

A comprehensive Bash-based tool for managing LVM (Logical Volume Manager) operations with dynamic volume capabilities, automated monitoring, and robust error handling.

## Overview

The LVM Dynamic Volume Manager simplifies complex LVM operations through an intuitive command-line interface. It provides safe, automated management of physical volumes, volume groups, and logical volumes with comprehensive logging and monitoring capabilities. This tool is essential for system administrators managing dynamic storage requirements in enterprise Linux environments.

## Features

- **Complete LVM Lifecycle Management**: Create, extend, shrink, and remove physical volumes, volume groups, and logical volumes
- **Dynamic Volume Operations**: Automated volume resizing based on usage thresholds
- **Safety Checks**: Pre-operation validation to prevent data loss
- **Comprehensive Logging**: File-based and syslog integration with configurable log levels
- **Configuration Management**: Flexible configuration file support
- **Backup Operations**: Automated LVM metadata backup and restore
- **Status Monitoring**: Real-time volume usage and health monitoring
- **Systemd Integration**: Service for automated monitoring and maintenance
- **CLI Interface**: Intuitive command-line interface with help documentation

## Requirements

- **Operating System**: Ubuntu 22.04+ or any standard Linux distribution
- **Dependencies**: 
  - `lvm2` package
  - `util-linux` (for filesystem operations)
  - `bash` 4.0+
  - `systemd` (for service management)
- **Permissions**: Root access required for LVM operations
- **Storage**: Available block devices or disk space for volume creation

## Installation

### Quick Installation

```bash
# Clone the project
git clone https://github.com/your-repo/lvm-manager.git
cd lvm-manager

# Make installation script executable
chmod +x install.sh

# Run installation (requires root)
sudo ./install.sh
```

### Manual Installation

```bash
# Copy main script to system location
sudo cp src/lvm-manager.sh /usr/local/bin/lvm-manager
sudo chmod +x /usr/local/bin/lvm-manager

# Copy configuration file
sudo cp config/lvm-manager.conf /etc/lvm-manager.conf

# Install systemd service
sudo cp systemd/lvm-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload

# Create log directory
sudo mkdir -p /var/log/lvm-manager
```

## Configuration

Configuration is managed through `/etc/lvm-manager.conf`:

```bash
# LVM Manager Configuration

# Logging Configuration
LOG_LEVEL="INFO"                    # DEBUG, INFO, WARN, ERROR
LOG_FILE="/var/log/lvm-manager/lvm-manager.log"
MAX_LOG_SIZE="10M"                  # Maximum log file size
LOG_RETENTION_DAYS=30               # Days to keep old logs

# Default Volume Group Settings
DEFAULT_VG_NAME="system_vg"         # Default volume group name
DEFAULT_PE_SIZE="4M"                # Physical extent size

# Monitoring Settings
USAGE_THRESHOLD=80                  # Alert when volume usage exceeds %
AUTO_EXTEND_THRESHOLD=90            # Auto-extend when usage exceeds %
AUTO_EXTEND_SIZE="1G"               # Default extension size

# Backup Settings
BACKUP_ENABLED=true                 # Enable automatic backups
BACKUP_LOCATION="/var/backup/lvm"   # Backup directory
BACKUP_RETENTION=7                  # Days to keep backups

# Safety Settings
REQUIRE_CONFIRMATION=true           # Require confirmation for destructive operations
DRY_RUN_DEFAULT=false              # Default to dry-run mode
```

## Usage

### Basic Operations

#### Create Physical Volume
```bash
# Create physical volume on device
sudo lvm-manager create-pv /dev/sdb

# Create multiple physical volumes
sudo lvm-manager create-pv /dev/sdb /dev/sdc /dev/sdd
```

#### Create Volume Group
```bash
# Create volume group with single PV
sudo lvm-manager create-vg my_vg /dev/sdb

# Create volume group with multiple PVs
sudo lvm-manager create-vg my_vg /dev/sdb /dev/sdc
```

#### Create Logical Volume
```bash
# Create logical volume with specific size
sudo lvm-manager create-lv my_lv my_vg 10G

# Create logical volume using percentage of VG
sudo lvm-manager create-lv my_lv my_vg 50%VG

# Create and format logical volume
sudo lvm-manager create-lv my_lv my_vg 10G --format ext4 --mount /mnt/data
```

### Volume Management

#### Extend Volumes
```bash
# Extend logical volume
sudo lvm-manager extend-lv my_vg/my_lv 5G

# Extend volume group
sudo lvm-manager extend-vg my_vg /dev/sdd

# Auto-extend based on usage
sudo lvm-manager auto-extend my_vg/my_lv
```

#### Monitor Volumes
```bash
# Show volume status
sudo lvm-manager status

# Show detailed volume information
sudo lvm-manager info my_vg/my_lv

# Monitor volume usage
sudo lvm-manager monitor --threshold 80
```

### Advanced Operations

#### Backup and Restore
```bash
# Backup LVM configuration
sudo lvm-manager backup

# Restore LVM configuration
sudo lvm-manager restore /var/backup/lvm/backup-20241201-120000.tar.gz

# List available backups
sudo lvm-manager list-backups
```

#### Snapshot Management
```bash
# Create snapshot
sudo lvm-manager create-snapshot my_vg/my_lv my_snapshot 1G

# Merge snapshot
sudo lvm-manager merge-snapshot my_vg/my_snapshot

# Remove snapshot
sudo lvm-manager remove-snapshot my_vg/my_snapshot
```

## Automation

### Systemd Service

Enable automated monitoring and maintenance:

```bash
# Enable and start LVM monitor service
sudo systemctl enable lvm-monitor.service
sudo systemctl start lvm-monitor.service

# Check service status
sudo systemctl status lvm-monitor.service

# View service logs
sudo journalctl -u lvm-monitor.service -f
```

### Cron Jobs

Add to root's crontab for automated operations:

```bash
# Edit root crontab
sudo crontab -e

# Add the following lines:

# Daily backup at 2 AM
0 2 * * * /usr/local/bin/lvm-manager backup

# Hourly volume monitoring
0 * * * * /usr/local/bin/lvm-manager monitor --auto-extend

# Weekly cleanup of old logs
0 3 * * 0 /usr/local/bin/lvm-manager cleanup-logs
```

## Logging

### Log Locations

- **Main Log**: `/var/log/lvm-manager/lvm-manager.log`
- **System Log**: Available via `journalctl -t lvm-manager`
- **Service Log**: `journalctl -u lvm-monitor.service`

### Viewing Logs

```bash
# View recent logs
sudo tail -f /var/log/lvm-manager/lvm-manager.log

# View logs with specific level
sudo grep "ERROR" /var/log/lvm-manager/lvm-manager.log

# View systemd service logs
sudo journalctl -u lvm-monitor.service --since "1 hour ago"
```

## Security Tips

### File Permissions
```bash
# Set proper permissions for configuration
sudo chmod 600 /etc/lvm-manager.conf
sudo chown root:root /etc/lvm-manager.conf

# Secure log directory
sudo chmod 755 /var/log/lvm-manager
sudo chown root:root /var/log/lvm-manager
```

### Access Control
- **Root Access Required**: All LVM operations require root privileges
- **Sudo Configuration**: Consider creating specific sudo rules for non-root users
- **Device Access**: Ensure proper permissions on block devices
- **Backup Security**: Encrypt backup files for sensitive environments

### Best Practices
- Always test operations in non-production environments first
- Maintain regular backups of LVM metadata
- Monitor disk space and volume usage proactively
- Use descriptive names for volume groups and logical volumes
- Document volume purposes and dependencies

## Example Output

### Volume Status Display
```
$ sudo lvm-manager status

=== LVM Dynamic Volume Manager Status ===
Timestamp: 2024-12-01 14:30:15

Physical Volumes:
  /dev/sdb1    system_vg    931.51g   245.12g   686.39g
  /dev/sdc1    data_vg      1.82t     892.45g   972.11g

Volume Groups:
  system_vg    2 PVs       931.51g   245.12g   686.39g
  data_vg      1 PV        1.82t     892.45g   972.11g

Logical Volumes:
  system_vg/root     20.00g    85%      17.00g
  system_vg/home     50.00g    72%      36.00g
  data_vg/database   200.00g   94%      188.00g   [WARNING: High usage]
  data_vg/backup     100.00g   45%      45.00g

Alerts:
  - data_vg/database usage (94%) exceeds threshold (80%)
  - Auto-extend recommended for data_vg/database
```

### Backup Operation Output
```
$ sudo lvm-manager backup

=== LVM Configuration Backup ===
Timestamp: 2024-12-01 14:35:22
Backup Location: /var/backup/lvm/backup-20241201-143522.tar.gz

Backing up:
✓ LVM metadata
✓ Configuration files
✓ Volume group information
✓ Physical volume data

Backup completed successfully.
Size: 2.3 MB
Retention: 7 days (automatic cleanup enabled)
```

## Author and License

**Author**: System Administration Team  
**Maintainer**: admin@company.com  
**Version**: 1.0.0  
**License**: MIT License

```
MIT License

Copyright (c) 2024 LVM Manager Project

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

---

For support, bug reports, or feature requests, please visit our repository or contact the maintenance team.