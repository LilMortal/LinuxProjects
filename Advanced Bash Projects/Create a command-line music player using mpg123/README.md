# 🎵 CLI Music Player

A feature-rich command-line music player built with Python and mpg123, designed for Linux systems.

## Overview

CLI Music Player is a lightweight, terminal-based music player that provides an intuitive interface for playing audio files. Built as a wrapper around the powerful mpg123 audio player, it offers playlist management, playback controls, and automation capabilities perfect for headless servers or terminal enthusiasts.

## Features

- **Multi-format Support**: MP3, WAV, and other formats supported by mpg123
- **Playlist Management**: Create, save, and load playlists
- **Playback Controls**: Play, pause, stop, skip, previous track
- **Random/Shuffle Mode**: Randomize your listening experience
- **Volume Control**: Adjust playback volume on-the-fly
- **Logging**: Comprehensive logging to file and syslog
- **Configuration**: Customizable settings via config file
- **Automation Ready**: SystemD service and cron job support
- **Terminal UI**: Clean, responsive terminal interface
- **Recursive Directory Scanning**: Automatically find music files

## Requirements

- **OS**: Ubuntu 22.04+ (or any standard Linux distribution)
- **Python**: 3.8+
- **Dependencies**:
  - `mpg123` (audio player engine)
  - `python3-pip` (for Python package management)
  - Standard Python libraries (no external packages required)

## Installation

### 1. Clone or Download the Project

```bash
# Clone the repository (if using git)
git clone https://github.com/yourusername/cli-music-player.git
cd cli-music-player

# Or create the directory structure manually
mkdir -p cli-music-player/{src,config,systemd,logs}
cd cli-music-player
```

### 2. Install System Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install mpg123 python3 python3-pip

# CentOS/RHEL/Fedora
sudo yum install mpg123 python3 python3-pip
# or
sudo dnf install mpg123 python3 python3-pip
```

### 3. Set Up the Project

```bash
# Make the install script executable
chmod +x install.sh

# Run the installation script
sudo ./install.sh

# Or install manually:
sudo cp src/music_player.py /usr/local/bin/music-player
sudo chmod +x /usr/local/bin/music-player
sudo cp config/music_player.conf /etc/music-player/
sudo mkdir -p /var/log/music-player
```

## Configuration

The configuration file is located at `/etc/music-player/music_player.conf`:

```ini
[DEFAULT]
# Default music directory
music_directory = /home/user/Music

# Log file location
log_file = /var/log/music-player/music_player.log

# Default volume (0-100)
default_volume = 70

# Enable syslog logging
use_syslog = true

# Default playlist location
playlist_directory = /home/user/.local/share/music-player/playlists

[PLAYBACK]
# Shuffle mode by default
shuffle = false

# Repeat playlist
repeat = true

# Auto-play on startup
autoplay = false
```

### Environment Variables

You can also configure using environment variables:

```bash
export MUSIC_PLAYER_DIR="/path/to/music"
export MUSIC_PLAYER_VOLUME="80"
export MUSIC_PLAYER_LOG="/path/to/logfile"
```

## Usage

### Basic Commands

```bash
# Start the music player
music-player

# Play a specific file
music-player --file /path/to/song.mp3

# Play all files in a directory
music-player --directory /path/to/music/folder

# Load and play a playlist
music-player --playlist /path/to/playlist.m3u

# Start with specific volume
music-player --volume 60

# Enable shuffle mode
music-player --shuffle

# Run in background/daemon mode
music-player --daemon --directory /home/user/Music
```

### Interactive Controls

Once the player is running, use these keyboard shortcuts:

```
SPACE or p    - Play/Pause
n or →        - Next track
b or ←        - Previous track
s             - Toggle shuffle
r             - Toggle repeat
+ or =        - Volume up
- or _        - Volume down
q or ESC      - Quit
h or ?        - Show help
l             - List current playlist
c             - Clear playlist
a             - Add file/directory to playlist
```

### Advanced Usage

```bash
# Create a playlist from directory
music-player --create-playlist "My Playlist" --directory /home/user/Music/Rock

# Play random album
music-player --random-album --directory /home/user/Music

# Start with specific log level
music-player --log-level DEBUG --directory /home/user/Music

# Run with custom config
music-player --config /path/to/custom.conf
```

## Automation

### SystemD Service

To run the music player as a system service:

```bash
# Copy the service file
sudo cp systemd/music-player.service /etc/systemd/system/

# Edit the service file to match your user and music directory
sudo nano /etc/systemd/system/music-player.service

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable music-player.service
sudo systemctl start music-player.service

# Check service status
sudo systemctl status music-player.service
```

### Cron Job Examples

Add to your crontab (`crontab -e`):

```bash
# Play music every morning at 7 AM
0 7 * * * /usr/local/bin/music-player --daemon --directory /home/user/Music/Morning --volume 50

# Create daily playlist at midnight
0 0 * * * /usr/local/bin/music-player --create-playlist "Daily-$(date +%Y%m%d)" --directory /home/user/Music --shuffle

# Stop music at 10 PM
0 22 * * * pkill -f music-player
```

## Logging

### Log Locations

- **Main log file**: `/var/log/music-player/music_player.log`
- **System log**: Check with `journalctl -u music-player`
- **Error log**: `/var/log/music-player/errors.log`

### Log Levels

- **INFO**: General playback information
- **DEBUG**: Detailed operation logs
- **WARNING**: Non-critical issues
- **ERROR**: Critical errors and failures

### Checking Logs

```bash
# View recent logs
tail -f /var/log/music-player/music_player.log

# View system service logs
journalctl -u music-player -f

# View last 50 log entries
journalctl -u music-player -n 50

# View logs for specific date
journalctl -u music-player --since "2024-01-01" --until "2024-01-02"
```

## Security Tips

### File Permissions

```bash
# Set proper permissions for the executable
sudo chmod 755 /usr/local/bin/music-player

# Secure the config file
sudo chmod 644 /etc/music-player/music_player.conf
sudo chown root:root /etc/music-player/music_player.conf

# Set log directory permissions
sudo chmod 775 /var/log/music-player
sudo chown user:adm /var/log/music-player
```

### Running as Non-Root

Always run the music player as a regular user, not root:

```bash
# Create a dedicated user for the service
sudo useradd -r -s /bin/false musicplayer

# Update systemd service to use the dedicated user
sudo systemctl edit music-player.service
```

### Network Security

If running as a service, consider:
- Firewall rules if exposing any network interfaces
- Running in a restricted environment or container
- Regular security updates for mpg123 and system packages

## Example Output

### Startup Output
```
🎵 CLI Music Player v1.0.0
=====================================
Loading configuration from /etc/music-player/music_player.conf
Scanning music directory: /home/user/Music
Found 1,247 audio files
Current playlist: 8 tracks loaded

Now Playing: Artist - Song Title [03:42]
Volume: 70% | Shuffle: OFF | Repeat: ON

Controls: [SPACE] Play/Pause | [n] Next | [q] Quit | [h] Help
```

### Playback Log
```
2024-01-15 14:30:15 [INFO] Music player started
2024-01-15 14:30:15 [INFO] Loaded playlist: 8 tracks
2024-01-15 14:30:16 [INFO] Now playing: /home/user/Music/rock/song1.mp3
2024-01-15 14:33:58 [INFO] Track completed, advancing to next
2024-01-15 14:33:59 [INFO] Now playing: /home/user/Music/jazz/song2.mp3
2024-01-15 14:35:12 [INFO] User skipped track
2024-01-15 14:35:12 [INFO] Now playing: /home/user/Music/blues/song3.mp3
```

### SystemD Service Status
```bash
$ sudo systemctl status music-player
● music-player.service - CLI Music Player Service
     Loaded: loaded (/etc/systemd/system/music-player.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2024-01-15 14:30:00 UTC; 2h 5min ago
   Main PID: 12345 (python3)
      Tasks: 3 (limit: 4915)
     Memory: 25.6M
        CPU: 1.234s
     CGroup: /system.slice/music-player.service
             ├─12345 python3 /usr/local/bin/music-player --daemon
             └─12346 mpg123 /home/user/Music/current_track.mp3

Jan 15 14:30:00 hostname systemd[1]: Started CLI Music Player Service.
Jan 15 14:30:01 hostname music-player[12345]: Music player daemon started
Jan 15 16:35:12 hostname music-player[12345]: Now playing: Artist - Song Title
```

## Author and License

**Author**: Your Name <your.email@example.com>  
**Version**: 1.0.0  
**License**: MIT License

```
MIT License

Copyright (c) 2024 Your Name

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

For issues, feature requests, or contributions, please visit: https://github.com/yourusername/cli-music-player