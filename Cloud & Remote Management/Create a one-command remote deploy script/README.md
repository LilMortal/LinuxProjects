# RemoteDeploy - One-Command Remote Deployment System

A comprehensive web-based deployment management system that provides a beautiful interface for managing and executing remote deployments with one command.

## Overview

RemoteDeploy is a full-stack application that combines a React frontend with a Node.js backend to provide enterprise-grade deployment capabilities. It allows you to manage multiple servers, configure deployment pipelines, and execute deployments with comprehensive logging and monitoring.

## Features

- **🎯 One-Command Deployment**: Execute complex deployment workflows with a single click
- **🖥️ Beautiful Web Interface**: Modern, responsive UI with real-time updates
- **🔧 Server Management**: Add, configure, and monitor multiple deployment targets
- **📊 Deployment History**: Track all deployments with detailed logs and status
- **🔍 Real-time Logging**: Comprehensive logging system with filtering and search
- **🔐 SSH Integration**: Secure connections using SSH keys or passwords
- **⚙️ Flexible Configuration**: Support for pre/post-deploy commands, service restarts, and environment variables
- **📱 Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04+ (or any standard Linux distribution)
- **Node.js**: 18.0 or higher
- **npm**: 8.0 or higher
- **Git**: 2.0 or higher

### Server Requirements (for deployment targets)
- SSH access with key-based or password authentication
- Git installed on target servers
- Appropriate permissions for deployment directories
- `systemctl` access for service management (if using service restart features)

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/remote-deploy-system.git
cd remote-deploy-system
```

### 2. Install Dependencies
```bash
# Install all dependencies (frontend and backend)
npm install
```

### 3. Create Required Directories
```bash
# Create logs directory
mkdir -p logs

# Create SSH keys directory (optional)
mkdir -p ~/.ssh
```

### 4. Build the Frontend
```bash
npm run build
```

## Configuration

### Environment Variables
Create a `.env` file in the root directory (optional):

```bash
# Server Configuration
PORT=3001
NODE_ENV=production

# Logging Configuration
LOG_LEVEL=info
LOG_FILE_PATH=./logs/combined.log

# Security Configuration (for future use)
JWT_SECRET=your-secret-key-here
SESSION_SECRET=your-session-secret-here
```

### SSH Key Setup (Recommended)
For secure, password-less deployments, set up SSH keys:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to target servers
ssh-copy-id user@your-server.com
```

## Usage

### Starting the Application

#### Development Mode
```bash
# Start both frontend and backend in development
npm run dev

# Or start them separately
npm run server  # Backend only
npm run dev     # Frontend only (in another terminal)
```

#### Production Mode
```bash
# Build and start the production server
npm run build
npm run server
```

The application will be available at `http://localhost:3001`

### Basic Deployment Workflow

1. **Add Servers**: Navigate to the "Servers" tab and add your deployment targets
2. **Test Connections**: Use the "Test Connection" button to verify SSH access
3. **Configure Deployment**: Go to the "Deploy" tab and configure your deployment:
   - Select target server
   - Enter repository URL and branch
   - Configure build commands and deployment path
   - Set up pre/post-deploy commands
   - Define environment variables and services to restart
4. **Execute Deployment**: Click "Deploy Now" to start the deployment
5. **Monitor Progress**: Watch real-time logs and deployment status
6. **Review History**: Check the "History" tab for deployment records

### Example Deployment Configuration

```json
{
  "serverId": "server-123",
  "repositoryUrl": "https://github.com/user/my-app.git",
  "branch": "main",
  "buildCommand": "npm install && npm run build",
  "deployPath": "/var/www/html/my-app",
  "preDeployCommands": [
    "sudo systemctl stop nginx"
  ],
  "postDeployCommands": [
    "npm install --production",
    "chmod +x scripts/setup.sh",
    "./scripts/setup.sh"
  ],
  "backupBeforeDeploy": true,
  "restartServices": ["nginx", "pm2"],
  "environmentVariables": {
    "NODE_ENV": "production",
    "API_URL": "https://api.example.com"
  }
}
```

## Automation

### Systemd Service (Recommended)

Create a systemd service file for automatic startup:

```bash
sudo nano /etc/systemd/system/remote-deploy.service
```

```ini
[Unit]
Description=RemoteDeploy Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=deploy
WorkingDirectory=/opt/remote-deploy
ExecStart=/usr/bin/node server/index.js
Environment=NODE_ENV=production
Environment=PORT=3001

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable remote-deploy
sudo systemctl start remote-deploy
```

### Cron Job Alternative

For scheduled deployments, you can set up cron jobs:

```bash
# Edit crontab
crontab -e

# Add entries (example: deploy every day at 2 AM)
0 2 * * * curl -X POST http://localhost:3001/api/deploy -H "Content-Type: application/json" -d @/path/to/deploy-config.json
```

### Docker Deployment

Create a `Dockerfile`:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3001

USER node

CMD ["npm", "run", "server"]
```

Build and run:
```bash
docker build -t remote-deploy .
docker run -d -p 3001:3001 -v ./logs:/app/logs remote-deploy
```

## Logging

### Log Locations
- **Application Logs**: `./logs/combined.log`
- **Error Logs**: `./logs/error.log`
- **Console Output**: Real-time during development

### Log Levels
- **error**: Critical errors and failures
- **warn**: Warning messages and non-critical issues
- **info**: General information and successful operations
- **debug**: Detailed debugging information

### Viewing Logs

#### Through Web Interface
Navigate to the "Logs" tab in the application for:
- Real-time log viewing
- Filtering by log level
- Search functionality
- Log download capabilities

#### Command Line
```bash
# View all logs
tail -f logs/combined.log

# View only errors
tail -f logs/error.log

# Filter logs by deployment
grep "deployment" logs/combined.log

# View systemd service logs (if using systemd)
sudo journalctl -u remote-deploy -f
```

## Security Tips

### SSH Security
- **Use SSH Keys**: Always prefer SSH key authentication over passwords
- **Restrict Key Permissions**: Set proper file permissions on SSH keys
  ```bash
  chmod 600 ~/.ssh/id_rsa
  chmod 644 ~/.ssh/id_rsa.pub
  ```
- **Use Dedicated Deployment Keys**: Create separate SSH keys for deployment purposes

### Server Security
- **Principle of Least Privilege**: Grant only necessary permissions to deployment users
- **Firewall Configuration**: Restrict SSH access to specific IP addresses
- **Regular Updates**: Keep target servers updated with security patches
- **Monitor Access**: Regularly review deployment logs for suspicious activity

### Application Security
- **Environment Variables**: Store sensitive data in environment variables, not code
- **HTTPS**: Use HTTPS in production environments
- **Access Control**: Implement proper authentication and authorization (future enhancement)
- **Input Validation**: Validate all deployment configurations

### Network Security
```bash
# Example: Restrict SSH access with iptables
sudo iptables -A INPUT -p tcp --dport 22 -s YOUR_IP_ADDRESS -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP
```

## Example Output

### Successful Deployment Log
```
[2025-01-16T10:30:15.123Z] Connecting to server...
[2025-01-16T10:30:16.456Z] Connected successfully
[2025-01-16T10:30:16.789Z] Creating backup...
[2025-01-16T10:30:18.234Z] Backup created at /var/www/html.backup.1705401018234
[2025-01-16T10:30:18.567Z] Running pre-deploy commands...
[2025-01-16T10:30:18.890Z] Executing: sudo systemctl stop nginx
[2025-01-16T10:30:20.123Z] Deploying application...
[2025-01-16T10:30:20.456Z] Cloning repository...
[2025-01-16T10:30:25.789Z] Building application...
[2025-01-16T10:30:45.234Z] Setting environment variables...
[2025-01-16T10:30:45.567Z] Copying files to deployment directory...
[2025-01-16T10:30:50.890Z] Running post-deploy commands...
[2025-01-16T10:30:51.123Z] Executing: npm install --production
[2025-01-16T10:31:15.456Z] Restarting services...
[2025-01-16T10:31:15.789Z] Restarting nginx...
[2025-01-16T10:31:17.234Z] Cleaning up temporary files...
[2025-01-16T10:31:18.567Z] Deployment completed successfully!
```

### System Health Check
```bash
curl http://localhost:3001/api/health

{
  "status": "healthy",
  "timestamp": "2025-01-16T10:30:00.000Z",
  "version": "1.0.0"
}
```

### Systemd Status
```bash
sudo systemctl status remote-deploy

● remote-deploy.service - RemoteDeploy Service
   Loaded: loaded (/etc/systemd/system/remote-deploy.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2025-01-16 10:30:00 UTC; 2h 15min ago
 Main PID: 12345 (node)
    Tasks: 11 (limit: 2048)
   Memory: 45.2M
   CGroup: /system.slice/remote-deploy.service
           └─12345 /usr/bin/node server/index.js
```

## Author and License

**Author**: [Your Name](https://github.com/yourusername)  
**License**: MIT License

### MIT License

```
Copyright (c) 2025 [Your Name]

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

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/remote-deploy-system/issues) page
2. Review the logs in the "Logs" tab of the application
3. Check system logs: `sudo journalctl -u remote-deploy`
4. Create a new issue with detailed information about your problem

---

*RemoteDeploy - Making deployments simple, secure, and scalable.*