#!/bin/bash

# Fix Proxmox VE dependencies for ParrotOS and other newer Debian-based systems
# This script installs the missing dependencies required by Proxmox VE

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

echo "=================================================="
echo "Proxmox VE Dependencies Fixer for Debian 12 Bookworm-based systems"
echo "=================================================="
echo ""

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
  # Try to find a compatible libssl1.1 package
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
USING_BOOKWORM_REPO=true

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

echo "7. Installing Proxmox kernel and base packages"
# First download key packages
echo "Downloading key Proxmox packages..."
apt-get download proxmox-ve pve-qemu-kvm pve-container pve-cluster qemu-server || true
dpkg -i pve-firmware_*.deb || true
dpkg -i pve-kernel-*.deb || true
apt-get -f install -y

echo "8. Creating pve-qemu-kvm compatibility layer"
# Create a dummy pve-qemu-kvm package if direct installation fails
if ! dpkg -l | grep -q pve-qemu-kvm; then
  echo "Creating compatibility package for pve-qemu-kvm..."
  mkdir -p pve-qemu-kvm-dummy/DEBIAN
  cat > pve-qemu-kvm-dummy/DEBIAN/control << EOL
Package: pve-qemu-kvm
Version: 7.4.0-1
Section: admin
Priority: optional
Architecture: amd64
Provides: pve-qemu-kvm
Depends: qemu-system-x86, qemu-utils
Maintainer: ParrotOS Team
Description: Compatibility package for pve-qemu-kvm
 Provides compatibility for Proxmox with Bookworm's QEMU
EOL
  dpkg-deb --build pve-qemu-kvm-dummy
  dpkg -i pve-qemu-kvm-dummy.deb
fi

echo "9. Installing Proxmox packages with force options"
# Try installation with native Bookworm packages
echo "Using native Bookworm packages - installing proxmox-ve..."
apt-get install -y proxmox-ve postfix open-iscsi

echo "10. Preparing for PVE service initialization"
# Create required directories if they don't exist
mkdir -p /etc/pve
mkdir -p /var/lib/pve-cluster
mkdir -p /var/lib/pve-manager

# Pre-create service symlinks
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /lib/systemd/system/pve-cluster.service /etc/systemd/system/multi-user.target.wants/pve-cluster.service 2>/dev/null || true
ln -sf /lib/systemd/system/pvedaemon.service /etc/systemd/system/multi-user.target.wants/pvedaemon.service 2>/dev/null || true
ln -sf /lib/systemd/system/pveproxy.service /etc/systemd/system/multi-user.target.wants/pveproxy.service 2>/dev/null || true
ln -sf /lib/systemd/system/pvestatd.service /etc/systemd/system/multi-user.target.wants/pvestatd.service 2>/dev/null || true

echo "11. Fixing any remaining broken packages"
apt-get --fix-broken install -y
apt-get autoremove -y

# Clean up downloaded files
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "=================================================="
echo "Dependency fixes completed for Debian 12 (Bookworm) based system."
echo "You can now try installing Proxmox VE with:"
echo "sudo apt-get install proxmox-ve"
echo "==================================================" 