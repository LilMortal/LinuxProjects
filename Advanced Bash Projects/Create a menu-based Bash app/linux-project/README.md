# System Admin Menu

A comprehensive menu-based system administration tool for Linux systems. This interactive Bash application provides a user-friendly interface for common system administration tasks including service management, log viewing, system monitoring, and more.

## Overview

System Admin Menu is designed to simplify system administration tasks by providing an intuitive menu-driven interface. It eliminates the need to remember complex command-line syntax and provides quick access to frequently used system administration functions. The application features comprehensive logging, configuration management, and error handling to ensure reliable operation in production environments.

## Features

- **Interactive Menu System**: Easy-to-navigate menu interface with numbered options
- **System Information Display**: Real-time system stats, uptime, memory usage, and disk space
- **Service Management**: Start, stop, restart, enable, and disable system services
- **Log Viewer**: View system logs, authentication logs, and application logs
- **Network Information**: Display network interfaces, routing tables, and active connections
- **User Management**: Show current user information and login history
- **Disk Usage Analysis**: Monitor disk space and identify large files/directories
- **System Updates**: Safe system package updates with confirmation prompts
- **Configuration Management**: Customizable settings via configuration file
- **Comprehensive Logging**: Detailed logging with configurable levels
- **Error Handling**: Robust error handling and user-friendly error messages
- **CLI Arguments**: Support for command-line options and batch operations
- **Systemd Integration**: Optional systemd service for automated operations

## Requirements

### System Requirements
- **Operating System**: Ubuntu 22.04+ or any modern Linux distribution
- **Shell**: Bash 4.0 or higher
- **Privileges**: Root or sudo access for system operations
- **Dependencies**: Standard Linux utilities (included in most distributions)

### Required Commands
The following commands must be available on your system:
- `bash`, `awk`, `grep`, `sed`, `cut`, `tail`, `head`, `sort`
- `systemctl` (systemd)
- `ip`, `ss` (networking)
- `df`, `du`, `free` (system information)
- `apt` (package management on Debian/Ubuntu systems)

## Installation

### Automatic Installation (Recommended)

1. **Clone or download the project**:
   ```bash
   git clone <repository-url>
   cd sysadmin-menu
   ```

2. **Run the installation script**:
   ```bash
   sudo ./install.sh
   ```

3. **Verify installation**:
   ```bash
   sysadmin-menu --version
   ```

### Manual Installation

1. **Create installation directory**:
   ```bash
   sudo mkdir -p /opt/sysadmin-menu/{bin,config,logs,systemd}
   ```

2. **Copy files**:
   ```bash
   sudo cp bin/sysadmin-menu /opt/sysadmin-menu/bin/
   sudo cp config/sysadmin-menu.conf /opt/sysadmin-menu/config/
   sudo cp systemd/sysadmin-menu.service /opt/sysadmin-menu/systemd/
   ```

3. **Set permissions**:
   ```bash
   sudo chmod +x /opt/sysadmin-menu/bin/sysadmin-menu
   sudo chown -R root:root /opt/sysadmin-menu
   ```

4. **Create symbolic link**:
   ```bash
   sudo ln -s /opt/sysadmin-menu/bin/sysadmin-menu /usr/local/bin/sysadmin-menu
   ```

## Configuration

### Configuration File

The main configuration file is located at `/opt/sysadmin-menu/config/sysadmin-menu.conf`. You can customize the following options:

```bash
# Logging Configuration
ENABLE_LOGGING="true"           # Enable/disable logging
LOG_LEVEL="INFO"               # Log level (DEBUG, INFO, WARNING, ERROR)

# Display Configuration
AUTO_REFRESH="false"           # Auto-refresh for certain views
REFRESH_INTERVAL="5"           # Refresh interval in seconds
```

### Environment Variables

You can also set configuration options via environment variables:
```bash
export ENABLE_LOGGING="true"
export LOG_LEVEL="DEBUG"
```

### Custom Configuration File

Use a custom configuration file:
```bash
sysadmin-menu --config /path/to/custom/config.conf
```

## Usage

### Basic Usage

Start the application:
```bash
sysadmin-menu
```

### Command Line Options

```bash
# Show help
sysadmin-menu --help

# Show version
sysadmin-menu --version

# Use custom configuration file
sysadmin-menu --config /path/to/config.conf

# Use custom log file
sysadmin-menu --log /path/to/logfile.log

# Run without logging
sysadmin-menu --quiet

# Enable debug mode
sysadmin-menu --debug
```

### Menu Navigation

The application presents a numbered menu system:

```
╔══════════════════════════════════════╗
║        SYSTEM ADMIN MENU v1.0.0      ║
╚══════════════════════════════════════╝

1.  System Information
2.  Service Management
3.  Log Viewer
4.  Disk Usage
5.  Network Information
6.  User Information
7.  Update System
8.  Reboot System
9.  View Application Logs
10. Configuration
0.  Exit
```

### Example Operations

**View system information**:
- Select option `1` from the main menu
- Displays hostname, OS, kernel, uptime, memory, CPU, and disk usage

**Manage services**:
- Select option `2` from the main menu
- Choose from start, stop, restart, enable, or disable services
- Example: Start Apache2 service

**View logs**:
- Select option `3` from the main menu
- Choose from system logs, authentication logs, or application logs
- Option to follow logs in real-time

## Automation

### Systemd Service

Install as a systemd service for automated operations:

```bash
# Install the service
sudo cp systemd/sysadmin-menu.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start the service
sudo systemctl enable sysadmin-menu
sudo systemctl start sysadmin-menu

# Check service status
sudo systemctl status sysadmin-menu
```

### Cron Job

Run specific operations via cron:

```bash
# Edit crontab
sudo crontab -e

# Add cron job (runs system check every hour)
0 * * * * /opt/sysadmin-menu/bin/sysadmin-menu --quiet 2>&1 | logger -t sysadmin-menu

# Weekly system update check (Sundays at 2 AM)
0 2 * * 0 /opt/sysadmin-menu/bin/sysadmin-menu --quiet --update-check
```

## Logging

### Log Locations

- **Application logs**: `/opt/sysadmin-menu/logs/sysadmin-menu.log`
- **System logs**: `/var/log/syslog` (via systemd)
- **Authentication logs**: `/var/log/auth.log`

### Log Levels

- **DEBUG**: Detailed debugging information
- **INFO**: General information messages
- **WARNING**: Warning messages
- **ERROR**: Error messages

### Viewing Logs

```bash
# View application logs
tail -f /opt/sysadmin-menu/logs/sysadmin-menu.log

# View systemd service logs
journalctl -u sysadmin-menu -f

# View last 100 log entries
journalctl -u sysadmin-menu -n 100
```

## Security Tips

### File Permissions

- Ensure the main script has execute permissions: `chmod +x /opt/sysadmin-menu/bin/sysadmin-menu`
- Restrict config file access: `chmod 600 /opt/sysadmin-menu/config/sysadmin-menu.conf`
- Secure log directory: `chmod 755 /opt/sysadmin-menu/logs`

### Root Access

- The application requires root privileges for system operations
- Use `sudo` instead of running as root user when possible
- Review all system-modifying operations before execution

### Network Security

- Monitor network connections regularly using the Network Information feature
- Review authentication logs for suspicious login attempts
- Keep the system updated using the built-in update functionality

### Service Management

- Only start/stop services you understand
- Review service status regularly
- Disable unnecessary services to reduce attack surface

## Example Output

### System Information Display
```
=== SYSTEM INFORMATION ===

Hostname: webserver01
Operating System: Ubuntu 22.04.3 LTS
Kernel: 5.15.0-76-generic
Architecture: x86_64
Uptime: up 2 days, 14 hours, 32 minutes
Load Average:  0.15, 0.20, 0.18

Memory Usage:
              total        used        free      shared  buff/cache   available
Mem:           7.8G        2.1G        3.2G         24M        2.5G        5.4G
Swap:          2.0G          0B        2.0G

CPU Information:
 Intel(R) Core(TM) i7-8700K CPU @ 3.70GHz
CPU Cores: 8

Disk Usage (Top 5):
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        98G   45G   48G  49% /
/dev/sda2       197G   12G  175G   7% /home
/dev/sda3       493G  367G  101G  79% /var
```

### Service Status Display
```
=== SERVICE STATUS ===

✓ ssh: active
✓ apache2: active
✗ nginx: inactive
✓ mysql: active
- postgresql: not installed/enabled
✓ docker: active
✓ fail2ban: active
```

### Log Viewer Output
```
=== LOG: /var/log/syslog ===

Jul 15 10:30:15 webserver01 systemd[1]: Started Daily apt download activities.
Jul 15 10:30:15 webserver01 systemd[1]: Starting Clean php session files...
Jul 15 10:30:16 webserver01 systemd[1]: phpsessionclean.service: Succeeded.
Jul 15 10:30:16 webserver01 systemd[1]: Finished Clean php session files.
Jul 15 10:35:01 webserver01 CRON[12345]: (root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)
```

## Author and License

### Author
**System Administrator**  
Created for efficient Linux system administration

### License
This project is licensed under the MIT License - see below for details:

```
MIT License

Copyright (c) 2024 System Admin Menu

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

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

### Support

For support, please check the logs first:
- Application logs: `/opt/sysadmin-menu/logs/sysadmin-menu.log`
- System logs: `journalctl -u sysadmin-menu`

For additional help, refer to the inline help: `sysadmin-menu --help`