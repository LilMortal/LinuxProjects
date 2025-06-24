# PodManager - Podman Management Utility

## Overview

PodManager is a comprehensive command-line utility that provides Docker-like functionality using Podman as the container runtime. This tool bridges the gap for users transitioning from Docker to Podman by offering familiar commands and enhanced container management capabilities with superior security and rootless operation.

## Features

- **Docker-compatible commands** - Familiar syntax for easy migration
- **Rootless container support** - Enhanced security without requiring root privileges
- **Container lifecycle management** - Build, run, stop, remove containers with ease
- **Image management** - Pull, build, tag, and manage container images
- **Volume and network management** - Complete container orchestration support
- **Health monitoring** - Built-in container health checks and reporting
- **Comprehensive logging** - Detailed operation logs with rotation
- **Batch operations** - Manage multiple containers simultaneously
- **Security scanning** - Basic vulnerability assessment for images
- **Resource monitoring** - Track CPU, memory, and disk usage

## Requirements

- **Operating System**: Ubuntu 22.04+ (or any modern Linux distribution)
- **Podman**: Version 3.4+ (automatically installed if missing)
- **Dependencies**: 
  - `curl` (for downloads)
  - `jq` (for JSON processing)
  - `rsync` (for file operations)
  - `systemd` (for service management)

## Installation

### Quick Install (Recommended)
```bash
# Clone the repository
git clone https://github.com/username/podmanager.git
cd podmanager

# Make the installer executable and run
chmod +x install.sh
sudo ./install.sh

# Verify installation
podmanager --version
```

### Manual Installation
```bash
# Install Podman if not present
sudo apt update
sudo apt install -y podman curl jq rsync

# Copy files to system locations
sudo cp bin/podmanager /usr/local/bin/
sudo cp config/podmanager.conf /etc/
sudo cp systemd/podmanager.service /etc/systemd/system/
sudo mkdir -p /var/log/podmanager

# Set permissions
sudo chmod +x /usr/local/bin/podmanager
sudo chmod 644 /etc/podmanager.conf
sudo chown $USER:$USER /var/log/podmanager
```

## Configuration

### Environment Variables
```bash
# Optional: Set custom configuration
export PODMANAGER_CONFIG="/path/to/custom/config"
export PODMANAGER_LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
export PODMANAGER_LOG_DIR="/custom/log/path"
```

### Configuration File (`/etc/podmanager.conf`)
```ini
# PodManager Configuration
LOG_LEVEL=INFO
LOG_DIR=/var/log/podmanager
LOG_MAX_SIZE=100M
LOG_ROTATE_COUNT=5
CONTAINER_STORAGE_PATH=/home/$USER/.local/share/containers
DEFAULT_REGISTRY=docker.io
HEALTH_CHECK_INTERVAL=30
SECURITY_SCAN_ENABLED=true
```

## Usage

### Basic Container Operations
```bash
# Pull an image
podmanager pull nginx:latest

# Run a container
podmanager run --name webserver -p 8080:80 -d nginx:latest

# List running containers
podmanager ps

# Stop a container
podmanager stop webserver

# Remove a container
podmanager rm webserver

# View container logs
podmanager logs webserver
```

### Advanced Operations
```bash
# Build an image from Dockerfile
podmanager build -t myapp:v1.0 .

# Health check on all containers
podmanager health-check --all

# Security scan an image
podmanager scan-security nginx:latest

# Batch stop all containers
podmanager stop-all

# Resource monitoring
podmanager stats

# Export container as archive
podmanager export webserver > webserver.tar
```

### Image Management
```bash
# List all images
podmanager images

# Remove unused images
podmanager image-prune

# Tag an image
podmanager tag myapp:v1.0 myapp:latest

# Push to registry
podmanager push myapp:latest
```

### Volume and Network Operations
```bash
# Create a volume
podmanager volume create data-vol

# List volumes
podmanager volume ls

# Create a network
podmanager network create mynetwork

# Connect container to network
podmanager network connect mynetwork webserver
```

## Automation

### Systemd Service Setup
```bash
# Enable the PodManager service for system monitoring
sudo systemctl enable podmanager.service
sudo systemctl start podmanager.service

# Check service status
sudo systemctl status podmanager.service

# View service logs
sudo journalctl -u podmanager.service -f
```

### Cron Job Examples
```bash
# Add to crontab (crontab -e)

# Daily container health check at 2 AM
0 2 * * * /usr/local/bin/podmanager health-check --all --notify

# Weekly image cleanup every Sunday at 3 AM
0 3 * * 0 /usr/local/bin/podmanager image-prune --force

# Hourly resource monitoring
0 * * * * /usr/local/bin/podmanager stats --log-only
```

## Logging

### Log Locations
- **Main Log**: `/var/log/podmanager/podmanager.log`
- **Error Log**: `/var/log/podmanager/error.log`
- **Access Log**: `/var/log/podmanager/access.log`
- **System Service**: `journalctl -u podmanager.service`

### Viewing Logs
```bash
# View recent activity
tail -f /var/log/podmanager/podmanager.log

# View errors only
tail -f /var/log/podmanager/error.log

# Search logs for specific container
grep "webserver" /var/log/podmanager/podmanager.log

# View systemd service logs
journalctl -u podmanager.service --since "1 hour ago"
```

## Security Tips

- **Run Rootless**: Always use rootless Podman for enhanced security
- **Regular Updates**: Keep Podman and container images updated
- **Image Scanning**: Enable security scanning for all pulled images
- **Resource Limits**: Set appropriate CPU and memory limits for containers
- **Network Isolation**: Use custom networks instead of default bridge
- **Secrets Management**: Use Podman secrets for sensitive data
- **File Permissions**: Ensure proper ownership of container storage directories

```bash
# Enable rootless mode
systemctl --user enable podman.socket
systemctl --user start podman.socket

# Set up proper permissions
chmod 755 ~/.local/share/containers
chown -R $USER:$USER ~/.local/share/containers
```

## Example Output

### Container Status Check
```
$ podmanager ps
CONTAINER ID   IMAGE          COMMAND                  STATUS         PORTS                   NAMES
3f2a4b1c8d9e   nginx:latest   "/docker-entrypoint.…"   Up 2 hours     0.0.0.0:8080->80/tcp   webserver
7e8f9a2b3c4d   redis:alpine   "redis-server"           Up 30 minutes  6379/tcp               cache
```

### Health Check Report
```
$ podmanager health-check --all
┌─────────────┬──────────┬────────────┬─────────────┬────────────┐
│ Container   │ Status   │ CPU Usage  │ Memory      │ Health     │
├─────────────┼──────────┼────────────┼─────────────┼────────────┤
│ webserver   │ running  │ 0.5%       │ 45MB/512MB  │ healthy    │
│ cache       │ running  │ 0.1%       │ 12MB/128MB  │ healthy    │
│ database    │ stopped  │ -          │ -           │ unhealthy  │
└─────────────┴──────────┴────────────┴─────────────┴────────────┘
```

### Security Scan Results
```
$ podmanager scan-security nginx:latest
Security Scan Results for nginx:latest
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ No critical vulnerabilities found
⚠ 2 medium severity issues detected
ℹ 5 informational notices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommendation: Update to nginx:1.25-alpine for security patches
```

## Author and License

**Author**: [Your Name]  
**Email**: [your.email@example.com]  
**GitHub**: [https://github.com/username/podmanager](https://github.com/username/podmanager)

**License**: MIT License

```
MIT License

Copyright (c) 2025 PodManager Contributors

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

For support, issues, or contributions, please visit the [GitHub repository](https://github.com/username/podmanager) or contact the maintainers directly.

