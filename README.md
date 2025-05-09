# Homelab Automation

A collection of scripts for automating and configuring homelab server environments.

## Current Hardware

This homelab currently runs on a single instance:
- Lenovo ThinkCentre m720q Tiny Form Factor
- Intel Core i7-8700T processor (8th Gen, 6 cores/12 threads)
- 32 GB DDR4 RAM (2x16GB configuration)
- 1 TB SSD
- Intel UHD Graphics 630
- Gigabit Ethernet

## XRDP Multi-Session Setup

This repository contains a script to set up Remote Desktop Protocol (XRDP) with multi-session support on Linux systems, specifically optimized for ParrotSec with MATE desktop.

### Features

- Enables multiple concurrent remote desktop sessions
- Configures XRDP to work correctly with MATE desktop
- Fixes common issues like black screens and authentication problems
- Sets appropriate permissions for home directories
- Configures theme compatibility for both dark and light themes
- Opens necessary firewall ports automatically

### Requirements

- ParrotSec Linux with MATE desktop
- Root or sudo privileges
- Internet connection for package installation

### Installation

1. Clone this repository or download the script:
   ```bash
   git clone https://github.com/yourusername/homelab-automation.git
   cd homelab-automation
   ```

2. Make the script executable (if not already):
   ```bash
   chmod +x setup-xrdp-multisession.sh
   ```

3. Run the script with sudo:
   ```bash
   sudo ./setup-xrdp-multisession.sh
   ```

### Usage

After installation, you can connect to your ParrotSec server using any RDP client:

- **Windows**: Use Remote Desktop Connection (mstsc.exe)
- **Linux**: Use Remmina or other RDP clients
- **macOS**: Use Microsoft Remote Desktop

Connect to your server using its IP address and port 3389 (default RDP port).

### Theme Compatibility

The script configures MATE to use the Adwaita theme, which provides good compatibility for both dark and light modes. If you encounter any theme issues:

1. Connect to your server via RDP
2. Open MATE Control Center 
3. Go to Appearance
4. Switch between themes as needed

### Troubleshooting

If you encounter issues:

- **Black Screen**: Try restarting the XRDP service:
  ```bash
  sudo systemctl restart xrdp
  sudo systemctl restart xrdp-sesman
  ```

- **Connection Refused**: Check if the XRDP service is running:
  ```bash
  sudo systemctl status xrdp
  ```

- **Authentication Issues**: Verify user permissions:
  ```bash
  ls -la /home/yourusername
  ```

## Project Roadmap

### Phase 1: Core Infrastructure
- [x] XRDP Multi-Session Setup for Linux servers
- [x] Proxmox VE installation and initial configuration
- [x] Code-Server (VS Code in browser) installation 
- [x] Nginx web server and reverse proxy setup
- [x] Local DNS setup with mDNS and Dnsmasq options
- [ ] Docker and Portainer deployment script
- [ ] Infrastructure network configuration (VLANs, firewall setup)
- [ ] Basic monitoring with Prometheus and Grafana

### Phase 2: Service Deployment
- [ ] Reverse proxy setup (Nginx/Traefik) with SSL automation
- [ ] Centralized authentication system (LDAP/Active Directory)
- [ ] VPN server configuration (WireGuard/OpenVPN)
- [ ] NAS/storage management setup (TrueNAS/OpenMediaVault)
- [ ] Automated backup solutions

### Phase 3: Infrastructure as Code
- [ ] Ansible playbooks for consistent server configuration
- [ ] Terraform templates for VM/container provisioning
- [ ] CI/CD pipeline setup (Jenkins/GitHub Actions)
- [ ] Secret management with HashiCorp Vault
- [ ] Automated testing and validation

### Phase 4: Service Enhancement
- [ ] Media server deployment (Plex/Jellyfin/Emby)
- [ ] Home automation server (Home Assistant)
- [ ] Documentation system (WikiJS/Bookstack)
- [ ] Dashboard for services (Heimdall/Homer)
- [ ] Log aggregation and analysis

### Suggested Hardware Infrastructure
- **Compute**: Dell Optiplex, HP EliteDesk, or Intel NUCs
- **Network**: Managed switch with VLAN support, decent router
- **Storage**: NAS solution or direct-attached storage arrays
- **Connectivity**: UPS for power management, reliable networking equipment

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 