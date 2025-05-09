# Code-Server Setup Guide

This guide covers the installation and configuration of code-server (VS Code in a browser) for your homelab environment.

## Overview

Code-server provides a browser-based VS Code experience, allowing you to:
- Edit code on any device with a browser
- Maintain a consistent development environment across devices
- Work directly on your server without transferring files
- Access your development environment remotely

## Installation

### Automated Installation (Recommended)

Our script automates the entire installation process:

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/homelab-automation.git
   cd homelab-automation
   ```

2. Review and customize settings in the script:
   ```bash
   nano scripts/services/install-code-server.sh
   ```
   
   Important configuration variables:
   - `CODE_SERVER_PORT`: The port to access code-server (default: 8080)
   - `CODE_SERVER_USER`: Username for the system account
   - `CODE_SERVER_PASSWORD`: Initial password (change this!)
   - `ENABLE_SSL`: Set to true to enable SSL

3. Make the script executable:
   ```bash
   chmod +x scripts/services/install-code-server.sh
   ```

4. Run the script with root privileges:
   ```bash
   sudo scripts/services/install-code-server.sh
   ```

5. After installation, access code-server at `http://your-server-ip:8080`

### Manual Installation

If you prefer a manual installation:

1. Install prerequisites:
   ```bash
   sudo apt update
   sudo apt install -y curl wget gnupg2 nodejs npm git
   ```

2. Download and run the code-server installer:
   ```bash
   curl -fsSL https://code-server.dev/install.sh | sh
   ```

3. Create a configuration file:
   ```bash
   mkdir -p ~/.config/code-server
   nano ~/.config/code-server/config.yaml
   ```
   
   Add the following content:
   ```yaml
   bind-addr: 0.0.0.0:8080
   auth: password
   password: your-secure-password
   cert: false
   ```

4. Start code-server:
   ```bash
   code-server --config ~/.config/code-server/config.yaml
   ```

## Post-Installation Configuration

### Theme Configuration

The installation script automatically configures both dark and light themes for compatibility. To adjust theme settings:

1. In code-server, open Settings (File > Preferences > Settings)
2. Search for "theme"
3. Modify the following settings:
   - `workbench.colorTheme`: Current theme
   - `workbench.preferredDarkColorTheme`: Theme for dark mode
   - `workbench.preferredLightColorTheme`: Theme for light mode
   - `window.autoDetectColorScheme`: Enable/disable auto detection

### Security Recommendations

1. **Change the default password**:
   ```bash
   sudo nano /home/code-server/.config/code-server/config.yaml
   ```

2. **Set up a reverse proxy with SSL** (recommended for external access):
   - Configure Nginx or Traefik as a reverse proxy
   - Use Let's Encrypt for free SSL certificates

3. **Limit access using firewall rules**:
   ```bash
   sudo ufw allow from trusted-ip-address to any port 8080
   ```

## Extension Management

### Pre-installed Extensions

The installation script includes these useful extensions:
- Python support
- Docker integration
- Terraform support
- YAML validation
- Code formatting (Prettier)
- Vim keybindings
- Live Server

### Installing Additional Extensions

Inside code-server:
1. Click the Extensions icon in the sidebar
2. Search for desired extensions
3. Click "Install"

From the command line:
```bash
sudo -u code-server code-server --install-extension extension-id
```

## Troubleshooting

### Service Not Starting

Check the service status:
```bash
systemctl status code-server
```

View logs for more details:
```bash
journalctl -u code-server
```

### Connection Issues

1. Verify the service is running:
   ```bash
   sudo systemctl status code-server
   ```

2. Check firewall settings:
   ```bash
   sudo ufw status
   ```

3. Confirm the correct IP and port configuration:
   ```bash
   cat /home/code-server/.config/code-server/config.yaml
   ```

## Resource Usage

Code-server is relatively lightweight but resource usage increases with:
- Number of extensions installed
- Size of projects
- Type of language services running

Recommended minimum resources:
- 1-2 CPU cores
- 2GB RAM
- 10GB storage space 