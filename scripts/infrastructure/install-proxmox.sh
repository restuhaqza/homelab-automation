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

# Function to detect primary network interface
detect_primary_interface() {
  # Try to detect the primary interface used for internet connection
  PRIMARY_INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
  
  # Fallback to the first non-loopback interface if detection fails
  if [ -z "$PRIMARY_INTERFACE" ]; then
    PRIMARY_INTERFACE=$(ip -o link show | grep -v "lo" | awk '{print $2}' | sed 's/://' | head -1)
  fi
  
  echo $PRIMARY_INTERFACE
}

# Function to check if an interface is wireless
is_wireless_interface() {
  local interface=$1
  if [ -d "/sys/class/net/$interface/wireless" ] || [ -L "/sys/class/net/$interface/phy80211" ]; then
    return 0  # True, it is a wireless interface
  else
    return 1  # False, not a wireless interface
  fi
}

# Function to get current network configuration
get_current_network_config() {
  local interface=$1
  
  # Get current IP address
  CURRENT_IP=$(ip -4 addr show $interface | grep -oP 'inet \K[^/]+')
  
  # Get current netmask in CIDR notation
  CURRENT_CIDR=$(ip -4 addr show $interface | grep -oP 'inet [0-9.]+/\K[0-9]+')
  
  # Convert CIDR to netmask
  if [ -n "$CURRENT_CIDR" ]; then
    CURRENT_NETMASK=$(cidr_to_netmask $CURRENT_CIDR)
  else
    CURRENT_NETMASK="255.255.255.0"  # Default fallback
  fi
  
  # Get current gateway
  CURRENT_GATEWAY=$(ip route | grep default | grep $interface | awk '{print $3}')
  
  # Get current DNS server
  CURRENT_DNS=$(grep -oP 'nameserver \K[^\s]+' /etc/resolv.conf | head -1)
  if [ -z "$CURRENT_DNS" ]; then
    CURRENT_DNS="1.1.1.1"  # Default fallback
  fi
}

# Function to convert CIDR to netmask
cidr_to_netmask() {
  local cidr=$1
  local mask=""
  local full_octets=$((cidr/8))
  local partial_octet=$((cidr%8))
  
  for ((i=0; i<4; i++)); do
    if [ $i -lt $full_octets ]; then
      mask="${mask}255."
    elif [ $i -eq $full_octets ]; then
      mask="${mask}$((256 - 2**(8-partial_octet)))."
    else
      mask="${mask}0."
    fi
  done
  
  echo "${mask%.}"
}

# Set default variables
HOSTNAME="proxmox"
INTERFACE=$(detect_primary_interface)
CONFIG_MODE="auto"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --hostname=*)
      HOSTNAME="${1#*=}"
      shift
      ;;
    --ip=*)
      IP_ADDRESS="${1#*=}"
      CONFIG_MODE="manual"
      shift
      ;;
    --netmask=*)
      NETMASK="${1#*=}"
      shift
      ;;
    --gateway=*)
      GATEWAY="${1#*=}"
      shift
      ;;
    --dns=*)
      DNS_SERVER="${1#*=}"
      shift
      ;;
    --interface=*)
      INTERFACE="${1#*=}"
      shift
      ;;
    --dhcp)
      CONFIG_MODE="dhcp"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Get current network configuration if using auto mode
if [ "$CONFIG_MODE" = "auto" ]; then
  get_current_network_config $INTERFACE
  IP_ADDRESS=${CURRENT_IP:-"192.168.1.100"}
  NETMASK=${CURRENT_NETMASK:-"255.255.255.0"}
  GATEWAY=${CURRENT_GATEWAY:-"192.168.1.1"}
  DNS_SERVER=${CURRENT_DNS:-"1.1.1.1"}
elif [ "$CONFIG_MODE" = "manual" ]; then
  # Use provided IP, but set defaults for any missing values
  NETMASK=${NETMASK:-"255.255.255.0"}
  GATEWAY=${GATEWAY:-"192.168.1.1"}
  DNS_SERVER=${DNS_SERVER:-"1.1.1.1"}
fi

# Confirm settings with user
echo "This script will install Proxmox VE with the following settings:"
echo "Hostname: $HOSTNAME"
echo "Network Interface: $INTERFACE"
if [ "$CONFIG_MODE" = "dhcp" ]; then
  echo "Network Configuration: DHCP (IP will be assigned automatically)"
else
  echo "IP Address: $IP_ADDRESS"
  echo "Netmask: $NETMASK"
  echo "Gateway: $GATEWAY"
  echo "DNS Server: $DNS_SERVER"
fi
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

# Health check function to verify installation
health_check() {
  echo "Performing health check..."
  local issues=0

  # Check if critical PVE services are running
  echo "Checking critical services..."
  for service in pve-cluster pvedaemon pveproxy pvestatd; do
    if systemctl is-active --quiet $service; then
      echo "  ✓ $service is running"
    else
      echo "  ✗ $service is not running"
      issues=$((issues+1))
    fi
  done

  # Check if qemu/kvm is available
  if [ -e /dev/kvm ]; then
    echo "  ✓ KVM virtualization is available"
  else
    echo "  ✗ KVM virtualization is not available"
    issues=$((issues+1))
  fi

  # Check disk space
  echo "Checking available disk space..."
  local available_space=$(df -h / | awk 'NR==2 {print $4}')
  echo "  ✓ Available disk space: $available_space"

  # Check memory
  echo "Checking available memory..."
  local available_mem=$(free -h | awk '/^Mem:/ {print $7}')
  echo "  ✓ Available memory: $available_mem"

  # Verify API connectivity (may not be fully up yet)
  echo "Checking Proxmox API access..."
  if pveversion &>/dev/null; then
    echo "  ✓ PVE version command works"
  else
    echo "  ✗ PVE version command failed"
    issues=$((issues+1))
  fi

  echo "Health check completed with $issues issues found."
  if [ $issues -gt 0 ]; then
    echo "Warning: Some issues were detected. Check the logs for more details."
  else
    echo "All checks passed successfully!"
  fi
}

# Run health check
health_check

# Setup networking
echo "Configuring network..."
if is_wireless_interface "$INTERFACE"; then
  echo "WARNING: Detected that $INTERFACE is a wireless interface."
  echo "Proxmox is designed to work with wired connections for stability."
  echo "The current network configuration will be preserved for WiFi."
  echo "You may need to configure a wired connection after installation."
  
  # Don't modify the network configuration for WiFi
  # Just verify we can add the hostname to /etc/hosts
else
  if [ "$CONFIG_MODE" = "dhcp" ]; then
    # Configure for DHCP
    cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet dhcp
EOF
  else
    # Configure for static IP
    cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
        address $IP_ADDRESS
        netmask $NETMASK
        gateway $GATEWAY
EOF
  fi
fi

# Update hosts file
echo "Updating /etc/hosts..."
if [ "$CONFIG_MODE" = "dhcp" ]; then
  # For DHCP, we'll use localhost for now and let the system update it later
  cat > /etc/hosts << EOF
127.0.0.1 localhost $HOSTNAME.homelab $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
else
  cat > /etc/hosts << EOF
127.0.0.1 localhost
$IP_ADDRESS $HOSTNAME.homelab $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
fi

# Set hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
hostnamectl set-hostname $HOSTNAME

# Configure DNS
echo "Configuring DNS..."
if [ "$CONFIG_MODE" != "dhcp" ]; then
  cat > /etc/resolv.conf << EOF
nameserver $DNS_SERVER
EOF
fi

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
if command -v pvesm &> /dev/null; then
  pvesm set local --content backup,iso,vztmpl
else
  echo "Warning: pvesm command not found. Will attempt to fix this issue."
  
  # Try to install the missing package
  echo "Installing proxmox-ve meta-package again to ensure all components are present..."
  apt-get install -y proxmox-ve
  
  # Try to find and configure storage manually if pvesm still not available
  if command -v pvesm &> /dev/null; then
    echo "pvesm is now available, configuring storage..."
    pvesm set local --content backup,iso,vztmpl
  else
    echo "Error: pvesm command still not available."
    echo "Manual storage configuration may be required after installation."
    echo "After reboot, check if /etc/pve directory exists and verify installation."
  fi
fi

# Final update
echo "Running final system update..."
apt update && apt upgrade -y

# Reboot notice
echo ""
echo "================================================================"
echo "Proxmox VE installation completed!"
if [ "$CONFIG_MODE" = "dhcp" ]; then
  echo "The system will reboot in 10 seconds. After reboot, check your"
  echo "router for the assigned IP and access the web interface at:"
  echo "https://YOUR_DHCP_IP:8006"
else
  echo "The system will reboot in 10 seconds. After reboot, you can"
  echo "access the Proxmox web interface at: https://$IP_ADDRESS:8006"
fi
echo "Default login: root (with your system's root password)"
echo "================================================================"

# Reboot
sleep 10
reboot 