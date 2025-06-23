#!/usr/bin/env python3
"""
Linux From Scratch (LFS) Build Monitor
Version: 1.0.0

This script monitors the LFS build process, showing real-time progress,
resource usage, and build status.
"""

import os
import sys
import json
import time
import argparse
import threading
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import psutil

class LFSBuildMonitor:
    """Monitor for LFS build process."""
    
    def __init__(self, log_dir: str = "/var/log/lfs-build"):
        self.log_dir = Path(log_dir)
        self.state_file = self.log_dir / "build-state.json"
        self.main_log = self.log_dir / "main.log"
        self.error_log = self.log_dir / "errors.log"
        
        self.running = False
        self.build_start_time = None
        self.current_phase = "unknown"
        self.current_package = "unknown"
        self.packages_built = 0
        self.total_packages = 87  # Approximate LFS package count
        
        # Resource monitoring
        self.cpu_history = []
        self.memory_history = []
        self.disk_usage_history = []
        
        # Build statistics
        self.error_count = 0
        self.warning_count = 0
    
    def load_build_state(self) -> Dict:
        """Load current build state from state file."""
        try:
            if self.state_file.exists():
                with open(self.state_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            print(f"Warning: Could not load build state: {e}")
        
        return {}
    
    def get_build_progress(self) -> Tuple[str, float, str]:
        """Get current build progress."""
        state = self.load_build_state()
        
        phase = state.get('phase', 'unknown')
        package = state.get('current_package', 'unknown')
        
        # Estimate progress based on phase
        phase_progress = {
            'host-prep': 5,
            'partitions': 10,
            'cross-tools': 25,
            'temp-system': 50,
            'final-system': 85,
            'system-config': 95,
            'bootloader': 100
        }
        
        progress = phase_progress.get(phase, 0)
        
        return phase, progress, package
    
    def get_log_stats(self) -> Tuple[int, int]:
        """Get error and warning counts from logs."""
        error_count = 0
        warning_count = 0
        
        try:
            if self.main_log.exists():
                with open(self.main_log, 'r') as f:
                    for line in f:
                        if 'ERROR:' in line:
                            error_count += 1
                        elif 'WARN:' in line:
                            warning_count += 1
        except Exception:
            pass
        
        return error_count, warning_count
    
    def get_build_time(self) -> Optional[timedelta]:
        """Get total build time."""
        state = self.load_build_state()
        
        if 'timestamp' in state:
            try:
                start_time = datetime.fromisoformat(state['timestamp'])
                return datetime.now() - start_time
            except Exception:
                pass
        
        return None
    
    def get_system_resources(self) -> Dict:
        """Get current system resource usage."""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            return {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'memory_used_gb': memory.used / (1024**3),
                'memory_total_gb': memory.total / (1024**3),
                'disk_percent': disk.percent,
                'disk_used_gb': disk.used / (1024**3),
                'disk_total_gb': disk.total / (1024**3)
            }
        except Exception as e:
            print(f"Warning: Could not get system resources: {e}")
            return {}
    
    def estimate_completion_time(self, progress: float) -> Optional[str]:
        """Estimate build completion time."""
        build_time = self.get_build_time()
        
        if not build_time or progress <= 0:
            return None
        
        total_estimated_time = build_time.total_seconds() * (100 / progress)
        remaining_time = total_estimated_time - build_time.total_seconds()
        
        if remaining_time <= 0:
            return "Completing soon..."
        
        remaining_delta = timedelta(seconds=remaining_time)
        
        # Format nicely
        hours = remaining_delta.seconds // 3600
        minutes = (remaining_delta.seconds % 3600) // 60
        
        if remaining_delta.days > 0:
            return f"{remaining_delta.days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    
    def display_status(self) -> None:
        """Display current build status."""
        phase, progress, package = self.get_build_progress()
        error_count, warning_count = self.get_log_stats()
        resources = self.get_system_resources()
        build_time = self.get_build_time()
        estimated_completion = self.estimate_completion_time(progress)
        
        # Clear screen
        os.system('clear')
        
        print("=" * 70)
        print("Linux From Scratch (LFS) Build Monitor")
        print("=" * 70)
        print()
        
        # Build status
        print(f"Current Phase: {phase}")
        print(f"Current Package: {package}")
        print(f"Progress: {progress:.1f}%")
        
        # Progress bar
        bar_width = 50
        filled_width = int(bar_width * progress / 100)
        bar = "█" * filled_width + "░" * (bar_width - filled_width)
        print(f"Progress: [{bar}] {progress:.1f}%")
        print()
        
        # Timing information
        if build_time:
            hours = build_time.seconds // 3600
            minutes = (build_time.seconds % 3600) // 60
            print(f"Build Time: {build_time.days}d {hours}h {minutes}m")
        
        if estimated_completion:
            print(f"Est. Remaining: {estimated_completion}")
        print()
        
        # Log statistics
        print(f"Errors: {error_count}")
        print(f"Warnings: {warning_count}")
        print()
        
        # System resources
        if resources:
            print("System Resources:")
            print(f"  CPU: {resources.get('cpu_percent', 0):.1f}%")
            print(f"  Memory: {resources.get('memory_percent', 0):.1f}% "
                  f"({resources.get('memory_used_gb', 0):.1f}GB / "
                  f"{resources.get('memory_total_gb', 0):.1f}GB)")
            print(f"  Disk: {resources.get('disk_percent', 0):.1f}% "
                  f"({resources.get('disk_used_gb', 0):.1f}GB / "
                  f"{resources.get('disk_total_gb', 0):.1f}GB)")
        print()
        
        # Recent log entries
        print("Recent Log Entries:")
        try:
            if self.main_log.exists():
                result = subprocess.run(
                    ['tail', '-n', '5', str(self.main_log)],
                    capture_output=True, text=True
                )
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        print(f"  {line}")
        except Exception:
            pass
        
        print()
        print("Press Ctrl+C to exit")
    
    def follow_logs(self) -> None:
        """Follow build logs in real-time."""
        try:
            if not self.main_log.exists():
                print(f"Log file not found: {self.main_log}")
                return
            
            print(f"Following log file: {self.main_log}")
            print("Press Ctrl+C to exit")
            print("-" * 50)
            
            # Use tail -f to follow the log
            process = subprocess.Popen(
                ['tail', '-f', str(self.main_log)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            try:
                for line in iter(process.stdout.readline, ''):
                    print(line.rstrip())
            except KeyboardInterrupt:
                process.terminate()
                print("\nLog following stopped")
        
        except Exception as e:
            print(f"Error following logs: {e}")
    
    def show_summary(self) -> None:
        """Show build summary."""
        phase, progress, package = self.get_build_progress()
        error_count, warning_count = self.get_log_stats()
        build_time = self.get_build_time()
        
        print("LFS Build Summary")
        print("=" * 40)
        print(f"Current Phase: {phase}")
        print(f"Progress: {progress:.1f}%")
        print(f"Errors: {error_count}")
        print(f"Warnings: {warning_count}")
        
        if build_time:
            hours = build_time.seconds // 3600
            minutes = (build_time.seconds % 3600) // 60
            print(f"Build Time: {build_time.days}d {hours}h {minutes}m")
        
        # Check if build is complete
        state = self.load_build_state()
        if state.get('state') == 'full-build-complete':
            print("Status: BUILD COMPLETE ✓")
        elif 'error' in state.get('state', '').lower():
            print("Status: BUILD FAILED ✗")
        else:
            print("Status: BUILD IN PROGRESS...")
    
    def monitor_loop(self) -> None:
        """Main monitoring loop."""
        self.running = True
        
        try:
            while self.running:
                self.display_status()
                time.sleep(5)  # Update every 5 seconds
        except KeyboardInterrupt:
            print("\nMonitoring stopped")
            self.running = False

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="LFS Build Monitor")
    parser.add_argument(
        '--log-dir', 
        default='/var/log/lfs-build',
        help='LFS build log directory'
    )
    parser.add_argument(
        '--follow', 
        action='store_true',
        help='Follow build logs in real-time'
    )
    parser.add_argument(
        '--status', 
        action='store_true',
        help='Show current build status and exit'
    )
    parser.add_argument(
        '--summary', 
        action='store_true',
        help='Show build summary and exit'
    )
    
    args = parser.parse_args()
    
    monitor = LFSBuildMonitor(args.log_dir)
    
    try:
        if args.follow:
            monitor.follow_logs()
        elif args.status:
            monitor.display_status()
        elif args.summary:
            monitor.show_summary()
        else:
            monitor.monitor_loop()
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()