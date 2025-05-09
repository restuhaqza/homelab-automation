#!/bin/bash

# K3s (Lightweight Kubernetes) Setup Script
# For use on a Proxmox VM in the homelab environment
# This script installs k3s and configures it for use

# Print banner
echo "================================================================"
echo "       K3s Kubernetes Cluster Setup Script"
echo "       For Homelab VM Environment"
echo "================================================================"
echo ""

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Variables (can be customized)
K3S_VERSION="v1.26.9+k3s1"  # Can be changed to a specific version if needed
INSTALL_HELM=true
INSTALL_DASHBOARD=true
NODE_TYPE="server"  # can be "server" or "agent"
SERVER_IP=""        # Only needed for agent nodes

# Function to configure system for Kubernetes
prepare_system() {
  echo "Preparing system for Kubernetes..."
  
  # Update the system
  apt update && apt upgrade -y
  
  # Install prerequisites
  apt install -y curl wget apt-transport-https gnupg2 software-properties-common

  # Disable swap (required for Kubernetes)
  swapoff -a
  sed -i '/swap/s/^/#/' /etc/fstab
  
  # Load required kernel modules
  cat > /etc/modules-load.d/k8s.conf << EOF
br_netfilter
overlay
EOF
  modprobe br_netfilter
  modprobe overlay

  # Set up required sysctl parameters
  cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
  sysctl --system
  
  echo "System preparation complete"
}

# Function to install K3s server (control plane)
install_k3s_server() {
  echo "Installing K3s server node..."
  
  # Install K3s server
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} sh -

  # Wait for k3s to start properly
  sleep 10
  
  # Set KUBECONFIG environment variable
  echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  
  # Create .kube directory for current user
  mkdir -p $HOME/.kube
  cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
  chmod 600 $HOME/.kube/config
  
  # Get the token for joining worker nodes
  echo "Node token for joining agents:"
  cat /var/lib/rancher/k3s/server/node-token
  
  # Get the IP address of the server
  SERVER_IP=$(hostname -I | awk '{print $1}')
  echo "Server IP: $SERVER_IP"
  
  echo "K3s server installation complete"
}

# Function to install K3s agent (worker node)
install_k3s_agent() {
  echo "Installing K3s agent node..."
  
  # Check if SERVER_IP is provided
  if [ -z "$SERVER_IP" ]; then
    echo "Error: SERVER_IP is required for agent installation"
    echo "Usage: K3S_TOKEN=<token> SERVER_IP=<ip> $0"
    exit 1
  fi
  
  # Check if K3S_TOKEN is provided
  if [ -z "$K3S_TOKEN" ]; then
    echo "Error: K3S_TOKEN is required for agent installation"
    echo "Usage: K3S_TOKEN=<token> SERVER_IP=<ip> $0"
    exit 1
  fi
  
  # Install K3s agent
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} K3S_URL=https://${SERVER_IP}:6443 K3S_TOKEN=${K3S_TOKEN} sh -
  
  echo "K3s agent installation complete"
}

# Function to install Helm package manager
install_helm() {
  if [ "$INSTALL_HELM" = true ]; then
    echo "Installing Helm package manager..."
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Verify installation
    helm version
    
    echo "Helm installation complete"
  fi
}

# Function to install Kubernetes Dashboard
install_dashboard() {
  if [ "$INSTALL_DASHBOARD" = true ]; then
    echo "Installing Kubernetes Dashboard..."
    
    # Install the Dashboard
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    # Create admin user and role binding
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
    
    # Get token for dashboard login
    echo "Getting token for Dashboard login..."
    kubectl -n kubernetes-dashboard create token admin-user
    
    echo "To access the dashboard, run: kubectl proxy"
    echo "Then visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    
    echo "Kubernetes Dashboard installation complete"
  fi
}

# Function to configure storage class with local-path-provisioner
configure_storage() {
  echo "Configuring persistent storage..."
  
  # K3s includes local-path-provisioner by default, but let's verify it
  if ! kubectl get storageclass | grep -q "local-path"; then
    echo "Installing local-path storage provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
  fi
  
  # Make local-path the default storage class
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  
  echo "Storage configuration complete"
}

# Main function
main() {
  # Confirm with user before proceeding
  echo "This script will install K3s Kubernetes on this system."
  echo "Node type: $NODE_TYPE"
  if [ "$NODE_TYPE" = "agent" ]; then
    echo "Server IP: $SERVER_IP"
  fi
  echo ""
  read -p "Do you want to continue? (y/n): " CONTINUE
  if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi
  
  # Prepare the system
  prepare_system
  
  # Install K3s based on node type
  if [ "$NODE_TYPE" = "server" ]; then
    install_k3s_server
    install_helm
    configure_storage
    install_dashboard
  else
    install_k3s_agent
  fi
  
  echo ""
  echo "================================================================"
  echo "K3s Kubernetes installation completed successfully!"
  echo "================================================================"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --server)
      NODE_TYPE="server"
      shift
      ;;
    --agent)
      NODE_TYPE="agent"
      shift
      ;;
    --server-ip)
      SERVER_IP="$2"
      shift
      shift
      ;;
    --token)
      K3S_TOKEN="$2"
      shift
      shift
      ;;
    --no-helm)
      INSTALL_HELM=false
      shift
      ;;
    --no-dashboard)
      INSTALL_DASHBOARD=false
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --server               Install as server node (default)"
      echo "  --agent                Install as agent node"
      echo "  --server-ip IP         Server IP address (required for agent)"
      echo "  --token TOKEN          Node token (required for agent)"
      echo "  --no-helm              Skip Helm installation"
      echo "  --no-dashboard         Skip Kubernetes Dashboard installation"
      echo "  --help                 Show this help message"
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