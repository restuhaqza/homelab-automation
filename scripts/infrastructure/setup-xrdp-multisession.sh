#!/bin/bash

# Script to install and configure XRDP for multi-session support on ParrotSec with MATE desktop
# This script must be run with sudo privileges

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

echo "Installing XRDP and required dependencies..."
apt update
apt install -y xrdp dbus-x11 xfce4-terminal mate-themes

# Stop xrdp service if it's running
systemctl stop xrdp
systemctl stop xrdp-sesman

# Create custom xsession for MATE
echo "Configuring MATE session for XRDP..."
cat > /etc/xrdp/startwm.sh << EOF
#!/bin/sh
# xrdp X session start script
# Copyright (C) 2022 Matt Burt <matt@burt.id.au>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

# Ensure D-Bus knows where to connect (multi-session fix)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$(id -u)/bus"

# Start mate-session
if [ -r /usr/bin/mate-session ]; then
  exec mate-session
fi

# Failsafe Xsession
if [ -r /usr/bin/xfce4-session ]; then
  exec xfce4-session
fi

# Last resort
exec /bin/sh
EOF

# Make the script executable
chmod +x /etc/xrdp/startwm.sh

# Configure xrdp.ini to enable multi-session
echo "Enabling multi-session support..."
sed -i 's/^allow_multimon=false/allow_multimon=true/g' /etc/xrdp/xrdp.ini
sed -i 's/^max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini
sed -i 's/^crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
sed -i 's/^security_layer=tls/security_layer=negotiate/g' /etc/xrdp/xrdp.ini

# Fix black screen issue caused by Polkit
echo "Fixing Polkit authentication for MATE..."
cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla << EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# Fix home directory permissions
echo "Setting correct permissions for /home directories..."
for user in $(ls /home); do
  if [ -d "/home/$user" ]; then
    chown -R $user:$user /home/$user
    chmod -R 700 /home/$user
  fi
done

# Configure theme compatibility
echo "Configuring theme compatibility..."
mkdir -p /etc/skel/.config/dconf
cat > /etc/skel/.config/dconf/user << EOF
[org/mate/desktop/interface]
gtk-theme='Adwaita'
icon-theme='mate'
EOF

# Enable and start services
echo "Starting XRDP services..."
systemctl enable xrdp
systemctl enable xrdp-sesman
systemctl start xrdp-sesman
systemctl start xrdp

# Configure firewall if UFW is active
if command -v ufw >/dev/null 2>&1; then
  echo "Configuring firewall..."
  ufw allow 3389/tcp
fi

echo "====================================="
echo "XRDP installation and configuration completed."
echo "You can now connect to your ParrotSec using an RDP client."
echo "Default RDP port: 3389"
echo "====================================="
echo "Notes:"
echo "- For theme issues, try switching between dark/light themes in MATE Control Center"
echo "- To connect from Windows: use Remote Desktop Connection"
echo "- To connect from Linux: use Remmina or any RDP client"
echo "- To connect from macOS: use Microsoft Remote Desktop"
echo "=====================================" 