#!/bin/bash

# Proxmox VE Post-Installation Script
# Run this after installing Proxmox VE to optimize for homelab use
# Specifically designed for ThinkCentre m720q with Core i7-8700T

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Proxmox VE Post-Installation Optimization Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Disable subscription nag
echo "Disabling subscription notice..."
sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service

# Optimize kernel parameters for virtualization
echo "Optimizing kernel parameters..."
cat > /etc/sysctl.d/99-proxmox-ve.conf << EOF
# Increase kernel shared memory for running multiple VMs
kernel.shmmax = 17179869184
kernel.shmall = 4194304

# Improve network performance
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0

# Virtual Memory settings
vm.swappiness = 10
vm.min_free_kbytes = 262144
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF

# Apply new kernel parameters
sysctl -p /etc/sysctl.d/99-proxmox-ve.conf

# Create default templates directory
echo "Setting up templates directory..."
mkdir -p /var/lib/vz/template/iso

# Install useful packages
echo "Installing additional packages..."
apt update
apt install -y htop iotop iftop screen nmap qemu-guest-agent zfsutils-linux

# Enable CPU mitigations for better security (but might impact performance)
echo "Configuring CPU mitigations..."
cat > /etc/default/grub.d/proxmox-mitigations.cfg << EOF
# Enable most CPU mitigations but keep reasonable performance
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT mitigations=auto"
EOF
update-grub

# Setup regular updates
echo "Setting up automatic security updates..."
apt install -y unattended-upgrades apt-listchanges
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Setup basic firewall rules
echo "Configuring basic firewall..."
cat > /etc/pve/firewall/cluster.fw << EOF
[OPTIONS]
enable: 1
policy_in: ACCEPT
policy_out: ACCEPT

[RULES]
# Allow established and related connections
IN ACCEPT -m conntrack --ctstate ESTABLISHED,RELATED
# Allow ping
IN ACCEPT -p icmp
# Allow SSH
IN ACCEPT -p tcp -dport 22
# Allow Proxmox web interface
IN ACCEPT -p tcp -dport 8006
# Allow Spice Console
IN ACCEPT -p tcp -dport 3128
# Allow VNC Console
IN ACCEPT -p tcp -dport 5900:5999
# Default drop policy
IN DROP
EOF

# Create backup directory
echo "Creating backup directory..."
mkdir -p /mnt/backup
pvesm add dir backup --path /mnt/backup --content backup

# Optimize SSD if present
echo "Optimizing for SSD..."
cat > /etc/udev/rules.d/60-schedulers.rules << EOF
# Set deadline scheduler for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
# Set noop scheduler for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

# Summary
echo ""
echo "================================================================"
echo "Proxmox VE post-installation optimizations completed!"
echo ""
echo "Optimizations applied:"
echo "- Disabled subscription notice"
echo "- Optimized kernel parameters for virtualization"
echo "- Installed useful system tools"
echo "- Configured CPU mitigations"
echo "- Set up automatic security updates"
echo "- Configured basic firewall"
echo "- Created backup directory"
echo "- Optimized disk schedulers for SSDs"
echo ""
echo "A reboot is recommended to apply all changes."
echo "================================================================"

# Ask to reboot
read -p "Do you want to reboot now? (y/n): " REBOOT
if [[ $REBOOT == "y" || $REBOOT == "Y" ]]; then
  echo "Rebooting system..."
  reboot
else
  echo "Please reboot at your convenience to apply all changes."
fi 