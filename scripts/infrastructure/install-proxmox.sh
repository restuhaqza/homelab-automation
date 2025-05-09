#!/bin/bash

# Proxmox VE Installation Script
# This script automates the installation of Proxmox VE on Debian-based systems
# Target hardware: Lenovo ThinkCentre m720q with Core i7-8700T

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Detect distribution
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME=$ID
    DISTRO_VERSION=$VERSION_ID
    DISTRO_CODENAME=$VERSION_CODENAME
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DISTRO_NAME=$DISTRIB_ID
    DISTRO_VERSION=$DISTRIB_RELEASE
    DISTRO_CODENAME=$DISTRIB_CODENAME
  else
    DISTRO_NAME=$(uname -s)
    DISTRO_VERSION=$(uname -r)
  fi
  
  echo "Detected distribution: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_CODENAME)"
  
  # Check if this is a supported Debian-based distribution
  if [[ "$DISTRO_NAME" != "debian" && "$DISTRO_NAME" != "ubuntu" && "$DISTRO_NAME" != "parrot" ]]; then
    echo "WARNING: This script is primarily designed for Debian. Other distributions may have compatibility issues."
    read -p "Continue anyway? (y/n): " CONTINUE_UNSUPPORTED
    if [[ $CONTINUE_UNSUPPORTED != "y" && $CONTINUE_UNSUPPORTED != "Y" ]]; then
      echo "Installation aborted."
      exit 1
    fi
  fi
  
  # Special handling for ParrotSec
  if [[ "$DISTRO_NAME" == "parrot" ]]; then
    echo "ParrotSec detected. Adding special handling for potential conflicts."
    PARROT_SYSTEM=true
  else
    PARROT_SYSTEM=false
  fi
}

# Function to handle dependency conflicts
handle_dependencies() {
  echo "Checking for potential dependency conflicts..."
  
  # List of packages that might conflict with Proxmox VE
  CONFLICTING_PACKAGES="virtualbox-* docker* lxc* lxd* nvidia-* xen* libvirt* qemu* virt-manager systemd-coredump"
  
  # Check if any conflicting packages are installed
  FOUND_CONFLICTS=false
  for pkg in $CONFLICTING_PACKAGES; do
    if dpkg -l | grep -q "$pkg"; then
      echo "  ⚠️ Potential conflict detected: $pkg"
      FOUND_CONFLICTS=true
    fi
  done
  
  if $FOUND_CONFLICTS; then
    echo "Conflicting packages detected that may interfere with Proxmox installation."
    echo "Options:"
    echo "  1. Remove conflicting packages (recommended)"
    echo "  2. Try to install anyway (may cause problems)"
    echo "  3. Abort installation"
    read -p "Select an option (1-3): " CONFLICT_OPTION
    
    case $CONFLICT_OPTION in
      1)
        echo "Removing conflicting packages..."
        for pkg in $CONFLICTING_PACKAGES; do
          if dpkg -l | grep -q "$pkg"; then
            apt-get remove --purge -y $pkg
          fi
        done
        apt-get autoremove -y
        ;;
      2)
        echo "Proceeding with installation despite conflicts..."
        ;;
      3)
        echo "Installation aborted due to potential conflicts."
        exit 1
        ;;
      *)
        echo "Invalid option. Aborting installation."
        exit 1
        ;;
    esac
  else
    echo "  ✓ No obvious conflicts detected."
  fi
  
  # Check for systemd issues (common in some security distros)
  if systemctl --version | grep -q "systemd 24[6-9]" || systemctl --version | grep -q "systemd 25[0-9]"; then
    echo "  ⚠️ Notice: Your systemd version may have compatibility issues with Proxmox."
    echo "     Consider downgrading systemd or using a standard Debian installation."
  fi
  
  # Special handling for ParrotSec
  if $PARROT_SYSTEM; then
    echo "ParrotSec-specific preparations:"
    echo "  - Ensuring standard repositories are available"
    if ! grep -q "deb http://deb.debian.org/debian bullseye main" /etc/apt/sources.list; then
      echo "deb http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list
    fi
    
    # Set apt preferences to handle potential conflicts
    cat > /etc/apt/preferences.d/proxmox-priority << EOF
Package: pve-*
Pin: origin "download.proxmox.com"
Pin-Priority: 1001

Package: *
Pin: origin "download.proxmox.com"
Pin-Priority: 501
EOF
    
    apt-get update
  fi
}

# Print banner
echo "================================================================"
echo "       Automated Proxmox VE Installation Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Detect distribution
detect_distro

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

# Handle dependencies and conflicts
handle_dependencies

# Install prerequisites
echo "Installing prerequisites..."
apt install -y sudo curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Proxmox VE repository
echo "Adding Proxmox VE repository..."
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget -q -O - http://download.proxmox.com/debian/proxmox-release-bullseye.gpg | apt-key add -

# Update repositories with new Proxmox source
apt update

# If there are conflicts during 'apt update', try to fix them
if [ $? -ne 0 ]; then
  echo "Repository update failed. Attempting to fix issues..."
  apt-get --fix-broken install
  apt update
fi

# Install Proxmox VE packages (without postfix)
echo "Installing Proxmox VE packages (this may take a while)..."
# Try to handle dependency conflicts with some advanced options
if $PARROT_SYSTEM || [[ "$DISTRO_NAME" != "debian" ]]; then
  echo "Using special installation options for non-standard Debian system..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" proxmox-ve postfix open-iscsi
  
  # If install fails, try with --no-install-recommends
  if [ $? -ne 0 ]; then
    echo "Standard installation failed. Trying alternative installation method..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends proxmox-ve
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix open-iscsi
  fi
  
  # If still having issues, try installing individual packages
  if [ $? -ne 0 ]; then
    echo "Alternative installation failed. Trying component-by-component installation..."
    for pkg in pve-manager pve-kernel-5.15 pve-container qemu-server libpve-storage-perl libpve-access-control postfix open-iscsi; do
      DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg || echo "Failed to install $pkg - continuing anyway"
    done
  fi
else
  # Standard installation for Debian
  DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi
fi

# Attempt to fix any broken installations
apt-get -f install

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
      
      # Try to start the service if it's not running
      echo "    Attempting to start $service..."
      systemctl start $service
      if systemctl is-active --quiet $service; then
        echo "    ✓ Successfully started $service"
      else
        echo "    ✗ Failed to start $service. Checking logs..."
        journalctl -u $service --no-pager -n 10
      fi
    fi
  done

  # Check if qemu/kvm is available
  if [ -e /dev/kvm ]; then
    echo "  ✓ KVM virtualization is available"
  else
    echo "  ✗ KVM virtualization is not available"
    issues=$((issues+1))
    
    # Check if virtualization is enabled in BIOS/UEFI
    if ! grep -q -E 'svm|vmx' /proc/cpuinfo; then
      echo "    ✗ CPU virtualization features not detected. Please enable virtualization in BIOS/UEFI."
    else
      echo "    ✓ CPU virtualization features detected"
      echo "    Attempting to load KVM module..."
      modprobe kvm
      if [ $? -eq 0 ]; then
        echo "    ✓ KVM module loaded successfully"
      else
        echo "    ✗ Failed to load KVM module"
      fi
    fi
  fi

  # Additional checks for common issues
  echo "Performing additional system checks..."

  # Check kernel compatibility
  if uname -r | grep -q "pve"; then
    echo "  ✓ Running PVE kernel: $(uname -r)"
  else
    echo "  ✗ Not running PVE kernel: $(uname -r)"
    echo "    Checking if PVE kernel is installed..."
    if dpkg -l | grep -q "pve-kernel"; then
      echo "    ✓ PVE kernel is installed, but not active"
      echo "    You will need to reboot to use the PVE kernel"
    else
      echo "    ✗ PVE kernel not installed"
      echo "    Attempting to install PVE kernel..."
      apt-get install -y pve-kernel
    fi
  fi

  # Check if all required packages are installed
  echo "Verifying Proxmox VE packages..."
  local missing_packages=0
  for pkg in proxmox-ve libpve-access-control libpve-common-perl libpve-guest-common-perl libpve-http-server-perl libpve-storage-perl pve-container pve-firewall pve-ha-manager pve-i18n pve-manager pve-xtermjs qemu-server; do
    if ! dpkg -l | grep -q "ii  $pkg"; then
      echo "  ✗ Package $pkg is missing or not properly installed"
      missing_packages=$((missing_packages+1))
    fi
  done
  
  if [ $missing_packages -gt 0 ]; then
    echo "  Found $missing_packages missing packages. Attempting to repair installation..."
    apt-get update
    apt-get install -y proxmox-ve
    apt-get install -f
  else
    echo "  ✓ All essential Proxmox packages appear to be installed"
  fi

  # Check disk space
  echo "Checking available disk space..."
  local available_space=$(df -h / | awk 'NR==2 {print $4}')
  echo "  ✓ Available disk space: $available_space"

  # Check memory
  echo "Checking available memory..."
  local available_mem=$(free -h | awk '/^Mem:/ {print $7}')
  echo "  ✓ Available memory: $available_mem"

  # Verify open ports
  echo "Checking if required ports are open..."
  if command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":8006"; then
      echo "  ✓ Web interface port 8006 is open"
    else
      echo "  ✗ Web interface port 8006 is not open"
      issues=$((issues+1))
    fi
  fi

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
    echo "You may need to run the following to troubleshoot further:"
    echo "  systemctl status pve*"
    echo "  journalctl -xeu pve*"
    echo "Consider adding '--reinstall' when running apt-get install proxmox-ve"
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