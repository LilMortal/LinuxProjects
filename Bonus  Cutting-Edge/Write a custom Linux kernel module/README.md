# Custom Linux Kernel Module Project

## 1. Project Title
**SimpleChar Kernel Module** - A educational character device driver for Linux kernel development

## 2. Overview
This project implements a simple character device driver for the Linux kernel that demonstrates fundamental kernel module concepts including device registration, file operations, parameter passing, and kernel logging. The module creates a virtual character device that can be read from and written to, making it an excellent learning tool for kernel development.

## 3. Features
- **Character Device Interface**: Creates `/dev/simplechar` device file
- **Read/Write Operations**: Supports basic file operations (open, close, read, write)
- **Module Parameters**: Configurable buffer size and debug level
- **Kernel Logging**: Comprehensive logging using `printk()` with different log levels
- **Memory Management**: Proper kernel memory allocation and cleanup
- **Error Handling**: Robust error handling throughout the module
- **Sysfs Integration**: Exposes module information via `/sys` filesystem
- **User Space Tools**: Helper scripts for module management

## 4. Requirements
- **Operating System**: Ubuntu 22.04+ or any modern Linux distribution
- **Kernel Headers**: Matching your kernel version (`linux-headers-$(uname -r)`)
- **Build Tools**: `gcc`, `make`, `build-essential`
- **Permissions**: Root access for module loading/unloading
- **Architecture**: x86_64, ARM64 (tested architectures)

### Install Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) kmod

# CentOS/RHEL/Fedora
sudo yum groupinstall "Development Tools"
sudo yum install kernel-devel kernel-headers
```

## 5. Installation

### Clone and Build
```bash
# Clone the project
git clone <repository-url>
cd linux-kernel-module

# Build the module
make

# Install helper scripts
sudo cp scripts/simplechar-* /usr/local/bin/
sudo chmod +x /usr/local/bin/simplechar-*
```

### Verify Build
```bash
# Check if module was built successfully
ls -la simplechar.ko
file simplechar.ko
```

## 6. Configuration

### Module Parameters
The module accepts the following parameters:

- `buffer_size`: Size of internal buffer (default: 1024 bytes, max: 4096)
- `debug_level`: Debug verbosity (0-3, default: 1)
- `device_name`: Custom device name (default: "simplechar")

### Environment Variables
```bash
export SIMPLECHAR_DEBUG=1          # Enable debug output
export SIMPLECHAR_BUFFER_SIZE=2048 # Set buffer size
```

## 7. Usage

### Basic Module Operations
```bash
# Load the module with default parameters
sudo insmod simplechar.ko

# Load with custom parameters
sudo insmod simplechar.ko buffer_size=2048 debug_level=2

# Check if module is loaded
lsmod | grep simplechar

# View module information
modinfo simplechar.ko

# Unload the module
sudo rmmod simplechar
```

### Device Operations
```bash
# Check device file (created automatically)
ls -l /dev/simplechar

# Write data to device
echo "Hello Kernel!" | sudo tee /dev/simplechar

# Read data from device
sudo cat /dev/simplechar

# Test with helper script
sudo simplechar-test
```

### Advanced Usage
```bash
# Load with helper script
sudo simplechar-load

# Monitor kernel messages
sudo dmesg -w | grep simplechar

# Check module status
sudo simplechar-status

# Unload with helper script
sudo simplechar-unload
```

## 8. Automation

### Systemd Service
The project includes a systemd service for automatic module loading:

```bash
# Install service file
sudo cp systemd/simplechar.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable auto-loading at boot
sudo systemctl enable simplechar.service

# Start service
sudo systemctl start simplechar.service

# Check status
sudo systemctl status simplechar.service
```

### Cron Job Example
```bash
# Add to root's crontab for periodic checks
sudo crontab -e

# Add this line to check module status every 10 minutes
*/10 * * * * /usr/local/bin/simplechar-status >> /var/log/simplechar-cron.log 2>&1
```

## 9. Logging

### Kernel Logs
The module logs to kernel ring buffer, accessible via:

```bash
# View recent kernel messages
sudo dmesg | grep simplechar

# Monitor live kernel messages
sudo dmesg -w | grep simplechar

# Check system journal
sudo journalctl -k | grep simplechar
```

### Log Levels
- `KERN_DEBUG`: Detailed debugging information
- `KERN_INFO`: General information messages
- `KERN_WARNING`: Warning conditions
- `KERN_ERR`: Error conditions

### Log File Locations
- Kernel messages: `/var/log/kern.log`
- System journal: `journalctl -k`
- Dmesg output: `/var/log/dmesg`

## 10. Security Tips

### File Permissions
```bash
# Ensure proper device permissions
sudo chmod 666 /dev/simplechar  # Read/write for all users
sudo chmod 644 /dev/simplechar  # Read-only for non-root (recommended)
```

### Module Signing (for Secure Boot)
```bash
# If using Secure Boot, sign the module
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
    sha256 /path/to/private.key /path/to/public.crt simplechar.ko
```

### Safety Precautions
- Always test on non-production systems first
- Use virtual machines for initial development
- Keep module source code and build logs
- Monitor system stability after loading
- Have a recovery plan (rescue boot media)

### SELinux/AppArmor Considerations
```bash
# Check SELinux status
sestatus

# If needed, create SELinux policy for the module
# (Consult SELinux documentation for custom policies)
```

## 11. Example Output

### Module Loading
```
$ sudo insmod simplechar.ko buffer_size=1024 debug_level=2
$ dmesg | tail -5
[12345.678901] simplechar: SimpleChar module loaded successfully
[12345.678902] simplechar: Buffer size: 1024 bytes
[12345.678903] simplechar: Debug level: 2
[12345.678904] simplechar: Device major number: 245
[12345.678905] simplechar: Device file: /dev/simplechar created
```

### Device Operations
```
$ echo "Test data" | sudo tee /dev/simplechar
Test data
$ sudo cat /dev/simplechar
Test data
$ sudo simplechar-status
SimpleChar Module Status:
  Status: Loaded
  Major: 245
  Buffer Size: 1024 bytes
  Debug Level: 2
  Device File: /dev/simplechar (exists)
  Open Count: 0
  Data Length: 9 bytes
```

### Module Unloading
```
$ sudo rmmod simplechar
$ dmesg | tail -3
[12346.789012] simplechar: Device closed, total reads: 1, writes: 1
[12346.789013] simplechar: Cleaning up resources
[12346.789014] simplechar: SimpleChar module unloaded successfully
```

## 12. Author and License

### Author
**Your Name** - Linux Kernel Developer
- Email: your.email@example.com
- GitHub: https://github.com/yourusername

### License
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Acknowledgments
- Linux Kernel Development Community
- "Linux Device Drivers" by Jonathan Corbet, Alessandro Rubini, and Greg Kroah-Hartman
- Linux Kernel Documentation Project

---

**⚠️ Warning: Kernel modules run in kernel space and can potentially crash your system. Always test on non-production machines and have proper backups.**