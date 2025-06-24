# VPN Server Setup (WireGuard & OpenVPN)

A comprehensive guide to setting up secure VPN servers using WireGuard and OpenVPN on Linux systems. This project provides step-by-step instructions, configuration files, and scripts to deploy your own VPN infrastructure.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [WireGuard Setup](#wireguard-setup)
- [OpenVPN Setup](#openvpn-setup)
- [Security Configuration](#security-configuration)
- [Client Configuration](#client-configuration)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Contributing](#contributing)

## 🔍 Overview

This project demonstrates how to set up two popular VPN solutions:

- **WireGuard**: Modern, fast, and secure VPN with minimal configuration
- **OpenVPN**: Mature, feature-rich VPN solution with extensive compatibility

Both solutions provide secure remote access and can route client traffic through the VPN server for enhanced privacy and security.

### Why Choose WireGuard?
- ✅ Extremely fast performance
- ✅ Minimal configuration required
- ✅ Modern cryptography (ChaCha20, Poly1305, BLAKE2s)
- ✅ Small codebase (easier to audit)
- ✅ Built into Linux kernel (5.6+)

### Why Choose OpenVPN?
- ✅ Mature and battle-tested
- ✅ Extensive feature set
- ✅ Wide platform compatibility
- ✅ Flexible authentication methods
- ✅ Enterprise-grade features

## 🛠️ Prerequisites

### System Requirements
- Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / RHEL 8+
- Root or sudo access
- Public IP address
- Minimum 1GB RAM, 1 CPU core
- 10GB+ available disk space

### Network Requirements
- Open firewall ports:
  - WireGuard: UDP 51820 (default)
  - OpenVPN: UDP 1194 (default)
- IPv4 forwarding enabled
- NAT/masquerading configured

### Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y curl wget ufw iptables-persistent

# CentOS/RHEL
sudo dnf install -y curl wget firewalld
```

## 🔵 WireGuard Setup

### Step 1: Install WireGuard

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y wireguard wireguard-tools
```

#### CentOS/RHEL
```bash
sudo dnf install -y epel-release
sudo dnf install -y wireguard-tools
```

### Step 2: Generate Server Keys
```bash
# Create WireGuard directory
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

# Generate server private key
wg genkey | sudo tee server_private.key
sudo chmod 600 server_private.key

# Generate server public key
sudo cat server_private.key | wg pubkey | sudo tee server_public.key
```

### Step 3: Configure Server
Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
# Server's private key
PrivateKey = <SERVER_PRIVATE_KEY>

# Server's VPN IP address
Address = 10.0.0.1/24

# VPN subnet
ListenPort = 51820

# Save config and restart interface
SaveConfig = true

# Post-up and post-down scripts for NAT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configurations will be added here
# [Peer]
# PublicKey = <CLIENT_PUBLIC_KEY>
# AllowedIPs = 10.0.0.2/32
```

### Step 4: Enable IP Forwarding
```bash
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Step 5: Configure Firewall
```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 51820/udp
sudo ufw allow ssh
sudo ufw --force enable

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
```

### Step 6: Start WireGuard Service
```bash
# Enable and start WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Check status
sudo systemctl status wg-quick@wg0
sudo wg show
```

## 🔴 OpenVPN Setup

### Step 1: Install OpenVPN
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y openvpn easy-rsa

# CentOS/RHEL
sudo dnf install -y epel-release
sudo dnf install -y openvpn easy-rsa
```

### Step 2: Set Up Certificate Authority
```bash
# Create CA directory
sudo make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# Configure variables
sudo nano vars
```

Edit the `vars` file:
```bash
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="MyOrg"
export KEY_EMAIL="admin@myorg.com"
export KEY_OU="MyOrgUnit"
```

### Step 3: Build Certificate Authority
```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa init-pki
sudo ./easyrsa build-ca nopass
sudo ./easyrsa gen-req server nopass
sudo ./easyrsa sign-req server server
sudo ./easyrsa gen-dh
sudo openvpn --genkey --secret ta.key
```

### Step 4: Configure OpenVPN Server
Create `/etc/openvpn/server.conf`:

```conf
# Server listening port and protocol
port 1194
proto udp

# Virtual network device type
dev tun

# SSL/TLS root certificate, server certificate, and private key
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key

# Diffie-Hellman parameters
dh /etc/openvpn/easy-rsa/pki/dh.pem

# Network topology
topology subnet

# VPN subnet
server 10.8.0.0 255.255.255.0

# Maintain client-server connection
keepalive 10 120

# TLS authentication key
tls-auth /etc/openvpn/easy-rsa/ta.key 0

# Data channel cipher
cipher AES-256-GCM
auth SHA256

# Compression
compress lz4-v2
push "compress lz4-v2"

# Client-to-client communication
client-to-client

# Duplicate CN certificates
duplicate-cn

# Redirect client traffic through VPN
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Privileges and logging
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/status.log
log /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1
```

### Step 5: Configure Network Settings
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i tun0 -j ACCEPT
sudo iptables -A FORWARD -o tun0 -j ACCEPT

# Save iptables rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Step 6: Start OpenVPN Service
```bash
# Create log directory
sudo mkdir -p /var/log/openvpn

# Enable and start OpenVPN
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server

# Check status
sudo systemctl status openvpn@server
```

## 🔒 Security Configuration

### Firewall Rules
```bash
# Basic firewall setup
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 51820/udp  # WireGuard
sudo ufw allow 1194/udp   # OpenVPN
sudo ufw --force enable
```

### SSH Hardening
```bash
# Disable root login and password authentication
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Fail2ban Protection
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## 📱 Client Configuration

### WireGuard Client Setup

#### Generate Client Keys
```bash
# On server
cd /etc/wireguard
wg genkey | sudo tee client1_private.key
sudo cat client1_private.key | wg pubkey | sudo tee client1_public.key
```

#### Add Client to Server Config
```bash
# Add to /etc/wireguard/wg0.conf
[Peer]
PublicKey = <CLIENT1_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32

# Restart WireGuard
sudo systemctl restart wg-quick@wg0
```

#### Client Configuration File
Create `client1.conf`:
```ini
[Interface]
PrivateKey = <CLIENT1_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### OpenVPN Client Setup

#### Generate Client Certificate
```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa gen-req client1 nopass
sudo ./easyrsa sign-req client client1
```

#### Create Client Configuration
Create `client1.ovpn`:
```conf
client
dev tun
proto udp
remote <SERVER_PUBLIC_IP> 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client1.crt
key client1.key
tls-auth ta.key 1
cipher AES-256-GCM
auth SHA256
compress lz4-v2
verb 3
```

## 🔧 Troubleshooting

### Common Issues

#### WireGuard
```bash
# Check interface status
sudo wg show

# Check logs
sudo journalctl -u wg-quick@wg0 -f

# Test connectivity
ping 10.0.0.1
```

#### OpenVPN
```bash
# Check service status
sudo systemctl status openvpn@server

# View logs
sudo tail -f /var/log/openvpn/openvpn.log

# Test port connectivity
sudo netstat -tuln | grep 1194
```

### Network Debugging
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Check routes
ip route show

# Check NAT rules
sudo iptables -t nat -L -n -v
```

## ⚡ Performance Optimization

### WireGuard Optimization
```bash
# Increase network buffer sizes
echo 'net.core.rmem_default = 262144' | sudo tee -a /etc/sysctl.conf
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_default = 262144' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### OpenVPN Optimization
```bash
# Add to server.conf
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
fast-io
```

## 📊 Monitoring and Maintenance

### Monitoring Scripts
```bash
#!/bin/bash
# wireguard-monitor.sh
echo "WireGuard Status:"
sudo wg show

echo -e "\nConnected Clients:"
sudo wg show wg0 peers | wc -l

echo -e "\nTraffic Statistics:"
sudo wg show wg0 transfer
```

### Backup Configuration
```bash
#!/bin/bash
# backup-vpn-config.sh
DATE=$(date +%Y%m%d_%H%M%S)
sudo tar -czf "/backup/vpn-config-$DATE.tar.gz" \
    /etc/wireguard/ \
    /etc/openvpn/ \
    /etc/iptables/
```

### Update Management
```bash
# Regular updates
sudo apt update && sudo apt upgrade -y

# Reboot if required
if [ -f /var/run/reboot-required ]; then
    sudo reboot
fi
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [WireGuard](https://www.wireguard.com/) - Jason A. Donenfeld
- [OpenVPN](https://openvpn.net/) - OpenVPN Inc.
- Ubuntu and Debian communities for excellent documentation
- Security researchers who continuously improve VPN technologies

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [Issues](https://github.com/LilMortal/LinuxProjects/issues)
3. Create a new issue with detailed information
4. Join our community discussions

---

**⚠️ Security Notice**: Always keep your VPN server updated with the latest security patches. Regularly audit your configuration and monitor for suspicious activity.
