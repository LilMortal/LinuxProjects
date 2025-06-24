# Cloud VM Automation Dashboard

A beautiful, production-ready web application for automating cloud virtual machine creation and management across AWS and Google Cloud Platform.

## Overview

The Cloud VM Automation Dashboard provides a modern, intuitive interface for managing your cloud infrastructure. Built with React, TypeScript, and Tailwind CSS, it offers a comprehensive solution for creating, monitoring, and managing virtual machines across multiple cloud providers.

## Features

**Core Features**:
- **Multi-Cloud Support**: Seamlessly manage VMs across AWS and Google Cloud Platform
- **VM Lifecycle Management**: Create, start, stop, and delete virtual machines with a few clicks
- **Real-time Dashboard**: Monitor your infrastructure with live statistics and status updates
- **Advanced Filtering**: Search and filter VMs by name, provider, region, status, and tags
- **Bulk Operations**: Perform actions on multiple VMs simultaneously
- **Cost Tracking**: Monitor spending with cost estimates and alerts
- **Tag Management**: Organize and categorize your VMs with custom tags
- **IP Address Management**: Track and copy public/private IP addresses

**Design Elements**:
- **Modern UI**: Clean, professional design with smooth animations and micro-interactions
- **Responsive Layout**: Optimized for desktop, tablet, and mobile devices
- **Color-Coded Status**: Visual indicators for VM status, providers, and health
- **Intuitive Navigation**: Easy-to-use sidebar navigation with active state indicators
- **Loading States**: Beautiful loading animations and progress indicators
- **Error Handling**: Comprehensive error messages and validation feedback

## Requirements

- Node.js 16.0 or higher
- NPM or Yarn package manager
- Modern web browser (Chrome, Firefox, Safari, Edge)
- AWS CLI configured (for AWS integration)
- Google Cloud SDK configured (for GCP integration)

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/cloud-vm-automation-dashboard.git
   cd cloud-vm-automation-dashboard
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Start the development server**:
   ```bash
   npm run dev
   ```

4. **Open your browser** and navigate to `http://localhost:5173`

## Configuration

### Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
# AWS Configuration
VITE_AWS_ACCESS_KEY_ID=your_aws_access_key
VITE_AWS_SECRET_ACCESS_KEY=your_aws_secret_key
VITE_AWS_DEFAULT_REGION=us-east-1

# Google Cloud Configuration
VITE_GCP_PROJECT_ID=your_gcp_project_id
VITE_GCP_SERVICE_ACCOUNT=path_to_service_account.json

# Application Settings
VITE_APP_NAME=Cloud VM Dashboard
VITE_SESSION_TIMEOUT=30
```

### Cloud Provider Setup

#### AWS Setup
1. Create an IAM user with EC2 full access permissions
2. Generate access keys for the user
3. Configure AWS CLI: `aws configure`
4. Add the credentials to your environment variables

#### Google Cloud Setup
1. Create a new project in Google Cloud Console
2. Enable the Compute Engine API
3. Create a service account with Compute Admin role
4. Download the service account key JSON file
5. Set the path in your environment variables

## Usage

### Creating a New VM

1. **Navigate to Create VM** page from the sidebar
2. **Fill in the basic configuration**:
   - VM Name (e.g., "web-server-prod")
   - Cloud Provider (AWS or GCP)
   - Region selection
   - Instance type with cost estimates

3. **Configure image and security**:
   - AMI/Image ID
   - Key pair for SSH access
   - Security groups
   - Tags for organization

4. **Click "Create VM"** to deploy

**Example CLI equivalent**:
```bash
# AWS
aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type t3.medium \
  --key-name my-key-pair \
  --security-groups default \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server-prod}]'

# GCP
gcloud compute instances create web-server-prod \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=n2-standard-2 \
  --zone=us-central1-a
```

### Managing Existing VMs

1. **Go to VM List** to see all your virtual machines
2. **Use filters** to find specific VMs by:
   - Name or tags
   - Cloud provider
   - Status (running, stopped, pending)
   - Region

3. **Perform actions**:
   - Start/stop individual VMs
   - Delete VMs
   - Copy IP addresses
   - Bulk operations on selected VMs

### Monitoring Dashboard

The dashboard provides:
- **Total VM count** across all providers
- **Running vs stopped** VMs ratio
- **Provider distribution** (AWS vs GCP)
- **Monthly cost estimates**
- **Recent activity** timeline
- **Status indicators** for system health

## Automation

### Scheduled Operations (Future Enhancement)

The application can be extended with automation features:

#### Cron Job Example
```bash
# Auto-stop development VMs at night (save costs)
0 22 * * * /usr/local/bin/vm-scheduler stop --tag=development

# Auto-start VMs in the morning
0 8 * * 1-5 /usr/local/bin/vm-scheduler start --tag=development
```

#### Systemd Service Example
```ini
[Unit]
Description=Cloud VM Monitor
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/vm-monitor
Restart=always
User=cloudvm

[Install]
WantedBy=multi-user.target
```

## Logging

### Application Logs
- **Browser Console**: Development and debugging information
- **Network Tab**: API requests and responses
- **Local Storage**: User preferences and session data

### Cloud Provider Logs
- **AWS CloudTrail**: EC2 API calls and changes
- **GCP Cloud Logging**: Compute Engine operations
- **Activity History**: Track VM lifecycle events

**Check logs**:
```bash
# View browser console logs (F12 Developer Tools)
# AWS CloudTrail
aws logs describe-log-groups --log-group-name-prefix /aws/cloudtrail

# GCP Logging
gcloud logging logs list
```

## Security Tips

### Access Control
- **Use IAM roles** with minimal required permissions
- **Enable MFA** on cloud provider accounts
- **Rotate access keys** regularly (every 90 days)
- **Use temporary credentials** when possible

### Network Security
- **Configure security groups** with minimal required ports
- **Use VPCs** for network isolation
- **Enable logging** for all network traffic
- **Regular security audits** of open ports and access rules

### Key Management
- **Store SSH keys securely** (use SSH agent)
- **Use different key pairs** for different environments
- **Regular key rotation** for production systems

### Environment Variables
```bash
# Never commit secrets to version control
echo ".env" >> .gitignore

# Use environment-specific configurations
cp .env.example .env.production
```

## Example Output

### Dashboard View
```
┌─ Cloud VM Automation Dashboard ─────────────────────────┐
│                                                         │
│  📊 Total VMs: 12    🟢 Running: 8    ⏸️  Stopped: 4    │
│  ☁️  AWS: 7         🔵 GCP: 5        💰 Cost: $247/mo  │
│                                                         │
│  Recent Activity:                                       │
│  • web-server-prod (AWS) - Started 2 hours ago         │
│  • database-staging (GCP) - Created 1 day ago          │
│  • analytics-dev (AWS) - Stopped 3 days ago            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### VM List View
```
┌─ Virtual Machines ──────────────────────────────────────┐
│ Name              Provider  Region      Status   IP      │
├─────────────────────────────────────────────────────────┤
│ web-server-prod   AWS       us-east-1   🟢 Running      │
│ database-staging  GCP       us-central1 🟢 Running      │
│ analytics-dev     AWS       us-west-2   ⏸️  Stopped     │
│ test-env         GCP       europe-west1 🟡 Pending      │
└─────────────────────────────────────────────────────────┘
```

### Create VM Form
```
Create New VM
├── Basic Configuration
│   ├── VM Name: [web-server-prod        ]
│   ├── Provider: [AWS ▼]
│   ├── Region: [US East (N. Virginia) ▼]
│   └── Instance: [t3.medium - $35.04/mo ▼]
├── Image & Security
│   ├── Image ID: [ami-0123456789abcdef0  ]
│   └── Key Pair: [my-production-key     ]
└── [Cancel] [Create VM]
```

## Author and License

**Author**: Cloud Infrastructure Team  
**Email**: admin@cloudvm.com  
**License**: MIT License

### MIT License
```
Copyright (c) 2024 Cloud VM Automation Dashboard

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
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

**Contributing**: We welcome contributions! Please read our contributing guidelines and submit pull requests for any improvements.

**Support**: For support and questions, please open an issue on GitHub or contact our team.