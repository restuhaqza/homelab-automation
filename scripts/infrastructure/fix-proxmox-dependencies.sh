#!/bin/bash

# Fix Proxmox VE dependencies for ParrotOS and other newer Debian-based systems
# This script installs the missing dependencies required by Proxmox VE

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

echo "=================================================="
echo "Proxmox VE Dependencies Fixer"
echo "=================================================="
echo ""

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Add Debian Bullseye repository - we'll need this for multiple packages
echo "Adding Debian Bullseye repository..."
echo "deb http://deb.debian.org/debian bullseye main contrib" > /etc/apt/sources.list.d/debian-bullseye-temp.list
apt-get update

echo "1. Installing libssl1.1 (required by Proxmox)"
apt-get install -y libssl1.1/bullseye

if [ $? -ne 0 ]; then
  echo "Trying alternative method for libssl1.1..."
  wget -q http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u2_amd64.deb
  if [ $? -ne 0 ]; then
    wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
  fi
  dpkg -i libssl1.1*.deb || apt-get -f install -y
fi

echo "2. Installing Perl 5.32 packages directly from Debian Bullseye"
apt-get install -y --allow-downgrades perl/bullseye perl-base/bullseye perl-modules-5.32/bullseye libperl5.32/bullseye

echo "3. Setting up key Perl modules"
wget -q http://ftp.debian.org/debian/pool/main/libp/libpve-common-perl/libpve-common-perl_7.4-1_all.deb
dpkg -i libpve-common-perl_7.4-1_all.deb || apt-get -f install -y

echo "4. Installing libgnutlsxx28"
apt-get install -y libgnutlsxx28/bullseye libgnutls30/bullseye

if [ $? -ne 0 ]; then
  echo "Trying alternative method for libgnutlsxx28..."
  wget -q http://ftp.debian.org/debian/pool/main/g/gnutls28/libgnutlsxx28_3.7.1-5+deb11u3_amd64.deb
  wget -q http://ftp.debian.org/debian/pool/main/g/gnutls28/libgnutls30_3.7.1-5+deb11u3_amd64.deb
  dpkg -i libgnutls30_3.7.1-5+deb11u3_amd64.deb || apt-get -f install -y
  dpkg -i libgnutlsxx28_3.7.1-5+deb11u3_amd64.deb || apt-get -f install -y
fi

echo "5. Installing liburing1"
apt-get install -y liburing1/bullseye

if [ $? -ne 0 ]; then
  echo "Trying alternative method for liburing1..."
  wget -q http://ftp.debian.org/debian/pool/main/libu/liburing/liburing1_0.7-3+deb11u1_amd64.deb
  dpkg -i liburing1_0.7-3+deb11u1_amd64.deb || apt-get -f install -y
fi

echo "6. Installing Critical QEmu Components"
apt-get install -y qemu-system-x86/bullseye qemu-utils/bullseye qemu-system-common/bullseye

echo "7. Properly configuring Proxmox repositories"
# Create proper repository files for Proxmox
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

# Download and add the repository key
wget -q -O - http://download.proxmox.com/debian/proxmox-release-bullseye.gpg | apt-key add -

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

echo "8. Installing key pve packages individually"
apt-get install -y --no-install-recommends lxc-pve || true
apt-get install -y --no-install-recommends pve-qemu-kvm || true
apt-get install -y --no-install-recommends pve-cluster || true
apt-get install -y --no-install-recommends pve-container || true
apt-get install -y --no-install-recommends qemu-server || true
apt-get install -y --no-install-recommends proxmox-ve || true

echo "9. Preparing for PVE service initialization"
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

echo "10. Fixing any remaining broken packages"
apt-get --fix-broken install -y
apt-get autoremove -y

# Keep the Debian sources for now to help with installation
# We'll clean up in the main script after installation completes
echo "Debian Bullseye repo will be kept temporarily to assist with installation."

# Clean up downloaded files
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "=================================================="
echo "Dependency fixes completed. You can now try installing Proxmox VE again."
echo "Run: apt-get install proxmox-ve"
echo "==================================================" 