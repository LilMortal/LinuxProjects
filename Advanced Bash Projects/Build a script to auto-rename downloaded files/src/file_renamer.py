#!/usr/bin/env python3
"""
File Auto-Renamer
A Python script to automatically rename downloaded files based on configurable rules.

Author: File Auto-Renamer Project
License: MIT
"""

import os
import sys
import time
import re
import shutil
import argparse
import logging
import configparser
from datetime import datetime
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class FileRenamerConfig:
    """Configuration manager for file renamer settings."""
    
    def __init__(self, config_path=None):
        self.config = configparser.ConfigParser()
        self.config_path = config_path or self._find_config_file()
        self.load_config()
    
    def _find_config_file(self):
        """Find configuration file in standard locations."""
        possible_paths = [
            'config/renamer.conf',
            '/etc/file-renamer/renamer.conf',
            os.path.expanduser('~/.config/file-renamer/renamer.conf')
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Return default path if none found
        return 'config/renamer.conf'
    
    def load_config(self):
        """Load configuration from file."""
        try:
            self.config.read(self.config_path)
        except Exception as e:
            logging.warning(f"Could not load config from {self.config_path}: {e}")
            self._set_defaults()
    
    def _set_defaults(self):
        """Set default configuration values."""
        self.config['DEFAULT'] = {
            'watch_directory': os.path.expanduser('~/Downloads'),
            'naming_pattern': 'timestamp',
            'timestamp_format': '%Y%m%d_%H%M%S',
            'add_prefix': '',
            'add_suffix': '',
            'allowed_extensions': 'pdf,doc,docx,txt,jpg,jpeg,png,gif,zip,tar,gz',
            'ignored_extensions': 'tmp,part,crdownload',
            'clean_names': 'true',
            'handle_duplicates': 'true',
            'log_file': 'logs/file_renamer.log',
            'log_level': 'INFO'
        }
    
    def get(self, section, key, fallback=None):
        """Get configuration value."""
        return self.config.get(section, key, fallback=fallback)
    
    def getboolean(self, section, key, fallback=False):
        """Get boolean configuration value."""
        return self.config.getboolean(section, key, fallback=fallback)

class FileRenamerHandler(FileSystemEventHandler):
    """File system event handler for auto-renaming files."""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger('FileRenamer')
        
        # Load configuration
        self.watch_dir = self.config.get('DEFAULT', 'watch_directory')
        self.naming_pattern = self.config.get('DEFAULT', 'naming_pattern')
        self.timestamp_format = self.config.get('DEFAULT', 'timestamp_format')
        self.prefix = self.config.get('DEFAULT', 'add_prefix')
        self.suffix = self.config.get('DEFAULT', 'add_suffix')
        self.clean_names = self.config.getboolean('DEFAULT', 'clean_names')
        self.handle_duplicates = self.config.getboolean('DEFAULT', 'handle_duplicates')
        
        # Parse file extensions
        allowed_ext = self.config.get('DEFAULT', 'allowed_extensions', fallback='')
        ignored_ext = self.config.get('DEFAULT', 'ignored_extensions', fallback='')
        
        self.allowed_extensions = set(ext.strip().lower() for ext in allowed_ext.split(',') if ext.strip())
        self.ignored_extensions = set(ext.strip().lower() for ext in ignored_ext.split(',') if ext.strip())
        
        self.logger.info(f"Initialized FileRenamer for directory: {self.watch_dir}")
    
    def on_created(self, event):
        """Handle file creation events."""
        if event.is_directory:
            return
        
        file_path = event.src_path
        self.logger.info(f"New file detected: {file_path}")
        
        # Wait a moment to ensure file is fully written
        time.sleep(1)
        
        try:
            self.rename_file(file_path)
        except Exception as e:
            self.logger.error(f"Error processing file {file_path}: {e}")
    
    def should_process_file(self, file_path):
        """Check if file should be processed based on extension filters."""
        file_ext = Path(file_path).suffix[1:].lower()  # Remove the dot
        
        # Skip ignored extensions
        if file_ext in self.ignored_extensions:
            self.logger.debug(f"Skipping file with ignored extension: {file_path}")
            return False
        
        # If allowed extensions specified, only process those
        if self.allowed_extensions and file_ext not in self.allowed_extensions:
            self.logger.debug(f"Skipping file with unallowed extension: {file_path}")
            return False
        
        return True
    
    def clean_filename(self, filename):
        """Clean filename by removing/replacing problematic characters."""
        if not self.clean_names:
            return filename
        
        # Remove or replace problematic characters
        cleaned = re.sub(r'[<>:"/\\|?*]', '_', filename)  # Replace forbidden chars
        cleaned = re.sub(r'\s+', '_', cleaned)  # Replace spaces with underscores
        cleaned = re.sub(r'_+', '_', cleaned)  # Replace multiple underscores with single
        cleaned = cleaned.strip('_')  # Remove leading/trailing underscores
        
        return cleaned
    
    def generate_new_name(self, original_path):
        """Generate new filename based on naming pattern."""
        path_obj = Path(original_path)
        original_name = path_obj.stem
        extension = path_obj.suffix
        
        # Clean original name if requested
        if self.clean_names:
            original_name = self.clean_filename(original_name)
        
        # Generate new name based on pattern
        if self.naming_pattern == 'timestamp':
            timestamp = datetime.now().strftime(self.timestamp_format)
            new_name = f"{timestamp}_{original_name}"
        elif self.naming_pattern == 'sequential':
            counter = 1
            base_name = original_name
            while True:
                new_name = f"{base_name}_{counter:03d}"
                test_path = path_obj.parent / f"{self.prefix}{new_name}{self.suffix}{extension}"
                if not test_path.exists():
                    break
                counter += 1
        elif self.naming_pattern == 'clean_only':
            new_name = original_name
        else:
            # Default to original name
            new_name = original_name
        
        # Add prefix and suffix
        final_name = f"{self.prefix}{new_name}{self.suffix}{extension}"
        
        return final_name
    
    def handle_duplicate(self, target_path):
        """Handle duplicate filenames by adding a counter."""
        if not self.handle_duplicates:
            return target_path
        
        path_obj = Path(target_path)
        base_name = path_obj.stem
        extension = path_obj.suffix
        parent = path_obj.parent
        
        counter = 1
        while path_obj.exists():
            new_name = f"{base_name}_{counter:03d}{extension}"
            path_obj = parent / new_name
            counter += 1
        
        return str(path_obj)
    
    def rename_file(self, original_path):
        """Rename a file according to configuration rules."""
        if not os.path.exists(original_path):
            self.logger.warning(f"File no longer exists: {original_path}")
            return
        
        if not self.should_process_file(original_path):
            return
        
        try:
            # Generate new filename
            new_filename = self.generate_new_name(original_path)
            new_path = os.path.join(os.path.dirname(original_path), new_filename)
            
            # Handle duplicates
            new_path = self.handle_duplicate(new_path)
            
            # Skip if names are the same
            if original_path == new_path:
                self.logger.info(f"No renaming needed for: {original_path}")
                return
            
            # Perform the rename
            shutil.move(original_path, new_path)
            self.logger.info(f"Renamed: {os.path.basename(original_path)} -> {os.path.basename(new_path)}")
            
        except Exception as e:
            self.logger.error(f"Failed to rename {original_path}: {e}")

class FileRenamer:
    """Main file renamer application."""
    
    def __init__(self, config_path=None):
        self.config = FileRenamerConfig(config_path)
        self.setup_logging()
        self.handler = FileRenamerHandler(self.config)
        self.observer = Observer()
    
    def setup_logging(self):
        """Setup logging configuration."""
        log_file = self.config.get('DEFAULT', 'log_file')
        log_level = self.config.get('DEFAULT', 'log_level', fallback='INFO')
        
        # Create log directory if it doesn't exist
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        
        # Configure logging
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        self.logger = logging.getLogger('FileRenamer')
    
    def start_monitoring(self):
        """Start monitoring the watch directory."""
        watch_dir = self.config.get('DEFAULT', 'watch_directory')
        
        if not os.path.exists(watch_dir):
            self.logger.error(f"Watch directory does not exist: {watch_dir}")
            return False
        
        self.logger.info(f"Starting to monitor: {watch_dir}")
        
        self.observer.schedule(self.handler, watch_dir, recursive=False)
        self.observer.start()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.logger.info("Stopping file renamer...")
            self.observer.stop()
        
        self.observer.join()
        return True
    
    def process_existing_files(self):
        """Process existing files in the watch directory."""
        watch_dir = self.config.get('DEFAULT', 'watch_directory')
        
        if not os.path.exists(watch_dir):
            self.logger.error(f"Watch directory does not exist: {watch_dir}")
            return
        
        self.logger.info(f"Processing existing files in: {watch_dir}")
        
        for filename in os.listdir(watch_dir):
            file_path = os.path.join(watch_dir, filename)
            if os.path.isfile(file_path):
                try:
                    self.handler.rename_file(file_path)
                except Exception as e:
                    self.logger.error(f"Error processing existing file {file_path}: {e}")

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Auto-rename downloaded files')
    parser.add_argument('--config', '-c', help='Configuration file path')
    parser.add_argument('--existing', '-e', action='store_true', 
                       help='Process existing files and exit')
    parser.add_argument('--daemon', '-d', action='store_true',
                       help='Run in daemon mode (monitor continuously)')
    parser.add_argument('--version', '-v', action='version', version='FileRenamer 1.0.0')
    
    args = parser.parse_args()
    
    try:
        renamer = FileRenamer(args.config)
        
        if args.existing:
            renamer.process_existing_files()
        else:
            renamer.start_monitoring()
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()