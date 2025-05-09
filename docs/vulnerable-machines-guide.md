# Vulnerable Machines Guide

This document outlines the process for acquiring, loading, and managing vulnerable machines in our homelab environment using Proxmox VE.

## Table of Contents

1. [Sources for Vulnerable Machines](#sources-for-vulnerable-machines)
2. [Preparing Proxmox Environment](#preparing-proxmox-environment)
3. [Importing Vulnerable Machines](#importing-vulnerable-machines)
4. [Network Isolation](#network-isolation)
5. [Security Considerations](#security-considerations)
6. [Recommended Vulnerable Machines](#recommended-vulnerable-machines)
7. [Troubleshooting](#troubleshooting)

## Sources for Vulnerable Machines

### VulnHub
- Website: [https://www.vulnhub.com/](https://www.vulnhub.com/)
- Free, downloadable VMs designed for security testing and pentesting practice
- Available as OVA or VMDK formats
- Good for beginners to advanced users

### Hack The Box (HTB)
- Website: [https://www.hackthebox.com/](https://www.hackthebox.com/)
- Free tier available with access to retired machines
- Premium tier for access to active machines
- Requires VPN connection to access labs

### TryHackMe
- Website: [https://tryhackme.com/](https://tryhackme.com/)
- Browser-accessible vulnerable machines
- Structured learning paths and guided rooms
- Subscription required for full access

### OWASP Projects
- WebGoat: [https://owasp.org/www-project-webgoat/](https://owasp.org/www-project-webgoat/)
- Juice Shop: [https://owasp.org/www-project-juice-shop/](https://owasp.org/www-project-juice-shop/)
- Deliberately insecure web applications

### Metasploitable
- Purpose-built vulnerable Linux server
- Available from Rapid7: [Metasploitable 2](https://docs.rapid7.com/metasploit/metasploitable-2/)

## Preparing Proxmox Environment

### Storage Preparation
1. Ensure adequate storage is available for VM images
   ```bash
   # Check available storage
   pvesm status
   ```

2. Create a dedicated storage directory for vulnerable machines
   ```bash
   # Create directory
   mkdir -p /var/lib/vz/images/vulnmachines
   
   # Add storage to Proxmox
   pvesm add dir vulnmachines --path /var/lib/vz/images/vulnmachines
   ```

### Network Preparation
1. Create an isolated network for vulnerable machines
   ```bash
   # Create a new Linux bridge for isolated network
   # Add to /etc/network/interfaces
   auto vmbr1
   iface vmbr1 inet static
           address 192.168.100.1/24
           bridge-ports none
           bridge-stp off
           bridge-fd 0
   ```

2. Restart networking
   ```bash
   systemctl restart networking
   ```

3. Configure a firewall to prevent vulnerable machines from accessing external networks
   ```bash
   # Example iptables rules
   iptables -I FORWARD -i vmbr1 -o vmbr0 -j DROP
   iptables -I FORWARD -i vmbr0 -o vmbr1 -m state --state ESTABLISHED,RELATED -j ACCEPT
   ```

## Importing Vulnerable Machines

### From OVA Files
1. Download the OVA file from your chosen source

2. Extract the OVA file
   ```bash
   tar -xvf vulnerable-machine.ova
   ```

3. Import to Proxmox
   ```bash
   qm importovf <VM_ID> <path_to_ovf_file> <storage_name>
   ```

### From VMDK Files
1. Download the VMDK file 

2. Convert to qcow2 format
   ```bash
   qemu-img convert -f vmdk -O qcow2 vulnerable-machine.vmdk vulnerable-machine.qcow2
   ```

3. Create a new VM in Proxmox
   ```bash
   qm create <VM_ID> --name "Vulnerable-Machine" --memory 2048 --net0 virtio,bridge=vmbr1
   ```

4. Import the disk
   ```bash
   qm importdisk <VM_ID> vulnerable-machine.qcow2 <storage_name>
   ```

5. Attach the disk to the VM
   ```bash
   qm set <VM_ID> --scsihw virtio-scsi-pci --scsi0 <storage_name>:vm-<VM_ID>-disk-0
   ```

6. Set the disk as bootable
   ```bash
   qm set <VM_ID> --boot c --bootdisk scsi0
   ```

### From ISO Files
1. Download the ISO file

2. Upload to Proxmox storage
   ```bash
   # Upload to local storage
   pvesm upload local iso vulnerable-machine.iso
   ```

3. Create a new VM and install from ISO
   ```bash
   # Create VM
   qm create <VM_ID> --name "Vulnerable-Machine" --memory 2048 --net0 virtio,bridge=vmbr1 --ide2 local:iso/vulnerable-machine.iso,media=cdrom --boot order=ide2
   ```

## Network Isolation

### Creating Separate Network for VMs
1. Configure a new network bridge in Proxmox
2. Assign vulnerable machines to this isolated network
3. Configure a security VM (like pfSense) to control traffic

### NAT Configuration
```bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up NAT for vulnerable machines network
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE
```

### Attack Machine Setup
1. Create a Kali Linux VM on the same isolated network
2. Configure it as your attack platform for testing vulnerable machines

## Security Considerations

### Snapshot Before Testing
```bash
# Create snapshot
qm snapshot <VM_ID> clean-state "Clean state before testing"
```

### Preventing External Access
- Always keep vulnerable machines on isolated networks
- Never expose vulnerable machines to the internet
- Implement strict firewall rules

### Regular Resets
- Reset vulnerable machines to known clean state after testing
- Use snapshots for quick restoration
```bash
# Restore snapshot
qm rollback <VM_ID> clean-state
```

## Recommended Vulnerable Machines

### For Beginners
1. **Metasploitable 2** - Multiple vulnerabilities, great for beginners
2. **VulnHub - Kioptrix Level 1** - Classic starter vulnerable machine
3. **DVWA (Damn Vulnerable Web Application)** - Web application vulnerabilities

### For Intermediate Users
1. **VulnHub - Brainpan** - Buffer overflow practice
2. **HackTheBox - Lame** - Good retired machine for practice
3. **VulnHub - Mr. Robot** - Based on the TV show

### For Advanced Users
1. **VulnHub - Hacklab: Vulnix** - Advanced Linux exploitation
2. **HackTheBox - Buff** - Complex exploitation chain
3. **VulnHub - SickOs** - Advanced penetration testing

## Troubleshooting

### Common Import Issues
- **OVF Parse Error**: Check if OVF file is valid or try direct disk import
- **Disk Format Errors**: Convert between formats as needed
  ```bash
  qemu-img convert -f <source_format> -O <destination_format> <source_file> <destination_file>
  ```

### VM Won't Boot
- Check storage configuration
- Verify boot order
- Check BIOS/UEFI settings

### Network Issues
- Verify bridge configuration
- Ensure VM is connected to the correct bridge
- Check firewall rules

### Resource Constraints
- Adjust VM memory and CPU allocation based on requirements
- Monitor host resources during VM operation 