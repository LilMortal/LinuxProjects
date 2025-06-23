# MT-Downloader

A robust, multi-threaded file downloader for Linux systems with comprehensive error handling, logging, and configuration management.

## Overview

MT-Downloader is a powerful command-line tool that enables efficient downloading of multiple files concurrently. Built with Bash and curl, it provides enterprise-grade features including retry logic, resume capability, speed limiting, and detailed logging. The tool is designed for system administrators, developers, and power users who need reliable batch downloading capabilities.

## Features

- **Multi-threaded Downloads**: Configure 1-50 concurrent download threads
- **Intelligent Retry Logic**: Automatic retry with exponential backoff
- **Resume Support**: Continue interrupted downloads seamlessly  
- **Speed Control**: Set maximum and minimum download speeds
- **Flexible Input**: Accept URLs via command line or file
- **Comprehensive Logging**: Detailed logs with multiple verbosity levels
- **Configuration Management**: Config file support with CLI overrides
- **Progress Tracking**: Real-time download progress and statistics
- **URL Validation**: Robust URL format validation
- **Signal Handling**: Graceful shutdown on interrupt signals
- **Security**: Follows security best practices for file operations

## Requirements

### System Requirements
- **Operating System**: Ubuntu 22.04+ (or any modern Linux distribution)
- **Architecture**: x86_64, ARM64, or any architecture supported by curl
- **Memory**: Minimum 512MB RAM (more recommended for high thread count)
- **Disk Space**: Sufficient space for downloaded files plus logs

### Dependencies
- **curl**: HTTP client (usually pre-installed)
  ```bash
  sudo apt update && sudo apt install curl
  ```
- **bash**: Version 4.0+ (standard on modern Linux)
- **GNU coreutils**: Standard utilities (pre-installed)

### Optional Dependencies
- **systemd**: For service management (standard on Ubuntu 22.04+)

## Installation

### Method 1: Direct Download
```bash
# Create installation directory
sudo mkdir -p /opt/mt-downloader
cd /opt/mt-downloader

# Download and extract (replace with actual release URL)
wget https://github.com/your-repo/mt-downloader/archive/main.tar.gz
tar -xzf main.tar.gz --strip-components=1
rm main.tar.gz

# Make executable
chmod +x bin/mt-downloader

# Create symlink for system-wide access
sudo ln -sf /opt/mt-downloader/bin/mt-downloader /usr/local/bin/mt-downloader
```

### Method 2: Git Clone
```bash
git clone https://github.com/your-repo/mt-downloader.git
cd mt-downloader
chmod +x bin/mt-downloader

# Optional: Install system-wide
sudo cp -r . /opt/mt-downloader
sudo ln -sf /opt/mt-downloader/bin/mt-downloader /usr/local/bin/mt-downloader
```

### Method 3: Local Installation
```bash
# Clone to your home directory
git clone https://github.com/your-repo/mt-downloader.git ~/mt-downloader
cd ~/mt-downloader
chmod +x bin/mt-downloader

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/mt-downloader/bin:$PATH"
```

## Configuration

### Configuration File
The main configuration file is located at `config/mt-downloader.conf`:

```bash
# Number of concurrent download threads (1-50)
THREADS=4

# Connection timeout in seconds (1-300)  
TIMEOUT=30

# Number of retry attempts for failed downloads (0-10)
RETRIES=3

# Default output directory for downloads
OUTPUT_DIR=./downloads

# User agent string for HTTP requests
USER_AGENT="MT-Downloader/1.0"

# Maximum download speed (e.g., 1M, 500K, 100K)
MAX_SPEED=

# Minimum download speed (e.g., 100K, 50K)
MIN_SPEED=
```

### Environment Variables
You can also set configuration via environment variables:
```bash
export MT_THREADS=8
export MT_OUTPUT_DIR="/tmp/downloads"
export MT_RETRIES=5
```

### Custom Configuration
Use a custom configuration file:
```bash
mt-downloader -c /path/to/custom.conf -f urls.txt
```

## Usage

### Basic Usage
```bash
# Download single file
mt-downloader https://example.com/file.zip

# Download multiple files
mt-downloader https://example.com/file1.zip https://example.com/file2.pdf

# Download from URL list file
mt-downloader -f urls.txt
```

### Advanced Usage
```bash
# Use 8 threads with custom output directory
mt-downloader -t 8 -o ~/Downloads -f urls.txt

# Resume interrupted downloads with speed limit
mt-downloader -R -s 1M -f urls.txt

# Verbose mode with custom retry count
mt-downloader -v -r 5 https://example.com/large-file.iso

# Quiet mode for scripts
mt-downloader -q -f urls.txt

# Custom user agent and timeout
mt-downloader -u "MyBot/1.0" -T 60 -f urls.txt
```

### Command Line Options
```
-h, --help              Show help message
-t, --threads N         Number of concurrent downloads (default: 4)
-o, --output DIR        Output directory (default: ./downloads)
-f, --file FILE         Read URLs from file (one URL per line)
-r, --retries N         Number of retry attempts (default: 3)
-T, --timeout N         Timeout in seconds (default: 30)
-u, --user-agent UA     User agent string
-s, --max-speed SPEED   Maximum download speed (e.g., 1M, 500K)
-m, --min-speed SPEED   Minimum download speed (e.g., 100K)
-R, --resume            Resume partial downloads
-v, --verbose           Enable verbose output
-q, --quiet             Suppress non-error output
-c, --config FILE       Use custom configuration file
```

### URL File Format
Create a text file with one URL per line:
```
# This is a comment
https://example.com/file1.zip
https://example.com/file2.pdf

# Comments and empty lines are ignored
https://example.com/file3.tar.gz
```

## Automation

### Cron Job Setup

**Daily downloads at 2 AM:**
```bash
# Edit crontab
crontab -e

# Add this line:
0 2 * * * /opt/mt-downloader/bin/mt-downloader -q -f /opt/mt-downloader/config/daily-urls.txt -o /data/downloads
```

**Hourly downloads with logging:**
```bash
# Hourly execution with log rotation
0 * * * * /opt/mt-downloader/bin/mt-downloader -q -f /opt/mt-downloader/config/urls.txt >> /var/log/mt-downloader-cron.log 2>&1
```

### Systemd Service

**Install the service:**
```bash
# Copy service file
sudo cp systemd/mt-downloader.service /etc/systemd/system/

# Create service user
sudo useradd -r -s /bin/false mt-downloader
sudo chown -R mt-downloader:mt-downloader /opt/mt-downloader

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable mt-downloader.service
```

**Run the service:**
```bash
# One-time execution
sudo systemctl start mt-downloader.service

# Check status
sudo systemctl status mt-downloader.service
```

**Timer-based execution:**
Create `/etc/systemd/system/mt-downloader.timer`:
```ini
[Unit]
Description=Run MT-Downloader every hour
Requires=mt-downloader.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable the timer:
```bash
sudo systemctl enable mt-downloader.timer
sudo systemctl start mt-downloader.timer
```

## Logging

### Log Locations
- **Main Log**: `logs/mt-downloader.log`
- **System Logs**: Available via `journalctl` when using systemd

### Log Levels
- **ERROR**: Critical errors and failures
- **WARN**: Warnings and retryable errors  
- **INFO**: General information and progress
- **DEBUG**: Detailed debugging information (use `-v` flag)

### Monitoring Logs
```bash
# Real-time log monitoring
tail -f logs/mt-downloader.log

# View recent errors
grep ERROR logs/mt-downloader.log | tail -20

# Monitor systemd service logs  
sudo journalctl -u mt-downloader.service -f

# View all logs for today
journalctl -u mt-downloader.service --since today
```

### Log Rotation
Set up log rotation with `/etc/logrotate.d/mt-downloader`:
```
/opt/mt-downloader/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress  
    missingok
    create 0644 mt-downloader mt-downloader
    postrotate
        systemctl reload mt-downloader.service > /dev/null 2>&1 || true
    endscript
}
```

## Security Tips

### File Permissions
```bash
# Secure installation
sudo chown root:root /opt/mt-downloader/bin/mt-downloader
sudo chmod 755 /opt/mt-downloader/bin/mt-downloader

# Protect configuration
sudo chmod 600 /opt/mt-downloader/config/mt-downloader.conf
```

### User Isolation
```bash
# Create dedicated user for downloads
sudo useradd -r -s /bin/false -d /opt/mt-downloader mt-downloader
sudo chown -R mt-downloader:mt-downloader /opt/mt-downloader
```

### Network Security
- **Firewall**: Ensure outbound HTTPS/HTTP access
- **Proxy**: Configure curl to use corporate proxy if needed:
  ```bash
  export https_proxy=http://proxy.company.com:8080
  export http_proxy=http://proxy.company.com:8080
  ```

### Safe Download Practices
- Always verify downloaded files with checksums when available
- Use HTTPS URLs whenever possible
- Limit download directories to specific paths
- Monitor download sizes to prevent disk space exhaustion

### Systemd Security
The included systemd service implements security hardening:
- **PrivateTmp**: Isolated temporary directories
- **ProtectSystem**: Read-only system directories
- **NoNewPrivileges**: Prevents privilege escalation
- **ReadWritePaths**: Limited write access

## Example Output

### Successful Download Session
```
[INFO] MT-Downloader starting (PID: 12345)
[INFO] Configuration: threads=4, retries=3, timeout=30s, output=./downloads
[INFO] Loaded 3 URLs from file
[INFO] Starting 3 downloads with 4 threads
[INFO] Starting download: file1.zip
[INFO] Starting download: file2.pdf  
[INFO] Starting download: file3.tar.gz
[INFO] ✓ Download completed: file2.pdf
[INFO] Progress: 1/3 completed
[INFO] ✓ Download completed: file1.zip
[INFO] Progress: 2/3 completed
[INFO] ✓ Download completed: file3.tar.gz
[INFO] Progress: 3/3 completed
[INFO] Waiting for remaining downloads to complete...
[INFO] Download summary: 3 completed, 0 failed, 3 total
[INFO] All downloads completed successfully
```

### Download with Retry
```
[INFO] Starting download: large-file.iso
[WARN] Download attempt 1 failed for large-file.iso (exit code: 28)
[DEBUG] Waiting 2s before retry...
[WARN] Download attempt 2 failed for large-file.iso (exit code: 28)  
[DEBUG] Waiting 4s before retry...
[INFO] ✓ Download completed: large-file.iso
```

### Verbose Output
```bash
mt-downloader -v -f urls.txt
```
```
[DEBUG] Loading configuration from config/mt-downloader.conf
[DEBUG] User-Agent: MT-Downloader/1.0
[INFO] MT-Downloader starting (PID: 12345)
[DEBUG] Loading URLs from file: urls.txt
[INFO] Loaded 2 URLs from file
[DEBUG] URL: https://example.com/file1.zip
[DEBUG] URL: https://example.com/file2.pdf
[INFO] Configuration: threads=4, retries=3, timeout=30s, output=./downloads
[INFO] Starting 2 downloads with 4 threads
[DEBUG] Started download thread (PID: 12346) for file1.zip
[DEBUG] Started download thread (PID: 12347) for file2.pdf
[DEBUG] Download attempt 1/3 for file1.zip
[DEBUG] Output: ./downloads/file1.zip
[INFO] ✓ Download completed: file1.zip
[INFO] Progress: 1/2 completed
[INFO] ✓ Download completed: file2.pdf
[INFO] Progress: 2/2 completed
[INFO] Download summary: 2 completed, 0 failed, 2 total
[INFO] All downloads completed successfully
```

## Author and License

### Author
**MT-Downloader Project**
- Repository: https://github.com/your-repo/mt-downloader
- Issues: https://github.com/your-repo/mt-downloader/issues
- Documentation: https://github.com/your-repo/mt-downloader/wiki

### Contributors
- Your Name - Initial work and maintenance
- Community contributors welcome!

### License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 MT-Downloader Project

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

### Contributions
Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Support
- **Bug Reports**: Use GitHub Issues
- **Feature Requests**: Use GitHub Issues with enhancement label  
- **Questions**: Check existing issues or create a new discussion

---

**Version**: 1.0.0  
**Last Updated**: January 2025