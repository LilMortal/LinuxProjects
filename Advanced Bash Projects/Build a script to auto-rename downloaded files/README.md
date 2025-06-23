# File Auto-Renamer

A powerful Linux-based Python script that automatically renames downloaded files based on configurable rules. Perfect for organizing your Downloads folder and maintaining consistent file naming conventions.

## Overview

File Auto-Renamer monitors your Downloads directory (or any specified directory) and automatically renames files according to your preferences. It supports timestamp-based naming, sequential numbering, filename cleaning, and handles duplicate files intelligently. Whether you download hundreds of files daily or just want better organization, this tool helps maintain a clean and structured file system.

## Features

- **Real-time monitoring**: Watches directories for new files and renames them instantly
- **Multiple naming patterns**: Timestamp, sequential numbering, or clean-only modes
- **Configurable rules**: Customize prefixes, suffixes, and naming formats
- **File type filtering**: Process only specific file extensions or ignore certain types
- **Duplicate handling**: Automatically handles filename conflicts with smart numbering
- **Clean filename**: Removes problematic characters and standardizes naming
- **Comprehensive logging**: File and console logging with configurable levels
- **System integration**: Includes systemd service and cron job configurations
- **Batch processing**: Can process existing files or monitor continuously
- **Security-focused**: Runs with minimal privileges and safe file operations

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04+ (or any modern Linux distribution)
- **Python**: Python 3.8 or higher
- **Permissions**: Read/write access to target directories

### Dependencies
- `watchdog` - Python library for file system monitoring
- Standard Python libraries (os, sys, time, re, shutil, logging, configparser, datetime, pathlib, argparse)

### Installation Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip

# CentOS/RHEL/Fedora
sudo dnf install python3 python3-pip
# or
sudo yum install python3 python3-pip
```

## Installation

### Quick Installation (Recommended)

1. **Clone or download the project**:
```bash
git clone <repository-url> file-auto-renamer
cd file-auto-renamer
```

2. **Run the installation script**:
```bash
# For system-wide installation (requires sudo)
sudo ./install.sh

# For user-only installation
./install.sh
```

### Manual Installation

1. **Create installation directory**:
```bash
sudo mkdir -p /opt/file-auto-renamer
sudo cp -r * /opt/file-auto-renamer/
sudo chmod +x /opt/file-auto-renamer/src/file_renamer.py
```

2. **Install Python dependencies**:
```bash
pip3 install -r requirements.txt
```

3. **Create symlink for easy access**:
```bash
sudo ln -s /opt/file-auto-renamer/src/file_renamer.py /usr/local/bin/file-renamer
```

## Configuration

The configuration file is located at `config/renamer.conf`. Edit this file to customize the behavior:

### Key Configuration Options

```ini
[DEFAULT]
# Directory to monitor
watch_directory = ~/Downloads

# Naming pattern: timestamp, sequential, clean_only
naming_pattern = timestamp

# Timestamp format (Python strftime)
timestamp_format = %Y%m%d_%H%M%S

# File extensions to process (empty = all files)
allowed_extensions = pdf,doc,docx,txt,jpg,jpeg,png,gif,zip

# File extensions to ignore
ignored_extensions = tmp,part,crdownload

# Clean filenames (remove special characters)
clean_names = true

# Handle duplicate files
handle_duplicates = true

# Logging configuration
log_file = logs/file_renamer.log
log_level = INFO
```

### Environment Variables
You can override config settings with environment variables:
```bash
export RENAMER_WATCH_DIR="/home/user/Downloads"
export RENAMER_LOG_LEVEL="DEBUG"
```

## Usage

### Command Line Interface

```bash
# Start monitoring (runs continuously)
file-renamer

# Process existing files once and exit
file-renamer --existing

# Use custom configuration file
file-renamer --config /path/to/custom.conf

# Run in daemon mode explicitly
file-renamer --daemon

# Show help
file-renamer --help

# Show version
file-renamer --version
```

### Examples

**Basic usage** - Monitor Downloads folder:
```bash
file-renamer
```

**Process existing files** without monitoring:
```bash
file-renamer --existing
```

**Custom configuration** for different directory:
```bash
# Create custom config
cp config/renamer.conf ~/my-renamer.conf
# Edit ~/my-renamer.conf to change watch_directory
file-renamer --config ~/my-renamer.conf
```

**Test run** with debug logging:
```bash
# Edit config to set log_level = DEBUG
file-renamer
# Check logs/file_renamer.log for detailed output
```

## Automation

### Systemd Service (Recommended)

For continuous monitoring, use the systemd service:

```bash
# Enable and start service for current user
sudo systemctl enable file-renamer@$(whoami)
sudo systemctl start file-renamer@$(whoami)

# Check service status
sudo systemctl status file-renamer@$(whoami)

# View service logs
sudo journalctl -u file-renamer@$(whoami) -f

# Stop service
sudo systemctl stop file-renamer@$(whoami)

# Disable service
sudo systemctl disable file-renamer@$(whoami)
```

### Cron Jobs

For periodic processing instead of continuous monitoring:

```bash
# Edit crontab
crontab -e

# Add one of these lines:

# Process existing files every hour
0 * * * * /usr/local/bin/file-renamer --existing

# Process existing files every 30 minutes
*/30 * * * * /usr/local/bin/file-renamer --existing

# Check if daemon is running every 5 minutes, start if not
*/5 * * * * pgrep -f "file_renamer.py" > /dev/null || /usr/local/bin/file-renamer --daemon >> /tmp/file-renamer.log 2>&1
```

## Logging

### Log Locations
- **Default log file**: `logs/file_renamer.log`
- **System journal**: Use `journalctl` for systemd service logs
- **Cron logs**: Check `/var/log/cron` or `/var/log/syslog`

### Checking Logs

```bash
# View recent log entries
tail -f logs/file_renamer.log

# View systemd service logs
sudo journalctl -u file-renamer@$(whoami) -f

# View last 50 log lines
tail -n 50 logs/file_renamer.log

# Search for errors
grep ERROR logs/file_renamer.log

# View logs with timestamps
cat logs/file_renamer.log | grep "$(date '+%Y-%m-%d')"
```

### Log Levels
- **DEBUG**: Detailed information for troubleshooting
- **INFO**: General operational messages
- **WARNING**: Important notices but not errors
- **ERROR**: Error conditions that don't stop the program
- **CRITICAL**: Serious errors that might stop the program

## Security Tips

### File Permissions
```bash
# Secure the installation directory
sudo chown -R root:root /opt/file-auto-renamer
sudo chmod -R 755 /opt/file-auto-renamer
sudo chmod 644 /opt/file-auto-renamer/config/renamer.conf

# Secure log directory (allow writing)
sudo chmod 755 /opt/file-auto-renamer/logs
```

### Running as Non-Root User
The script is designed to run as a regular user. The systemd service includes security restrictions:
- `PrivateTmp=true` - Isolated tmp directory
- `ProtectSystem=strict` - Read-only system directories
- `NoNewPrivileges=true` - Cannot gain new privileges

### Directory Access
- Ensure the user running the script has read/write access to the watch directory
- Limit access to configuration files containing sensitive paths
- Consider using a dedicated user for the service:

```bash
# Create dedicated user
sudo useradd -r -s /bin/false file-renamer
sudo systemctl enable file-renamer@file-renamer
```

## Example Output

### Successful Rename Operation
```
2024-01-15 14:30:25 - FileRenamer - INFO - Starting to monitor: /home/user/Downloads
2024-01-15 14:30:45 - FileRenamer - INFO - New file detected: /home/user/Downloads/document.pdf
2024-01-15 14:30:46 - FileRenamer - INFO - Renamed: document.pdf -> 20240115_143046_document.pdf
2024-01-15 14:31:12 - FileRenamer - INFO - New file detected: /home/user/Downloads/IMG_001.jpg
2024-01-15 14:31:13 - FileRenamer - INFO - Renamed: IMG_001.jpg -> 20240115_143113_IMG_001.jpg
```

### Duplicate Handling
```
2024-01-15 14:32:00 - FileRenamer - INFO - New file detected: /home/user/Downloads/document.pdf
2024-01-15 14:32:01 - FileRenamer - INFO - Renamed: document.pdf -> 20240115_143201_document_001.pdf
```

### File Type Filtering
```
2024-01-15 14:33:15 - FileRenamer - DEBUG - Skipping file with ignored extension: /home/user/Downloads/download.tmp
2024-01-15 14:33:20 - FileRenamer - DEBUG - Skipping file with unallowed extension: /home/user/Downloads/video.mkv
```

### Service Status
```bash
$ sudo systemctl status file-renamer@user
● file-renamer@user.service - File Auto-Renamer Service
     Loaded: loaded (/etc/systemd/system/file-renamer.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2024-01-15 14:30:00 UTC; 1h 5min ago
   Main PID: 12345 (python3)
     Status: "Monitoring /home/user/Downloads"
      Tasks: 3 (limit: 4915)
     Memory: 15.2M
        CPU: 2.3s
     CGroup: /system.slice/system-file\x2drenamer.slice/file-renamer@user.service
             └─12345 /usr/bin/python3 /opt/file-auto-renamer/src/file_renamer.py --daemon
```

## Author and License

**Author**: File Auto-Renamer Project  
**License**: MIT License

```
MIT License

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
Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest new features.

### Support
For issues and questions:
1. Check the logs for error messages
2. Verify configuration settings
3. Test with `--existing` flag first
4. Enable DEBUG logging for troubleshooting