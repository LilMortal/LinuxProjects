#!/bin/bash
# File Auto-Renamer Installation Script

set -e

INSTALL_DIR="/opt/file-auto-renamer"
SERVICE_NAME="file-renamer"
CURRENT_USER=$(whoami)

echo "🚀 Installing File Auto-Renamer..."

# Check if running as root for system installation
if [[ $EUID -eq 0 ]]; then
    echo "Installing system-wide..."
    SYSTEM_INSTALL=true
else
    echo "Installing for current user..."
    SYSTEM_INSTALL=false
    INSTALL_DIR="$HOME/.local/share/file-auto-renamer"
fi

# Create installation directory
echo "📁 Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"/{src,config,logs,systemd,cron}

# Copy files
echo "📋 Copying files..."
cp -r src/* "$INSTALL_DIR/src/"
cp -r config/* "$INSTALL_DIR/config/"
cp -r systemd/* "$INSTALL_DIR/systemd/"
cp -r cron/* "$INSTALL_DIR/cron/"
cp requirements.txt "$INSTALL_DIR/"

# Make script executable
chmod +x "$INSTALL_DIR/src/file_renamer.py"

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
if command -v pip3 &> /dev/null; then
    pip3 install -r "$INSTALL_DIR/requirements.txt"
elif command -v pip &> /dev/null; then
    pip install -r "$INSTALL_DIR/requirements.txt"
else
    echo "⚠️  Warning: pip not found. Please install the watchdog package manually:"
    echo "   sudo apt install python3-pip"
    echo "   pip3 install watchdog"
fi

# Create symlink for easy access
if [[ $SYSTEM_INSTALL == true ]]; then
    echo "🔗 Creating system symlink..."
    ln -sf "$INSTALL_DIR/src/file_renamer.py" /usr/local/bin/file-renamer
    
    # Install systemd service
    echo "⚙️  Installing systemd service..."
    cp "$INSTALL_DIR/systemd/file-renamer.service" /etc/systemd/system/
    systemctl daemon-reload
    
    echo "✅ System installation complete!"
    echo ""
    echo "To start the service:"
    echo "  sudo systemctl enable file-renamer@$CURRENT_USER"
    echo "  sudo systemctl start file-renamer@$CURRENT_USER"
    echo ""
    echo "To check service status:"
    echo "  sudo systemctl status file-renamer@$CURRENT_USER"
    
else
    echo "🔗 Creating user symlink..."
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/src/file_renamer.py" "$HOME/.local/bin/file-renamer"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "📝 Added ~/.local/bin to PATH in ~/.bashrc"
        echo "   Please run: source ~/.bashrc"
    fi
    
    echo "✅ User installation complete!"
    echo ""
    echo "To run manually:"
    echo "  $HOME/.local/bin/file-renamer"
    echo ""
    echo "To set up with cron, edit your crontab:"
    echo "  crontab -e"
    echo "  (See examples in $INSTALL_DIR/cron/file-renamer.cron)"
fi

echo ""
echo "📝 Configuration file: $INSTALL_DIR/config/renamer.conf"
echo "📊 Logs location: $INSTALL_DIR/logs/file_renamer.log"
echo ""
echo "🎉 Installation complete! Happy file renaming!"