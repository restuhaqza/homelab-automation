#!/bin/bash

# Nginx Installation Script
# This script installs and configures Nginx server with reverse proxy capabilities
# Compatible with Debian/Ubuntu-based systems

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Print banner
echo "================================================================"
echo "       Nginx Installation Script"
echo "       For Homelab Automation Project"
echo "================================================================"
echo ""

# Set variables
NGINX_USER="www-data"
NGINX_CONF_DIR="/etc/nginx"
SITES_AVAILABLE_DIR="$NGINX_CONF_DIR/sites-available"
SITES_ENABLED_DIR="$NGINX_CONF_DIR/sites-enabled"
ENABLE_SSL=true  # SSL enabled by default
DEFAULT_SERVER_NAME="homelab.local"
DEFAULT_PORT=80
DEFAULT_SSL_PORT=443
SETUP_REVERSE_PROXY=false
REVERSE_PROXY_TARGET=""
REVERSE_PROXY_PORT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --server-name)
      DEFAULT_SERVER_NAME="$2"
      shift 2
      ;;
    --disable-ssl)  # New flag to disable SSL
      ENABLE_SSL=false
      shift
      ;;
    --setup-reverse-proxy)
      SETUP_REVERSE_PROXY=true
      shift
      ;;
    --proxy-target)
      REVERSE_PROXY_TARGET="$2"
      shift 2
      ;;
    --proxy-port)
      REVERSE_PROXY_PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# If reverse proxy is enabled but no target specified, prompt user
if [ "$SETUP_REVERSE_PROXY" = true ] && [ -z "$REVERSE_PROXY_TARGET" ]; then
  read -p "Enter the reverse proxy target (e.g., localhost): " REVERSE_PROXY_TARGET
  read -p "Enter the reverse proxy port (e.g., 8080): " REVERSE_PROXY_PORT
fi

# Confirm settings with user
echo "This script will install Nginx with the following settings:"
echo "Server Name: $DEFAULT_SERVER_NAME"
echo "SSL Enabled: $ENABLE_SSL"
echo "Setup Reverse Proxy: $SETUP_REVERSE_PROXY"

if [ "$SETUP_REVERSE_PROXY" = true ]; then
  echo "Reverse Proxy Target: $REVERSE_PROXY_TARGET"
  echo "Reverse Proxy Port: $REVERSE_PROXY_PORT"
fi

echo ""
read -p "Continue with these settings? (y/n): " CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo "Installation aborted by user"
  exit 1
fi

# Update system
echo "Updating system packages..."
apt update

# Install Nginx and related packages
echo "Installing Nginx and related packages..."
apt install -y nginx curl gnupg2 ssl-cert

# Create directory structure if not exists
echo "Creating directory structure..."
mkdir -p $SITES_AVAILABLE_DIR
mkdir -p $SITES_ENABLED_DIR
mkdir -p /var/www/html/$DEFAULT_SERVER_NAME/public

# Set up default index page
echo "Setting up default index page..."
cat > /var/www/html/$DEFAULT_SERVER_NAME/public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Restricted Area | Kawasan Berbahaya</title>
    <style>
        :root {
            --bg-color: #f5f5f5;
            --text-color: #333;
            --primary-color: #cc0000;
            --secondary-color: #870000;
            --border-color: #ddd;
            --container-bg: #fff;
            --shadow-color: rgba(0, 0, 0, 0.1);
            --warning-bg: rgba(204, 0, 0, 0.1);
        }
        
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-color: #121212;
                --text-color: #e0e0e0;
                --primary-color: #ff4444;
                --secondary-color: #cc0000;
                --border-color: #333;
                --container-bg: #1e1e1e;
                --shadow-color: rgba(0, 0, 0, 0.4);
                --warning-bg: rgba(204, 0, 0, 0.2);
            }
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            display: flex;
            flex-direction: column;
            min-height: 100vh;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            width: 100%;
            background-color: var(--container-bg);
            border-radius: 10px;
            box-shadow: 0 4px 15px var(--shadow-color);
            overflow: hidden;
            margin: 20px 0;
        }
        
        .header {
            background-color: var(--primary-color);
            color: white;
            padding: 20px;
            text-align: center;
            position: relative;
        }
        
        .warning-tape {
            background: repeating-linear-gradient(
                45deg,
                var(--primary-color),
                var(--primary-color) 10px,
                var(--secondary-color) 10px,
                var(--secondary-color) 20px
            );
            height: 20px;
        }
        
        .content {
            padding: 30px;
        }
        
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        
        .subtitle {
            font-size: 1.5em;
            font-weight: normal;
            margin-bottom: 5px;
            color: rgba(255, 255, 255, 0.9);
        }
        
        .warning-box {
            background-color: var(--warning-bg);
            border-left: 5px solid var(--primary-color);
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        
        ul {
            list-style-type: none;
            margin: 20px 0;
        }
        
        ul li {
            padding: 10px 0;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
        }
        
        ul li:before {
            content: "⚠️";
            margin-right: 10px;
        }
        
        .footer {
            margin-top: 20px;
            font-size: 0.8em;
            color: #777;
            text-align: center;
            border-top: 1px solid var(--border-color);
            padding-top: 15px;
        }
        
        .button {
            display: inline-block;
            background-color: var(--primary-color);
            color: white;
            padding: 10px 20px;
            border-radius: 5px;
            text-decoration: none;
            font-weight: bold;
            margin-top: 20px;
            transition: background-color 0.3s;
        }
        
        .button:hover {
            background-color: var(--secondary-color);
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.7; }
            100% { opacity: 1; }
        }
        
        .pulse {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="warning-tape"></div>
        <div class="header">
            <h1 class="pulse">RESTRICTED AREA</h1>
            <p class="subtitle">KAWASAN BERBAHAYA</p>
        </div>
        <div class="warning-tape"></div>
        
        <div class="content">
            <div class="warning-box">
                <p>This server is a part of a private homelab infrastructure. Unauthorized access is strictly prohibited and may be subject to monitoring, logging, and legal action.</p>
            </div>
            
            <h2>System Details:</h2>
            <ul>
                <li>Hostname: $(hostname)</li>
                <li>IP Address: $(hostname -I | awk '{print $1}')</li>
                <li>Nginx Version: $(nginx -v 2>&1 | cut -d'/' -f2)</li>
                <li>Operating System: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)</li>
            </ul>
            
            <h2>Access Information:</h2>
            <ul>
                <li>Server Status: <a href="/status">Status Page</a> (authorized users only)</li>
                <li>Access Time: $(date)</li>
                <li>Your IP: \${remote_addr}</li>
            </ul>
            
            <a href="javascript:history.back()" class="button">Go Back</a>
        </div>
        
        <div class="footer">
            Powered by Homelab Automation
        </div>
    </div>
</body>
</html>
EOF

# Create Nginx server configuration
echo "Creating Nginx server configuration..."

if [ "$SETUP_REVERSE_PROXY" = true ]; then
  # Create reverse proxy configuration
  cat > $SITES_AVAILABLE_DIR/$DEFAULT_SERVER_NAME << EOF
server {
    listen $DEFAULT_PORT;
    server_name $DEFAULT_SERVER_NAME;
    access_log /var/log/nginx/$DEFAULT_SERVER_NAME-access.log;
    error_log /var/log/nginx/$DEFAULT_SERVER_NAME-error.log;

    location / {
        proxy_pass http://$REVERSE_PROXY_TARGET:$REVERSE_PROXY_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

  if [ "$ENABLE_SSL" = true ]; then
    # Create SSL configuration for reverse proxy
    cat > $SITES_AVAILABLE_DIR/${DEFAULT_SERVER_NAME}-ssl << EOF
server {
    listen $DEFAULT_SSL_PORT ssl;
    server_name $DEFAULT_SERVER_NAME;
    access_log /var/log/nginx/$DEFAULT_SERVER_NAME-ssl-access.log;
    error_log /var/log/nginx/$DEFAULT_SERVER_NAME-ssl-error.log;

    # SSL Configuration
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    location / {
        proxy_pass http://$REVERSE_PROXY_TARGET:$REVERSE_PROXY_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
  fi
else
  # Create standard web server configuration
  cat > $SITES_AVAILABLE_DIR/$DEFAULT_SERVER_NAME << EOF
server {
    listen $DEFAULT_PORT;
    server_name $DEFAULT_SERVER_NAME;
    root /var/www/html/$DEFAULT_SERVER_NAME/public;
    index index.html index.htm index.php;

    access_log /var/log/nginx/$DEFAULT_SERVER_NAME-access.log;
    error_log /var/log/nginx/$DEFAULT_SERVER_NAME-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

  if [ "$ENABLE_SSL" = true ]; then
    # Create SSL configuration for web server
    cat > $SITES_AVAILABLE_DIR/${DEFAULT_SERVER_NAME}-ssl << EOF
server {
    listen $DEFAULT_SSL_PORT ssl;
    server_name $DEFAULT_SERVER_NAME;
    root /var/www/html/$DEFAULT_SERVER_NAME/public;
    index index.html index.htm index.php;

    access_log /var/log/nginx/$DEFAULT_SERVER_NAME-ssl-access.log;
    error_log /var/log/nginx/$DEFAULT_SERVER_NAME-ssl-error.log;

    # SSL Configuration
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
  fi
fi

# Enable site configuration
echo "Enabling site configuration..."
ln -sf $SITES_AVAILABLE_DIR/$DEFAULT_SERVER_NAME $SITES_ENABLED_DIR/

if [ "$ENABLE_SSL" = true ]; then
  ln -sf $SITES_AVAILABLE_DIR/${DEFAULT_SERVER_NAME}-ssl $SITES_ENABLED_DIR/
fi

# Remove default configuration if it exists
if [ -f $SITES_ENABLED_DIR/default ]; then
  rm $SITES_ENABLED_DIR/default
fi

# Create optimized nginx.conf
echo "Creating optimized nginx.conf..."
cat > $NGINX_CONF_DIR/nginx.conf << EOF
user $NGINX_USER;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 100M;

    # MIME Types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Set permissions
echo "Setting proper permissions..."
chown -R $NGINX_USER:$NGINX_USER /var/www/html/$DEFAULT_SERVER_NAME

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

if [ $? -ne 0 ]; then
  echo "Nginx configuration test failed. Please check the configuration."
  exit 1
fi

# Restart Nginx
echo "Restarting Nginx..."
systemctl restart nginx
systemctl enable nginx

# Configure firewall if available
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
  ufw allow 'Nginx Full'
  echo "UFW rules added for Nginx"
elif command -v firewall-cmd &> /dev/null; then
  firewall-cmd --permanent --add-service=http
  [ "$ENABLE_SSL" = true ] && firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
  echo "FirewallD rules added for Nginx"
else
  echo "No firewall detected, please manually configure firewall rules if needed"
fi

# Generate self-signed certificate info
CERT_INFO=""
if [ "$ENABLE_SSL" = true ]; then
  CERT_INFO="- Self-signed SSL certificate is configured at:
  - Certificate: /etc/ssl/certs/ssl-cert-snakeoil.pem
  - Private Key: /etc/ssl/private/ssl-cert-snakeoil.key

  For production, replace with Let's Encrypt certificates:
  certbot --nginx -d $DEFAULT_SERVER_NAME"
fi

# Summary
echo ""
echo "================================================================"
echo "Nginx installation completed!"
echo ""
echo "Server Configuration:"
echo "- Server Name: $DEFAULT_SERVER_NAME"
echo "- Web Root: /var/www/html/$DEFAULT_SERVER_NAME/public"
echo "- HTTP Port: $DEFAULT_PORT"
[ "$ENABLE_SSL" = true ] && echo "- HTTPS Port: $DEFAULT_SSL_PORT"
[ "$SETUP_REVERSE_PROXY" = true ] && echo "- Reverse Proxy to: http://$REVERSE_PROXY_TARGET:$REVERSE_PROXY_PORT"
echo ""
echo "Configuration Files:"
echo "- Main Config: $NGINX_CONF_DIR/nginx.conf"
echo "- Site Config: $SITES_AVAILABLE_DIR/$DEFAULT_SERVER_NAME"
[ "$ENABLE_SSL" = true ] && echo "- SSL Config: $SITES_AVAILABLE_DIR/${DEFAULT_SERVER_NAME}-ssl"
echo ""
echo "Access your server at:"
echo "- http://$DEFAULT_SERVER_NAME"
[ "$ENABLE_SSL" = true ] && echo "- https://$DEFAULT_SERVER_NAME"
echo "- http://$(hostname -I | awk '{print $1}')"
[ "$ENABLE_SSL" = true ] && echo "- https://$(hostname -I | awk '{print $1}')"
echo ""
echo "$CERT_INFO"
echo "================================================================" 