#!/bin/bash

# Custom ISO Downloader Script for Proxmox
# This script helps add custom ISO images to your Proxmox server
# Run this on your Mac to manage your Proxmox server remotely

# Print banner
echo "================================================================"
echo "       Custom ISO Downloader for Proxmox"
echo "       For Homelab Automation"
echo "================================================================"
echo ""

# Default variables
PROXMOX_HOST=""
PROXMOX_USER="root@pam"
PROXMOX_PASSWORD=""
SSH_KEY_FILE=""
SSH_PORT=22
ISO_URL=""
ISO_NAME=""
VERIFY_CHECKSUM=false
ISO_CHECKSUM=""
INTERACTIVE=true

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

# Function to download a custom ISO image to Proxmox
download_iso() {
    local iso_url=$1
    local iso_name=$2
    local checksum=$3
    local verify=$4
    
    echo "Downloading ISO from: $iso_url"
    echo "Saving as: $iso_name"
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    # Download the ISO
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && wget -c '$iso_url' -O '$iso_name'"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download ISO"
        exit 1
    fi
    
    # Verify checksum if requested
    if [ "$verify" = true ] && [ -n "$checksum" ]; then
        echo "Verifying checksum..."
        
        # Determine checksum type based on length
        case ${#checksum} in
            32) # MD5
                $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && echo '$checksum $iso_name' | md5sum -c"
                ;;
            40) # SHA1
                $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && echo '$checksum $iso_name' | sha1sum -c"
                ;;
            64) # SHA256
                $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && echo '$checksum $iso_name' | sha256sum -c"
                ;;
            128) # SHA512
                $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "cd /var/lib/vz/template/iso && echo '$checksum $iso_name' | sha512sum -c"
                ;;
            *)
                echo "Warning: Unknown checksum format. Skipping verification."
                ;;
        esac
        
        if [ $? -ne 0 ]; then
            echo "Error: Checksum verification failed. The downloaded ISO may be corrupted."
            echo "Do you want to keep the ISO anyway? (y/n)"
            read -p "> " keep_iso
            if [[ $keep_iso != "y" && $keep_iso != "Y" ]]; then
                $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "rm -f /var/lib/vz/template/iso/'$iso_name'"
                echo "ISO deleted."
                exit 1
            fi
        else
            echo "Checksum verification passed!"
        fi
    fi
    
    echo "ISO downloaded successfully"
}

# Function for interactive mode
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
        echo "1) List existing ISO images"
        echo "2) Download custom ISO"
        echo "3) Exit"
        echo ""
        read -p "Select an option (1-3): " option
        
        case $option in
            1)
                list_isos
                ;;
            2)
                # Get ISO details
                read -p "Enter ISO URL: " ISO_URL
                
                # Extract filename from URL or ask for custom name
                default_name=$(basename "$ISO_URL")
                read -p "Enter ISO name [$default_name]: " ISO_NAME
                ISO_NAME=${ISO_NAME:-$default_name}
                
                # Ask about checksum verification
                read -p "Verify checksum? (y/n): " verify_checksum
                if [[ $verify_checksum == "y" || $verify_checksum == "Y" ]]; then
                    read -p "Enter ISO checksum (MD5, SHA1, SHA256, or SHA512): " ISO_CHECKSUM
                    VERIFY_CHECKSUM=true
                else
                    VERIFY_CHECKSUM=false
                    ISO_CHECKSUM=""
                fi
                
                # Confirm
                echo ""
                echo "About to download ISO with the following details:"
                echo "URL: $ISO_URL"
                echo "Name: $ISO_NAME"
                if [ "$VERIFY_CHECKSUM" = true ]; then
                    echo "Checksum: $ISO_CHECKSUM"
                else
                    echo "Checksum verification: Disabled"
                fi
                echo ""
                read -p "Continue? (y/n): " confirm
                
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    download_iso "$ISO_URL" "$ISO_NAME" "$ISO_CHECKSUM" "$VERIFY_CHECKSUM"
                else
                    echo "Operation cancelled."
                fi
                ;;
            3)
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
    echo "  --list-isos             List available ISO images"
    echo "  --iso-url URL           URL of the ISO to download"
    echo "  --iso-name NAME         Name to save the ISO as (default: derived from URL)"
    echo "  --verify-checksum       Verify ISO checksum"
    echo "  --iso-checksum SUM      Checksum value for verification"
    echo "  --interactive           Run in interactive mode (default)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --interactive"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --list-isos"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --iso-url https://example.com/custom.iso"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --iso-url https://example.com/custom.iso --iso-name my-custom.iso --verify-checksum --iso-checksum 1234...abcd"
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
        --list-isos)
            INTERACTIVE=false
            LIST_ISOS=true
            shift
            ;;
        --iso-url)
            INTERACTIVE=false
            ISO_URL="$2"
            shift
            shift
            ;;
        --iso-name)
            ISO_NAME="$2"
            shift
            shift
            ;;
        --verify-checksum)
            VERIFY_CHECKSUM=true
            shift
            ;;
        --iso-checksum)
            ISO_CHECKSUM="$2"
            shift
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

# Set default ISO name if not provided but URL is
if [ -z "$ISO_NAME" ] && [ -n "$ISO_URL" ]; then
    ISO_NAME=$(basename "$ISO_URL")
fi

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
    if [ "$LIST_ISOS" = true ]; then
        list_isos
    fi
    
    if [ -n "$ISO_URL" ]; then
        download_iso "$ISO_URL" "$ISO_NAME" "$ISO_CHECKSUM" "$VERIFY_CHECKSUM"
    fi
fi 