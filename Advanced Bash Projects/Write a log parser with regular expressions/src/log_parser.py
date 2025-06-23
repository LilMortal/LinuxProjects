#!/usr/bin/env python3
"""
Advanced Log Parser with Regular Expressions
A comprehensive log parsing tool for various log formats with configurable patterns.
"""

import re
import sys
import os
import json
import argparse
import logging
import configparser
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import signal

class LogParser:
    """
    Advanced log parser with regex pattern matching and multiple output formats.
    """
    
    def __init__(self, config_file: str = "config/patterns.conf"):
        """Initialize the log parser with configuration."""
        self.config_file = config_file
        self.patterns = {}
        self.stats = {
            'total_lines': 0,
            'matched_lines': 0,
            'unmatched_lines': 0,
            'errors': 0,
            'start_time': datetime.now()
        }
        self.setup_logging()
        self.load_patterns()
        
    def setup_logging(self):
        """Configure logging for the application."""
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        logging.basicConfig(
            level=logging.INFO,
            format=log_format,
            handlers=[
                logging.FileHandler(log_dir / 'log_parser.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('LogParser')
        
    def load_patterns(self):
        """Load regex patterns from configuration file."""
        try:
            if not os.path.exists(self.config_file):
                self.logger.error(f"Configuration file not found: {self.config_file}")
                self.create_default_config()
                
            config = configparser.ConfigParser()
            config.read(self.config_file)
            
            for section in config.sections():
                self.patterns[section] = {}
                for key, value in config.items(section):
                    try:
                        # Compile regex pattern to validate it
                        compiled_pattern = re.compile(value)
                        self.patterns[section][key] = {
                            'pattern': value,
                            'compiled': compiled_pattern
                        }
                    except re.error as e:
                        self.logger.error(f"Invalid regex pattern in {section}.{key}: {e}")
                        
            self.logger.info(f"Loaded {len(self.patterns)} pattern categories")
            
        except Exception as e:
            self.logger.error(f"Error loading patterns: {e}")
            sys.exit(1)
            
    def create_default_config(self):
        """Create a default configuration file with common log patterns."""
        config = configparser.ConfigParser()
        
        # Apache/Nginx access log patterns
        config['apache'] = {
            'common': r'^(\S+) \S+ \S+ \[([^\]]+)\] "([^"]*)" (\d+) (\d+|-)',
            'combined': r'^(\S+) \S+ \S+ \[([^\]]+)\] "([^"]*)" (\d+) (\d+|-) "([^"]*)" "([^"]*)"',
            'error': r'^\[([^\]]+)\] \[([^\]]+)\] (.+)'
        }
        
        # System log patterns
        config['syslog'] = {
            'standard': r'^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) ([^:]+): (.+)',
            'auth': r'^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) sshd\[(\d+)\]: (.+)',
            'kernel': r'^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) kernel: (.+)'
        }
        
        # Application log patterns
        config['application'] = {
            'timestamp_level': r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)',
            'java_exception': r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d+) (\w+) (.+Exception.+)',
            'python_traceback': r'^Traceback \(most recent call last\):'
        }
        
        # Custom patterns
        config['custom'] = {
            'ip_address': r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            'url': r'https?://[^\s<>"{}|\\^`[\]]*',
            'credit_card': r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'
        }
        
        os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
        with open(self.config_file, 'w') as f:
            config.write(f)
            
        self.logger.info(f"Created default configuration file: {self.config_file}")
        
    def parse_line(self, line: str, pattern_category: str = None) -> Dict:
        """
        Parse a single log line using configured patterns.
        
        Args:
            line: Log line to parse
            pattern_category: Specific pattern category to use (optional)
            
        Returns:
            Dictionary with parsing results
        """
        result = {
            'original': line.strip(),
            'matched': False,
            'pattern_used': None,
            'matches': {},
            'timestamp': datetime.now().isoformat()
        }
        
        categories_to_check = [pattern_category] if pattern_category else self.patterns.keys()
        
        for category in categories_to_check:
            if category not in self.patterns:
                continue
                
            for pattern_name, pattern_data in self.patterns[category].items():
                try:
                    match = pattern_data['compiled'].search(line)
                    if match:
                        result['matched'] = True
                        result['pattern_used'] = f"{category}.{pattern_name}"
                        result['matches'] = {
                            'groups': match.groups(),
                            'named_groups': match.groupdict()
                        }
                        return result
                        
                except Exception as e:
                    self.logger.error(f"Error matching pattern {category}.{pattern_name}: {e}")
                    self.stats['errors'] += 1
                    
        return result
        
    def parse_file(self, file_path: str, pattern_category: str = None, 
                   output_format: str = 'json', max_lines: int = None) -> List[Dict]:
        """
        Parse an entire log file.
        
        Args:
            file_path: Path to log file
            pattern_category: Specific pattern category to use
            output_format: Output format (json, csv, txt)
            max_lines: Maximum number of lines to process
            
        Returns:
            List of parsing results
        """
        results = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, 1):
                    if max_lines and line_num > max_lines:
                        break
                        
                    self.stats['total_lines'] += 1
                    
                    if line.strip():  # Skip empty lines
                        result = self.parse_line(line, pattern_category)
                        result['line_number'] = line_num
                        result['file_path'] = file_path
                        
                        if result['matched']:
                            self.stats['matched_lines'] += 1
                        else:
                            self.stats['unmatched_lines'] += 1
                            
                        results.append(result)
                        
                    # Progress indicator for large files
                    if line_num % 10000 == 0:
                        self.logger.info(f"Processed {line_num} lines...")
                        
        except FileNotFoundError:
            self.logger.error(f"File not found: {file_path}")
            sys.exit(1)
        except Exception as e:
            self.logger.error(f"Error processing file {file_path}: {e}")
            sys.exit(1)
            
        return results
        
    def generate_report(self, results: List[Dict]) -> Dict:
        """Generate a summary report of parsing results."""
        report = {
            'summary': dict(self.stats),
            'pattern_usage': {},
            'file_summary': {},
            'unmatched_samples': []
        }
        
        # Calculate processing time
        report['summary']['processing_time'] = str(datetime.now() - self.stats['start_time'])
        report['summary']['match_rate'] = (
            self.stats['matched_lines'] / max(1, self.stats['total_lines']) * 100
        )
        
        # Pattern usage statistics
        for result in results:
            if result['matched']:
                pattern = result['pattern_used']
                report['pattern_usage'][pattern] = report['pattern_usage'].get(pattern, 0) + 1
                
        # Collect unmatched samples (up to 10)
        unmatched_count = 0
        for result in results:
            if not result['matched'] and unmatched_count < 10:
                report['unmatched_samples'].append({
                    'line': result['original'][:100],  # Truncate long lines
                    'line_number': result.get('line_number', 'N/A')
                })
                unmatched_count += 1
                
        return report
        
    def output_results(self, results: List[Dict], output_format: str, output_file: str = None):
        """Output results in specified format."""
        if output_format.lower() == 'json':
            output_data = json.dumps(results, indent=2, default=str)
        elif output_format.lower() == 'csv':
            output_data = self.to_csv(results)
        elif output_format.lower() == 'txt':
            output_data = self.to_text(results)
        else:
            self.logger.error(f"Unsupported output format: {output_format}")
            return
            
        if output_file:
            try:
                with open(output_file, 'w') as f:
                    f.write(output_data)
                self.logger.info(f"Results written to {output_file}")
            except Exception as e:
                self.logger.error(f"Error writing to file {output_file}: {e}")
        else:
            print(output_data)
            
    def to_csv(self, results: List[Dict]) -> str:
        """Convert results to CSV format."""
        if not results:
            return ""
            
        lines = ["line_number,file_path,matched,pattern_used,original_line"]
        
        for result in results:
            line = f"{result.get('line_number', '')},{result.get('file_path', '')}," \
                   f"{result['matched']},{result.get('pattern_used', '')}," \
                   f"\"{result['original'].replace('\"', '\"\"')}\""
            lines.append(line)
            
        return "\n".join(lines)
        
    def to_text(self, results: List[Dict]) -> str:
        """Convert results to human-readable text format."""
        lines = []
        
        for result in results:
            lines.append(f"Line {result.get('line_number', 'N/A')}: {result['original']}")
            if result['matched']:
                lines.append(f"  ✓ Matched pattern: {result['pattern_used']}")
                if result['matches']['groups']:
                    lines.append(f"  Groups: {result['matches']['groups']}")
            else:
                lines.append("  ✗ No pattern matched")
            lines.append("")
            
        return "\n".join(lines)

def signal_handler(signum, frame):
    """Handle interrupt signals gracefully."""
    print("\nInterrupt received. Exiting gracefully...")
    sys.exit(0)

def main():
    """Main function with command-line interface."""
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    parser = argparse.ArgumentParser(
        description="Advanced Log Parser with Regular Expressions",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -f /var/log/apache2/access.log -c apache
  %(prog)s -f /var/log/syslog -c syslog -o json -w results.json
  %(prog)s -f app.log -c application --max-lines 1000 --report
        """
    )
    
    parser.add_argument('-f', '--file', required=True,
                       help='Path to log file to parse')
    parser.add_argument('-c', '--category',
                       help='Pattern category to use (apache, syslog, application, custom)')
    parser.add_argument('-o', '--output', choices=['json', 'csv', 'txt'], default='json',
                       help='Output format (default: json)')
    parser.add_argument('-w', '--write',
                       help='Write results to file instead of stdout')
    parser.add_argument('--config', default='config/patterns.conf',
                       help='Configuration file path (default: config/patterns.conf)')
    parser.add_argument('--max-lines', type=int,
                       help='Maximum number of lines to process')
    parser.add_argument('--report', action='store_true',
                       help='Generate summary report')
    parser.add_argument('--patterns', action='store_true',
                       help='List available patterns and exit')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Initialize parser
    log_parser = LogParser(args.config)
    
    # List patterns if requested
    if args.patterns:
        print("Available patterns:")
        for category, patterns in log_parser.patterns.items():
            print(f"\n[{category}]")
            for name, data in patterns.items():
                print(f"  {name}: {data['pattern']}")
        sys.exit(0)
    
    # Parse the log file
    log_parser.logger.info(f"Starting to parse {args.file}")
    results = log_parser.parse_file(args.file, args.category, args.output, args.max_lines)
    
    # Generate report if requested
    if args.report:
        report = log_parser.generate_report(results)
        print("\n" + "="*50)
        print("PARSING REPORT")
        print("="*50)
        print(f"Total lines processed: {report['summary']['total_lines']}")
        print(f"Matched lines: {report['summary']['matched_lines']}")
        print(f"Unmatched lines: {report['summary']['unmatched_lines']}")
        print(f"Match rate: {report['summary']['match_rate']:.2f}%")
        print(f"Processing time: {report['summary']['processing_time']}")
        print(f"Errors: {report['summary']['errors']}")
        
        if report['pattern_usage']:
            print("\nPattern usage:")
            for pattern, count in sorted(report['pattern_usage'].items(), 
                                       key=lambda x: x[1], reverse=True):
                print(f"  {pattern}: {count} matches")
                
        if report['unmatched_samples']:
            print("\nSample unmatched lines:")
            for sample in report['unmatched_samples']:
                print(f"  Line {sample['line_number']}: {sample['line']}")
        print("="*50)
    else:
        # Output results
        log_parser.output_results(results, args.output, args.write)
    
    log_parser.logger.info("Parsing completed successfully")

if __name__ == "__main__":
    main()