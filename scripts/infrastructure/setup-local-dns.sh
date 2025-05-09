#!/bin/bash

# Local DNS Setup Script
# This script sets up .local domain resolution using either mDNS or Dnsmasq
# Compatible with Debian/Ubuntu-based systems

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Local DNS Setup Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Set variables
METHOD="mdns"  # Default method - mdns or dnsmasq
SERVER_HOSTNAME="homelab-server"
LOCAL_DOMAIN="homelab.local"
SERVER_IP=$(hostname -I | awk '{print $1}')
DNS_SERVER_IP=$SERVER_IP
ROUTER_IP=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --method)
      METHOD="$2"
      shift 2
      ;;
    --hostname)
      SERVER_HOSTNAME="$2"
      shift 2
      ;;
    --domain)
      LOCAL_DOMAIN="$2"
      shift 2
      ;;
    --server-ip)
      SERVER_IP="$2"
      shift 2
      ;;
    --router-ip)
      ROUTER_IP="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate method
if [[ "$METHOD" != "mdns" && "$METHOD" != "dnsmasq" ]]; then
  echo "Invalid method: $METHOD. Must be 'mdns' or 'dnsmasq'"
  exit 1
fi

# If method is dnsmasq and router IP is not provided, try to guess it
if [[ "$METHOD" == "dnsmasq" && -z "$ROUTER_IP" ]]; then
  # Try to guess the router IP (default gateway)
  ROUTER_IP=$(ip route | grep default | awk '{print $3}')
  if [[ -z "$ROUTER_IP" ]]; then
    echo "Could not determine router IP. Please provide it with --router-ip"
    exit 1
  fi
  echo "Detected router IP: $ROUTER_IP"
fi

# Confirm settings with user
echo "This script will set up .local domain resolution with the following settings:"
echo "Method: $METHOD"
echo "Hostname: $SERVER_HOSTNAME"
echo "Domain: $LOCAL_DOMAIN"
echo "Server IP: $SERVER_IP"
if [[ "$METHOD" == "dnsmasq" ]]; then
  echo "Router IP: $ROUTER_IP"
fi

echo ""
read -p "Continue with these settings? (y/n): " CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo "Setup aborted by user"
  exit 1
fi

# Update system
echo "Updating system packages..."
apt update

# Setup based on method
if [[ "$METHOD" == "mdns" ]]; then
  # Install and configure Avahi (mDNS)
  echo "Installing Avahi (mDNS) packages..."
  apt install -y avahi-daemon avahi-utils

  # Set hostname
  echo "Setting hostname to $SERVER_HOSTNAME..."
  hostnamectl set-hostname $SERVER_HOSTNAME

  # Configure Avahi
  echo "Configuring Avahi..."
  cat > /etc/avahi/avahi-daemon.conf << EOF
[server]
host-name=$SERVER_HOSTNAME
domain-name=$LOCAL_DOMAIN
use-ipv4=yes
use-ipv6=no
allow-interfaces=eth0,eno1,enp0s3,enp1s0,wlan0
enable-dbus=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
publish-aaaa-on-ipv4=no

[reflector]
enable-reflector=yes

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=30
rlimit-stack=4194304
EOF

  # Create service definitions for common services
  echo "Creating service definitions..."
  
  # HTTP service
  cat > /etc/avahi/services/http.service << EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>Web Server</name>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>
  <service>
    <type>_https._tcp</type>
    <port>443</port>
  </service>
</service-group>
EOF

  # SSH service
  cat > /etc/avahi/services/ssh.service << EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>SSH Server</name>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
EOF

  # Proxmox service if it exists
  if command -v pveversion &> /dev/null; then
    cat > /etc/avahi/services/proxmox.service << EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>Proxmox VE</name>
  <service>
    <type>_https._tcp</type>
    <port>8006</port>
  </service>
</service-group>
EOF
  fi

  # Enable and start Avahi
  echo "Enabling and starting Avahi daemon..."
  systemctl enable avahi-daemon
  systemctl restart avahi-daemon

  # Verify
  echo "Testing mDNS resolution..."
  avahi-resolve -n $SERVER_HOSTNAME.local || echo "Could not resolve hostname yet. This might take a moment to propagate."

  # Inform about client requirements
  echo "
For client systems:
- Linux: Install avahi-daemon
- macOS: Already supported (Bonjour)
- Windows: Install Bonjour Print Services or iTunes
"

elif [[ "$METHOD" == "dnsmasq" ]]; then
  # Install and configure Dnsmasq
  echo "Installing Dnsmasq..."
  apt install -y dnsmasq

  # Backup original configuration
  if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
  fi

  # Configure Dnsmasq
  echo "Configuring Dnsmasq..."
  cat > /etc/dnsmasq.conf << EOF
# Basic settings
domain-needed
bogus-priv
no-resolv
no-poll

# Domain configuration
local=/$LOCAL_DOMAIN/
domain=$LOCAL_DOMAIN
expand-hosts

# Upstream DNS servers (using Cloudflare and Google)
server=1.1.1.1
server=8.8.8.8

# Listen on all interfaces
interface=*

# Fixed IPs for local hosts
address=/$SERVER_HOSTNAME.$LOCAL_DOMAIN/$SERVER_IP
address=/server.$LOCAL_DOMAIN/$SERVER_IP
address=/code.$LOCAL_DOMAIN/$SERVER_IP
address=/nginx.$LOCAL_DOMAIN/$SERVER_IP
EOF

  if command -v pveversion &> /dev/null; then
    echo "address=/proxmox.$LOCAL_DOMAIN/$SERVER_IP" >> /etc/dnsmasq.conf
  fi

  # Add additional hosts
  echo "127.0.0.1 localhost" > /etc/hosts
  echo "$SERVER_IP $SERVER_HOSTNAME.$LOCAL_DOMAIN $SERVER_HOSTNAME" >> /etc/hosts

  # Configure system to use local DNS
  echo "Configuring system to use local DNS..."
  
  # Back up resolv.conf
  cp /etc/resolv.conf /etc/resolv.conf.backup
  
  # Set localhost as nameserver
  echo "nameserver 127.0.0.1" > /etc/resolv.conf
  
  # Make resolv.conf immutable to prevent NetworkManager from changing it
  # This is optional and can be commented out if causing issues
  chattr +i /etc/resolv.conf

  # Enable and start Dnsmasq
  echo "Enabling and starting Dnsmasq..."
  systemctl enable dnsmasq
  systemctl restart dnsmasq

  # Verify
  echo "Testing DNS resolution..."
  host $SERVER_HOSTNAME.$LOCAL_DOMAIN localhost || echo "Could not resolve hostname yet. This might take a moment to propagate."

  # Create network configuration advice
  echo "
For client systems, set DNS server to $SERVER_IP

Router configuration advice:
1. Access your router admin page (usually at $ROUTER_IP)
2. Find DHCP or DNS settings
3. Set primary DNS server to $SERVER_IP
4. Keep a secondary public DNS (e.g., 1.1.1.1 or 8.8.8.8)

Alternative: Configure each client manually:
- Linux/macOS: Edit /etc/resolv.conf
- Windows: Network adapter DNS settings
"
fi

# Create hosts file entries for common services
echo "Creating additional host entries..."
if ! grep -q "$SERVER_IP $SERVER_HOSTNAME.$LOCAL_DOMAIN" /etc/hosts; then
  echo "$SERVER_IP $SERVER_HOSTNAME.$LOCAL_DOMAIN $SERVER_HOSTNAME" >> /etc/hosts
fi

# Add entries for common services
for SERVICE in code nginx server; do
  if ! grep -q "$SERVICE.$LOCAL_DOMAIN" /etc/hosts; then
    echo "$SERVER_IP $SERVICE.$LOCAL_DOMAIN $SERVICE" >> /etc/hosts
  fi
done

# Add proxmox entry if it exists
if command -v pveversion &> /dev/null && ! grep -q "proxmox.$LOCAL_DOMAIN" /etc/hosts; then
  echo "$SERVER_IP proxmox.$LOCAL_DOMAIN proxmox" >> /etc/hosts
fi

# Create a simple test page for checking resolution
echo "Creating test page..."
mkdir -p /var/www/html/dns-test
cat > /var/www/html/dns-test/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Homelab DNS Test</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            line-height: 1.6;
            padding: 2em;
            background-color: #f5f5f5;
            color: #333;
        }
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #222;
                color: #f0f0f0;
            }
            a {
                color: #6ea8fe;
            }
        }
        h1 { color: #486; }
        .success { color: #5a2; }
        .box {
            border: 1px solid #ddd;
            padding: 1em;
            margin: 1em 0;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <h1>Homelab DNS Resolution Test</h1>
    <p>If you can see this page, your <code>.local</code> domain resolution is working correctly!</p>
    
    <div class="box">
        <h2>DNS Configuration</h2>
        <p><strong>Method:</strong> $METHOD</p>
        <p><strong>Hostname:</strong> $SERVER_HOSTNAME</p>
        <p><strong>Domain:</strong> $LOCAL_DOMAIN</p>
        <p><strong>Server IP:</strong> $SERVER_IP</p>
    </div>

    <div class="box">
        <h2>Available Services</h2>
        <ul>
            <li><a href="http://$SERVER_HOSTNAME.$LOCAL_DOMAIN">Main Server ($SERVER_HOSTNAME.$LOCAL_DOMAIN)</a></li>
            <li><a href="http://nginx.$LOCAL_DOMAIN">Nginx (nginx.$LOCAL_DOMAIN)</a></li>
            <li><a href="http://code.$LOCAL_DOMAIN">Code Server (code.$LOCAL_DOMAIN)</a></li>
EOF

if command -v pveversion &> /dev/null; then
cat >> /var/www/html/dns-test/index.html << EOF
            <li><a href="https://proxmox.$LOCAL_DOMAIN:8006">Proxmox (proxmox.$LOCAL_DOMAIN)</a></li>
EOF
fi

cat >> /var/www/html/dns-test/index.html << EOF
        </ul>
    </div>

    <p class="success">✓ DNS setup successful</p>
    <p>Generated: $(date)</p>
</body>
</html>
EOF

# If Nginx is installed, create vhost entry for test page
if command -v nginx &> /dev/null; then
  echo "Creating Nginx configuration for test page..."
  cat > /etc/nginx/sites-available/dns-test << EOF
server {
    listen 80;
    server_name dns.$LOCAL_DOMAIN;
    root /var/www/html/dns-test;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

  # Enable the site
  ln -sf /etc/nginx/sites-available/dns-test /etc/nginx/sites-enabled/
  
  # Test and reload Nginx
  nginx -t && systemctl reload nginx
  
  # Add DNS entry for test page
  if ! grep -q "dns.$LOCAL_DOMAIN" /etc/hosts; then
    echo "$SERVER_IP dns.$LOCAL_DOMAIN dns" >> /etc/hosts
  fi
fi

# Summary
echo ""
echo "================================================================"
echo "Local DNS setup completed!"
echo ""
echo "You can now access your services using .local domains:"
echo "- $SERVER_HOSTNAME.$LOCAL_DOMAIN (main server)"
echo "- code.$LOCAL_DOMAIN (for code-server)"
echo "- nginx.$LOCAL_DOMAIN (for nginx)"
if [ -d /var/www/html/dns-test ]; then
  echo "- dns.$LOCAL_DOMAIN (DNS test page)"
fi
if command -v pveversion &> /dev/null; then
  echo "- proxmox.$LOCAL_DOMAIN (for Proxmox VE)"
fi
echo ""
echo "Method: $METHOD"
if [[ "$METHOD" == "mdns" ]]; then
  echo "mDNS is automatically discovered by compatible clients."
elif [[ "$METHOD" == "dnsmasq" ]]; then
  echo "Set DNS server to $SERVER_IP on clients or router."
fi
echo "================================================================" 