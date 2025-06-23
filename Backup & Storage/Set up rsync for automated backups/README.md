# Rsync Backup Tool

A comprehensive, production-ready backup solution using rsync with automation support for Linux systems.

## Overview

The Rsync Backup Tool is a robust bash-based backup solution designed for Linux systems that provides automated, configurable, and reliable backups using rsync. It supports both local and remote backups, includes comprehensive logging, error handling, and can be easily automated using systemd timers or cron jobs.

This tool is perfect for system administrators who need a reliable, lightweight backup solution that can handle multiple backup jobs with different configurations, exclusion patterns, and retention policies.

## Features

- **Multiple Backup Jobs**: Configure multiple backup jobs with individual settings
- **Local and Remote Backups**: Support for both local filesystem and remote SSH-based backups
- **Flexible Configuration**: YAML-like configuration file for easy management
- **Comprehensive Logging**: Dual logging to files and syslog with different log levels
- **Dry-Run Mode**: Test your backup configurations without actually copying files
- **Exclusion Patterns**: Support for exclude files and inline exclude patterns
- **Error Handling**: Robust error handling with detailed error reporting
- **Automation Ready**: Built-in systemd service and timer support
- **Security Focused**: Runs as dedicated backup user with minimal privileges
- **CLI Interface**: Full command-line interface with multiple options

## Requirements

- **Operating System**: Ubuntu 22.04+ or any modern Linux distribution
- **Dependencies**: 
  - `rsync` (for backup operations)
  - `bash` 4.0+ (for script execution)
  - `systemd` (for service automation, optional)
  - `cron` (for cron-based automation, optional)
- **Privileges**: Root access for installation, dedicated backup user for execution
- **Disk Space**: Sufficient space on backup destination
- **Network**: SSH access to remote hosts (for remote backups)

## Installation

### Quick Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/rsync-backup-tool.git
   cd rsync-backup-tool
   ```

2. **Run the installer (requires root):**
   ```bash
   sudo ./install.sh
   ```

3. **The installer will:**
   - Install required dependencies
   - Create a dedicated `backup` user and group
   - Install files to `/opt/rsync-backup-tool`
   - Set up systemd service files
   - Create backup directories with proper permissions

### Manual Installation

If you prefer manual installation:

```bash
# Create backup user
sudo useradd --system --create-home --shell /bin/bash backup

# Create installation directory
sudo mkdir -p /opt/rsync-backup-tool

# Copy files
sudo cp -r src config systemd examples /opt/rsync-backup-tool/
sudo cp README.md /opt/rsync-backup-tool/

# Set permissions
sudo chown -R backup:backup /opt/rsync-backup-tool
sudo chmod +x /opt/rsync-backup-tool/src/backup.sh

# Install systemd files
sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

## Configuration

### Main Configuration File

Edit `/opt/rsync-backup-tool/config/backup.conf` to configure your backup jobs:

```ini
# Example home directory backup
[backup:home-backup]
source = /home/user/
destination = /backup/home/
exclude_file = /home/user/.backup_exclude
exclude_patterns = .cache, .tmp, *.log
rsync_options = --delete --backup --backup-dir=deleted-files
retention_days = 30

# Example remote backup
[backup:documents-remote]
source = /home/user/Documents/
destination = /backup/documents/
remote_host = backup.example.com
remote_user = backupuser
exclude_patterns = *.tmp, .DS_Store
rsync_options = --delete
```

### Configuration Options

- `source`: Source directory to backup (required)
- `destination`: Destination directory (required)
- `exclude_file`: Path to file containing exclude patterns
- `exclude_patterns`: Comma-separated exclude patterns
- `rsync_options`: Additional rsync options
- `retention_days`: Days to keep backups (for cleanup)
- `remote_host`: Remote host for network backups
- `remote_user`: Remote username (defaults to current user)

### Environment Variables

The tool uses these environment variables (set automatically by systemd):

- `PATH`: Standard system PATH
- Log files are written to `/opt/rsync-backup-tool/logs/`

## Usage

### Command Line Interface

```bash
# Run all configured backup jobs
sudo -u backup /opt/rsync-backup-tool/src/backup.sh

# Run specific backup job
sudo -u backup /opt/rsync-backup-tool/src/backup.sh home-backup

# Dry run (test without actually copying)
sudo -u backup /opt/rsync-backup-tool/src/backup.sh -n documents-remote

# Verbose output
sudo -u backup /opt/rsync-backup-tool/src/backup.sh -v

# Use custom configuration file
sudo -u backup /opt/rsync-backup-tool/src/backup.sh -c /path/to/config.conf

# Show help
/opt/rsync-backup-tool/src/backup.sh --help
```

### Available Options

```
-c, --config FILE       Use custom configuration file
-l, --log FILE          Use custom log file
-n, --dry-run           Show what would be done without doing it
-v, --verbose           Enable verbose output and debug logging
-f, --force             Force backup even if recent backup exists
-h, --help              Show help message
--version               Show version information
```

### Example Commands

```bash
# Test all backup configurations
sudo -u backup /opt/rsync-backup-tool/src/backup.sh -n -v

# Run only critical backups during business hours
sudo -u backup /opt/rsync-backup-tool/src/backup.sh critical-data

# Backup with custom exclude patterns
sudo -u backup /opt/rsync-backup-tool/src/backup.sh -v home-backup
```

## Automation

### Using Systemd (Recommended)

The tool includes systemd service and timer files for automation:

```bash
# Enable and start the timer (runs daily at 2 AM)
sudo systemctl enable --now rsync-backup.timer

# Check timer status
sudo systemctl status rsync-backup.timer

# View upcoming timer runs
sudo systemctl list-timers rsync-backup.timer

# Run backup manually via systemd
sudo systemctl start rsync-backup.service

# Check service logs
sudo journalctl -u rsync-backup.service -f
```

### Using Cron

Alternative cron-based automation (examples in `examples/crontab.example`):

```bash
# Edit crontab for backup user
sudo -u backup crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * /opt/rsync-backup-tool/src/backup.sh >/dev/null 2>&1

# Multiple backup jobs at different times
0 1 * * * /opt/rsync-backup-tool/src/backup.sh home-backup
0 3 * * * /opt/rsync-backup-tool/src/backup.sh documents-remote
0 4 * * 0 /opt/rsync-backup-tool/src/backup.sh system-config
```

### Monitoring Automation

```bash
# Check if timer is active
sudo systemctl is-active rsync-backup.timer

# View recent backup logs
sudo journalctl -t rsync-backup-tool --since "1 day ago"

# Monitor logs in real-time
sudo tail -f /opt/rsync-backup-tool/logs/backup.log
```

## Logging

### Log Locations

- **Main log file**: `/opt/rsync-backup-tool/logs/backup.log`
- **System logs**: Available via `journalctl -t rsync-backup-tool`
- **Service logs**: `journalctl -u rsync-backup.service`

### Log Levels

- **INFO**: General information about backup progress
- **WARN**: Warnings that don't stop the backup
- **ERROR**: Errors that cause backup failures
- **DEBUG**: Detailed debugging information (with -v flag)

### Checking Logs

```bash
# View recent backup logs
sudo tail -f /opt/rsync-backup-tool/logs/backup.log

# Check systemd service logs
sudo journalctl -u rsync-backup.service --since "1 day ago"

# View all rsync-backup-tool logs
sudo journalctl -t rsync-backup-tool

# Follow logs in real-time
sudo journalctl -t rsync-backup-tool -f
```

### Log Rotation

Configure logrotate to manage log files:

```bash
sudo tee /etc/logrotate.d/rsync-backup-tool << EOF
/opt/rsync-backup-tool/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 backup backup
}
EOF
```

## Security Tips

### File Permissions

- Backup script runs as dedicated `backup` user (not root)
- Configuration files are readable by backup user only
- Log files have restricted permissions
- Backup destinations should have appropriate ownership

### SSH Key Setup for Remote Backups

```bash
# Generate SSH key for backup user
sudo -u backup ssh-keygen -t ed25519 -f /home/backup/.ssh/id_ed25519

# Copy public key to remote server
sudo -u backup ssh-copy-id backupuser@backup.example.com

# Test SSH connection
sudo -u backup ssh backupuser@backup.example.com
```

### Backup Security

- Use SSH keys instead of passwords for remote backups
- Restrict SSH access on backup servers
- Encrypt sensitive backup destinations
- Regularly test backup integrity
- Store backups in multiple locations

### Configuration Security

```bash
# Secure configuration file
sudo chmod 600 /opt/rsync-backup-tool/config/backup.conf
sudo chown backup:backup /opt/rsync-backup-tool/config/backup.conf

# Secure log directory
sudo chmod 750 /opt/rsync-backup-tool/logs
sudo chown backup:backup /opt/rsync-backup-tool/logs
```

## Example Output

### Successful Backup Run

```
[2024-01-15 02:00:01] [INFO] Starting rsync-backup-tool v1.0.0
[2024-01-15 02:00:01] [INFO] Found 2 backup job(s) to execute: home-backup documents-remote
[2024-01-15 02:00:01] [INFO] Starting backup job: home-backup
[2024-01-15 02:00:01] [INFO] Local backup to: /backup/home/
[2024-01-15 02:00:01] [INFO] Executing: rsync -avz --progress --stats --delete --backup --backup-dir=deleted-files --exclude-from=/home/user/.backup_exclude /home/user/ /backup/home/

sending incremental file list
./
.bashrc
Documents/
Documents/report.pdf
Pictures/
Pictures/vacation.jpg

Number of files: 1,234
Number of files transferred: 5
Total file size: 2.5G
Total transferred file size: 15.2M

[2024-01-15 02:02:15] [INFO] Backup job 'home-backup' completed successfully in 134s
[2024-01-15 02:02:17] [INFO] Starting backup job: documents-remote
[2024-01-15 02:02:17] [INFO] Remote backup to: backupuser@backup.example.com:/backup/documents/
[2024-01-15 02:02:17] [INFO] Executing: rsync -avz --progress --stats --delete /home/user/Documents/ backupuser@backup.example.com:/backup/documents/

sending incremental file list
./
project1/
project1/readme.txt
project2/
project2/data.xlsx

Number of files: 456
Number of files transferred: 2
Total file size: 890M
Total transferred file size: 5.1M

[2024-01-15 02:03:45] [INFO] Backup job 'documents-remote' completed successfully in 88s
[2024-01-15 02:03:45] [INFO] Backup execution completed: 2 successful, 0 failed
[2024-01-15 02:03:45] [INFO] All backup jobs completed successfully
```

### Dry Run Output

```
[2024-01-15 10:30:01] [INFO] Starting rsync-backup-tool v1.0.0
[2024-01-15 10:30:01] [INFO] Starting backup job: home-backup
[2024-01-15 10:30:01] [INFO] DRY RUN MODE: No files will be modified
[2024-01-15 10:30:01] [INFO] Local backup to: /backup/home/
[2024-01-15 10:30:01] [INFO] Executing: rsync -avz --progress --stats --dry-run --delete /home/user/ /backup/home/

(DRY RUN) sending incremental file list
(DRY RUN) ./
(DRY RUN) .bashrc
(DRY RUN) Documents/new-file.txt
(DRY RUN) Downloads/software.deb

Number of files: 1,234 (reg: 1,100, dir: 134)
Number of files transferred: 3
Total file size: 2.5G
Total transferred file size: 2.1M

[2024-01-15 10:30:05] [INFO] Backup job 'home-backup' completed successfully in 4s
```

## Author and License

**Author**: Your Name  
**Email**: your.email@example.com  
**GitHub**: https://github.com/yourusername/rsync-backup-tool

### License

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

---

**Contributing**: Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

**Support**: For support, please open an issue on GitHub or contact the author directly.