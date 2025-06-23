# 🗄️ AutoBackup Pro

## Overview

AutoBackup Pro is a robust Linux-based backup automation system that performs daily backups of specified directories to a remote server. It uses rsync for efficient incremental backups, provides comprehensive logging, email notifications, and integrates seamlessly with systemd for reliable automation.

## Features

- **Incremental Backups**: Uses rsync for efficient, bandwidth-saving transfers
- **Compression**: Optional tar.gz compression for archived backups
- **Retention Policy**: Automatic cleanup of old backups based on configurable retention periods
- **Remote Transfer**: Secure SSH-based transfers to remote servers
- **Email Notifications**: Optional email alerts for backup failures
- **Comprehensive Logging**: Detailed logs with rotation support
- **CLI Interface**: Manual backup execution with various options
- **Systemd Integration**: Automated daily execution via systemd timer
- **Configuration Management**: Easy-to-edit configuration file
- **Error Recovery**: Robust error handling with retry mechanisms

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04+ or any modern Linux distribution
- **Shell**: Bash 4.0+
- **Disk Space**: Sufficient space for temporary backup archives

### Dependencies
```bash
# Standard tools (usually pre-installed)
rsync, ssh, tar, gzip, find, date, logger

# Optional (for email notifications)
mailutils or sendmail
```

## Installation

### 1. Clone or Download
```bash
# Clone the repository
git clone https://github.com/yourusername/autobackup-pro.git
cd autobackup-pro

# Or download and extract
wget https://github.com/yourusername/autobackup-pro/archive/main.zip
unzip main.zip && cd autobackup-pro-main
```

### 2. Set Permissions
```bash
# Make scripts executable
chmod +x bin/autobackup.sh
chmod +x bin/install.sh

# Run installation script
sudo ./bin/install.sh
```

### 3. Manual Installation
```bash
# Copy files to system locations
sudo cp bin/autobackup.sh /usr/local/bin/autobackup
sudo cp config/autobackup.conf /etc/autobackup/
sudo cp systemd/autobackup.service /etc/systemd/system/
sudo cp systemd/autobackup.timer /etc/systemd/system/

# Create directories
sudo mkdir -p /var/log/autobackup
sudo mkdir -p /var/lib/autobackup

# Set permissions
sudo chown -R $USER:$USER /var/log/autobackup
sudo chmod 755 /usr/local/bin/autobackup
```

## Configuration

### Main Configuration File
Edit `/etc/autobackup/autobackup.conf`:

```bash
# Backup source directories (space-separated)
BACKUP_DIRS="/home/user/documents /home/user/projects /etc"

# Remote server settings
REMOTE_HOST="backup.example.com"
REMOTE_USER="backupuser"
REMOTE_PATH="/backups/$(hostname)"

# Local backup settings
LOCAL_BACKUP_DIR="/var/lib/autobackup"
BACKUP_NAME_PREFIX="backup-$(hostname)"

# Retention settings (days)
RETENTION_DAYS=30

# Compression settings
ENABLE_COMPRESSION=true
COMPRESSION_LEVEL=6

# Email notifications
ENABLE_EMAIL_ALERTS=true
EMAIL_RECIPIENT="admin@example.com"
EMAIL_SUBJECT="Backup Alert - $(hostname)"

# SSH settings
SSH_KEY_PATH="/home/$USER/.ssh/backup_key"
SSH_PORT=22

# Logging
LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
LOG_MAX_SIZE="10M"
LOG_RETENTION_DAYS=90
```

### SSH Key Setup
```bash
# Generate SSH key for automated backups
ssh-keygen -t rsa -b 4096 -f ~/.ssh/backup_key -N ""

# Copy public key to remote server
ssh-copy-id -i ~/.ssh/backup_key.pub backupuser@backup.example.com

# Test connection
ssh -i ~/.ssh/backup_key backupuser@backup.example.com
```

## Usage

### Manual Backup Execution
```bash
# Run backup with default settings
autobackup

# Run backup with verbose output
autobackup --verbose

# Run backup with dry-run (test mode)
autobackup --dry-run

# Run backup with custom config file
autobackup --config /path/to/custom.conf

# Show help
autobackup --help

# Show version and status
autobackup --status
```

### Command Line Options
```bash
Usage: autobackup [OPTIONS]

Options:
  -v, --verbose         Enable verbose output
  -d, --dry-run         Perform dry run without actual backup
  -c, --config FILE     Use custom configuration file
  -f, --force           Force backup even if recent backup exists
  -s, --status          Show backup status and statistics
  -h, --help            Show this help message
  --version             Show version information
```

## Automation

### Systemd Timer (Recommended)
```bash
# Enable and start the backup timer
sudo systemctl enable autobackup.timer
sudo systemctl start autobackup.timer

# Check timer status
sudo systemctl status autobackup.timer

# View next scheduled run
sudo systemctl list-timers autobackup.timer

# Manual service execution
sudo systemctl start autobackup.service
```

### Cron Alternative
```bash
# Edit crontab
crontab -e

# Add daily backup at 2:00 AM
0 2 * * * /usr/local/bin/autobackup >/dev/null 2>&1

# Add weekly backup with email notification
0 2 * * 0 /usr/local/bin/autobackup --verbose 2>&1 | mail -s "Weekly Backup Report" admin@example.com
```

## Logging

### Log Locations
- **Main Log**: `/var/log/autobackup/autobackup.log`
- **Error Log**: `/var/log/autobackup/error.log`
- **System Log**: Use `journalctl -u autobackup.service`

### Viewing Logs
```bash
# View recent backup logs
tail -f /var/log/autobackup/autobackup.log

# View error logs
tail -f /var/log/autobackup/error.log

# View systemd service logs
journalctl -u autobackup.service -f

# View logs for specific date
journalctl -u autobackup.service --since "2024-01-01" --until "2024-01-02"

# View backup statistics
autobackup --status
```

## Security Tips

### SSH Security
- **Use SSH Keys**: Never use password authentication for automated backups
- **Restrict SSH Key**: Create a dedicated SSH key with limited permissions
- **SSH Config**: Configure SSH client settings in `~/.ssh/config`
- **Firewall**: Ensure proper firewall rules on both client and server

### File Permissions
```bash
# Secure configuration file
sudo chmod 600 /etc/autobackup/autobackup.conf

# Secure SSH private key
chmod 600 ~/.ssh/backup_key

# Secure backup directories
sudo chmod 750 /var/lib/autobackup
sudo chmod 750 /var/log/autobackup
```

### Remote Server Security
- **Dedicated User**: Create a dedicated backup user on the remote server
- **Directory Restrictions**: Limit backup user access to backup directories only
- **SSH Restrictions**: Use `authorized_keys` restrictions (command, from, etc.)
- **Monitoring**: Monitor backup activities and disk usage

## Example Output

### Successful Backup
```
[2024-01-15 02:00:01] INFO: Starting backup process
[2024-01-15 02:00:01] INFO: Configuration loaded from /etc/autobackup/autobackup.conf
[2024-01-15 02:00:02] INFO: Creating backup archive: backup-server01-20240115-020001.tar.gz
[2024-01-15 02:00:45] INFO: Archive created successfully (2.3 GB)
[2024-01-15 02:00:45] INFO: Starting remote transfer to backup.example.com
[2024-01-15 02:03:22] INFO: Transfer completed successfully
[2024-01-15 02:03:22] INFO: Cleaning up old backups (retention: 30 days)
[2024-01-15 02:03:23] INFO: Removed 2 old backup files
[2024-01-15 02:03:23] INFO: Backup completed successfully
[2024-01-15 02:03:23] INFO: Total time: 3m 22s, Size: 2.3 GB
```

### Error Example
```
[2024-01-15 02:00:01] ERROR: Failed to connect to remote server backup.example.com
[2024-01-15 02:00:01] ERROR: SSH connection failed: Permission denied (publickey)
[2024-01-15 02:00:01] ERROR: Backup failed - check SSH key configuration
[2024-01-15 02:00:01] INFO: Email notification sent to admin@example.com
```

## Author and License

**Author**: Your Name  
**Email**: your.email@example.com  
**GitHub**: https://github.com/yourusername/autobackup-pro

### License
```
MIT License

Copyright (c) 2024 Your Name

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