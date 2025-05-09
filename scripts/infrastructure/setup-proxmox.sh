#!/bin/bash

# Proxmox VE Setup Script for ThinkCentre
# This script prepares a USB for Proxmox installation and provides post-install instructions
# Must be run on macOS (for the ThinkCentre installation)

# Print banner
echo "================================================================"
echo "       Proxmox VE Installation Preparation Script"
echo "       For ThinkCentre m720q Homelab"
echo "================================================================"
echo ""

# Check if script is run on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script is designed to run on macOS"
  exit 1
fi

# Function to download Proxmox ISO
download_proxmox_iso() {
  echo "Downloading latest Proxmox VE ISO..."
  
  # Create downloads directory if it doesn't exist
  mkdir -p ~/Downloads/proxmox
  
  # Check and download latest Proxmox VE ISO
  PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_7.4-1.iso"
  PROXMOX_ISO_PATH="~/Downloads/proxmox/proxmox-ve_latest.iso"
  
  if [ -f "$PROXMOX_ISO_PATH" ]; then
    echo "ISO already exists at $PROXMOX_ISO_PATH"
    read -p "Do you want to download again? (y/n): " DOWNLOAD_AGAIN
    if [[ $DOWNLOAD_AGAIN != "y" && $DOWNLOAD_AGAIN != "Y" ]]; then
      echo "Using existing ISO file."
      return
    fi
  fi
  
  echo "Downloading Proxmox VE ISO from $PROXMOX_ISO_URL..."
  curl -L "$PROXMOX_ISO_URL" -o "$PROXMOX_ISO_PATH"
  
  if [ $? -ne 0 ]; then
    echo "Failed to download Proxmox VE ISO."
    exit 1
  fi
  
  echo "Successfully downloaded Proxmox VE ISO to $PROXMOX_ISO_PATH"
}

# Function to prepare USB drive
prepare_usb_drive() {
  echo ""
  echo "USB Drive Preparation for Proxmox Installation"
  echo "----------------------------------------------"
  echo "CAUTION: This will erase all data on the selected USB drive!"
  echo ""
  
  # List available disks
  diskutil list
  
  echo ""
  read -p "Enter the disk identifier for your USB drive (e.g., disk2): " USB_DISK
  
  # Confirm with user
  echo ""
  echo "You selected: $USB_DISK"
  diskutil info "/dev/$USB_DISK" | grep "Device / Media Name"
  echo ""
  echo "WARNING: ALL DATA ON THIS DISK WILL BE ERASED!"
  read -p "Are you absolutely sure you want to continue? (yes/no): " CONFIRM
  
  if [[ $CONFIRM != "yes" ]]; then
    echo "Operation cancelled."
    return
  fi
  
  # Unmount the disk
  echo "Unmounting disk..."
  diskutil unmountDisk "/dev/$USB_DISK"
  
  # Create bootable USB
  echo "Creating bootable USB drive (this may take a while)..."
  echo "Converting ISO to IMG format..."
  PROXMOX_IMG_PATH="${PROXMOX_ISO_PATH%.iso}.img"
  hdiutil convert "$PROXMOX_ISO_PATH" -format UDRW -o "$PROXMOX_IMG_PATH"
  
  echo "Writing image to USB drive..."
  sudo dd if="$PROXMOX_IMG_PATH" of="/dev/r$USB_DISK" bs=1m
  
  # Eject the disk
  diskutil eject "/dev/$USB_DISK"
  
  echo "USB drive preparation complete. You can now use this to install Proxmox VE on your ThinkCentre."
}

# Function to display post-installation instructions
show_post_install_instructions() {
  echo ""
  echo "Post-Installation Instructions"
  echo "---------------------------"
  echo "After booting from the USB and installing Proxmox VE on your ThinkCentre:"
  echo ""
  echo "1. Log in to the Proxmox web interface at https://thinkcentre-ip:8006"
  echo "   Default credentials: root / password you set during installation"
  echo ""
  echo "2. Update the system:"
  echo "   - SSH into the Proxmox host: ssh root@thinkcentre-ip"
  echo "   - Run: apt update && apt full-upgrade -y"
  echo ""
  echo "3. Run the post-installation optimization script:"
  echo "   - Copy the script to the Proxmox host:"
  echo "     scp configs/proxmox/post-install.sh root@thinkcentre-ip:/root/"
  echo "   - SSH into the Proxmox host and run the script:"
  echo "     ssh root@thinkcentre-ip"
  echo "     chmod +x /root/post-install.sh"
  echo "     /root/post-install.sh"
  echo ""
  echo "4. Create VMs according to the topology document:"
  echo "   - System VM (2 vCPU, 4GB RAM)"
  echo "   - Storage VM (2 vCPU, 4GB RAM)"
  echo "   - Kubernetes/Container Host VM (4-6 vCPU, 16-20GB RAM)"
  echo ""
  echo "5. Follow the rest of the implementation steps in docs/homelab_topology.md"
}

# Main menu
while true; do
  echo ""
  echo "Proxmox VE Installation Preparation"
  echo "----------------------------------"
  echo "1. Download Proxmox VE ISO"
  echo "2. Prepare USB drive for installation"
  echo "3. Show post-installation instructions"
  echo "4. Exit"
  echo ""
  read -p "Select an option (1-4): " OPTION
  
  case $OPTION in
    1) download_proxmox_iso ;;
    2) prepare_usb_drive ;;
    3) show_post_install_instructions ;;
    4) echo "Exiting."; exit 0 ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done 