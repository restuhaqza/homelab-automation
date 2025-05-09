#!/bin/bash

# Proxmox VM Creator Script
# This script automates downloading ISO images and creating VMs on Proxmox
# Run this on your Mac to manage your Proxmox server remotely

# Print banner
echo "================================================================"
echo "       Proxmox VM Creator Script"
echo "       For Homelab Automation"
echo "================================================================"
echo ""

# Default variables
PROXMOX_HOST=""
PROXMOX_USER="root@pam"
PROXMOX_PASSWORD=""
PROXMOX_NODE="pve"
STORAGE_NAME="local"
ISO_STORAGE="local"
SSH_KEY_FILE=""
SSH_PORT=22
VM_ID=""
VM_NAME=""
VM_CORES=2
VM_MEMORY=2048
VM_DISK_SIZE=32
VM_NETWORK_BRIDGE="vmbr0"
ISO_FILE=""
INTERACTIVE=true

# Array of common ISO images with download URLs
declare -A ISO_URLS
ISO_URLS["ubuntu-22.04-live-server-amd64.iso"]="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
ISO_URLS["ubuntu-23.10-live-server-amd64.iso"]="https://old-releases.ubuntu.com/releases/mantic/ubuntu-23.10-live-server-amd64.iso"
ISO_URLS["ubuntu-24.04-live-server-amd64.iso"]="https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
ISO_URLS["debian-12.5-amd64-netinst.iso"]="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
ISO_URLS["almalinux-9-latest-x86_64-minimal.iso"]="https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9-latest-x86_64-minimal.iso"
ISO_URLS["almalinux-8-latest-x86_64-minimal.iso"]="https://repo.almalinux.org/almalinux/8/isos/x86_64/AlmaLinux-8-latest-x86_64-minimal.iso"
ISO_URLS["centos-stream-9-dvd.iso"]="https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1"
ISO_URLS["alpine-virt-3.19.0-x86_64.iso"]="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso"
ISO_URLS["fedora-workstation-39.iso"]="https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-39-1.5.iso"
ISO_URLS["freebsd-13.2-release-amd64.iso"]="https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/13.2/FreeBSD-13.2-RELEASE-amd64-disc1.iso"
ISO_URLS["archlinux-2023.03.01-x86_64.iso"]="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
ISO_URLS["proxmox-ve_7.4-1.iso"]="http://download.proxmox.com/iso/proxmox-ve_7.4-1.iso"
ISO_URLS["proxmox-ve_8.4-1.iso"]="http://download.proxmox.com/iso/proxmox-ve_8.4-1.iso"

# Function to check requirements
check_requirements() {
    echo "Checking requirements..."
    
    # Check if ssh client is available
    if ! command -v ssh &> /dev/null; then
        echo "Error: ssh client is not installed"
        exit 1
    fi
    
    # Check if sshpass is available (for password authentication)
    if [ -z "$SSH_KEY_FILE" ]; then
        if ! command -v sshpass &> /dev/null; then
            echo "Warning: sshpass is not installed. It's required for password authentication."
            echo "You can install it with 'brew install hudochenkov/sshpass/sshpass' on macOS"
            echo "Alternatively, use SSH key authentication with --ssh-key option"
            exit 1
        fi
    fi
    
    echo "Requirements satisfied"
}

# Function to validate connection to Proxmox
validate_connection() {
    echo "Validating connection to Proxmox server..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    if ! $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "pveversion"; then
        echo "Error: Could not connect to Proxmox server"
        exit 1
    fi
    
    echo "Connection to Proxmox server successful"
}

# Function to list available ISO images on Proxmox
list_isos() {
    echo "Listing available ISO images on Proxmox..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "ls -la /var/lib/vz/template/iso/"
}

# Function to list available VMs on Proxmox
list_vms() {
    echo "Listing existing VMs on Proxmox..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm list"
}

# Function to show available ISO images to download
show_available_isos() {
    echo "Available ISO images to download:"
    echo "--------------------------------"
    
    local i=1
    for iso in "${!ISO_URLS[@]}"; do
        echo "$i) $iso"
        i=$((i+1))
    done
}

# Function to download an ISO image to Proxmox
download_iso() {
    local iso_name=$1
    local iso_url=${ISO_URLS[$iso_name]}
    
    echo "Downloading ISO: $iso_name from $iso_url"
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && wget -c '$iso_url' -O '$iso_name'"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download ISO"
        exit 1
    fi
    
    echo "ISO downloaded successfully"
}

# Function to find a free VM ID
find_free_vm_id() {
    echo "Finding a free VM ID..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    VM_ID=$($ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "pvesh get /cluster/nextid")
    
    echo "Found free VM ID: $VM_ID"
}

# Function to create a VM on Proxmox
create_vm() {
    echo "Creating VM with ID $VM_ID and name $VM_NAME..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    # Create VM
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm create $VM_ID --name $VM_NAME --memory $VM_MEMORY --cores $VM_CORES --net0 virtio,bridge=$VM_NETWORK_BRIDGE --bootdisk scsi0 --scsihw virtio-scsi-pci"
    
    # Add disk
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $VM_ID --scsi0 $STORAGE_NAME:$VM_DISK_SIZE"
    
    # Set display to VNC
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $VM_ID --vga std"
    
    # Set boot order and attach CD-ROM
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $VM_ID --boot c --bootdisk scsi0"
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $VM_ID --ide2 $ISO_STORAGE:iso/$ISO_FILE,media=cdrom"
    
    # Set boot order to CD-ROM first
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $VM_ID --boot order=ide2;scsi0"
    
    echo "VM created successfully"
}

# Function to start the VM
start_vm() {
    echo "Starting VM with ID $VM_ID..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm start $VM_ID"
    
    echo "VM started successfully"
}

# Function to interactive mode
interactive_mode() {
    echo "Interactive Mode"
    echo "---------------"
    
    # Ask for Proxmox connection details
    read -p "Enter Proxmox host (IP or hostname): " PROXMOX_HOST
    read -p "Enter Proxmox user [$PROXMOX_USER]: " input
    PROXMOX_USER=${input:-$PROXMOX_USER}
    
    # Decide between SSH key and password
    read -p "Use SSH key for authentication? (y/n): " use_ssh_key
    if [[ $use_ssh_key == "y" || $use_ssh_key == "Y" ]]; then
        read -p "Enter path to SSH private key: " SSH_KEY_FILE
    else
        read -s -p "Enter Proxmox password: " PROXMOX_PASSWORD
        echo ""
    fi
    
    # Validate connection
    check_requirements
    validate_connection
    
    # Show main menu
    while true; do
        echo ""
        echo "Main Menu"
        echo "---------"
        echo "1) List existing VMs"
        echo "2) List available ISO images"
        echo "3) Download ISO image"
        echo "4) Create new VM"
        echo "5) Exit"
        echo ""
        read -p "Select an option (1-5): " option
        
        case $option in
            1)
                list_vms
                ;;
            2)
                list_isos
                ;;
            3)
                show_available_isos
                read -p "Select ISO to download (1-${#ISO_URLS[@]}): " iso_option
                if [[ $iso_option -ge 1 && $iso_option -le ${#ISO_URLS[@]} ]]; then
                    iso_name=$(echo "${!ISO_URLS[@]}" | tr ' ' '\n' | sed -n "${iso_option}p")
                    download_iso "$iso_name"
                else
                    echo "Invalid option"
                fi
                ;;
            4)
                # Get VM details
                read -p "Enter VM name: " VM_NAME
                read -p "Enter number of CPU cores [$VM_CORES]: " input
                VM_CORES=${input:-$VM_CORES}
                read -p "Enter memory in MB [$VM_MEMORY]: " input
                VM_MEMORY=${input:-$VM_MEMORY}
                read -p "Enter disk size in GB [$VM_DISK_SIZE]: " input
                VM_DISK_SIZE=${input:-$VM_DISK_SIZE}
                
                # List ISOs for selection
                echo "Available ISOs:"
                list_isos | grep -v total | awk '{print NR") " $9}'
                read -p "Select ISO for VM installation (enter number): " iso_num
                ISO_FILE=$(list_isos | grep -v total | awk '{print $9}' | sed -n "${iso_num}p")
                
                # Find free VM ID
                find_free_vm_id
                
                # Create VM
                create_vm
                
                # Ask to start VM
                read -p "Start the VM now? (y/n): " start_now
                if [[ $start_now == "y" || $start_now == "Y" ]]; then
                    start_vm
                fi
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host HOST             Proxmox host IP or hostname"
    echo "  --user USER             Proxmox user (default: root@pam)"
    echo "  --password PASSWORD     Proxmox password"
    echo "  --ssh-key KEY_FILE      SSH private key file for authentication"
    echo "  --ssh-port PORT         SSH port (default: 22)"
    echo "  --list-vms              List existing VMs"
    echo "  --list-isos             List available ISO images"
    echo "  --available-isos        Show available ISO images to download"
    echo "  --download-iso ISO      Download specific ISO image"
    echo "  --create-vm             Create a new VM"
    echo "  --vm-id ID              VM ID (auto-generated if not provided)"
    echo "  --vm-name NAME          VM name"
    echo "  --vm-cores CORES        Number of CPU cores (default: 2)"
    echo "  --vm-memory MEMORY      Memory in MB (default: 2048)"
    echo "  --vm-disk-size SIZE     Disk size in GB (default: 32)"
    echo "  --vm-network BRIDGE     Network bridge (default: vmbr0)"
    echo "  --iso-file FILE         ISO file to use for VM"
    echo "  --storage NAME          Storage name (default: local)"
    echo "  --iso-storage NAME      ISO storage name (default: local)"
    echo "  --start-vm              Start VM after creation"
    echo "  --interactive           Run in interactive mode (default)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --interactive"
    echo "  $0 --host 192.168.1.100 --user root@pam --password secret --list-vms"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --available-isos"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --download-iso ubuntu-22.04-live-server-amd64.iso"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-vm --vm-name ubuntu-server --vm-cores 4 --vm-memory 4096 --vm-disk-size 64 --iso-file ubuntu-22.04-live-server-amd64.iso --start-vm"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --host)
            PROXMOX_HOST="$2"
            shift
            shift
            ;;
        --user)
            PROXMOX_USER="$2"
            shift
            shift
            ;;
        --password)
            PROXMOX_PASSWORD="$2"
            shift
            shift
            ;;
        --ssh-key)
            SSH_KEY_FILE="$2"
            shift
            shift
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift
            shift
            ;;
        --list-vms)
            INTERACTIVE=false
            LIST_VMS=true
            shift
            ;;
        --list-isos)
            INTERACTIVE=false
            LIST_ISOS=true
            shift
            ;;
        --available-isos)
            INTERACTIVE=false
            SHOW_AVAILABLE_ISOS=true
            shift
            ;;
        --download-iso)
            INTERACTIVE=false
            DOWNLOAD_ISO=true
            ISO_FILE="$2"
            shift
            shift
            ;;
        --create-vm)
            INTERACTIVE=false
            CREATE_VM=true
            shift
            ;;
        --vm-id)
            VM_ID="$2"
            shift
            shift
            ;;
        --vm-name)
            VM_NAME="$2"
            shift
            shift
            ;;
        --vm-cores)
            VM_CORES="$2"
            shift
            shift
            ;;
        --vm-memory)
            VM_MEMORY="$2"
            shift
            shift
            ;;
        --vm-disk-size)
            VM_DISK_SIZE="$2"
            shift
            shift
            ;;
        --vm-network)
            VM_NETWORK_BRIDGE="$2"
            shift
            shift
            ;;
        --iso-file)
            ISO_FILE="$2"
            shift
            shift
            ;;
        --storage)
            STORAGE_NAME="$2"
            shift
            shift
            ;;
        --iso-storage)
            ISO_STORAGE="$2"
            shift
            shift
            ;;
        --start-vm)
            START_VM=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $key"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution flow
if [ "$INTERACTIVE" = true ]; then
    interactive_mode
else
    # Check if host is provided for non-interactive mode
    if [ -z "$PROXMOX_HOST" ]; then
        echo "Error: Proxmox host is required for non-interactive mode"
        exit 1
    fi
    
    # Check requirements and validate connection
    check_requirements
    validate_connection
    
    # Execute requested commands
    if [ "$LIST_VMS" = true ]; then
        list_vms
    fi
    
    if [ "$LIST_ISOS" = true ]; then
        list_isos
    fi
    
    if [ "$SHOW_AVAILABLE_ISOS" = true ]; then
        show_available_isos
    fi
    
    if [ "$DOWNLOAD_ISO" = true ]; then
        if [[ -n "$ISO_FILE" && -n "${ISO_URLS[$ISO_FILE]}" ]]; then
            download_iso "$ISO_FILE"
        else
            echo "Error: Invalid ISO file specified or not available in the list"
            show_available_isos
            exit 1
        fi
    fi
    
    if [ "$CREATE_VM" = true ]; then
        # Check required parameters
        if [ -z "$VM_NAME" ]; then
            echo "Error: VM name is required for VM creation"
            exit 1
        fi
        
        if [ -z "$ISO_FILE" ]; then
            echo "Error: ISO file is required for VM creation"
            exit 1
        fi
        
        # Find a free VM ID if not provided
        if [ -z "$VM_ID" ]; then
            find_free_vm_id
        fi
        
        # Create VM
        create_vm
        
        # Start VM if requested
        if [ "$START_VM" = true ]; then
            start_vm
        fi
    fi
fi 