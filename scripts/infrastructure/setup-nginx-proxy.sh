#!/bin/bash

# Nginx Reverse Proxy Setup Script
# For use on the system VM in the homelab environment
# This script installs Nginx and configures it as a reverse proxy for various services

# Print banner
echo "================================================================"
echo "       Nginx Reverse Proxy Setup Script"
echo "       For Homelab System VM"
echo "================================================================"
echo ""

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Variables (can be customized)
INSTALL_CERTBOT=true
ENABLE_SSL=true
DOMAIN_NAME="homelab.local"  # Change to your domain if using real SSL
EMAIL_ADDRESS="your.email@example.com"  # For Let's Encrypt notifications

# Function to install Nginx
install_nginx() {
  echo "Installing Nginx..."
  
  # Update repositories
  apt update
  
  # Install Nginx
  apt install -y nginx
  
  # Enable and start Nginx
  systemctl enable nginx
  systemctl start nginx
  
  # Verify installation
  nginx -v
  
  echo "Nginx installation complete"
}

# Function to install Certbot for SSL
install_certbot() {
  if [ "$INSTALL_CERTBOT" = true ] && [ "$ENABLE_SSL" = true ]; then
    echo "Installing Certbot for SSL..."
    
    # Install Certbot and Nginx plugin
    apt install -y certbot python3-certbot-nginx
    
    echo "Certbot installation complete"
  fi
}

# Function to configure basic Nginx settings
configure_nginx_base() {
  echo "Configuring base Nginx settings..."
  
  # Backup original configuration
  cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
  
  # Create optimized Nginx configuration
  cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # MIME Types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    # Logging Settings
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
    
    # Security Headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self' data:; style-src 'self'; font-src 'self'; connect-src 'self';";
    
    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
    
    # Upstream Definitions
    include /etc/nginx/upstreams/*.conf;
}
EOF
  
  # Create directories for configuration
  mkdir -p /etc/nginx/upstreams
  mkdir -p /etc/nginx/sites-available
  mkdir -p /etc/nginx/sites-enabled
  
  echo "Base Nginx configuration complete"
}

# Function to create a default landing page
create_landing_page() {
  echo "Creating landing page..."
  
  # Create landing page directory
  mkdir -p /var/www/html/landing
  
  # Create a simple but good looking landing page with dark/light mode support
  cat > /var/www/html/landing/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Homelab Dashboard</title>
    <style>
        :root {
            --bg-color: #f5f7fa;
            --text-color: #333;
            --card-bg: #fff;
            --card-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            --header-bg: #2a3f5f;
            --header-text: #fff;
            --link-color: #3498db;
            --link-hover: #2980b9;
            --border-color: #e1e4e8;
        }
        
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-color: #1a1a1a;
                --text-color: #e0e0e0;
                --card-bg: #2d2d2d;
                --card-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
                --header-bg: #1e293b;
                --header-text: #f8fafc;
                --link-color: #60a5fa;
                --link-hover: #93c5fd;
                --border-color: #4b5563;
            }
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            margin: 0;
            padding: 0;
            transition: all 0.3s ease;
        }
        
        header {
            background-color: var(--header-bg);
            color: var(--header-text);
            padding: 2rem;
            text-align: center;
        }
        
        h1 {
            margin: 0;
            font-size: 2.5rem;
        }
        
        .subtitle {
            opacity: 0.8;
            margin-top: 0.5rem;
        }
        
        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 1rem;
        }
        
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-top: 2rem;
        }
        
        .service-card {
            background-color: var(--card-bg);
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: var(--card-shadow);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            border: 1px solid var(--border-color);
        }
        
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 16px rgba(0, 0, 0, 0.1);
        }
        
        .service-card h3 {
            margin-top: 0;
            color: var(--link-color);
        }
        
        .service-card p {
            margin-bottom: 1rem;
            opacity: 0.8;
        }
        
        a.service-link {
            display: inline-block;
            color: var(--link-color);
            text-decoration: none;
            font-weight: 500;
            padding: 0.5rem 1rem;
            border-radius: 4px;
            border: 1px solid var(--link-color);
            transition: all 0.3s ease;
        }
        
        a.service-link:hover {
            background-color: var(--link-color);
            color: white;
        }
        
        footer {
            text-align: center;
            padding: 2rem;
            margin-top: 2rem;
            border-top: 1px solid var(--border-color);
            font-size: 0.9rem;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <header>
        <h1>Homelab Dashboard</h1>
        <p class="subtitle">Central access to all your homelab services</p>
    </header>
    
    <div class="container">
        <div class="services">
            <!-- Example service cards - these will be replaced by the actual services -->
            <div class="service-card">
                <h3>Proxmox VE</h3>
                <p>Virtual environment management interface for your homelab infrastructure.</p>
                <a href="/proxmox/" class="service-link">Access Proxmox</a>
            </div>
            
            <div class="service-card">
                <h3>Portainer</h3>
                <p>Docker container management with an easy-to-use interface.</p>
                <a href="/portainer/" class="service-link">Access Portainer</a>
            </div>
            
            <div class="service-card">
                <h3>Kubernetes Dashboard</h3>
                <p>Web UI for managing applications running in your K3s cluster.</p>
                <a href="/kubernetes/" class="service-link">Access Dashboard</a>
            </div>
            
            <div class="service-card">
                <h3>Grafana</h3>
                <p>Monitoring and observability platform for visualizing metrics.</p>
                <a href="/grafana/" class="service-link">Access Grafana</a>
            </div>
            
            <div class="service-card">
                <h3>System Status</h3>
                <p>Check the current status of all homelab systems and services.</p>
                <a href="/status/" class="service-link">View Status</a>
            </div>
            
            <div class="service-card">
                <h3>Documentation</h3>
                <p>Homelab documentation, guides, and reference materials.</p>
                <a href="/docs/" class="service-link">View Docs</a>
            </div>
        </div>
    </div>
    
    <footer>
        <p>Homelab Automation Project | <span id="current-year"></span></p>
    </footer>
    
    <script>
        // Set current year in footer
        document.getElementById('current-year').textContent = new Date().getFullYear();
    </script>
</body>
</html>
EOF
  
  # Set proper permissions
  chown -R www-data:www-data /var/www/html/landing
  
  echo "Landing page created"
}

# Function to create default Nginx site configuration
create_default_site() {
  echo "Creating default site configuration..."
  
  # Create default site configuration
  cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html/landing;
    index index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
  
  # Enable the site if it's not already enabled
  if [ ! -L /etc/nginx/sites-enabled/default ]; then
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  fi
  
  echo "Default site configuration created"
}

# Function to create proxy configurations for services
create_proxy_configs() {
  echo "Creating proxy configurations for services..."
  
  # Create a Proxmox VE proxy configuration
  cat > /etc/nginx/sites-available/proxmox << EOF
# Proxmox VE proxy configuration
server {
    listen 80;
    server_name proxmox.$DOMAIN_NAME;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name proxmox.$DOMAIN_NAME;
    
    # SSL Configuration will be added by Certbot if enabled
    
    location / {
        proxy_pass https://PROXMOX_IP:8006;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Don't buffer
        proxy_buffering off;
    }
}
EOF

  # Create a Portainer proxy configuration
  cat > /etc/nginx/sites-available/portainer << EOF
# Portainer proxy configuration
server {
    listen 80;
    server_name portainer.$DOMAIN_NAME;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name portainer.$DOMAIN_NAME;
    
    # SSL Configuration will be added by Certbot if enabled
    
    location / {
        proxy_pass http://PORTAINER_IP:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

  # Create a Kubernetes Dashboard proxy configuration
  cat > /etc/nginx/sites-available/kubernetes << EOF
# Kubernetes Dashboard proxy configuration
server {
    listen 80;
    server_name kubernetes.$DOMAIN_NAME;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name kubernetes.$DOMAIN_NAME;
    
    # SSL Configuration will be added by Certbot if enabled
    
    location / {
        proxy_pass http://K8S_IP:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

  # Create a Grafana proxy configuration
  cat > /etc/nginx/sites-available/grafana << EOF
# Grafana proxy configuration
server {
    listen 80;
    server_name grafana.$DOMAIN_NAME;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name grafana.$DOMAIN_NAME;
    
    # SSL Configuration will be added by Certbot if enabled
    
    location / {
        proxy_pass http://GRAFANA_IP:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  echo "Proxy configurations created"
  echo "NOTE: You need to replace placeholder IP addresses in the configuration files with actual IPs."
  echo "      Example: sed -i 's/PROXMOX_IP/192.168.1.10/g' /etc/nginx/sites-available/proxmox"
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
  if [ "$ENABLE_SSL" = true ]; then
    echo "Setting up SSL with Let's Encrypt..."
    
    # Check if we're using a real domain or local domain
    if [[ "$DOMAIN_NAME" == *".local"* ]] || [[ "$DOMAIN_NAME" == *".lan"* ]] || [[ "$DOMAIN_NAME" == *".home"* ]]; then
      echo "Using local domain: $DOMAIN_NAME"
      echo "For local domains, Let's Encrypt cannot be used. Will setup self-signed certificates instead."
      
      # Create directory for SSL certificates
      mkdir -p /etc/nginx/ssl
      
      # Generate a private key
      openssl genrsa -out /etc/nginx/ssl/homelab.key 2048
      
      # Generate a self-signed certificate
      openssl req -new -key /etc/nginx/ssl/homelab.key -out /etc/nginx/ssl/homelab.csr -subj "/CN=$DOMAIN_NAME"
      openssl x509 -req -days 365 -in /etc/nginx/ssl/homelab.csr -signkey /etc/nginx/ssl/homelab.key -out /etc/nginx/ssl/homelab.crt
      
      # Update all site configurations to use the self-signed certificate
      for site in /etc/nginx/sites-available/*; do
        if [ "$(basename $site)" != "default" ]; then
          # Add SSL certificate configuration after the server_name line
          sed -i "/server_name/a \ \ \ \ ssl_certificate /etc/nginx/ssl/homelab.crt;\n\ \ \ \ ssl_certificate_key /etc/nginx/ssl/homelab.key;" $site
        fi
      done
      
      echo "Self-signed certificates have been created and configured."
      echo "NOTE: Browsers will show a warning for self-signed certificates."
    else
      echo "Using public domain: $DOMAIN_NAME"
      echo "Will attempt to set up Let's Encrypt certificates."
      
      # Request certificates for all configured domains
      for site in /etc/nginx/sites-available/*; do
        if [ "$(basename $site)" != "default" ]; then
          domain=$(grep server_name $site | head -1 | awk '{print $2}' | sed 's/;//')
          if [ -n "$domain" ]; then
            echo "Setting up SSL for $domain..."
            certbot --nginx -d $domain --non-interactive --agree-tos --email $EMAIL_ADDRESS
          fi
        fi
      done
      
      echo "Let's Encrypt certificates have been set up."
      echo "Certificates will auto-renew via Certbot's timer service."
    fi
  else
    echo "SSL setup skipped as per configuration."
  fi
}

# Function to enable site configurations
enable_sites() {
  echo "Enabling site configurations..."
  
  # Enable all sites
  for site in /etc/nginx/sites-available/*; do
    site_name=$(basename $site)
    if [ "$site_name" != "default" ] && [ ! -L "/etc/nginx/sites-enabled/$site_name" ]; then
      ln -s $site /etc/nginx/sites-enabled/
      echo "Enabled site: $site_name"
    fi
  done
  
  # Test Nginx configuration
  nginx -t
  
  # Reload Nginx to apply changes
  systemctl reload nginx
  
  echo "Site configurations enabled and Nginx reloaded"
}

# Function to configure firewall
configure_firewall() {
  echo "Configuring firewall..."
  
  # Check if UFW is installed
  if command -v ufw &> /dev/null; then
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall if not already enabled
    if ! ufw status | grep -q "Status: active"; then
      echo "y" | ufw enable
    fi
    
    ufw status
  else
    echo "UFW not installed, skipping firewall configuration"
  fi
}

# Main function
main() {
  # Confirm with user before proceeding
  echo "This script will install and configure Nginx as a reverse proxy for your homelab services."
  echo "Domain name: $DOMAIN_NAME"
  if [ "$ENABLE_SSL" = true ]; then
    if [[ "$DOMAIN_NAME" == *".local"* ]] || [[ "$DOMAIN_NAME" == *".lan"* ]] || [[ "$DOMAIN_NAME" == *".home"* ]]; then
      echo "SSL: Self-signed certificates will be used (local domain)"
    else
      echo "SSL: Let's Encrypt certificates will be used"
      echo "Email for Let's Encrypt: $EMAIL_ADDRESS"
    fi
  else
    echo "SSL: Disabled"
  fi
  echo ""
  read -p "Do you want to continue? (y/n): " CONTINUE
  if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi
  
  # Step 1: Install Nginx
  install_nginx
  
  # Step 2: Install Certbot
  install_certbot
  
  # Step 3: Configure Nginx base settings
  configure_nginx_base
  
  # Step 4: Create landing page
  create_landing_page
  
  # Step 5: Create default site
  create_default_site
  
  # Step 6: Create proxy configurations
  create_proxy_configs
  
  # Step 7: Configure firewall
  configure_firewall
  
  # Step 8: Set up SSL
  setup_ssl
  
  # Step 9: Enable sites
  enable_sites
  
  echo ""
  echo "================================================================"
  echo "Nginx reverse proxy setup completed successfully!"
  echo ""
  echo "Next steps:"
  echo "1. Replace placeholder IP addresses in the configuration files with actual IPs:"
  echo "   - Edit files in /etc/nginx/sites-available/"
  echo "   - Replace PROXMOX_IP, PORTAINER_IP, K8S_IP, GRAFANA_IP with actual values"
  echo ""
  echo "2. For each service, you may need to configure DNS or hosts file entries:"
  echo "   - Add entries to /etc/hosts or your local DNS server"
  echo "   - Example: 192.168.1.5 proxmox.$DOMAIN_NAME portainer.$DOMAIN_NAME"
  echo ""
  echo "3. Access your homelab dashboard at: http://<server-ip>/"
  if [ "$ENABLE_SSL" = true ]; then
    echo "   Or via HTTPS: https://<server-ip>/"
  fi
  echo "================================================================"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN_NAME="$2"
      shift
      shift
      ;;
    --email)
      EMAIL_ADDRESS="$2"
      shift
      shift
      ;;
    --no-ssl)
      ENABLE_SSL=false
      shift
      ;;
    --no-certbot)
      INSTALL_CERTBOT=false
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --domain DOMAIN       Set domain name (default: homelab.local)"
      echo "  --email EMAIL         Set email for Let's Encrypt (default: your.email@example.com)"
      echo "  --no-ssl              Disable SSL setup"
      echo "  --no-certbot          Skip Certbot installation"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $key"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Run the main function
main 