#!/usr/bin/env python3
"""
CLI Music Player - A command-line music player using mpg123
Author: Your Name
Version: 1.0.0
License: MIT
"""

import os
import sys
import subprocess
import threading
import time
import signal
import argparse
import configparser
import logging
import logging.handlers
import random
import json
from pathlib import Path
from typing import List, Optional, Dict, Any
import termios
import tty
import select

class MusicPlayer:
    """Main music player class that handles playback and user interaction."""
    
    def __init__(self, config_file: str = "/etc/music-player/music_player.conf"):
        """Initialize the music player with configuration."""
        self.config_file = config_file
        self.config = self._load_config()
        self.logger = self._setup_logging()
        
        # Player state
        self.playlist: List[str] = []
        self.current_index: int = 0
        self.is_playing: bool = False
        self.is_paused: bool = False
        self.shuffle_mode: bool = False
        self.repeat_mode: bool = True
        self.volume: int = 70
        self.daemon_mode: bool = False
        
        # mpg123 process
        self.mpg123_process: Optional[subprocess.Popen] = None
        self.control_thread: Optional[threading.Thread] = None
        self.playback_thread: Optional[threading.Thread] = None
        
        # Supported audio formats
        self.supported_formats = {'.mp3', '.wav', '.ogg', '.flac', '.aac', '.m4a'}
        
        # Terminal settings
        self.old_terminal_settings = None
        
        # Signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        self.logger.info("Music player initialized")

    def _load_config(self) -> configparser.ConfigParser:
        """Load configuration from file."""
        config = configparser.ConfigParser()
        
        # Default configuration
        config['DEFAULT'] = {
            'music_directory': os.path.expanduser('~/Music'),
            'log_file': '/var/log/music-player/music_player.log',
            'default_volume': '70',
            'use_syslog': 'true',
            'playlist_directory': os.path.expanduser('~/.local/share/music-player/playlists')
        }
        
        config['PLAYBACK'] = {
            'shuffle': 'false',
            'repeat': 'true',
            'autoplay': 'false'
        }
        
        # Load from file if it exists
        if os.path.exists(self.config_file):
            try:
                config.read(self.config_file)
            except Exception as e:
                print(f"Warning: Could not read config file {self.config_file}: {e}")
        
        return config

    def _setup_logging(self) -> logging.Logger:
        """Set up logging configuration."""
        logger = logging.getLogger('music_player')
        logger.setLevel(logging.INFO)
        
        # Ensure log directory exists
        log_file = self.config.get('DEFAULT', 'log_file')
        log_dir = os.path.dirname(log_file)
        os.makedirs(log_dir, exist_ok=True)
        
        # File handler
        try:
            file_handler = logging.handlers.RotatingFileHandler(
                log_file, maxBytes=10*1024*1024, backupCount=5
            )
            file_formatter = logging.Formatter(
                '%(asctime)s [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            file_handler.setFormatter(file_formatter)
            logger.addHandler(file_handler)
        except Exception as e:
            print(f"Warning: Could not set up file logging: {e}")
        
        # Syslog handler
        if self.config.getboolean('DEFAULT', 'use_syslog', fallback=True):
            try:
                syslog_handler = logging.handlers.SysLogHandler(address='/dev/log')
                syslog_formatter = logging.Formatter(
                    'music-player[%(process)d]: %(levelname)s %(message)s'
                )
                syslog_handler.setFormatter(syslog_formatter)
                logger.addHandler(syslog_handler)
            except Exception as e:
                print(f"Warning: Could not set up syslog: {e}")
        
        return logger

    def _signal_handler(self, signum: int, frame) -> None:
        """Handle system signals for graceful shutdown."""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop_playback()
        self._restore_terminal()
        sys.exit(0)

    def _check_dependencies(self) -> bool:
        """Check if required dependencies are installed."""
        try:
            subprocess.run(['mpg123', '--version'], 
                         capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.logger.error("mpg123 is not installed or not in PATH")
            print("Error: mpg123 is required but not installed.")
            print("Install it with: sudo apt install mpg123")
            return False

    def scan_directory(self, directory: str, recursive: bool = True) -> List[str]:
        """Scan directory for audio files."""
        audio_files = []
        directory = Path(directory)
        
        if not directory.exists():
            self.logger.error(f"Directory does not exist: {directory}")
            return audio_files
        
        try:
            if recursive:
                pattern = "**/*"
            else:
                pattern = "*"
            
            for file_path in directory.glob(pattern):
                if file_path.is_file() and file_path.suffix.lower() in self.supported_formats:
                    audio_files.append(str(file_path))
            
            self.logger.info(f"Found {len(audio_files)} audio files in {directory}")
            
        except Exception as e:
            self.logger.error(f"Error scanning directory {directory}: {e}")
        
        return sorted(audio_files)

    def load_playlist(self, playlist_file: str) -> List[str]:
        """Load playlist from M3U file."""
        playlist = []
        
        try:
            with open(playlist_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        if os.path.exists(line):
                            playlist.append(line)
                        else:
                            self.logger.warning(f"File not found in playlist: {line}")
            
            self.logger.info(f"Loaded playlist with {len(playlist)} tracks")
            
        except Exception as e:
            self.logger.error(f"Error loading playlist {playlist_file}: {e}")
        
        return playlist

    def save_playlist(self, playlist: List[str], filename: str) -> bool:
        """Save playlist to M3U file."""
        try:
            playlist_dir = Path(self.config.get('DEFAULT', 'playlist_directory'))
            playlist_dir.mkdir(parents=True, exist_ok=True)
            
            playlist_path = playlist_dir / f"{filename}.m3u"
            
            with open(playlist_path, 'w', encoding='utf-8') as f:
                f.write("#EXTM3U\n")
                for track in playlist:
                    f.write(f"{track}\n")
            
            self.logger.info(f"Playlist saved to {playlist_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error saving playlist: {e}")
            return False

    def start_playback(self, file_path: str) -> bool:
        """Start playing a single file."""
        try:
            # Stop any current playback
            self.stop_playback()
            
            # Build mpg123 command
            cmd = ['mpg123', '--stereo', '--buffer', '1024']
            
            # Add volume control if supported
            if self.volume != 100:
                cmd.extend(['--scale', str(self.volume)])
            
            cmd.append(file_path)
            
            # Start mpg123 process
            self.mpg123_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True
            )
            
            self.is_playing = True
            self.is_paused = False
            
            # Get track info
            track_name = os.path.basename(file_path)
            self.logger.info(f"Now playing: {track_name}")
            
            if not self.daemon_mode:
                print(f"\n🎵 Now Playing: {track_name}")
                print(f"Volume: {self.volume}% | Shuffle: {'ON' if self.shuffle_mode else 'OFF'} | Repeat: {'ON' if self.repeat_mode else 'OFF'}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error starting playback: {e}")
            return False

    def stop_playback(self) -> None:
        """Stop current playback."""
        if self.mpg123_process:
            try:
                self.mpg123_process.terminate()
                self.mpg123_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.mpg123_process.kill()
            except Exception as e:
                self.logger.error(f"Error stopping playback: {e}")
            finally:
                self.mpg123_process = None
        
        self.is_playing = False
        self.is_paused = False

    def pause_playback(self) -> None:
        """Pause/resume playback."""
        if self.mpg123_process and self.is_playing:
            try:
                if self.is_paused:
                    # Resume (send SIGCONT)
                    self.mpg123_process.send_signal(signal.SIGCONT)
                    self.is_paused = False
                    self.logger.info("Playback resumed")
                    if not self.daemon_mode:
                        print("▶️  Resumed")
                else:
                    # Pause (send SIGSTOP)
                    self.mpg123_process.send_signal(signal.SIGSTOP)
                    self.is_paused = True
                    self.logger.info("Playback paused")
                    if not self.daemon_mode:
                        print("⏸️  Paused")
            except Exception as e:
                self.logger.error(f"Error pausing/resuming playback: {e}")

    def next_track(self) -> None:
        """Skip to next track."""
        if not self.playlist:
            return
        
        if self.shuffle_mode:
            self.current_index = random.randint(0, len(self.playlist) - 1)
        else:
            self.current_index = (self.current_index + 1) % len(self.playlist)
        
        self.play_current_track()

    def previous_track(self) -> None:
        """Skip to previous track."""
        if not self.playlist:
            return
        
        if self.shuffle_mode:
            self.current_index = random.randint(0, len(self.playlist) - 1)
        else:
            self.current_index = (self.current_index - 1) % len(self.playlist)
        
        self.play_current_track()

    def play_current_track(self) -> None:
        """Play the current track in the playlist."""
        if self.playlist and 0 <= self.current_index < len(self.playlist):
            self.start_playback(self.playlist[self.current_index])

    def set_volume(self, volume: int) -> None:
        """Set playback volume (0-100)."""
        self.volume = max(0, min(100, volume))
        self.logger.info(f"Volume set to {self.volume}%")
        
        if not self.daemon_mode:
            print(f"🔊 Volume: {self.volume}%")
        
        # Restart playback with new volume if currently playing
        if self.is_playing and not self.is_paused:
            current_file = self.playlist[self.current_index] if self.playlist else None
            if current_file:
                self.start_playback(current_file)

    def toggle_shuffle(self) -> None:
        """Toggle shuffle mode."""
        self.shuffle_mode = not self.shuffle_mode
        self.logger.info(f"Shuffle mode: {'ON' if self.shuffle_mode else 'OFF'}")
        
        if not self.daemon_mode:
            print(f"🔀 Shuffle: {'ON' if self.shuffle_mode else 'OFF'}")

    def toggle_repeat(self) -> None:
        """Toggle repeat mode."""
        self.repeat_mode = not self.repeat_mode
        self.logger.info(f"Repeat mode: {'ON' if self.repeat_mode else 'OFF'}")
        
        if not self.daemon_mode:
            print(f"🔁 Repeat: {'ON' if self.repeat_mode else 'OFF'}")

    def _setup_terminal(self) -> None:
        """Set up terminal for non-blocking input."""
        if not self.daemon_mode:
            try:
                self.old_terminal_settings = termios.tcgetattr(sys.stdin)
                tty.setraw(sys.stdin.fileno())
            except Exception:
                pass  # Not a terminal or not supported

    def _restore_terminal(self) -> None:
        """Restore terminal settings."""
        if self.old_terminal_settings:
            try:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, self.old_terminal_settings)
            except Exception:
                pass

    def _get_key_input(self) -> Optional[str]:
        """Get non-blocking keyboard input."""
        if self.daemon_mode:
            return None
        
        try:
            if select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], []):
                return sys.stdin.read(1)
        except Exception:
            pass
        
        return None

    def _show_help(self) -> None:
        """Display help information."""
        help_text = """
🎵 CLI Music Player - Controls:

SPACE or p    - Play/Pause
n or →        - Next track  
b or ←        - Previous track
s             - Toggle shuffle
r             - Toggle repeat
+ or =        - Volume up
- or _        - Volume down
q or ESC      - Quit
h or ?        - Show this help
l             - List current playlist
c             - Clear playlist

Currently Playing: """ + (os.path.basename(self.playlist[self.current_index]) if self.playlist else "None")
        
        print(help_text)

    def _playback_monitor(self) -> None:
        """Monitor playback and handle track transitions."""
        while True:
            if self.mpg123_process and self.is_playing:
                # Check if process has ended
                if self.mpg123_process.poll() is not None:
                    # Track ended, play next if repeat is on
                    if self.repeat_mode and self.playlist:
                        self.next_track()
                    else:
                        self.is_playing = False
                        if not self.daemon_mode:
                            print("\n🎵 Playback finished")
                        break
            
            time.sleep(1)

    def run_interactive(self) -> None:
        """Run the interactive music player."""
        if not self._check_dependencies():
            return
        
        self._setup_terminal()
        
        try:
            print("🎵 CLI Music Player v1.0.0")
            print("=" * 40)
            print("Loading configuration...")
            
            # Load default music directory if no playlist
            if not self.playlist:
                music_dir = self.config.get('DEFAULT', 'music_directory')
                if os.path.exists(music_dir):
                    print(f"Scanning music directory: {music_dir}")
                    self.playlist = self.scan_directory(music_dir)
                    if self.playlist:
                        print(f"Found {len(self.playlist)} audio files")
                    else:
                        print("No audio files found")
                        return
            
            # Apply config settings
            self.volume = self.config.getint('DEFAULT', 'default_volume', fallback=70)
            self.shuffle_mode = self.config.getboolean('PLAYBACK', 'shuffle', fallback=False)
            self.repeat_mode = self.config.getboolean('PLAYBACK', 'repeat', fallback=True)
            
            # Start playback if autoplay is enabled
            if self.config.getboolean('PLAYBACK', 'autoplay', fallback=False) and self.playlist:
                self.play_current_track()
            
            print("\nControls: [SPACE] Play/Pause | [n] Next | [q] Quit | [h] Help")
            print("Press 'h' for full help\n")
            
            # Start playback monitor thread
            self.playback_thread = threading.Thread(target=self._playback_monitor, daemon=True)
            self.playback_thread.start()
            
            # Main control loop
            while True:
                key = self._get_key_input()
                
                if key:
                    if key in ['q', '\x1b']:  # q or ESC
                        break
                    elif key in [' ', 'p']:  # SPACE or p
                        if self.playlist:
                            if not self.is_playing:
                                self.play_current_track()
                            else:
                                self.pause_playback()
                    elif key in ['n', '\x1b[C']:  # n or right arrow
                        self.next_track()
                    elif key in ['b', '\x1b[D']:  # b or left arrow
                        self.previous_track()
                    elif key == 's':
                        self.toggle_shuffle()
                    elif key == 'r':
                        self.toggle_repeat()
                    elif key in ['+', '=']:
                        self.set_volume(self.volume + 5)
                    elif key in ['-', '_']:
                        self.set_volume(self.volume - 5)
                    elif key in ['h', '?']:
                        self._show_help()
                    elif key == 'l':
                        self._list_playlist()
                    elif key == 'c':
                        self._clear_playlist()
                
                time.sleep(0.1)
        
        finally:
            self.stop_playback()
            self._restore_terminal()
            print("\n👋 Goodbye!")

    def _list_playlist(self) -> None:
        """List current playlist."""
        if not self.playlist:
            print("📝 Playlist is empty")
            return
        
        print(f"\n📝 Current Playlist ({len(self.playlist)} tracks):")
        for i, track in enumerate(self.playlist[:10]):  # Show first 10
            marker = "▶️ " if i == self.current_index else "   "
            print(f"{marker}{i+1:2d}. {os.path.basename(track)}")
        
        if len(self.playlist) > 10:
            print(f"   ... and {len(self.playlist) - 10} more tracks")

    def _clear_playlist(self) -> None:
        """Clear current playlist."""
        self.stop_playback()
        self.playlist.clear()
        self.current_index = 0
        print("🗑️  Playlist cleared")

    def run_daemon(self, music_directory: str) -> None:
        """Run as daemon service."""
        if not self._check_dependencies():
            return
        
        self.daemon_mode = True
        self.logger.info("Starting music player daemon")
        
        # Load playlist
        if os.path.exists(music_directory):
            self.playlist = self.scan_directory(music_directory)
            self.logger.info(f"Loaded {len(self.playlist)} tracks")
        else:
            self.logger.error(f"Music directory not found: {music_directory}")
            return
        
        # Apply config
        self.volume = self.config.getint('DEFAULT', 'default_volume', fallback=70)
        self.shuffle_mode = self.config.getboolean('PLAYBACK', 'shuffle', fallback=False)
        self.repeat_mode = self.config.getboolean('PLAYBACK', 'repeat', fallback=True)
        
        # Start playback
        if self.playlist:
            self.play_current_track()
        
        # Start monitor thread
        self.playback_thread = threading.Thread(target=self._playback_monitor, daemon=True)
        self.playback_thread.start()
        
        # Keep daemon running
        try:
            while True:
                time.sleep(60)  # Wake up every minute
                
                # Auto-advance if not playing and repeat is on
                if not self.is_playing and self.repeat_mode and self.playlist:
                    self.next_track()
                    
        except KeyboardInterrupt:
            self.logger.info("Daemon stopped by user")
        finally:
            self.stop_playback()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="CLI Music Player using mpg123")
    
    parser.add_argument('--file', '-f', help='Play a single file')
    parser.add_argument('--directory', '-d', help='Play all files in directory')
    parser.add_argument('--playlist', '-p', help='Load and play M3U playlist')
    parser.add_argument('--volume', '-v', type=int, default=70, help='Set volume (0-100)')
    parser.add_argument('--shuffle', '-s', action='store_true', help='Enable shuffle mode')
    parser.add_argument('--repeat', '-r', action='store_true', help='Enable repeat mode')
    parser.add_argument('--daemon', action='store_true', help='Run as daemon')
    parser.add_argument('--config', '-c', default='/etc/music-player/music_player.conf', 
                       help='Config file path')
    parser.add_argument('--create-playlist', help='Create playlist with given name')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], 
                       default='INFO', help='Set log level')
    
    args = parser.parse_args()
    
    # Create player instance
    player = MusicPlayer(config_file=args.config)
    player.logger.setLevel(getattr(logging, args.log_level))
    
    # Set initial volume
    player.set_volume(args.volume)
    
    # Set modes
    if args.shuffle:
        player.shuffle_mode = True
    if args.repeat:
        player.repeat_mode = True
    
    try:
        # Handle different input sources
        if args.file:
            if os.path.exists(args.file):
                player.playlist = [args.file]
                player.logger.info(f"Added single file: {args.file}")
            else:
                print(f"Error: File not found: {args.file}")
                return 1
        
        elif args.directory:
            if os.path.exists(args.directory):
                player.playlist = player.scan_directory(args.directory)
                player.logger.info(f"Scanned directory: {args.directory}")
            else:
                print(f"Error: Directory not found: {args.directory}")
                return 1
        
        elif args.playlist:
            if os.path.exists(args.playlist):
                player.playlist = player.load_playlist(args.playlist)
                player.logger.info(f"Loaded playlist: {args.playlist}")
            else:
                print(f"Error: Playlist not found: {args.playlist}")
                return 1
        
        elif args.create_playlist:
            if args.directory:
                files = player.scan_directory(args.directory)
                if player.save_playlist(files, args.create_playlist):
                    print(f"Playlist '{args.create_playlist}' created successfully")
                    return 0
                else:
                    print("Error creating playlist")
                    return 1
            else:
                print("Error: --directory required when creating playlist")
                return 1
        
        # Run player
        if args.daemon:
            music_dir = args.directory or player.config.get('DEFAULT', 'music_directory')
            player.run_daemon(music_dir)
        else:
            player.run_interactive()
        
        return 0
        
    except KeyboardInterrupt:
        player.logger.info("Interrupted by user")
        return 0
    except Exception as e:
        player.logger.error(f"Unexpected error: {e}")
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())