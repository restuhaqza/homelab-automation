#!/bin/bash

# Proxmox Template Creator Script
# This script automates creating VM templates in Proxmox
# You can use these templates to quickly deploy VMs without reinstallation

# Print banner
echo "================================================================"
echo "       Proxmox Template Creator Script"
echo "       For Homelab Automation"
echo "================================================================"
echo ""

# Default variables
PROXMOX_HOST=""
PROXMOX_USER="root@pam"
PROXMOX_PASSWORD=""
PROXMOX_NODE="pve"
SSH_KEY_FILE=""
SSH_PORT=22
VM_ID=""
TEMPLATE_NAME=""
TEMPLATE_DESCRIPTION=""
INTERACTIVE=true
SOURCE_VM_ID=""

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

# Function to list existing templates on Proxmox
list_templates() {
    echo "Listing existing templates on Proxmox..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm list | grep -i template"
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

# Function to shut down a VM
shutdown_vm() {
    local vm_id=$1
    echo "Shutting down VM $vm_id..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm shutdown $vm_id && while qm status $vm_id | grep -q running; do sleep 5; echo 'Waiting for VM to shut down...'; done"
    
    echo "VM $vm_id shut down successfully"
}

# Function to create a template from an existing VM
create_template_from_vm() {
    local source_vm_id=$1
    local template_id=$2
    local template_name=$3
    local template_desc=$4
    
    echo "Creating template from VM $source_vm_id..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    # Clone the VM to create a template
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm clone $source_vm_id $template_id --name $template_name --full"
    
    # Set the VM as a template
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $template_id --template 1"
    
    # Add description if provided
    if [ -n "$template_desc" ]; then
        $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm set $template_id --description '$template_desc'"
    fi
    
    echo "Template created successfully with ID $template_id"
}

# Function to create a VM from a template
create_vm_from_template() {
    local template_id=$1
    local new_vm_id=$2
    local new_vm_name=$3
    
    echo "Creating VM from template $template_id..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    # Clone the template to create a new VM
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm clone $template_id $new_vm_id --name $new_vm_name"
    
    echo "VM created successfully with ID $new_vm_id"
}

# Function to start a VM
start_vm() {
    local vm_id=$1
    echo "Starting VM $vm_id..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm start $vm_id"
    
    echo "VM $vm_id started successfully"
}

# Function to delete a VM/template
delete_vm() {
    local vm_id=$1
    echo "Deleting VM/template $vm_id..."
    
    local ssh_cmd=""
    
    if [ -n "$SSH_KEY_FILE" ]; then
        ssh_cmd="ssh -i $SSH_KEY_FILE -p $SSH_PORT -o StrictHostKeyChecking=no"
    else
        ssh_cmd="sshpass -p '$PROXMOX_PASSWORD' ssh -p $SSH_PORT -o StrictHostKeyChecking=no"
    fi
    
    $ssh_cmd $PROXMOX_USER@$PROXMOX_HOST "qm destroy $vm_id"
    
    echo "VM/template $vm_id deleted successfully"
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
        echo "1) List existing VMs"
        echo "2) List existing templates"
        echo "3) Create template from VM"
        echo "4) Create VM from template"
        echo "5) Delete VM/template"
        echo "6) Exit"
        echo ""
        read -p "Select an option (1-6): " option
        
        case $option in
            1)
                list_vms
                ;;
            2)
                list_templates
                ;;
            3)
                # Get source VM details
                list_vms
                read -p "Enter source VM ID: " SOURCE_VM_ID
                
                # Check if VM exists
                vm_exists=$( (list_vms | grep -w "$SOURCE_VM_ID") || echo "")
                if [ -z "$vm_exists" ]; then
                    echo "Error: VM with ID $SOURCE_VM_ID does not exist"
                    continue
                fi
                
                # Get template details
                read -p "Enter template name: " TEMPLATE_NAME
                read -p "Enter template description (optional): " TEMPLATE_DESCRIPTION
                
                # Find a free VM ID for the template
                find_free_vm_id
                TEMPLATE_ID=$VM_ID
                
                # Confirm
                echo ""
                echo "About to create template with the following details:"
                echo "Source VM ID: $SOURCE_VM_ID"
                echo "Template ID: $TEMPLATE_ID"
                echo "Template name: $TEMPLATE_NAME"
                echo "Template description: $TEMPLATE_DESCRIPTION"
                echo ""
                read -p "Continue? (y/n): " confirm
                
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    # Shut down the VM if running
                    vm_status=$( (list_vms | grep -w "$SOURCE_VM_ID" | grep -w "running") || echo "")
                    if [ -n "$vm_status" ]; then
                        read -p "VM is currently running. Shut it down? (y/n): " shutdown
                        if [[ $shutdown == "y" || $shutdown == "Y" ]]; then
                            shutdown_vm $SOURCE_VM_ID
                        else
                            echo "Cannot create template from running VM. Operation cancelled."
                            continue
                        fi
                    fi
                    
                    # Create template
                    create_template_from_vm $SOURCE_VM_ID $TEMPLATE_ID "$TEMPLATE_NAME" "$TEMPLATE_DESCRIPTION"
                else
                    echo "Operation cancelled."
                fi
                ;;
            4)
                # Get template details
                list_templates
                read -p "Enter template ID: " TEMPLATE_ID
                
                # Check if template exists
                template_exists=$( (list_templates | grep -w "$TEMPLATE_ID") || echo "")
                if [ -z "$template_exists" ]; then
                    echo "Error: Template with ID $TEMPLATE_ID does not exist"
                    continue
                fi
                
                # Get new VM details
                read -p "Enter new VM name: " NEW_VM_NAME
                
                # Find a free VM ID for the new VM
                find_free_vm_id
                NEW_VM_ID=$VM_ID
                
                # Confirm
                echo ""
                echo "About to create VM with the following details:"
                echo "Template ID: $TEMPLATE_ID"
                echo "New VM ID: $NEW_VM_ID"
                echo "New VM name: $NEW_VM_NAME"
                echo ""
                read -p "Continue? (y/n): " confirm
                
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    # Create VM from template
                    create_vm_from_template $TEMPLATE_ID $NEW_VM_ID "$NEW_VM_NAME"
                    
                    # Ask to start VM
                    read -p "Start the new VM now? (y/n): " start_now
                    if [[ $start_now == "y" || $start_now == "Y" ]]; then
                        start_vm $NEW_VM_ID
                    fi
                else
                    echo "Operation cancelled."
                fi
                ;;
            5)
                # Get VM/template details
                echo "Existing VMs and templates:"
                list_vms
                read -p "Enter VM/template ID to delete: " DELETE_ID
                
                # Check if VM/template exists
                vm_exists=$( (list_vms | grep -w "$DELETE_ID") || echo "")
                if [ -z "$vm_exists" ]; then
                    echo "Error: VM/template with ID $DELETE_ID does not exist"
                    continue
                fi
                
                # Confirm
                echo ""
                echo "WARNING: You are about to delete VM/template with ID $DELETE_ID"
                echo "This operation cannot be undone!"
                echo ""
                read -p "Are you absolutely sure? (yes/no): " confirm
                
                if [ "$confirm" == "yes" ]; then
                    # Delete VM/template
                    delete_vm $DELETE_ID
                else
                    echo "Operation cancelled."
                fi
                ;;
            6)
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
    echo "  --host HOST                Proxmox host IP or hostname"
    echo "  --user USER                Proxmox user (default: root@pam)"
    echo "  --password PASSWORD        Proxmox password"
    echo "  --ssh-key KEY_FILE         SSH private key file for authentication"
    echo "  --ssh-port PORT            SSH port (default: 22)"
    echo "  --list-vms                 List existing VMs"
    echo "  --list-templates           List existing templates"
    echo "  --create-template          Create template from VM"
    echo "  --source-vm ID             Source VM ID for template creation"
    echo "  --template-id ID           Template ID (auto-generated if not provided)"
    echo "  --template-name NAME       Template name"
    echo "  --template-desc DESC       Template description"
    echo "  --create-vm                Create VM from template"
    echo "  --template-id ID           Template ID to create VM from"
    echo "  --vm-id ID                 VM ID (auto-generated if not provided)"
    echo "  --vm-name NAME             VM name"
    echo "  --start-vm                 Start VM after creation"
    echo "  --delete-vm ID             Delete VM/template with specified ID"
    echo "  --interactive              Run in interactive mode (default)"
    echo "  --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --interactive"
    echo "  $0 --host 192.168.1.100 --user root@pam --password secret --list-vms"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --list-templates"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-template --source-vm 100 --template-name 'Ubuntu Server Template' --template-desc 'Ubuntu 22.04 minimal install'"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --create-vm --template-id 900 --vm-name 'Web Server' --start-vm"
    echo "  $0 --host 192.168.1.100 --ssh-key ~/.ssh/id_rsa --delete-vm 101"
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
        --list-templates)
            INTERACTIVE=false
            LIST_TEMPLATES=true
            shift
            ;;
        --create-template)
            INTERACTIVE=false
            CREATE_TEMPLATE=true
            shift
            ;;
        --source-vm)
            SOURCE_VM_ID="$2"
            shift
            shift
            ;;
        --template-id)
            TEMPLATE_ID="$2"
            shift
            shift
            ;;
        --template-name)
            TEMPLATE_NAME="$2"
            shift
            shift
            ;;
        --template-desc)
            TEMPLATE_DESCRIPTION="$2"
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
        --start-vm)
            START_VM=true
            shift
            ;;
        --delete-vm)
            INTERACTIVE=false
            DELETE_VM=true
            DELETE_ID="$2"
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
    
    if [ "$LIST_TEMPLATES" = true ]; then
        list_templates
    fi
    
    if [ "$CREATE_TEMPLATE" = true ]; then
        # Check required parameters
        if [ -z "$SOURCE_VM_ID" ]; then
            echo "Error: Source VM ID is required for template creation"
            exit 1
        fi
        
        if [ -z "$TEMPLATE_NAME" ]; then
            echo "Error: Template name is required for template creation"
            exit 1
        fi
        
        # Get template ID if not provided
        if [ -z "$TEMPLATE_ID" ]; then
            find_free_vm_id
            TEMPLATE_ID=$VM_ID
        fi
        
        # Check if source VM is running and shut it down if needed
        vm_status=$( (list_vms | grep -w "$SOURCE_VM_ID" | grep -w "running") || echo "")
        if [ -n "$vm_status" ]; then
            echo "Source VM is running. Shutting it down..."
            shutdown_vm $SOURCE_VM_ID
        fi
        
        # Create template
        create_template_from_vm $SOURCE_VM_ID $TEMPLATE_ID "$TEMPLATE_NAME" "$TEMPLATE_DESCRIPTION"
    fi
    
    if [ "$CREATE_VM" = true ]; then
        # Check required parameters
        if [ -z "$TEMPLATE_ID" ]; then
            echo "Error: Template ID is required for VM creation"
            exit 1
        fi
        
        if [ -z "$VM_NAME" ]; then
            echo "Error: VM name is required for VM creation"
            exit 1
        fi
        
        # Get VM ID if not provided
        if [ -z "$VM_ID" ]; then
            find_free_vm_id
        fi
        
        # Create VM from template
        create_vm_from_template $TEMPLATE_ID $VM_ID "$VM_NAME"
        
        # Start VM if requested
        if [ "$START_VM" = true ]; then
            start_vm $VM_ID
        fi
    fi
    
    if [ "$DELETE_VM" = true ]; then
        # Check required parameters
        if [ -z "$DELETE_ID" ]; then
            echo "Error: VM/template ID is required for deletion"
            exit 1
        fi
        
        # Delete VM/template
        delete_vm $DELETE_ID
    fi
fi 