#!/bin/bash

# Docker and Portainer Setup Script
# For use on a Proxmox VM in the homelab environment
# This script installs Docker, Docker Compose, and Portainer

# Print banner
echo "================================================================"
echo "       Docker and Portainer Setup Script"
echo "       For Homelab VM Environment"
echo "================================================================"
echo ""

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Variables (can be customized)
INSTALL_PORTAINER=true
INSTALL_COMPOSE=true
PORTAINER_PORT=9000
DOCKER_DATA_DIR="/var/lib/docker"
DOCKER_COMPOSE_VERSION="v2.21.0"  # Set to "latest" for the latest version

# Function to configure system for Docker
prepare_system() {
  echo "Preparing system for Docker installation..."
  
  # Update the system
  apt update && apt upgrade -y
  
  # Install prerequisites
  apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

  # Load required kernel modules
  cat > /etc/modules-load.d/docker.conf << EOF
overlay
br_netfilter
EOF
  modprobe overlay
  modprobe br_netfilter

  # Set up required sysctl parameters
  cat > /etc/sysctl.d/docker.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
  sysctl --system
  
  echo "System preparation complete"
}

# Function to install Docker
install_docker() {
  echo "Installing Docker..."
  
  # Remove any old versions
  apt remove -y docker docker-engine docker.io containerd runc || true
  
  # Add Docker's official GPG key
  curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  
  # Add the repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Install Docker Engine
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  
  # Configure Docker to start on boot
  systemctl enable docker
  systemctl start docker
  
  # Create docker group and add current user (if not root)
  groupadd -f docker
  if [ -n "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    echo "Added user $SUDO_USER to the docker group"
  fi
  
  # Verify installation
  docker --version
  
  echo "Docker installation complete"
}

# Function to install Docker Compose
install_docker_compose() {
  if [ "$INSTALL_COMPOSE" = true ]; then
    echo "Installing Docker Compose..."
    
    # Get the latest version if specified
    if [ "$DOCKER_COMPOSE_VERSION" = "latest" ]; then
      DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    fi
    
    # Install Docker Compose
    mkdir -p /usr/local/lib/docker/cli-plugins/
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    
    # Verify installation
    docker compose version
    
    echo "Docker Compose installation complete"
  fi
}

# Function to install Portainer
install_portainer() {
  if [ "$INSTALL_PORTAINER" = true ]; then
    echo "Installing Portainer..."
    
    # Create Portainer volume
    docker volume create portainer_data
    
    # Remove any existing Portainer container
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Install Portainer
    docker run -d \
      --name portainer \
      --restart=always \
      -p $PORTAINER_PORT:9000 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest
    
    # Get the IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo "Portainer installation complete"
    echo "You can access Portainer at: http://$SERVER_IP:$PORTAINER_PORT"
  fi
}

# Function to configure firewall
configure_firewall() {
  echo "Configuring firewall..."
  
  # Check if UFW is installed
  if command -v ufw &> /dev/null; then
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow Docker port range
    ufw allow 2375/tcp
    ufw allow 2376/tcp
    
    # Allow Portainer if installed
    if [ "$INSTALL_PORTAINER" = true ]; then
      ufw allow $PORTAINER_PORT/tcp
    fi
    
    # Enable firewall if not already enabled
    if ! ufw status | grep -q "Status: active"; then
      echo "y" | ufw enable
    fi
    
    ufw status
  else
    echo "UFW not installed, skipping firewall configuration"
  fi
}

# Function to create an example Docker Compose file
create_example_compose() {
  if [ "$INSTALL_COMPOSE" = true ]; then
    echo "Creating example Docker Compose file..."
    
    # Create directory for Docker Compose files
    mkdir -p /opt/docker-compose
    
    # Create an example Docker Compose file
    cat > /opt/docker-compose/example.yml << EOF
version: '3'

# This is an example Docker Compose file with some common services
# Uncomment the services you want to use

services:
  # Web server example
  # nginx:
  #   image: nginx:latest
  #   container_name: nginx
  #   restart: unless-stopped
  #   ports:
  #     - "80:80"
  #     - "443:443"
  #   volumes:
  #     - /opt/docker-compose/nginx/html:/usr/share/nginx/html
  #     - /opt/docker-compose/nginx/conf:/etc/nginx/conf.d
  #   networks:
  #     - web

  # Database example
  # mariadb:
  #   image: mariadb:latest
  #   container_name: mariadb
  #   restart: unless-stopped
  #   environment:
  #     MYSQL_ROOT_PASSWORD: your_secure_password
  #     MYSQL_DATABASE: your_database
  #     MYSQL_USER: your_user
  #     MYSQL_PASSWORD: your_password
  #   volumes:
  #     - /opt/docker-compose/mariadb:/var/lib/mysql
  #   networks:
  #     - database

  # Monitoring example
  # prometheus:
  #   image: prom/prometheus:latest
  #   container_name: prometheus
  #   restart: unless-stopped
  #   ports:
  #     - "9090:9090"
  #   volumes:
  #     - /opt/docker-compose/prometheus:/etc/prometheus
  #   networks:
  #     - monitoring

  # grafana:
  #   image: grafana/grafana:latest
  #   container_name: grafana
  #   restart: unless-stopped
  #   ports:
  #     - "3000:3000"
  #   volumes:
  #     - /opt/docker-compose/grafana:/var/lib/grafana
  #   networks:
  #     - monitoring
  #   depends_on:
  #     - prometheus

# Define networks for better isolation
networks:
  web:
    driver: bridge
  database:
    driver: bridge
  monitoring:
    driver: bridge
EOF
    
    # Create the directory structure
    mkdir -p /opt/docker-compose/nginx/{html,conf}
    mkdir -p /opt/docker-compose/mariadb
    mkdir -p /opt/docker-compose/prometheus
    mkdir -p /opt/docker-compose/grafana
    
    echo "Example Docker Compose file created at /opt/docker-compose/example.yml"
  fi
}

# Main function
main() {
  # Confirm with user before proceeding
  echo "This script will install Docker on this system."
  if [ "$INSTALL_COMPOSE" = true ]; then
    echo "Docker Compose will also be installed."
  fi
  if [ "$INSTALL_PORTAINER" = true ]; then
    echo "Portainer will be installed and available at port $PORTAINER_PORT."
  fi
  echo ""
  read -p "Do you want to continue? (y/n): " CONTINUE
  if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi
  
  # Prepare the system
  prepare_system
  
  # Install Docker and tools
  install_docker
  install_docker_compose
  install_portainer
  configure_firewall
  create_example_compose
  
  echo ""
  echo "================================================================"
  echo "Docker and tools installation completed successfully!"
  if [ "$INSTALL_PORTAINER" = true ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "Portainer is available at: http://$SERVER_IP:$PORTAINER_PORT"
  fi
  echo "================================================================"
  
  # Notify about user inclusion in docker group
  if [ -n "$SUDO_USER" ]; then
    echo "NOTE: You may need to log out and back in for the docker group changes to take effect."
    echo "To use Docker as a non-root user, run: newgrp docker"
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --no-portainer)
      INSTALL_PORTAINER=false
      shift
      ;;
    --no-compose)
      INSTALL_COMPOSE=false
      shift
      ;;
    --portainer-port)
      PORTAINER_PORT="$2"
      shift
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --no-portainer          Skip Portainer installation"
      echo "  --no-compose            Skip Docker Compose installation"
      echo "  --portainer-port PORT   Set Portainer port (default: 9000)"
      echo "  --help                  Show this help message"
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