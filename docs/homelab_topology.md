# Homelab Topology

## Physical Hardware

### Primary Compute Node (ThinkCentre)
- **Hardware**: Lenovo ThinkCentre m720q Tiny Form Factor
- **CPU**: Intel Core i7-8700T (6 cores/12 threads)
- **RAM**: 32 GB DDR4
- **Storage**: 1 TB SSD
- **Network**: Gigabit Ethernet
- **Role**: Proxmox Hypervisor Host (Type 1)

### Management/Development System (Mac)
- **Role**: Management workstation, development environment, and secondary compute resource
- **Usage**: 
  - Managing Proxmox VE via web interface
  - Running development tools
  - Testing and development environment
  - Optional: Docker containers for lightweight services

## Network Layout

```
Internet
   |
[Router/Firewall]
   |
   +------------------------+
   |                        |
[Mac]                 [ThinkCentre]
 Management            Proxmox Host
 Development              |
                          |
                   +------+------+
                   |      |      |
                [VM 1]  [VM 2]  [VM 3]
                   |
                   |
             +-----+-----+
             |     |     |
        [Container Cluster]
```

## Virtualization Layer

### Proxmox VE (ThinkCentre)

The ThinkCentre will run Proxmox VE as the hypervisor:

1. **System VM** (2 vCPU, 4GB RAM)
   - Runs Nginx reverse proxy
   - Handles SSL termination
   - Internal DNS server

2. **Storage VM** (2 vCPU, 4GB RAM)
   - Network Attached Storage (NAS) functionality
   - Backup destination
   - Media server (optional)

3. **Kubernetes/Container Host VM** (4-6 vCPU, 16-20GB RAM)
   - Choose one of the following options:
     - **Option A: Kubernetes Cluster**
       - k3s lightweight Kubernetes
       - Container orchestration
     - **Option B: Docker with Portainer**
       - Docker for container deployments
       - Portainer for web-based management

## Management and Access

- **Remote Access**:
  - XRDP multi-session for direct VM access
  - SSH for command-line management
  - Proxmox web interface (https://thinkcentre-ip:8006)

- **Monitoring**:
  - Prometheus + Grafana stack for system monitoring
  - Log collection and analysis

## Service Deployment Options

### For Kubernetes Option
- Ingress controller for routing
- Persistent volumes for storage
- Helm for package management
- Dashboard for web management

### For Docker Option
- Docker Compose for service definitions
- Portainer for web management
- Traefik/Nginx for service routing

## Data Storage and Backup

- Primary storage on ThinkCentre's local SSD
- Regular backups to external storage
- Optional: Mac as secondary backup destination

## Network Considerations

- Consider setting up VLANs if your router supports it:
  - Management VLAN (Proxmox management, SSH)
  - Services VLAN (Containers, applications)
  - Storage VLAN (NAS traffic)
  
- Set up static IPs for consistent addressing

## Security Recommendations

- Firewall rules to limit access
- Regular security updates
- Use VPN for remote access
- Strong authentication

## Expansion Options

As your needs grow:
- Add additional SSD/HDD to ThinkCentre
- Add network storage
- Add additional compute nodes
- Consider clustering Proxmox with additional nodes

## Implementation Steps

1. Install Proxmox VE on ThinkCentre
2. Run post-install optimization script
3. Create VMs according to topology
4. Set up container platform (Kubernetes or Docker)
5. Deploy services
6. Configure monitoring
7. Set up backup strategy 