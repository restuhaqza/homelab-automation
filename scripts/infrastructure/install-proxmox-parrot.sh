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
  "$SCRIPT_DIR/install-proxmox.sh"
else
  echo "Error: Proxmox installation script not found at $SCRIPT_DIR/install-proxmox.sh"
  exit 1
fi

# Save a copy of the log to /root for future reference
cp "$INSTALL_LOG" "$FINAL_LOG"
echo "Installation log saved to $FINAL_LOG"
echo "Installation log also available at $INSTALL_LOG"

echo ""
echo "================================================================"
echo "Installation process completed. Check the logs for any errors."
echo "================================================================" 