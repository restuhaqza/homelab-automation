# Homelab Automation

A collection of scripts for automating and configuring homelab server environments.

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

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 