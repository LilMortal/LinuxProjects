# Linux From Scratch (LFS) Automation Toolkit

A comprehensive automation toolkit for building Linux From Scratch (LFS) systems with enhanced logging, error handling, and validation.

## Overview

This toolkit automates the complex process of building a Linux From Scratch system, providing structured scripts, configuration management, and comprehensive logging. It follows the official LFS book methodology while adding automation, safety checks, and monitoring capabilities.

The toolkit handles all major phases of LFS construction:
- Host system preparation and validation
- Partition management and filesystem creation
- Cross-compilation toolchain building
- Temporary system construction
- Final LFS system building
- System configuration and bootloader setup

## Features

- **Automated Build Process**: Complete automation of all LFS build phases
- **Safety Checks**: Pre-flight validation and dependency checking
- **Comprehensive Logging**: Detailed logs with timestamps and progress tracking
- **Error Recovery**: Intelligent error handling and recovery mechanisms
- **Configuration Management**: Centralized configuration with environment validation
- **Progress Monitoring**: Real-time build status and completion tracking
- **Modular Design**: Phase-based execution allowing selective builds
- **Backup Integration**: Automatic backup creation at critical phases
- **Resource Monitoring**: CPU, memory, and disk usage tracking
- **Customization Support**: Easy customization for different target architectures

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04+ / Debian 11+ / CentOS 8+ / Arch Linux
- **Architecture**: x86_64 (primary), ARM64 (experimental)
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 20GB free space, Recommended 50GB+
- **CPU**: Multi-core recommended for parallel compilation

### Dependencies
```bash
# Essential build tools
sudo apt-get install -y build-essential gawk wget bison flex texinfo gperf libc6-dev-i386
sudo apt-get install -y python3 python3-pip curl git rsync parted util-linux

# Additional tools
sudo apt-get install -y vim nano htop tree jq bc cpio
```

### User Requirements
- Non-root user with sudo privileges
- User must be in 'lfs' group (created automatically by setup)

## Installation

### Quick Install
```bash
# Clone the repository
git clone https://github.com/your-username/lfs-automation-toolkit.git
cd lfs-automation-toolkit

# Run the setup script
sudo ./scripts/setup.sh

# Initialize the build environment
./scripts/init-environment.sh
```

### Manual Install
```bash
# Create project directory
sudo mkdir -p /opt/lfs-toolkit
sudo chown $USER:$USER /opt/lfs-toolkit
cd /opt/lfs-toolkit

# Copy all files from this repository
# Set executable permissions
chmod +x scripts/*.sh scripts/*.py
```

## Configuration

### Environment Variables
Create and customize `/opt/lfs-toolkit/config/lfs.conf`:

```bash
# LFS Configuration File
export LFS=/mnt/lfs                    # LFS mount point
export LFS_TGT=x86_64-lfs-linux-gnu   # Target triplet
export LFS_DISK=/dev/sdb               # Target disk (BE CAREFUL!)
export LFS_VERSION=12.0                # LFS version
export MAKEFLAGS="-j$(nproc)"         # Parallel compilation
export LFS_LOG_LEVEL=INFO             # Logging level
export LFS_BACKUP_ENABLED=true        # Enable automatic backups
```

### Advanced Configuration
```bash
# Edit advanced settings
cp config/advanced.conf.example config/advanced.conf
nano config/advanced.conf
```

## Usage

### Complete Build Process
```bash
# Full automated build (recommended for first-time users)
sudo ./lfs-build.sh --full --config=/opt/lfs-toolkit/config/lfs.conf

# With custom log directory
sudo ./lfs-build.sh --full --log-dir=/var/log/lfs-build
```

### Phase-by-Phase Build
```bash
# Phase 1: Host system preparation
sudo ./lfs-build.sh --phase=host-prep

# Phase 2: Partition and filesystem setup
sudo ./lfs-build.sh --phase=partitions

# Phase 3: Build cross-compilation tools
sudo ./lfs-build.sh --phase=cross-tools

# Phase 4: Build temporary system
sudo ./lfs-build.sh --phase=temp-system

# Phase 5: Build final LFS system
sudo ./lfs-build.sh --phase=final-system

# Phase 6: System configuration
sudo ./lfs-build.sh --phase=system-config

# Phase 7: Bootloader installation
sudo ./lfs-build.sh --phase=bootloader
```

### Validation and Testing
```bash
# Validate host system
./scripts/validate-host.py

# Check build progress
./scripts/monitor-build.py --status

# Verify completed system
./scripts/verify-lfs.sh /mnt/lfs
```

### Advanced Usage
```bash
# Resume from specific package
sudo ./lfs-build.sh --resume-from=gcc-pass2

# Build with custom package list
sudo ./lfs-build.sh --package-list=config/minimal-packages.txt

# Generate build report
./scripts/generate-report.py --output=/tmp/lfs-build-report.html
```

## Automation

### Systemd Service (Scheduled Builds)
```bash
# Copy service file
sudo cp systemd/lfs-builder.service /etc/systemd/system/
sudo cp systemd/lfs-builder.timer /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable lfs-builder.timer
sudo systemctl start lfs-builder.timer

# Check status
sudo systemctl status lfs-builder.timer
```

### Cron Job (Alternative)
```bash
# Install cron job for automated builds
sudo cp cron/lfs-maintenance /etc/cron.d/

# Manual cron entry (weekly builds)
sudo crontab -e
# Add: 0 2 * * 0 /opt/lfs-toolkit/lfs-build.sh --maintenance >> /var/log/lfs-cron.log 2>&1
```

### Build Monitoring
```bash
# Start build monitor daemon
sudo systemctl start lfs-monitor.service

# View real-time build status
./scripts/monitor-build.py --follow

# Set up alerts
./scripts/setup-alerts.sh --email=admin@example.com --slack-webhook=https://...
```

## Logging

### Log Locations
- **Main Build Log**: `/var/log/lfs-build/main.log`
- **Phase Logs**: `/var/log/lfs-build/phase-*.log`
- **Error Log**: `/var/log/lfs-build/errors.log`
- **System Journal**: `journalctl -u lfs-builder.service`

### Log Monitoring
```bash
# Follow main build log
tail -f /var/log/lfs-build/main.log

# View errors only
tail -f /var/log/lfs-build/errors.log

# Check systemd journal
sudo journalctl -u lfs-builder.service -f

# Generate log summary
./scripts/log-analyzer.py --summary --last=24h
```

### Log Rotation
```bash
# Logs are automatically rotated via logrotate
cat /etc/logrotate.d/lfs-build

# Manual log cleanup
./scripts/cleanup-logs.sh --older-than=30days
```

## Security Tips

### File System Security
```bash
# Set proper ownership for LFS directory
sudo chown -R lfs:lfs /mnt/lfs
sudo chmod 755 /mnt/lfs

# Secure configuration files
chmod 600 config/lfs.conf
sudo chown root:lfs config/lfs.conf
```

### Build Environment Security
```bash
# Use dedicated LFS user (recommended)
sudo useradd -m -s /bin/bash lfs
sudo usermod -aG sudo lfs

# Set resource limits
echo "lfs soft nproc 4096" | sudo tee -a /etc/security/limits.conf
echo "lfs hard nproc 8192" | sudo tee -a /etc/security/limits.conf
```

### Network Security
```bash
# Use HTTPS for all downloads
export LFS_USE_HTTPS=true

# Verify package signatures
export LFS_VERIFY_SIGNATURES=true

# Set up local mirror (recommended)
./scripts/setup-mirror.sh --local-path=/opt/lfs-sources
```

## Example Output

### Successful Build Start
```
[2024-01-15 10:30:00] INFO: Starting LFS build process
[2024-01-15 10:30:01] INFO: LFS Version: 12.0
[2024-01-15 10:30:01] INFO: Target: x86_64-lfs-linux-gnu
[2024-01-15 10:30:02] INFO: Build directory: /mnt/lfs
[2024-01-15 10:30:03] INFO: Host validation: PASSED
[2024-01-15 10:30:05] INFO: Disk space check: 45.2GB available
[2024-01-15 10:30:06] INFO: Phase 1 - Host Preparation: STARTING
```

### Build Progress
```
[2024-01-15 11:45:30] INFO: Building binutils-2.41 (Pass 1)
[2024-01-15 11:47:22] INFO: binutils-2.41: Configure completed
[2024-01-15 11:52:15] INFO: binutils-2.41: Compilation completed
[2024-01-15 11:52:45] INFO: binutils-2.41: Installation completed
[2024-01-15 11:52:46] INFO: Progress: 15/87 packages (17.2%)
[2024-01-15 11:52:47] INFO: Estimated time remaining: 4h 23m
```

### Build Completion
```
[2024-01-15 18:30:45] INFO: LFS system build completed successfully!
[2024-01-15 18:30:46] INFO: Total build time: 7h 58m 33s
[2024-01-15 18:30:47] INFO: Total packages built: 87
[2024-01-15 18:30:48] INFO: LFS system size: 2.8GB
[2024-01-15 18:30:49] INFO: System ready at: /mnt/lfs
[2024-01-15 18:30:50] INFO: Next step: Configure bootloader
```

### System Validation
```
$ ./scripts/verify-lfs.sh /mnt/lfs
✓ Kernel version: 6.1.11
✓ Glibc version: 2.38
✓ GCC version: 13.2.0
✓ Essential binaries: 156/156 found
✓ Library links: All resolved
✓ System integrity: PASSED
✓ Boot configuration: Valid
LFS system validation: SUCCESSFUL
```

## Author and License

**Author**: LFS Automation Project Contributors  
**Maintainer**: [Your Name] <your.email@example.com>  
**License**: MIT License

### MIT License
```
Copyright (c) 2024 LFS Automation Toolkit

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
Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

### Support
- GitHub Issues: [Repository Issues](https://github.com/your-username/lfs-automation-toolkit/issues)
- Documentation: [Wiki](https://github.com/your-username/lfs-automation-toolkit/wiki)
- Community: [Discussions](https://github.com/your-username/lfs-automation-toolkit/discussions)