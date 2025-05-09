#!/bin/bash

# Proxmox VE Installation Script for Parrot OS
# This script automates the installation of Proxmox VE on Parrot OS and other newer Debian-based systems
# It fixes dependencies first, then installs Proxmox

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Automated Proxmox VE Installation Script for Parrot OS"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Setup logging
INSTALL_LOG="/var/log/proxmox-install-$(date +%Y%m%d-%H%M%S).log"
FINAL_LOG="/root/proxmox-installation.log"

# Execute the entire script with logging
exec > >(tee -a "$INSTALL_LOG") 2>&1

echo "Installation started at $(date)"
echo "Logging installation to $INSTALL_LOG"
echo ""

# Directory where the scripts are located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Step 1: Fix dependencies first
echo "Step 1: Fixing Proxmox dependencies for Parrot OS..."
if [ -f "$SCRIPT_DIR/fix-proxmox-dependencies.sh" ]; then
  chmod +x "$SCRIPT_DIR/fix-proxmox-dependencies.sh"
  "$SCRIPT_DIR/fix-proxmox-dependencies.sh"
else
  echo "Error: Dependency fixer script not found at $SCRIPT_DIR/fix-proxmox-dependencies.sh"
  exit 1
fi

# Step 2: Run the main Proxmox installation script
echo "Step 2: Installing Proxmox VE..."
if [ -f "$SCRIPT_DIR/install-proxmox.sh" ]; then
  chmod +x "$SCRIPT_DIR/install-proxmox.sh"
  if ! "$SCRIPT_DIR/install-proxmox.sh"; then
    echo "Main installation script encountered errors. Trying alternative installation method..."
    
    echo "Step 2b: Attempting manual Proxmox installation..."
    # Try direct installation
    echo "Adding Proxmox Repository..."
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    wget -q -O - http://download.proxmox.com/debian/proxmox-release-bullseye.gpg | apt-key add -
    apt-get update
    
    echo "Installing Proxmox VE packages..."
    # First try normal installation
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi; then
      echo "Standard installation failed. Trying with more options..."
      # Try with force options
      if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" proxmox-ve postfix open-iscsi; then
        echo "Forced installation failed. Trying component-by-component installation..."
        # Try individual components
        for pkg in pve-manager pve-kernel-5.15 pve-firmware pve-container qemu-server libpve-storage-perl libpve-access-control proxmox-widget-toolkit pve-docs postfix open-iscsi; do
          DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg || echo "Failed to install $pkg - continuing anyway"
        done
      fi
    fi
    
    # Ensure services are enabled
    systemctl daemon-reload
    for service in pve-cluster pvedaemon pveproxy pvestatd; do
      systemctl enable $service || true
      systemctl start $service || true
    done
  fi
else
  echo "Error: Proxmox installation script not found at $SCRIPT_DIR/install-proxmox.sh"
  exit 1
fi

# Step 3: Verify installation
echo "Step 3: Verifying Proxmox VE installation..."
INSTALLATION_SUCCESS=true

# Check for critical PVE packages
echo "Checking for critical PVE packages..."
REQUIRED_PACKAGES="pve-manager qemu-server pve-container"
for pkg in $REQUIRED_PACKAGES; do
  if ! dpkg -l | grep -q "ii  $pkg"; then
    echo "❌ Critical package '$pkg' is not installed properly."
    INSTALLATION_SUCCESS=false
  else
    echo "✅ Package '$pkg' is installed."
  fi
done

# Check for critical PVE services
echo "Checking for critical PVE services..."
REQUIRED_SERVICES="pve-cluster pvedaemon pveproxy pvestatd"
for service in $REQUIRED_SERVICES; do
  if ! systemctl is-active --quiet $service; then
    echo "❌ Critical service '$service' is not running."
    echo "   Attempting to start service..."
    systemctl start $service
    if ! systemctl is-active --quiet $service; then
      echo "   Failed to start service."
      INSTALLATION_SUCCESS=false
    else
      echo "   Service started successfully."
    fi
  else
    echo "✅ Service '$service' is running."
  fi
done

# Check PVE web interface accessibility
echo "Checking PVE web interface accessibility..."
if command -v curl >/dev/null 2>&1; then
  if ! curl -k -s --head --fail https://localhost:8006 >/dev/null; then
    echo "❌ PVE web interface is not accessible."
    INSTALLATION_SUCCESS=false
  else
    echo "✅ PVE web interface is accessible."
  fi
fi

# Final result
if [ "$INSTALLATION_SUCCESS" = false ]; then
  echo "⚠️ The Proxmox VE installation may not be complete or fully functional."
  echo "   Please check the logs and consider manual fixes."
else
  echo "✅ Proxmox VE installation verification completed successfully."
fi

# Clean up temporary Debian repo (we kept it during installation for dependencies)
echo "Cleaning up temporary Debian repository..."
if [ -f /etc/apt/sources.list.d/debian-bullseye-temp.list ]; then
  rm /etc/apt/sources.list.d/debian-bullseye-temp.list
  apt-get update
fi

# Save a copy of the log to /root for future reference
cp "$INSTALL_LOG" "$FINAL_LOG"
echo "Installation log saved to $FINAL_LOG"
echo "Installation log also available at $INSTALL_LOG"

echo ""
echo "================================================================"
echo "Installation process completed. Check the logs for any errors."
echo "================================================================" 