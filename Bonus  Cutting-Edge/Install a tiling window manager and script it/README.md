# TilingWM Manager

A comprehensive Linux system for installing, configuring, and managing the i3 tiling window manager with automation scripts and system integration.

## Overview

TilingWM Manager is a complete solution for setting up and managing the i3 tiling window manager on Linux systems. It provides automated installation, configuration management, workspace automation, and system integration through systemd services. The project includes utilities for window management, status bar configuration, and automated workspace switching based on time or system events.

## Features

- **Automated Installation**: One-command setup of i3wm with all dependencies
- **Smart Configuration**: Template-based config generation with user customization
- **Workspace Automation**: Time-based and event-triggered workspace switching
- **System Integration**: Systemd services for background automation
- **Window Management**: Scripts for advanced window manipulation and layout management
- **Status Bar**: Custom i3status configuration with system monitoring
- **Logging**: Comprehensive logging to syslog and custom log files
- **Backup & Restore**: Configuration backup and restoration utilities

## Requirements

- **OS**: Ubuntu 22.04+ or any systemd-based Linux distribution
- **Dependencies**: bash, systemd, cron, curl, git
- **Permissions**: sudo access for installation
- **Display**: X11 display server (Wayland support planned)
- **Memory**: Minimum 1GB RAM recommended
- **Storage**: ~500MB for full installation with dependencies

## Installation

### Quick Install
```bash
# Clone the repository
git clone https://github.com/yourusername/tilingwm-manager.git
cd tilingwm-manager

# Make scripts executable
chmod +x scripts/*.sh

# Run the installer
sudo ./scripts/install.sh
```

### Manual Install
```bash
# Install dependencies first
sudo apt update
sudo apt install -y i3 dmenu i3status i3lock feh compton

# Then run our configuration script
./scripts/configure.sh --user-config
```

## Configuration

### Environment Variables
```bash
# Optional: Set in ~/.bashrc or /etc/environment
export TILINGWM_CONFIG_DIR="$HOME/.config/tilingwm"
export TILINGWM_LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
export TILINGWM_WORKSPACE_TIMEOUT="300"  # seconds
export TILINGWM_BACKUP_DIR="$HOME/.local/share/tilingwm/backups"
```

### Configuration Files
- `~/.config/tilingwm/config.yaml` - Main configuration
- `~/.config/tilingwm/workspaces.conf` - Workspace automation rules
- `~/.config/tilingwm/keybindings.conf` - Custom keybinding definitions
- `/etc/tilingwm/system.conf` - System-wide settings (optional)

## Usage

### Basic Commands
```bash
# Install and configure i3wm
sudo tilingwm install

# Start workspace automation
tilingwm start-automation

# Switch to workspace by name
tilingwm workspace --name "Development"

# Apply new configuration
tilingwm configure --reload

# Backup current configuration
tilingwm backup --name "pre-update-$(date +%Y%m%d)"

# Restore from backup
tilingwm restore --backup "pre-update-20241201"

# Show status
tilingwm status

# Get help for any command
tilingwm help [command]
```

### Window Management
```bash
# Focus management
tilingwm focus --direction left
tilingwm focus --window "firefox"

# Layout management
tilingwm layout --set tabbed
tilingwm layout --toggle split

# Multi-monitor setup
tilingwm monitor --setup dual
tilingwm monitor --workspace 1 --output HDMI-1
```

### Workspace Automation
```bash
# Enable time-based workspace switching
tilingwm automation --enable time-based

# Set workspace schedule
tilingwm schedule --workspace "Work" --time "09:00-17:00"
tilingwm schedule --workspace "Personal" --time "17:00-09:00"

# Event-based switching
tilingwm automation --on-idle --workspace "Screensaver"
tilingwm automation --on-battery --workspace "Power-Save"
```

## Automation

### Systemd Service
```bash
# Enable the automation service
sudo systemctl enable tilingwm-automation.service
sudo systemctl start tilingwm-automation.service

# Check service status
systemctl status tilingwm-automation.service

# View service logs
journalctl -u tilingwm-automation.service -f
```

### Cron Jobs
```bash
# Add to user crontab for workspace cleanup
crontab -e

# Example entries:
# Backup config daily at 2 AM
0 2 * * * /usr/local/bin/tilingwm backup --auto

# Reset workspaces every hour
0 * * * * /usr/local/bin/tilingwm workspace --reset-empty

# Update status bar every 30 seconds
*/30 * * * * /usr/local/bin/tilingwm status --update
```

## Logging

### Log Locations
```bash
# System logs (via systemd)
journalctl -u tilingwm-automation.service

# Application logs
tail -f ~/.local/share/tilingwm/logs/tilingwm.log
tail -f ~/.local/share/tilingwm/logs/automation.log

# Error logs
tail -f ~/.local/share/tilingwm/logs/errors.log

# Syslog entries
grep "tilingwm" /var/log/syslog
```

### Log Levels
- **DEBUG**: Detailed execution information
- **INFO**: General operational messages
- **WARN**: Warning conditions that don't stop operation
- **ERROR**: Error conditions that may affect functionality

## Security Tips

### File Permissions
```bash
# Secure configuration directory
chmod 700 ~/.config/tilingwm
chmod 600 ~/.config/tilingwm/*.conf

# Secure log directory
chmod 750 ~/.local/share/tilingwm/logs
```

### Service Security
```bash
# Run automation service as user (not root)
systemctl --user enable tilingwm-automation.service

# Limit service permissions in systemd unit file
# See: configs/tilingwm-automation.service
```

### X11 Security
```bash
# Secure X11 access (if needed)
xhost -
xauth list

# Use SSH X11 forwarding securely
ssh -X -c aes256-ctr user@host
```

## Example Output

### Installation Output
```
[INFO] TilingWM Manager Installation Starting...
[INFO] Detecting system: Ubuntu 22.04.3 LTS
[INFO] Installing i3 window manager...
[INFO] Installing dependencies: dmenu, i3status, i3lock...
[INFO] Configuring i3 with default settings...
[INFO] Setting up systemd automation service...
[INFO] Creating backup directory: /home/user/.local/share/tilingwm/backups
[INFO] Installation completed successfully!
[INFO] Run 'tilingwm status' to verify installation
```

### Status Output
```
TilingWM Manager Status:
========================
WM Status: i3 running (PID: 1234)
Config: ~/.config/tilingwm/config.yaml (loaded)
Automation: enabled (systemd service active)
Workspaces: 4 active, 2 empty
Current Workspace: 2 (Development)
Last Backup: 2024-12-01 14:30:22
Log Level: INFO
```

### Workspace Automation Output
```
[2024-12-01 09:00:01] Switching to workspace 'Work' (time-based rule)
[2024-12-01 12:30:15] Opening terminal in workspace 'Work'
[2024-12-01 17:00:01] Switching to workspace 'Personal' (time-based rule)
[2024-12-01 17:30:45] Idle detected, switching to workspace 'Background'
```

## Author and License

**Author**: Your Name <your.email@example.com>
**Project**: TilingWM Manager
**License**: MIT License

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

**Repository**: https://github.com/yourusername/tilingwm-manager
**Issues**: https://github.com/yourusername/tilingwm-manager/issues
**Documentation**: https://github.com/yourusername/tilingwm-manager/wiki