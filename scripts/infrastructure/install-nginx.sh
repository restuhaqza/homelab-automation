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
<html>
<head>
    <title>Welcome to Homelab Server</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding: 2em;
            background-color: #f5f5f5;
            color: #333;
        }
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #222;
                color: #f0f0f0;
            }
            a {
                color: #6ea8fe;
            }
            a:visited {
                color: #b589ec;
            }
        }
        h1 {
            color: #486;
            font-size: 2em;
            margin-bottom: 0.5em;
        }
        ul {
            list-style-type: square;
            padding-left: 1.2em;
        }
        .footer {
            margin-top: 2em;
            font-size: 0.8em;
            color: #777;
            border-top: 1px solid #ddd;
            padding-top: 1em;
        }
    </style>
</head>
<body>
    <h1>Welcome to your Homelab Server!</h1>
    <p>If you see this page, the Nginx web server is successfully installed and working.</p>

    <h2>System Details:</h2>
    <ul>
        <li>Hostname: $(hostname)</li>
        <li>IP Address: $(hostname -I | awk '{print $1}')</li>
        <li>Nginx Version: $(nginx -v 2>&1 | cut -d'/' -f2)</li>
        <li>Operating System: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)</li>
    </ul>

    <h2>Quick Links:</h2>
    <ul>
        <li><a href="/status">Server Status</a></li>
        <li><a href="https://github.com/yourusername/homelab-automation">Homelab Automation</a></li>
    </ul>

    <div class="footer">
        Powered by Nginx | $(date)
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