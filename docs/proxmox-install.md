# Proxmox VE Installation Guide

This guide covers the automated installation of Proxmox VE on your homelab hardware using the provided script.

## Prerequisites

- Debian-based system (preferably a clean Debian 12 Bookworm installation)
- Root access to the system
- Internet connectivity for downloading packages
- Dedicated machine (recommended) - Lenovo ThinkCentre m720q in our case

## Installation Methods

### Method 1: Automated Script (Recommended)

Our automation script handles the entire installation process for Proxmox VE:

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/homelab-automation.git
   cd homelab-automation
   ```

2. Review and modify settings in the script:
   ```bash
   nano scripts/infrastructure/install-proxmox.sh
   ```
   
   Customize these variables:
   - `HOSTNAME`: Your desired Proxmox host name
   - `IP_ADDRESS`: Static IP for Proxmox (recommended)
   - `NETMASK`: Your network mask
   - `GATEWAY`: Your network gateway
   - `DNS_SERVER`: DNS server

3. Make the script executable:
   ```bash
   chmod +x scripts/infrastructure/install-proxmox.sh
   ```

4. Run the script as root:
   ```bash
   sudo scripts/infrastructure/install-proxmox.sh
   ```

5. Follow the on-screen prompts to confirm settings.

6. After installation completes, the system will automatically reboot.

7. Access Proxmox VE web interface at `https://your-ip:8006`.

### Method 2: Manual Installation

For a manual installation, follow these steps:

1. Download Proxmox VE ISO from [proxmox.com/downloads](https://www.proxmox.com/downloads)
2. Create bootable USB using tools like Rufus (Windows) or `dd` (Linux)
3. Boot from the USB and follow the on-screen installer
4. Select appropriate storage, network, and account settings
5. Complete installation and access web UI

## Post-Installation Tasks

After installing Proxmox VE, consider these recommended tasks:

1. **Update System**:
   ```bash
   apt update && apt upgrade
   ```

2. **Configure Storage**:
   - Set up additional storage (via UI or command line)
   - Consider separating VM disks and container storage

3. **Backup Configuration**:
   ```bash
   cp /etc/pve /etc/pve.bak -r
   ```

4. **Setup Network Bonding** (if multiple NICs are available):
   - Navigate to System → Network in web UI
   - Create bond device for improved reliability

5. **Create Resource Pools**:
   - Navigate to Datacenter → Pools
   - Organize VMs and containers into logical groups

## Troubleshooting

- **Web UI Not Accessible**: Check network settings and firewall rules
- **Package Installation Fails**: Verify internet connectivity and repository access
- **Performance Issues**: Review hardware resource allocation and SSD health

## Proxmox VE Resource Management

For your ThinkCentre m720q with 32GB RAM and 6-core/12-thread i7:

- **Host System**: Reserve ~2GB RAM and 2 cores
- **Core Services**: Allocate ~8-12GB RAM total
- **Development VMs**: Remaining resources as needed

## Next Steps

After installation, proceed to:
1. Creating VM templates
2. Setting up backup schedules
3. Configuring storage replication (if/when additional nodes are added)
4. Implementing automation scripts for VM provisioning 