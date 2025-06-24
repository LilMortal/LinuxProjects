#!/bin/bash

# RemoteDeploy Setup Script
# This script helps set up the RemoteDeploy system on Ubuntu 22.04+

set -e

echo "🚀 RemoteDeploy Setup Script"
echo "============================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   exit 1
fi

# Check Ubuntu version
if ! lsb_release -a 2>/dev/null | grep -q "Ubuntu"; then
    print_warning "This script is designed for Ubuntu. Proceed with caution on other distributions."
fi

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js (using NodeSource repository for latest LTS)
print_status "Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    print_success "Node.js installed: $(node --version)"
else
    print_success "Node.js already installed: $(node --version)"
fi

# Install Git
print_status "Installing Git..."
if ! command -v git &> /dev/null; then
    sudo apt install -y git
    print_success "Git installed: $(git --version)"
else
    print_success "Git already installed: $(git --version)"
fi

# Install other required packages
print_status "Installing additional packages..."
sudo apt install -y curl wget openssh-client rsync

# Create application directory
APP_DIR="/opt/remote-deploy"
print_status "Creating application directory at $APP_DIR..."
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Create logs directory
print_status "Creating logs directory..."
mkdir -p logs

# Set up SSH directory with proper permissions
print_status "Setting up SSH configuration..."
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p $HOME/.ssh
    chmod 700 $HOME/.ssh
fi

# Generate SSH key if it doesn't exist
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    print_status "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -C "remote-deploy@$(hostname)" -f $HOME/.ssh/id_rsa -N ""
    chmod 600 $HOME/.ssh/id_rsa
    chmod 644 $HOME/.ssh/id_rsa.pub
    print_success "SSH key pair generated"
    print_status "Your public key is:"
    cat $HOME/.ssh/id_rsa.pub
    echo ""
    print_warning "Copy this public key to your deployment target servers using:"
    print_warning "ssh-copy-id user@your-server.com"
else
    print_success "SSH key pair already exists"
fi

# Install PM2 for process management (optional)
print_status "Installing PM2 for process management..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    print_success "PM2 installed globally"
else
    print_success "PM2 already installed"
fi

# Create systemd service file
print_status "Creating systemd service file..."
sudo tee /etc/systemd/system/remote-deploy.service > /dev/null <<EOF
[Unit]
Description=RemoteDeploy Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER
WorkingDirectory=$PWD
ExecStart=/usr/bin/node server/index.js
Environment=NODE_ENV=production
Environment=PORT=3001

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
print_status "Configuring systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable remote-deploy
print_success "RemoteDeploy service enabled"

# Set up firewall (optional)
print_status "Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 3001/tcp comment "RemoteDeploy"
    print_success "Firewall rule added for port 3001"
else
    print_warning "UFW not found. Consider setting up firewall rules manually."
fi

# Create environment file from example
if [ ! -f .env ]; then
    print_status "Creating environment file..."
    cp .env.example .env
    print_success "Environment file created. Please edit .env with your settings."
else
    print_warning "Environment file already exists"
fi

# Set proper file permissions
print_status "Setting file permissions..."
chmod +x scripts/*.sh
find . -name "*.log" -exec chmod 644 {} \; 2>/dev/null || true

print_success "Setup completed successfully!"
echo ""
print_status "Next steps:"
echo "1. Edit the .env file with your configuration"
echo "2. Install dependencies: npm install"
echo "3. Build the application: npm run build"
echo "4. Start the service: sudo systemctl start remote-deploy"
echo "5. Check service status: sudo systemctl status remote-deploy"
echo "6. Access the application at: http://localhost:3001"
echo ""
print_warning "Don't forget to:"
echo "- Copy your SSH public key to target servers"
echo "- Configure your deployment targets in the web interface"
echo "- Test connections before deploying"
echo ""
print_success "Happy deploying! 🚀"