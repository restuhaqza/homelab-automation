# Homelab Hardware

## Current Setup (Single Instance)

### Primary Server
- **Model**: Lenovo ThinkCentre m720q Tiny Form Factor
- **Processor**: Intel Core i7-8700T (6 cores/12 threads, 2.4GHz base, 4.0GHz turbo)
- **Memory**: 32 GB DDR4 RAM (2x16GB, 2666MHz)
- **Storage**: 1 TB SSD
- **Graphics**: Intel UHD Graphics 630
- **Networking**: Intel Gigabit Ethernet
- **Connectivity**: 
  - 4x USB 3.1 Gen 1
  - 2x USB 3.1 Gen 2
  - 2x DisplayPort
  - 1x HDMI
- **Dimensions**: 1.4 x 7.0 x 7.2 inches (35.5 x 179 x 183mm)
- **Operating System**: ParrotSec with MATE desktop

### Network
- Home network with standard consumer router/switch

## Hardware Considerations

### Current Limitations
- Single server instance limits redundancy
- Consumer-grade networking equipment

### Future Expansion Options
- Add additional compute nodes for clustering
- Implement dedicated NAS for storage
- Upgrade to managed switch with VLAN support
- Add UPS for power protection

### Resource Allocation Strategy
- **Hypervisor (Proxmox)**: Base system with minimal resource reservation
- **Core Services**: Higher priority for resource allocation
- **Development/Testing**: Lower priority, can use dynamic resource allocation

## Performance Notes
- Current hardware is suitable for running multiple VMs/containers simultaneously
- 32GB RAM allows for 5-10 reasonably sized VMs depending on workload
- Core i7 provides good multi-threaded performance for virtualization
- SSD storage provides good I/O performance for multiple concurrent VMs 