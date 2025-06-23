#!/bin/bash
# CLI Music Player Installation Script
# Run as root: sudo ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/music-player"
LOG_DIR="/var/log/music-player"
SYSTEMD_DIR="/etc/systemd/system"
USER_NAME="musicplayer"

echo -e "${GREEN}🎵 CLI Music Player Installation${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check system requirements
echo "Checking system requirements..."

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is required but not installed${NC}"
    echo "Install with: apt install python3"
    exit 1
fi

# Check for mpg123
if ! command -v mpg123 &> /dev/null; then
    echo -e "${YELLOW}mpg123 not found. Installing...${NC}"
    if command -v apt &> /dev/null; then
        apt update && apt install -y mpg123
    elif command -v yum &> /dev/null; then
        yum install -y mpg123
    elif command -v dnf &> /dev/null; then
        dnf install -y mpg123
    else
        echo -e "${RED}Could not install mpg123. Please install manually.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ System requirements met${NC}"

# Create user for the service
echo "Creating system user..."
if ! id "$USER_NAME" &>/dev/null; then
    useradd -r -s /bin/false -d /home/$USER_NAME -m $USER_NAME
    usermod -a -G audio $USER_NAME
    echo -e "${GREEN}✓ Created user: $USER_NAME${NC}"
else
    echo -e "${YELLOW}✓ User $USER_NAME already exists${NC}"
fi

# Create directories
echo "Creating directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/home/$USER_NAME/Music"
mkdir -p "/home/$USER_NAME/.local/share/music-player/playlists"

# Set permissions
chown -R $USER_NAME:$USER_NAME "/home/$USER_NAME"
chown -R $USER_NAME:adm "$LOG_DIR"
chmod 755 "$CONFIG_DIR"
chmod 775 "$LOG_DIR"

echo -e "${GREEN}✓ Directories created${NC}"

# Install main script
echo "Installing music player..."
cp src/music_player.py "$INSTALL_DIR/music-player"
chmod +x "$INSTALL_DIR/music-player"
echo -e "${GREEN}✓ Installed to $INSTALL_DIR/music-player${NC}"

# Install configuration
echo "Installing configuration..."
if [[ ! -f "$CONFIG_DIR/music_player.conf" ]]; then
    cp config/music_player.conf "$CONFIG_DIR/"
    # Update config with correct user paths
    sed -i "s|/home/user/Music|/home/$USER_NAME/Music|g" "$CONFIG_DIR/music_player.conf"
    sed -i "s|/home/user/.local|/home/$USER_NAME/.local|g" "$CONFIG_DIR/music_player.conf"
    echo -e "${GREEN}✓ Configuration installed${NC}"
else
    echo -e "${YELLOW}✓ Configuration already exists (not overwritten)${NC}"
fi

# Install systemd service
echo "Installing systemd service..."
cp systemd/music-player.service "$SYSTEMD_DIR/"
# Update service file with correct user
sed -i "s|User=musicplayer|User=$USER_NAME|g" "$SYSTEMD_DIR/music-player.service"
sed -i "s|/home/musicplayer|/home/$USER_NAME|g" "$SYSTEMD_DIR/music-player.service"

# Set correct UID for XDG_RUNTIME_DIR
USER_UID=$(id -u $USER_NAME)
sed -i "s|XDG_RUNTIME_DIR=/run/user/1001|XDG_RUNTIME_DIR=/run/user/$USER_UID|g" "$SYSTEMD_DIR/music-player.service"

systemctl daemon-reload
echo -e "${GREEN}✓ Systemd service installed${NC}"

# Create sample music directory structure
echo "Setting up sample music directory..."
mkdir -p "/home/$USER_NAME/Music/"{Rock,Jazz,Classical,Pop}
chown -R $USER_NAME:$USER_NAME "/home/$USER_NAME/Music"

# Create a simple test playlist
cat > "/home/$USER_NAME/.local/share/music-player/playlists/sample.m3u" << EOF
#EXTM3U
# Sample playlist - add your music files here
# /home/$USER_NAME/Music/Rock/song1.mp3
# /home/$USER_NAME/Music/Jazz/song2.mp3
EOF
chown $USER_NAME:$USER_NAME "/home/$USER_NAME/.local/share/music-player/playlists/sample.m3u"

echo -e "${GREEN}✓ Sample directories created${NC}"

# Test installation
echo "Testing installation..."
if $INSTALL_DIR/music-player --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Installation test passed${NC}"
else
    echo -e "${RED}✗ Installation test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Add music files to /home/$USER_NAME/Music/"
echo "2. Test the player: music-player --directory /home/$USER_NAME/Music"
echo "3. Enable service: sudo systemctl enable music-player"
echo "4. Start service: sudo systemctl start music-player"
echo "5. Check status: sudo systemctl status music-player"
echo ""
echo "Configuration file: $CONFIG_DIR/music_player.conf"
echo "Log files: $LOG_DIR/"
echo "Playlists: /home/$USER_NAME/.local/share/music-player/playlists/"
echo ""
echo -e "${GREEN}Happy listening! 🎵${NC}"