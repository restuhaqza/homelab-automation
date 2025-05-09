# VM Creation Guide for Proxmox

This guide explains how to create and manage VMs on your Proxmox server using the automation scripts in this repository.

## Table of Contents
- [Prerequisites](#prerequisites)
- [VM Creation Options](#vm-creation-options)
- [Using the VM Creator Script](#using-the-vm-creator-script)
- [Using the Template Creator Script](#using-the-template-creator-script)
- [Recommended VM Configurations](#recommended-vm-configurations)
- [Common Issues and Solutions](#common-issues-and-solutions)

## Prerequisites

Before you begin, ensure you have:

1. A working Proxmox VE installation on your ThinkCentre
2. Network connectivity between your Mac and Proxmox server
3. SSH access to your Proxmox server
4. The following tools installed on your Mac:
   - `ssh` client (installed by default on macOS)
   - `sshpass` (optional, for password authentication)

## VM Creation Options

You have two main approaches for creating VMs on your Proxmox server:

1. **Direct ISO Installation**: Create a VM and install an OS from an ISO image
   - Use the `proxmox-vm-creator.sh` script
   - Good for initial setup and testing different OS configurations

2. **Template-based Deployment**: Create VMs from pre-configured templates
   - First create a base VM and configure it to your needs
   - Convert it to a template using the `proxmox-template-creator.sh` script
   - Deploy new VMs from this template
   - This approach is much faster and ensures consistent VM configuration

## Using the VM Creator Script

The `proxmox-vm-creator.sh` script automates downloading ISO images and creating VMs directly on your Proxmox server.

### Interactive Mode

For a guided experience, run the script in interactive mode:

```bash
./scripts/infrastructure/proxmox-vm-creator.sh
```

Follow the prompts to:
1. Connect to your Proxmox server
2. List available VMs and ISO images
3. Download ISO images from a predefined list
4. Create new VMs with customized CPU, memory, and storage

### Command Line Mode

For automation in scripts or more direct control, use command line options:

```bash
# List available VMs on the Proxmox server
./scripts/infrastructure/proxmox-vm-creator.sh --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --list-vms

# Download Ubuntu ISO to Proxmox server
./scripts/infrastructure/proxmox-vm-creator.sh --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --download-iso ubuntu-22.04-live-server-amd64.iso

# Create a new VM with the downloaded ISO
./scripts/infrastructure/proxmox-vm-creator.sh --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-vm --vm-name "ubuntu-server" --vm-cores 2 --vm-memory 4096 --vm-disk-size 32 --iso-file ubuntu-22.04-live-server-amd64.iso --start-vm
```

## Using the Template Creator Script

The `proxmox-template-creator.sh` script helps manage VM templates, which allow you to quickly deploy pre-configured VMs.

### Creating Templates

1. First, create and configure a base VM using the VM Creator script
2. Install the OS and configure it as needed
3. Shut down the VM
4. Use the Template Creator script to convert it to a template:

```bash
./scripts/infrastructure/proxmox-template-creator.sh --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-template --source-vm 100 --template-name "Ubuntu Server Template" --template-desc "Ubuntu 22.04 minimal install"
```

### Deploying VMs from Templates

Once you have a template, you can quickly deploy VMs from it:

```bash
./scripts/infrastructure/proxmox-template-creator.sh --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-vm --template-id 900 --vm-name "Web Server" --start-vm
```

This approach is much faster than installing from ISO each time and ensures consistent configuration across VMs.

### Interactive Mode

Like the VM Creator script, the Template Creator also has an interactive mode:

```bash
./scripts/infrastructure/proxmox-template-creator.sh
```

## Recommended VM Configurations

Based on the homelab topology document, here are the recommended configurations for your VMs:

### System VM (Nginx Reverse Proxy)
- **Cores**: 2 vCPU
- **Memory**: 4 GB
- **Disk**: 32 GB
- **OS**: Ubuntu Server 22.04 LTS
- **Network**: Bridge to your LAN

### Storage VM (NAS Functionality)
- **Cores**: 2 vCPU
- **Memory**: 4 GB
- **Disk**: 32 GB base + additional storage volumes as needed
- **OS**: Ubuntu Server 22.04 LTS or TrueNAS Scale
- **Network**: Bridge to your LAN

### Kubernetes/Container Host VM
- **Cores**: 4-6 vCPU
- **Memory**: 16-20 GB
- **Disk**: 64 GB or more
- **OS**: Ubuntu Server 22.04 LTS
- **Network**: Bridge to your LAN

## Common Issues and Solutions

### Cannot Connect to Proxmox Server

If you're having trouble connecting to your Proxmox server:

1. Verify the IP address is correct
2. Ensure SSH is enabled on the Proxmox server
3. Check that your Mac can reach the Proxmox server (try pinging it)
4. Verify SSH credentials (username, password, or SSH key)

### ISO Download Fails

If ISO downloads are failing:

1. Check internet connectivity on the Proxmox server
2. Verify there's enough disk space in the ISO storage
3. Try downloading the ISO manually to your Mac and then uploading it to Proxmox

### VM Creation Fails

If VM creation fails:

1. Check the Proxmox server logs (`/var/log/pve/tasks/`)
2. Verify you have enough resources (CPU, RAM, disk space)
3. Make sure the specified storage locations exist on the Proxmox server

### VM Performance Issues

If VMs are running slowly:

1. Check for resource contention (CPU, memory, disk I/O)
2. Consider deploying fewer VMs with more resources each
3. Add additional storage or use SSD storage for improved performance
4. Enable CPU and I/O limits to prevent a single VM from consuming all resources 