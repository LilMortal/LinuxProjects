#!/usr/bin/env python3
"""
Linux From Scratch (LFS) Host System Validation Script
Version: 1.0.0

This script validates that the host system meets all requirements for building LFS.
It checks for required tools, versions, and system configuration.
"""

import os
import sys
import subprocess
import re
import logging
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HostValidator:
    """Host system validation for LFS build requirements."""
    
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.checks_passed = 0
        self.checks_total = 0
        
        # Required tools with minimum versions
        self.required_tools = {
            'bash': '3.2',
            'bc': '1.06',
            'binutils': '2.25',
            'bison': '2.7',
            'coreutils': '6.9',
            'diffutils': '2.8.1',
            'findutils': '4.2.31',
            'gawk': '4.0.1',
            'gcc': '5.1',
            'glibc': '2.11',
            'grep': '2.5.1a',
            'gzip': '1.3.12',
            'linux-kernel': '4.14',
            'm4': '1.4.10',
            'make': '4.0',
            'patch': '2.5.4',
            'perl': '5.8.8',
            'python': '3.4',
            'sed': '4.1.5',
            'tar': '1.22',
            'texinfo': '4.7',
            'xz': '5.0.0'
        }
        
        # Additional required commands
        self.required_commands = [
            'awk', 'cat', 'chmod', 'chown', 'cp', 'cut', 'du', 'echo',
            'expr', 'head', 'install', 'ln', 'ls', 'mkdir', 'mkfifo',
            'mknod', 'mktemp', 'mv', 'pwd', 'rm', 'rmdir', 'sort',
            'stat', 'tail', 'touch', 'tr', 'uniq', 'wc', 'wget', 'which'
        ]
    
    def run_command(self, cmd: str) -> Tuple[int, str, str]:
        """Run a shell command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except Exception as e:
            return 1, "", str(e)
    
    def check_command_exists(self, command: str) -> bool:
        """Check if a command exists and is executable."""
        returncode, _, _ = self.run_command(f"command -v {command}")
        return returncode == 0
    
    def get_tool_version(self, tool: str) -> Optional[str]:
        """Get version string for a specific tool."""
        version_commands = {
            'bash': 'bash --version | head -n1',
            'bc': 'bc --version | head -n1',
            'binutils': 'ld --version | head -n1',
            'bison': 'bison --version | head -n1',
            'coreutils': 'ls --version | head -n1',
            'diffutils': 'diff --version | head -n1',
            'findutils': 'find --version | head -n1',
            'gawk': 'gawk --version | head -n1',
            'gcc': 'gcc --version | head -n1',
            'glibc': 'ldd --version | head -n1',
            'grep': 'grep --version | head -n1',
            'gzip': 'gzip --version | head -n1',
            'linux-kernel': 'uname -r',
            'm4': 'm4 --version | head -n1',
            'make': 'make --version | head -n1',
            'patch': 'patch --version | head -n1',
            'perl': 'perl -V:version | cut -d"'" -f2',
            'python': 'python3 --version',
            'sed': 'sed --version | head -n1',
            'tar': 'tar --version | head -n1',
            'texinfo': 'makeinfo --version | head -n1',
            'xz': 'xz --version | head -n1'
        }
        
        cmd = version_commands.get(tool)
        if not cmd:
            return None
        
        returncode, stdout, _ = self.run_command(cmd)
        if returncode != 0:
            return None
        
        return stdout.strip()
    
    def parse_version(self, version_string: str) -> List[int]:
        """Parse version string into list of integers."""
        # Extract version numbers using regex
        version_match = re.search(r'(\d+(?:\.\d+)*)', version_string)
        if not version_match:
            return [0]
        
        version_parts = version_match.group(1).split('.')
        return [int(part) for part in version_parts]
    
    def compare_versions(self, version1: str, version2: str) -> int:
        """Compare two version strings. Returns 1 if version1 > version2, -1 if less, 0 if equal."""
        v1_parts = self.parse_version(version1)
        v2_parts = self.parse_version(version2)
        
        # Pad shorter version with zeros
        max_len = max(len(v1_parts), len(v2_parts))
        v1_parts.extend([0] * (max_len - len(v1_parts)))
        v2_parts.extend([0] * (max_len - len(v2_parts)))
        
        for v1, v2 in zip(v1_parts, v2_parts):
            if v1 > v2:
                return 1
            elif v1 < v2:
                return -1
        
        return 0
    
    def check_tool_version(self, tool: str, required_version: str) -> bool:
        """Check if tool meets minimum version requirement."""
        self.checks_total += 1
        
        if not self.check_command_exists(tool.replace('-', '')):
            self.errors.append(f"Required tool not found: {tool}")
            return False
        
        current_version = self.get_tool_version(tool)
        if not current_version:
            self.warnings.append(f"Could not determine version for {tool}")
            self.checks_passed += 1  # Don't fail for version detection issues
            return True
        
        if self.compare_versions(current_version, required_version) >= 0:
            logger.info(f"✓ {tool}: {current_version} (>= {required_version})")
            self.checks_passed += 1
            return True
        else:
            self.errors.append(f"{tool} version {current_version} is too old (need >= {required_version})")
            return False
    
    def check_required_commands(self) -> bool:
        """Check that all required commands are available."""
        logger.info("Checking required commands...")
        
        missing_commands = []
        for cmd in self.required_commands:
            self.checks_total += 1
            if self.check_command_exists(cmd):
                self.checks_passed += 1
            else:
                missing_commands.append(cmd)
        
        if missing_commands:
            self.errors.append(f"Missing required commands: {', '.join(missing_commands)}")
            return False
        
        logger.info(f"✓ All {len(self.required_commands)} required commands found")
        return True
    
    def check_disk_space(self, path: str = "/tmp", min_gb: int = 10) -> bool:
        """Check available disk space."""
        self.checks_total += 1
        
        try:
            stat = os.statvfs(path)
            available_bytes = stat.f_bavail * stat.f_frsize
            available_gb = available_bytes / (1024**3)
            
            if available_gb >= min_gb:
                logger.info(f"✓ Disk space: {available_gb:.1f}GB available (>= {min_gb}GB required)")
                self.checks_passed += 1
                return True
            else:
                self.errors.append(f"Insufficient disk space: {available_gb:.1f}GB available, {min_gb}GB required")
                return False
        except Exception as e:
            self.warnings.append(f"Could not check disk space: {e}")
            self.checks_passed += 1
            return True
    
    def check_memory(self, min_mb: int = 1024) -> bool:
        """Check available memory."""
        self.checks_total += 1
        
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('MemTotal:'):
                        mem_kb = int(line.split()[1])
                        mem_mb = mem_kb / 1024
                        
                        if mem_mb >= min_mb:
                            logger.info(f"✓ Memory: {mem_mb:.0f}MB available (>= {min_mb}MB required)")
                            self.checks_passed += 1
                            return True
                        else:
                            self.errors.append(f"Insufficient memory: {mem_mb:.0f}MB available, {min_mb}MB required")
                            return False
            
            self.warnings.append("Could not determine memory size")
            self.checks_passed += 1
            return True
        except Exception as e:
            self.warnings.append(f"Could not check memory: {e}")
            self.checks_passed += 1
            return True
    
    def check_kernel_features(self) -> bool:
        """Check kernel configuration for required features."""
        self.checks_total += 1
        
        kernel_config_paths = [
            '/proc/config.gz',
            '/boot/config-' + os.uname().release,
            '/usr/src/linux/.config'
        ]
        
        config_content = None
        for config_path in kernel_config_paths:
            try:
                if config_path.endswith('.gz'):
                    import gzip
                    with gzip.open(config_path, 'rt') as f:
                        config_content = f.read()
                else:
                    with open(config_path, 'r') as f:
                        config_content = f.read()
                break
            except (FileNotFoundError, PermissionError):
                continue
        
        if not config_content:
            self.warnings.append("Could not find kernel configuration file")
            self.checks_passed += 1
            return True
        
        # Check for essential kernel features
        required_features = [
            'CONFIG_DEVTMPFS=y',
            'CONFIG_CGROUPS=y',
            'CONFIG_INOTIFY_USER=y',
            'CONFIG_SIGNALFD=y',
            'CONFIG_TIMERFD=y',
            'CONFIG_EPOLL=y'
        ]
        
        missing_features = []
        for feature in required_features:
            if feature not in config_content:
                missing_features.append(feature)
        
        if missing_features:
            self.warnings.append(f"Missing recommended kernel features: {', '.join(missing_features)}")
        else:
            logger.info("✓ Kernel configuration looks good")
        
        self.checks_passed += 1
        return True
    
    def check_file_systems(self) -> bool:
        """Check for required file system support."""
        self.checks_total += 1
        
        try:
            with open('/proc/filesystems', 'r') as f:
                filesystems = f.read()
            
            required_fs = ['ext2', 'ext3', 'ext4', 'tmpfs', 'devtmpfs']
            missing_fs = []
            
            for fs in required_fs:
                if fs not in filesystems:
                    missing_fs.append(fs)
            
            if missing_fs:
                self.warnings.append(f"Missing file system support: {', '.join(missing_fs)}")
            else:
                logger.info("✓ Required file systems supported")
            
            self.checks_passed += 1
            return True
        except Exception as e:
            self.warnings.append(f"Could not check file system support: {e}")
            self.checks_passed += 1
            return True
    
    def check_user_permissions(self) -> bool:
        """Check user permissions and capabilities."""
        self.checks_total += 1
        
        # Check if user can use sudo
        returncode, _, _ = self.run_command("sudo -n true")
        if returncode != 0:
            self.warnings.append("User does not have passwordless sudo access")
        
        # Check if user is in required groups
        try:
            import grp
            user_groups = [g.gr_name for g in grp.getgrall() if os.getenv('USER') in g.gr_mem]
            
            recommended_groups = ['disk', 'wheel', 'sudo']
            missing_groups = [g for g in recommended_groups if g not in user_groups]
            
            if missing_groups:
                self.warnings.append(f"User not in recommended groups: {', '.join(missing_groups)}")
            
        except Exception as e:
            self.warnings.append(f"Could not check user groups: {e}")
        
        logger.info("✓ User permissions checked")
        self.checks_passed += 1
        return True
    
    def validate_all(self) -> bool:
        """Run all validation checks."""
        logger.info("Starting LFS host system validation...")
        logger.info("=" * 50)
        
        # Check tool versions
        logger.info("Checking tool versions...")
        for tool, min_version in self.required_tools.items():
            self.check_tool_version(tool, min_version)
        
        # Check required commands
        self.check_required_commands()
        
        # Check system resources
        logger.info("Checking system resources...")
        self.check_disk_space()
        self.check_memory()
        
        # Check kernel and system configuration
        logger.info("Checking system configuration...")
        self.check_kernel_features()
        self.check_file_systems()
        self.check_user_permissions()
        
        # Report results
        logger.info("=" * 50)
        logger.info(f"Validation complete: {self.checks_passed}/{self.checks_total} checks passed")
        
        if self.warnings:
            logger.warning(f"Warnings ({len(self.warnings)}):")
            for warning in self.warnings:
                logger.warning(f"  - {warning}")
        
        if self.errors:
            logger.error(f"Errors ({len(self.errors)}):")
            for error in self.errors:
                logger.error(f"  - {error}")
            logger.error("Host system validation FAILED")
            return False
        
        logger.info("Host system validation PASSED")
        return True

def main():
    """Main function."""
    validator = HostValidator()
    
    try:
        success = validator.validate_all()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("Validation interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Validation failed with exception: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()