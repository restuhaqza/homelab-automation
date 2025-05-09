#!/bin/bash

# Code-Server Installation Script
# This script installs and configures code-server (VS Code in browser) for the homelab
# Compatible with Proxmox VMs and LXC containers

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Code-Server Installation Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Set variables
CODE_SERVER_PORT=8080
CODE_SERVER_USER="codeuser"
CODE_SERVER_PASSWORD="changeme"  # Change this!
CODE_SERVER_DOMAIN=""  # Optional: Set if you'll access through a domain
ENABLE_SSL=false  # Set to true to enable SSL
INSTALL_DIR="/opt/code-server"
SERVICE_USER="code-server"

# Confirm settings with user
echo "This script will install code-server with the following settings:"
echo "Port: $CODE_SERVER_PORT"
echo "User: $CODE_SERVER_USER"
echo "Install Directory: $INSTALL_DIR"
echo ""
read -p "Continue with these settings? (y/n): " CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo "Installation aborted by user"
  exit 1
fi

# Update system
echo "Updating system packages..."
apt update

# Install dependencies
echo "Installing dependencies..."
apt install -y curl wget gnupg2 apt-transport-https sudo git unzip nodejs npm

# Create service user
echo "Creating service user..."
useradd -m -s /bin/bash $SERVICE_USER

# Create the user for accessing code-server
echo "Creating user account..."
useradd -m -s /bin/bash $CODE_SERVER_USER
echo "$CODE_SERVER_USER:$CODE_SERVER_PASSWORD" | chpasswd
usermod -aG sudo $CODE_SERVER_USER

# Create installation directory
echo "Creating installation directory..."
mkdir -p $INSTALL_DIR
chown $SERVICE_USER:$SERVICE_USER $INSTALL_DIR

# Download and install code-server
echo "Downloading and installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# Configure code-server
echo "Configuring code-server..."
mkdir -p /home/$SERVICE_USER/.config/code-server
cat > /home/$SERVICE_USER/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:$CODE_SERVER_PORT
auth: password
password: $CODE_SERVER_PASSWORD
cert: ${ENABLE_SSL}
EOF

chown -R $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/.config

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=Code Server IDE
After=network.target

[Service]
User=$SERVICE_USER
Environment=PASSWORD=$CODE_SERVER_PASSWORD
WorkingDirectory=/home/$SERVICE_USER
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:$CODE_SERVER_PORT --user-data-dir /home/$SERVICE_USER/.code-server --config /home/$SERVICE_USER/.config/code-server/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling and starting code-server service..."
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server

# Configure firewall
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
  ufw allow $CODE_SERVER_PORT/tcp
  echo "UFW rule added for port $CODE_SERVER_PORT"
elif command -v firewall-cmd &> /dev/null; then
  firewall-cmd --permanent --add-port=$CODE_SERVER_PORT/tcp
  firewall-cmd --reload
  echo "FirewallD rule added for port $CODE_SERVER_PORT"
else
  echo "No firewall detected, please manually open port $CODE_SERVER_PORT if needed"
fi

# Setup NodeJS extensions
echo "Setting up extension dependencies..."
sudo -u $SERVICE_USER mkdir -p /home/$SERVICE_USER/.npm-global
sudo -u $SERVICE_USER npm config set prefix '/home/$SERVICE_USER/.npm-global'
cat >> /home/$SERVICE_USER/.bashrc << EOF
export PATH=/home/$SERVICE_USER/.npm-global/bin:\$PATH
EOF
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/.bashrc

# Configure dark/light theme compatibility
echo "Configuring theme compatibility..."
sudo -u $SERVICE_USER mkdir -p /home/$SERVICE_USER/.code-server/User
cat > /home/$SERVICE_USER/.code-server/User/settings.json << EOF
{
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.preferredDarkColorTheme": "Default Dark Modern",
    "workbench.preferredLightColorTheme": "Default Light Modern",
    "window.autoDetectColorScheme": true,
    "editor.fontSize": 14,
    "terminal.integrated.fontSize": 14,
    "editor.fontFamily": "'Droid Sans Mono', 'monospace', monospace",
    "workbench.startupEditor": "newUntitledFile",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000
}
EOF
chown -R $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/.code-server

# Setup common extensions
echo "Installing common VS Code extensions..."
sudo -u $SERVICE_USER code-server --install-extension ms-python.python
sudo -u $SERVICE_USER code-server --install-extension ms-azuretools.vscode-docker
sudo -u $SERVICE_USER code-server --install-extension hashicorp.terraform
sudo -u $SERVICE_USER code-server --install-extension redhat.vscode-yaml
sudo -u $SERVICE_USER code-server --install-extension esbenp.prettier-vscode
sudo -u $SERVICE_USER code-server --install-extension vscodevim.vim
sudo -u $SERVICE_USER code-server --install-extension ritwickdey.liveserver

# Summary
echo ""
echo "================================================================"
echo "Code-server installation completed!"
echo ""
echo "You can access code-server at: http://$(hostname -I | awk '{print $1}'):$CODE_SERVER_PORT"
echo "Password: $CODE_SERVER_PASSWORD"
echo ""
echo "Please change the default password in the config file:"
echo "/home/$SERVICE_USER/.config/code-server/config.yaml"
echo ""
echo "To restart the service after changes:"
echo "systemctl restart code-server"
echo "================================================================" 