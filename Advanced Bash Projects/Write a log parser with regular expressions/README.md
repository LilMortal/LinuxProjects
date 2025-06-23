# Advanced Log Parser with Regular Expressions

A comprehensive, production-ready log parsing tool for Linux systems that uses configurable regular expression patterns to parse various log formats including Apache/Nginx access logs, system logs, application logs, and custom formats.

## Overview

This log parser is designed to handle large-scale log analysis with high performance and flexibility. It supports multiple log formats out of the box, provides detailed reporting capabilities, and can be easily integrated into monitoring and automation workflows. The tool is particularly useful for system administrators, DevOps engineers, and security analysts who need to extract meaningful information from log files.

## Features

- **Multi-format support**: Apache/Nginx, syslog, application logs, and custom patterns
- **Configurable regex patterns**: Easy to add new patterns via configuration file
- **Multiple output formats**: JSON, CSV, and human-readable text
- **Performance optimized**: Handles large files efficiently with progress indicators
- **Comprehensive reporting**: Detailed statistics and unmatched line samples
- **Security-focused patterns**: Built-in patterns for detecting security threats
- **Production-ready**: Includes logging, error handling, and signal management
- **Automation-friendly**: CLI interface perfect for cron jobs and systemd services
- **Extensible**: Clean architecture allows easy addition of new features

## Requirements

- **Operating System**: Ubuntu 22.04+ (or any modern Linux distribution)
- **Python**: Python 3.8 or higher (usually pre-installed)
- **Permissions**: Read access to log files you want to parse
- **Dependencies**: Uses only Python standard library (no external packages required)

### Optional Requirements
- `systemd` for service automation
- `cron` for scheduled parsing
- Root or sudo access for system log parsing

## Installation

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/username/log-parser.git
cd log-parser

# Make the script executable
chmod +x src/log_parser.py

# Create symbolic link for system-wide access (optional)
sudo ln -s $(pwd)/src/log_parser.py /usr/local/bin/log-parser
```

### System Installation

```bash
# Install to /opt (recommended for production)
sudo mkdir -p /opt/log-parser
sudo cp -r * /opt/log-parser/
sudo chown -R root:root /opt/log-parser
sudo chmod +x /opt/log-parser/src/log_parser.py

# Create system user for service
sudo useradd -r -s /bin/false -d /opt/log-parser logparser
sudo chown -R logparser:logparser /opt/log-parser/logs

# Install systemd service
sudo cp systemd/log-parser.service /etc/systemd/system/
sudo cp systemd/log-parser.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

### Development Installation

```bash
# Clone and set up development environment
git clone https://github.com/username/log-parser.git
cd log-parser

# Create virtual environment (optional)
python3 -m venv venv
source venv/bin/activate

# Install development dependencies (optional)
pip install -r requirements.txt
```

## Configuration

The tool uses a configuration file `config/patterns.conf` to define regex patterns. The configuration is automatically created with default patterns on first run.

### Environment Variables

- `PYTHONPATH`: Set to the project directory if needed
- `LOG_PARSER_CONFIG`: Override default config file path
- `LOG_PARSER_LOG_LEVEL`: Set logging level (DEBUG, INFO, WARN, ERROR)

### Configuration File Structure

```ini
[apache]
common = ^(\S+) \S+ \S+ \[([^\]]+)\] "([^"]*)" (\d+) (\d+|-)
combined = ^(\S+) \S+ \S+ \[([^\]]+)\] "([^"]*)" (\d+) (\d+|-) "([^"]*)" "([^"]*)"

[syslog]
standard = ^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) ([^:]+): (.+)
auth = ^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) sshd\[(\d+)\]: (.+)

[custom]
ip_address = \b(?:\d{1,3}\.){3}\d{1,3}\b
email = \b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b
```

## Usage

### Basic Usage

```bash
# Parse Apache access log
./src/log_parser.py -f /var/log/apache2/access.log -c apache

# Parse system log with report
./src/log_parser.py -f /var/log/syslog -c syslog --report

# Parse any log file and save as CSV
./src/log_parser.py -f /path/to/logfile.log -o csv -w results.csv
```

### Advanced Usage Examples

```bash
# Parse first 1000 lines of a large log file
./src/log_parser.py -f /var/log/huge.log --max-lines 1000 --report

# Security analysis of auth logs
./src/log_parser.py -f /var/log/auth.log -c security --report

# Custom pattern matching with verbose output
./src/log_parser.py -f app.log -c application -v --report

# Extract all email addresses from logs
./src/log_parser.py -f /var/log/mail.log -c custom --patterns

# Parse multiple formats and generate JSON report
./src/log_parser.py -f /var/log/nginx/access.log -c nginx -o json -w nginx-analysis.json --report
```

### Command Line Options

```
usage: log_parser.py [-h] -f FILE [-c CATEGORY] [-o {json,csv,txt}] [-w WRITE]
                     [--config CONFIG] [--max-lines MAX_LINES] [--report]
                     [--patterns] [-v]

Arguments:
  -f, --file FILE       Path to log file to parse (required)
  -c, --category        Pattern category (apache, syslog, application, custom)
  -o, --output          Output format: json, csv, txt (default: json)
  -w, --write           Write results to file instead of stdout
  --config CONFIG       Configuration file path (default: config/patterns.conf)
  --max-lines N         Maximum number of lines to process
  --report              Generate summary report
  --patterns            List available patterns and exit
  -v, --verbose         Enable verbose logging
```

## Automation

### Cron Jobs

Add to your crontab (`crontab -e`):

```bash
# Daily Apache log analysis at 2 AM
0 2 * * * /usr/local/bin/log-parser -f /var/log/apache2/access.log -c apache --report > /var/log/apache-daily-report.txt 2>&1

# Hourly security monitoring
0 * * * * /usr/local/bin/log-parser -f /var/log/auth.log -c security --report | grep -E "(failed|brute)" && echo "Security alert detected!"

# Weekly comprehensive log analysis
0 3 * * 0 /usr/local/bin/log-parser -f /var/log/syslog -c syslog -o csv -w /var/log/weekly-analysis-$(date +\%Y\%m\%d).csv
```

### Systemd Service

Enable and start the systemd service:

```bash
# Enable and start the service
sudo systemctl enable log-parser.service
sudo systemctl enable log-parser.timer
sudo systemctl start log-parser.timer

# Check service status
sudo systemctl status log-parser.service
sudo systemctl list-timers log-parser.timer

# View logs
sudo journalctl -u log-parser.service -f
```

### Custom Automation Script

```bash
#!/bin/bash
# Log analysis automation script

LOG_DIR="/var/log"
OUTPUT_DIR="/var/log/parsed"
DATE=$(date +%Y%m%d)

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Parse different log types
/usr/local/bin/log-parser -f "$LOG_DIR/apache2/access.log" -c apache -o json -w "$OUTPUT_DIR/apache-$DATE.json" --report
/usr/local/bin/log-parser -f "$LOG_DIR/syslog" -c syslog -o csv -w "$OUTPUT_DIR/syslog-$DATE.csv" --report
/usr/local/bin/log-parser -f "$LOG_DIR/auth.log" -c security --report > "$OUTPUT_DIR/security-$DATE.txt"

# Cleanup old files (keep 30 days)
find "$OUTPUT_DIR" -name "*.json" -o -name "*.csv" -o -name "*.txt" | head -n -30 | xargs rm -f
```

## Logging

The application logs its operations to multiple destinations:

### Log Locations

- **Application logs**: `logs/log_parser.log` (in project directory)
- **System logs**: Available via `journalctl -u log-parser.service`
- **Cron logs**: `/var/log/cron.log` or `/var/log/syslog`

### Checking Logs

```bash
# View application logs
tail -f logs/log_parser.log

# View systemd service logs
sudo journalctl -u log-parser.service -f

# View cron execution logs
grep log-parser /var/log/syslog

# Check for errors
grep ERROR logs/log_parser.log
```

### Log Levels

- **DEBUG**: Detailed pattern matching information
- **INFO**: General operational messages
- **WARN**: Non-critical issues
- **ERROR**: Critical errors that need attention

## Security Tips

### File Permissions

```bash
# Secure the installation
sudo chown -R root:root /opt/log-parser
sudo chmod 755 /opt/log-parser/src/log_parser.py
sudo chmod 644 /opt/log-parser/config/patterns.conf

# Restrict log access
sudo chown logparser:logparser /opt/log-parser/logs
sudo chmod 750 /opt/log-parser/logs
```

### Running as Non-Root User

```bash
# Create dedicated user
sudo useradd -r -s /bin/false -d /opt/log-parser logparser

# Add user to necessary groups for log access
sudo usermod -a -G adm logparser  # For /var/log access on Ubuntu
sudo usermod -a -G systemd-journal logparser  # For journal access
```

### Secure Pattern Configuration

- Regularly review regex patterns for potential ReDoS vulnerabilities
- Avoid overly complex patterns that could cause performance issues
- Use anchors (^ and $) to prevent partial matches where appropriate
- Test patterns with `regex101.com` or similar tools before deployment

### Network Security

- Never parse logs containing sensitive data without proper access controls
- Sanitize output when sharing reports
- Use secure file permissions for output files
- Consider encrypting stored analysis results

## Example Output

### JSON Output
```json
[
  {
    "original": "127.0.0.1 - - [10/Oct/2023:13:55:36 +0000] \"GET /index.html HTTP/1.1\" 200 2326",
    "matched": true,
    "pattern_used": "apache.common",
    "matches": {
      "groups": ["127.0.0.1", "10/Oct/2023:13:55:36 +0000", "GET /index.html HTTP/1.1", "200", "2326"],
      "named_groups": {}
    },
    "line_number": 1,
    "file_path": "/var/log/apache2/access.log",
    "timestamp": "2023-10-10T13:55:36.123456"
  }
]
```

### Report Output
```
==================================================
PARSING REPORT
==================================================
Total lines processed: 1500
Matched lines: 1423
Unmatched lines: 77
Match rate: 94.87%
Processing time: 0:00:02.345678
Errors: 0

Pattern usage:
  apache.common: 856 matches
  syslog.standard: 234 matches
  application.timestamp_level: 178 matches
  custom.ip_address: 155 matches

Sample unmatched lines:
  Line 42: Invalid request format received
  Line 98: Corrupted log entry detected
  Line 156: [MALFORMED] Unable to parse timestamp
==================================================
```

### CSV Output
```csv
line_number,file_path,matched,pattern_used,original_line
1,/var/log/apache2/access.log,True,apache.common,"127.0.0.1 - - [10/Oct/2023:13:55:36 +0000] ""GET /index.html HTTP/1.1"" 200 2326"
2,/var/log/apache2/access.log,True,apache.common,"192.168.1.100 - - [10/Oct/2023:13:55:37 +0000] ""POST /login.php HTTP/1.1"" 302 -"
```

## Author and License



### License

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

---

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Reporting Issues
Please use the GitHub issue tracker to report bugs or request features.
