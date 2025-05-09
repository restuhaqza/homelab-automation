#!/bin/bash

# Proxmox VE Installation Script
# This script automates the installation of Proxmox VE on Debian-based systems
# Target hardware: Lenovo ThinkCentre m720q with Core i7-8700T

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Automated Proxmox VE Installation Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Set variables
HOSTNAME="proxmox"
IP_ADDRESS="192.168.1.100"  # Change to your desired IP
NETMASK="255.255.255.0"     # Change based on your network
GATEWAY="192.168.1.1"       # Change to your gateway
DNS_SERVER="1.1.1.1"        # Can be changed to your preferred DNS

# Confirm settings with user
echo "This script will install Proxmox VE with the following settings:"
echo "Hostname: $HOSTNAME"
echo "IP Address: $IP_ADDRESS"
echo "Netmask: $NETMASK"
echo "Gateway: $GATEWAY"
echo "DNS Server: $DNS_SERVER"
echo ""
read -p "Continue with these settings? (y/n): " CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo "Installation aborted by user"
  exit 1
fi

# Update system
echo "Updating system packages..."
apt update && apt upgrade -y

# Install prerequisites
echo "Installing prerequisites..."
apt install -y sudo curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Proxmox VE repository
echo "Adding Proxmox VE repository..."
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget -q -O - http://download.proxmox.com/debian/proxmox-release-bullseye.gpg | apt-key add -

# Update repositories with new Proxmox source
apt update

# Install Proxmox VE packages (without postfix)
echo "Installing Proxmox VE packages (this may take a while)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi

# Setup networking
echo "Configuring network..."
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet static
        address $IP_ADDRESS
        netmask $NETMASK
        gateway $GATEWAY
EOF

# Update hosts file
echo "Updating /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1 localhost
$IP_ADDRESS $HOSTNAME.homelab $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Set hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
hostnamectl set-hostname $HOSTNAME

# Configure DNS
echo "Configuring DNS..."
cat > /etc/resolv.conf << EOF
nameserver $DNS_SERVER
EOF

# Disable enterprise repository and enable no-subscription repository
echo "Configuring repositories for non-subscription use..."
sed -i.bak "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
apt update

# Optional: Remove subscription notice
echo "Removing subscription notice..."
cat > /etc/apt/apt.conf.d/99no-subscription-warning << EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

# Set up local storage
echo "Configuring local storage..."
pvesm set local --content backup,iso,vztmpl

# Final update
echo "Running final system update..."
apt update && apt upgrade -y

# Reboot notice
echo ""
echo "================================================================"
echo "Proxmox VE installation completed!"
echo "The system will reboot in 10 seconds. After reboot, you can"
echo "access the Proxmox web interface at: https://$IP_ADDRESS:8006"
echo "Default login: root (with your system's root password)"
echo "================================================================"

# Reboot
sleep 10
reboot 