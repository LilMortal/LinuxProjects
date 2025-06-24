# ImmutableOS Explorer

A comprehensive command-line tool for discovering, comparing, and trying immutable operating systems like Fedora Silverblue, openSUSE MicroOS, and others.

## Overview

ImmutableOS Explorer is a Bash-based utility that helps Linux enthusiasts and system administrators explore the world of immutable operating systems. It provides detailed information about various immutable OS distributions, helps download ISO files, creates bootable USB drives, and offers installation guidance. The tool is designed to make the transition to immutable systems easier by providing centralized access to resources and automation capabilities.

## Features

- **OS Discovery**: Browse and compare 10+ immutable operating systems
- **ISO Management**: Download, verify, and manage ISO files with progress tracking
- **USB Creation**: Create bootable USB drives with multiple tools (dd, Ventoy support)
- **System Information**: Get detailed specs about hardware compatibility
- **Installation Guides**: Step-by-step installation instructions for each OS
- **Comparison Matrix**: Side-by-side feature comparison of different immutable OSes
- **Update Notifications**: Automatic checking for new OS releases
- **Logging**: Comprehensive logging with rotation and syslog integration
- **Configuration**: Flexible JSON-based configuration system

## Requirements

- **Operating System**: Ubuntu 22.04+, Debian 11+, Fedora 35+, or any modern Linux distribution
- **Dependencies**: 
  - `curl` (for downloads)
  - `jq` (for JSON processing)
  - `zenity` (optional, for GUI dialogs)
  - `pv` (for progress visualization)
  - `lsblk`, `fdisk` (for USB operations)
  - `sha256sum` (for ISO verification)
- **Permissions**: Root access required for USB creation operations
- **Storage**: Minimum 10GB free space for ISO downloads

## Installation

### Quick Install (Recommended)
```bash
# Clone the repository
git clone https://github.com/username/immutable-os-explorer.git
cd immutable-os-explorer

# Make the installer executable
chmod +x install.sh

# Run the installer (requires sudo for system integration)
sudo ./install.sh
```

### Manual Install
```bash
# Clone the repository
git clone https://github.com/username/immutable-os-explorer.git
cd immutable-os-explorer

# Copy main script to system path
sudo cp src/immutable-os-explorer.sh /usr/local/bin/immutable-os-explorer
sudo chmod +x /usr/local/bin/immutable-os-explorer

# Copy configuration file
sudo mkdir -p /etc/immutable-os-explorer
sudo cp config/config.json /etc/immutable-os-explorer/

# Create log directory
sudo mkdir -p /var/log/immutable-os-explorer
sudo chown $USER:$USER /var/log/immutable-os-explorer

# Install systemd service (optional)
sudo cp systemd/immutable-os-explorer.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## Configuration

The tool uses a JSON configuration file located at `/etc/immutable-os-explorer/config.json`:

```json
{
  "download_dir": "/home/$USER/Downloads/ImmutableOS",
  "log_level": "INFO",
  "auto_verify_checksums": true,
  "max_concurrent_downloads": 3,
  "update_check_interval": "weekly",
  "preferred_mirror": "auto",
  "usb_creation_tool": "dd"
}
```

### Environment Variables
- `IMMUTABLE_OS_CONFIG`: Override default config file path
- `IMMUTABLE_OS_LOG_LEVEL`: Set logging level (DEBUG, INFO, WARN, ERROR)
- `IMMUTABLE_OS_DOWNLOAD_DIR`: Override download directory

## Usage

### Basic Commands

```bash
# List all available immutable operating systems
immutable-os-explorer list

# Get detailed information about a specific OS
immutable-os-explorer info fedora-silverblue

# Download an ISO file
immutable-os-explorer download fedora-silverblue

# Compare multiple operating systems
immutable-os-explorer compare fedora-silverblue opensuse-microos

# Create a bootable USB drive
sudo immutable-os-explorer create-usb fedora-silverblue /dev/sdb

# Check system compatibility
immutable-os-explorer check-compatibility
```

### Advanced Usage

```bash
# Download with specific version
immutable-os-explorer download fedora-silverblue --version 39

# Create USB with Ventoy
sudo immutable-os-explorer create-usb --method ventoy /dev/sdb

# Generate comparison report
immutable-os-explorer compare --output report.html fedora-silverblue opensuse-microos nixos

# Check for updates with notification
immutable-os-explorer update-check --notify

# Interactive mode
immutable-os-explorer interactive
```

### CLI Options

```bash
Options:
  -h, --help           Show this help message
  -v, --verbose        Enable verbose output
  -q, --quiet          Suppress non-essential output
  -c, --config FILE    Use custom configuration file
  -l, --log-level LVL  Set logging level (DEBUG|INFO|WARN|ERROR)
  -d, --download-dir   Override download directory
  -n, --dry-run        Show what would be done without executing
  --no-color           Disable colored output
  --version            Show version information
```

## Automation

### Systemd Service (Automatic Updates)

Enable the systemd service to automatically check for OS updates:

```bash
# Enable and start the service
sudo systemctl enable immutable-os-explorer.service
sudo systemctl start immutable-os-explorer.service

# Check service status
sudo systemctl status immutable-os-explorer.service

# View service logs
sudo journalctl -u immutable-os-explorer.service -f
```

### Cron Job (Alternative)

Add to your crontab for weekly update checks:

```bash
# Edit crontab
crontab -e

# Add this line for weekly checks on Sundays at 2 AM
0 2 * * 0 /usr/local/bin/immutable-os-explorer update-check --quiet
```

### Automated ISO Downloads

Set up automated ISO downloads for specific distributions:

```bash
# Create a script for automated downloads
cat > ~/auto-download-isos.sh << 'EOF'
#!/bin/bash
immutable-os-explorer download fedora-silverblue --latest --quiet
immutable-os-explorer download opensuse-microos --latest --quiet
EOF

chmod +x ~/auto-download-isos.sh

# Add to cron for monthly downloads
0 3 1 * * ~/auto-download-isos.sh
```

## Logging

### Log Locations
- **Main Log**: `/var/log/immutable-os-explorer/main.log`
- **Download Log**: `/var/log/immutable-os-explorer/downloads.log`
- **Error Log**: `/var/log/immutable-os-explorer/errors.log`
- **System Log**: `journalctl -u immutable-os-explorer.service`

### Checking Logs

```bash
# View recent activity
tail -f /var/log/immutable-os-explorer/main.log

# Search for errors
grep "ERROR" /var/log/immutable-os-explorer/main.log

# Check download progress
tail -f /var/log/immutable-os-explorer/downloads.log

# View systemd service logs
sudo journalctl -u immutable-os-explorer.service --since "1 hour ago"
```

### Log Rotation

Logs are automatically rotated using `logrotate`. Configuration is in `/etc/logrotate.d/immutable-os-explorer`.

## Security Tips

1. **USB Operations**: Always double-check the target device before creating bootable USBs to avoid data loss
   ```bash
   lsblk  # List all block devices before proceeding
   ```

2. **ISO Verification**: The tool automatically verifies checksums, but you can manually verify:
   ```bash
   immutable-os-explorer verify-iso /path/to/downloaded.iso
   ```

3. **Root Privileges**: Only USB creation requires root access. Other operations run as regular user.

4. **Download Sources**: All ISOs are downloaded from official distribution mirrors with HTTPS verification.

5. **File Permissions**: Downloaded files are set with appropriate permissions (644) and ownership.

## Example Output

### Listing Available OSes
```
$ immutable-os-explorer list

Available Immutable Operating Systems:
┌─────────────────────┬─────────────┬──────────────┬─────────────┐
│ Name                │ Version     │ Base         │ Status      │
├─────────────────────┼─────────────┼──────────────┼─────────────┤
│ Fedora Silverblue   │ 39          │ Fedora       │ Stable      │
│ openSUSE MicroOS    │ Tumbleweed  │ openSUSE     │ Rolling     │
│ NixOS               │ 23.05       │ NixOS        │ Stable      │
│ Endless OS          │ 5.0         │ Debian       │ Stable      │
│ Clear Linux         │ 39140       │ Intel        │ Rolling     │
│ Ubuntu Core         │ 22          │ Ubuntu       │ LTS         │
│ Fedora CoreOS       │ 38.20230918 │ Fedora       │ Stable      │
└─────────────────────┴─────────────┴──────────────┴─────────────┘

Use 'immutable-os-explorer info <name>' for detailed information.
```

### OS Information
```
$ immutable-os-explorer info fedora-silverblue

Fedora Silverblue 39
════════════════════════════════════════════════════

Description: A variant of Fedora Workstation that uses rpm-ostree 
            technology to provide an immutable desktop experience.

Key Features:
• Atomic updates and rollbacks
• Container-focused development
• GNOME desktop environment
• Flatpak for applications
• Toolbox for development environments

System Requirements:
• RAM: 4GB minimum, 8GB recommended
• Storage: 20GB minimum, 64GB recommended
• Processor: x86_64 with UEFI support

Download Size: 1.8GB
Release Date: 2023-11-07
Support: Community supported until Fedora 41 release

Installation Guide: /usr/share/doc/immutable-os-explorer/guides/fedora-silverblue.md
```

## Author and License

**Author**: Your Name (your.email@example.com)  
**License**: MIT License

```
MIT License

Copyright (c) 2024 ImmutableOS Explorer Contributors

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

**Contributing**: Pull requests are welcome! Please read CONTRIBUTING.md for details.  
**Issues**: Report bugs and feature requests at: https://github.com/username/immutable-os-explorer/issues  
**Documentation**: Additional documentation available at: https://immutable-os-explorer.readthedocs.io