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

echo "1. Installing libssl1.1 (required by Proxmox)"
# Download libssl1.1 from Debian Bullseye
echo "Downloading libssl1.1 from Debian repositories..."
wget -q http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u2_amd64.deb
if [ $? -ne 0 ]; then
  # Alternative download location
  echo "Trying alternative source..."
  wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
fi

# Install the package
echo "Installing libssl1.1..."
dpkg -i libssl1.1*.deb
if [ $? -ne 0 ]; then
  echo "Error installing libssl1.1. Attempting to fix dependencies..."
  apt-get -f install -y
fi

echo "2. Installing required Perl API"
# Need to install perl from Debian Bullseye for compatibility
echo "Adding Debian Bullseye repository temporarily..."
echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/debian-bullseye-temp.list

# Update package lists but don't upgrade
apt-get update

# Install libperl specifically from bullseye
echo "Installing compatible perl packages..."
apt-get install -y --no-upgrade perl/bullseye libperl5.32/bullseye perl-base/bullseye

# Remove temporary repo
echo "Removing temporary Debian repository..."
rm /etc/apt/sources.list.d/debian-bullseye-temp.list
apt-get update

echo "3. Installing libgnutlsxx28"
# Download and install libgnutlsxx28
wget -q http://ftp.debian.org/debian/pool/main/g/gnutls28/libgnutlsxx28_3.7.1-5+deb11u3_amd64.deb
dpkg -i libgnutlsxx28*.deb
if [ $? -ne 0 ]; then
  echo "Error installing libgnutlsxx28. Attempting to fix dependencies..."
  apt-get -f install -y
fi

echo "4. Installing liburing1"
# Download and install liburing1
wget -q http://ftp.debian.org/debian/pool/main/libu/liburing/liburing1_0.7-3+deb11u1_amd64.deb
dpkg -i liburing1*.deb
if [ $? -ne 0 ]; then
  echo "Error installing liburing1. Attempting to fix dependencies..."
  apt-get -f install -y
fi

echo "5. Fixing any remaining broken packages"
apt-get --fix-broken install -y

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "=================================================="
echo "Dependency fixes completed. You can now try installing Proxmox VE again."
echo "Run: apt-get install proxmox-ve"
echo "==================================================" 