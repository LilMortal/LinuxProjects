#!/bin/bash

# RemoteDeploy Backup Script
# Creates backups of deployment configurations and logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="remote-deploy-backup-$TIMESTAMP"
FULL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Create backup directory
print_status "Creating backup directory..."
mkdir -p "$BACKUP_DIR"

# Create the backup
print_status "Creating backup: $BACKUP_NAME"
mkdir -p "$FULL_BACKUP_PATH"

# Backup logs
if [ -d "logs" ]; then
    print_status "Backing up logs..."
    cp -r logs "$FULL_BACKUP_PATH/"
    print_success "Logs backed up"
fi

# Backup configuration files
print_status "Backing up configuration files..."
cp .env "$FULL_BACKUP_PATH/" 2>/dev/null || print_status "No .env file found"
cp package.json "$FULL_BACKUP_PATH/"
cp README.md "$FULL_BACKUP_PATH/"

# Create metadata file
cat > "$FULL_BACKUP_PATH/backup-info.txt" << EOF
RemoteDeploy Backup Information
==============================
Backup Date: $(date)
Hostname: $(hostname)
User: $(whoami)
Working Directory: $(pwd)
Node Version: $(node --version 2>/dev/null || echo "Not installed")
NPM Version: $(npm --version 2>/dev/null || echo "Not installed")

Backup Contents:
- Application logs
- Configuration files
- Package information
EOF

# Compress the backup
print_status "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"
cd ..

print_success "Backup created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Clean up old backups (keep last 10)
print_status "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t *.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
cd ..

print_success "Backup process completed!"