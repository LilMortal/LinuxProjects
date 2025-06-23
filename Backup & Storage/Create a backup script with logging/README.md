# Linux Backup Manager

A robust, feature-rich backup script for Linux systems with comprehensive logging, rotation, and automation capabilities.

## Overview

Linux Backup Manager is a Bash-based backup solution designed for Ubuntu 22.04+ and other standard Linux distributions. It provides automated backup functionality with intelligent rotation, compression options, integrity checking, and detailed logging. The script is designed for system administrators who need reliable, automated backup solutions with minimal maintenance overhead.

## Features

- **Multiple Backup Sources**: Backup multiple directories and files in a single operation
- **Compression Support**: Choose between gzip, bzip2, xz, or no compression
- **Intelligent Rotation**: Automatic cleanup of old backups based on retention policies
- **Integrity Checking**: SHA256 checksums for backup verification
- **Comprehensive Logging**: File-based and syslog integration with configurable levels
- **Dry Run Mode**: Test backup operations without actually creating backups
- **Email Notifications**: Optional email alerts for backup success/failure
- **Flexible Configuration**: Config file and CLI argument support
- **Systemd Integration**: Ready-to-use systemd service and timer units
- **Cron Support**: Traditional cron job examples included
- **Error Handling**: Robust error detection and recovery mechanisms

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04+ (or any standard Linux distribution)
- **Shell**: Bash 4.0+
- **Disk Space**: Sufficient space for backup storage and temporary files

### Dependencies
All dependencies are standard Linux tools:
- `tar` - Archive creation
- `gzip`/`bzip2`/`xz` - Compression (optional)
- `sha256sum` - Integrity checking
- `rsync` - File synchronization (optional)
- `mail` or `sendmail` - Email notifications (optional)
- `logger` - Syslog integration

## Installation

### 1. Clone or Download
```bash
# Clone the project
git clone https://github.com/yourusername/linux-backup-manager.git
cd linux-backup-manager

# Or download and extract
wget -O backup-manager.tar.gz https://github.com/yourusername/linux-backup-manager/archive/main.tar.gz
tar -xzf backup-manager.tar.gz
cd linux-backup-manager-main
```

### 2. Make Script Executable
```bash
chmod +x src/backup.sh
```

### 3. Install System-wide (Optional)
```bash
sudo cp src/backup.sh /usr/local/bin/backup-manager
sudo cp config/backup.conf /etc/backup-manager.conf
sudo mkdir -p /var/log/backup-manager
sudo chown $USER:$USER /var/log/backup-manager
```

## Configuration

### Environment Variables
```bash
export BACKUP_CONFIG="/path/to/backup.conf"    # Custom config file location
export BACKUP_LOG_LEVEL="INFO"                 # LOG_LEVEL: DEBUG, INFO, WARN, ERROR
export BACKUP_NOTIFY_EMAIL="admin@example.com" # Email for notifications
```

### Configuration File (`config/backup.conf`)
```bash
# Backup Configuration
BACKUP_SOURCES="/home/user/documents /home/user/projects /etc"
BACKUP_DESTINATION="/backup/daily"
BACKUP_PREFIX="backup"
COMPRESSION="gzip"  # Options: gzip, bzip2, xz, none
RETENTION_DAYS=30
LOG_FILE="/var/log/backup-manager/backup.log"
LOG_LEVEL="INFO"
ENABLE_EMAIL_NOTIFICATIONS=false
EMAIL_RECIPIENT="admin@example.com"
VERIFY_CHECKSUMS=true
```

## Usage

### Basic Usage
```bash
# Run backup with default configuration
./src/backup.sh

# Run with custom config file
./src/backup.sh -c /path/to/custom.conf

# Dry run (show what would be backed up)
./src/backup.sh --dry-run

# Verbose output
./src/backup.sh -v

# Run with specific compression
./src/backup.sh --compression xz
```

### Command Line Options
```bash
Usage: backup.sh [OPTIONS]

Options:
  -c, --config FILE        Use custom configuration file
  -d, --destination DIR    Override backup destination
  -s, --source DIRS        Override backup sources (space-separated)
  -r, --retention DAYS     Override retention period
  --compression TYPE       Compression type (gzip|bzip2|xz|none)
  --dry-run               Show what would be backed up without doing it
  -v, --verbose           Enable verbose output
  --no-checksum           Skip checksum verification
  --notify                Force email notification
  -h, --help              Display this help message

Examples:
  backup.sh -c /etc/backup.conf
  backup.sh --dry-run -v
  backup.sh -d /mnt/external/backups -r 14
  backup.sh -s "/home/user /var/www" --compression bzip2
```

## Automation

### Systemd Service (Recommended)

1. **Install service files:**
```bash
sudo cp systemd/backup-manager.service /etc/systemd/system/
sudo cp systemd/backup-manager.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

2. **Enable and start the timer:**
```bash
sudo systemctl enable backup-manager.timer
sudo systemctl start backup-manager.timer
```

3. **Check timer status:**
```bash
sudo systemctl status backup-manager.timer
sudo systemctl list-timers backup-manager*
```

### Cron Job (Alternative)

1. **Install cron job:**
```bash
sudo cp cron/backup-cron /etc/cron.d/backup-manager
```

2. **Or add to user crontab:**
```bash
crontab -e
# Add the following line for daily backups at 2 AM:
0 2 * * * /usr/local/bin/backup-manager -c /etc/backup-manager.conf
```

## Logging

### Log Locations
- **Default Log File**: `/var/log/backup-manager/backup.log`
- **Syslog Integration**: Check with `journalctl -u backup-manager` (systemd) or `/var/log/syslog`

### Log Levels
- **DEBUG**: Detailed operation information
- **INFO**: General information about backup progress
- **WARN**: Warning messages for non-critical issues
- **ERROR**: Error messages for failed operations

### Checking Logs
```bash
# View recent backup logs
tail -f /var/log/backup-manager/backup.log

# View systemd service logs
sudo journalctl -u backup-manager -f

# View logs for specific date
sudo journalctl -u backup-manager --since "2024-01-01" --until "2024-01-02"

# Check backup statistics
grep "Backup completed" /var/log/backup-manager/backup.log | tail -10
```

## Security Tips

### File Permissions
```bash
# Secure the backup script
chmod 755 /usr/local/bin/backup-manager

# Secure configuration file (may contain sensitive info)
chmod 600 /etc/backup-manager.conf
sudo chown root:root /etc/backup-manager.conf

# Secure log directory
chmod 755 /var/log/backup-manager
chown root:root /var/log/backup-manager
```

### Backup Destination Security
- Use encrypted storage for sensitive backups
- Implement proper access controls on backup directories
- Consider using `rsync` with SSH for remote backups
- Regularly test backup restoration procedures

### Network Backups
```bash
# Example: Remote backup with SSH
BACKUP_DESTINATION="user@remote-server:/backup/path"
# Ensure SSH key authentication is set up
```

## Example Output

### Successful Backup
```bash
$ ./src/backup.sh -v
[2024-01-15 14:30:01] INFO: Starting backup operation
[2024-01-15 14:30:01] INFO: Configuration loaded from config/backup.conf
[2024-01-15 14:30:01] INFO: Backup sources: /home/user/documents /home/user/projects /etc
[2024-01-15 14:30:01] INFO: Backup destination: /backup/daily
[2024-01-15 14:30:01] INFO: Compression: gzip
[2024-01-15 14:30:02] INFO: Creating backup: backup_20240115_143001.tar.gz
[2024-01-15 14:30:45] INFO: Backup created successfully (142.3 MB)
[2024-01-15 14:30:46] INFO: Generating SHA256 checksum
[2024-01-15 14:30:47] INFO: Checksum: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
[2024-01-15 14:30:47] INFO: Cleaning up old backups (retention: 30 days)
[2024-01-15 14:30:47] INFO: Removed 2 old backup files
[2024-01-15 14:30:47] INFO: Backup completed successfully
[2024-01-15 14:30:47] INFO: Total backup time: 46 seconds
```

### Dry Run Output
```bash
$ ./src/backup.sh --dry-run
[DRY RUN] Would backup the following sources:
  - /home/user/documents (1.2 GB)
  - /home/user/projects (856 MB)
  - /etc (45 MB)
[DRY RUN] Destination: /backup/daily/backup_20240115_143205.tar.gz
[DRY RUN] Estimated compressed size: 687 MB
[DRY RUN] Would remove 1 old backup file
[DRY RUN] No actual backup was performed
```

## Author and License

### Author
**Linux Backup Manager** - Created by [Your Name]
- Email: your.email@example.com
- GitHub: https://github.com/yourusername/linux-backup-manager

### Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 [Your Name]

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