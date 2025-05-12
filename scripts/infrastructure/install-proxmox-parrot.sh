#!/bin/bash

# Proxmox VE Installation Script for Parrot OS
# This script automates the installation of Proxmox VE on Parrot OS and other newer Debian-based systems
# It installs dependencies and then installs Proxmox

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

# Step 1: Install Proxmox dependencies directly
echo "Step 1: Installing Proxmox dependencies for Parrot OS..."

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Create APT preferences to prioritize the host system's packages
cat > /etc/apt/preferences.d/99-prefer-current << EOF
Package: *
Pin: release n=bookworm
Pin-Priority: 900
EOF

# Update apt
apt-get update

echo "1. Installing libssl1.1 (required by Proxmox)"
apt-get install -y libssl1.1 || {
  echo "Installing libssl1.1 from available sources..."
  apt-get install -y libssl-dev
}

echo "2. Creating compatibility layer for Perl API"
# Need to create compatibility symlinks for perl
if [ ! -e /usr/lib/x86_64-linux-gnu/perl5/5.32/ ]; then
  echo "Creating Perl 5.32 compatibility directory..."
  mkdir -p /usr/lib/x86_64-linux-gnu/perl5/5.32/
fi

# If using Perl 5.36 on Bookworm, create symlinks from 5.36 to 5.32
CURRENT_PERL=$(perl -e 'print $^V' | sed 's/v//')
echo "Current Perl version: $CURRENT_PERL"

if [[ "$CURRENT_PERL" == 5.36* ]]; then
  echo "Creating Perl 5.32 compatibility links from Perl 5.36..."
  # Create necessary symlinks for perlapi
  ln -sf /usr/lib/x86_64-linux-gnu/perl5/5.36 /usr/lib/x86_64-linux-gnu/perl-5.32
  ln -sf /usr/lib/x86_64-linux-gnu/libperl.so.5.36 /usr/lib/x86_64-linux-gnu/libperl.so.5.32
  # Create a fake perlapi provider
  echo "Creating perlapi-5.32.1 package..."
  mkdir -p perlapi-5.32.1/DEBIAN
  cat > perlapi-5.32.1/DEBIAN/control << EOL
Package: perlapi-5.32.1
Version: 5.32.1
Section: perl
Priority: optional
Architecture: amd64
Provides: perlapi-5.32.1
Depends: perl
Maintainer: ParrotOS Team
Description: Compatibility package for perlapi-5.32.1
 Provides compatibility for Proxmox with Perl 5.36
EOL
  dpkg-deb --build perlapi-5.32.1
  dpkg -i perlapi-5.32.1.deb
fi

echo "3. Installing libgnutlsxx28"
apt-get install -y libgnutlsxx28 libgnutls30 || {
  echo "Installing gnutls from available sources..."
  apt-get install -y libgnutls-openssl27 libgnutls28-dev
}

echo "4. Installing liburing1"
apt-get install -y liburing1 || {
  echo "Installing liburing from available sources..."
  apt-get install -y liburing-dev
}

echo "5. Setting up Proxmox repositories"
echo "Proxmox VE repository for Bookworm - using native Debian 12 packages."
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
# Download and add the repository key
wget -q -O - http://download.proxmox.com/debian/proxmox-release-bookworm.gpg | apt-key add -

# Create a dummy enterprise repository to prevent errors
touch /etc/apt/sources.list.d/pve-enterprise.list
echo "# This file intentionally left empty to prevent errors" > /etc/apt/sources.list.d/pve-enterprise.list

# Create apt preferences to prioritize Proxmox packages
cat > /etc/apt/preferences.d/proxmox-pin << EOF
Package: *
Pin: origin download.proxmox.com
Pin-Priority: 1001
EOF

# Update repositories
apt-get update

echo "6. Preparing for QEmu compatibility"
# Install some prerequisites for building
apt-get install -y build-essential libncurses-dev pkg-config libelf-dev flex bison
apt-get install -y qemu-system-x86 qemu-utils

# Clean up downloaded files
cd - > /dev/null
rm -rf "$TEMP_DIR"

# Step 2: Run the main Proxmox installation script
echo "Step 2: Installing Proxmox VE..."
if [ -f "$SCRIPT_DIR/install-proxmox.sh" ]; then
  chmod +x "$SCRIPT_DIR/install-proxmox.sh"
  if ! "$SCRIPT_DIR/install-proxmox.sh"; then
    echo "Main installation script encountered errors. Trying alternative installation method..."
    
    echo "Step 2b: Attempting manual Proxmox installation..."
    # Try direct installation
    echo "Adding Proxmox Repository..."
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    # Download and add the repository key
    wget -q -O - http://download.proxmox.com/debian/proxmox-release-bookworm.gpg | apt-key add -
    apt-get update
    
    echo "Installing Proxmox VE packages..."
    echo "Using native Bookworm packages - standard installation..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi
    
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

# Save a copy of the log to /root for future reference
cp "$INSTALL_LOG" "$FINAL_LOG"
echo "Installation log saved to $FINAL_LOG"
echo "Installation log also available at $INSTALL_LOG"

echo ""
echo "================================================================"
echo "Installation process completed. Check the logs for any errors."
echo "================================================================" 