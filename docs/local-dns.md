# Local DNS Setup Guide

This guide explains how to set up .local domain resolution for your homelab environment, allowing you to access services using friendly domain names without external DNS providers.

## Overview

Setting up local DNS resolution offers several benefits:
- Access services using names like `server.homelab.local` instead of IP addresses
- Create a consistent naming scheme for all homelab services
- Avoid tracking dynamic IP addresses
- Work in environments without internet access

Our script provides two methods:
1. **mDNS** (Multicast DNS) - Zero-configuration networking via Avahi
2. **Dnsmasq** - Lightweight DNS/DHCP server with more control

## Installation

### Automated Installation

Our script automates the entire setup process:

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/homelab-automation.git
   cd homelab-automation
   ```

2. Make the script executable:
   ```bash
   chmod +x scripts/infrastructure/setup-local-dns.sh
   ```

3. Run the script with your preferred method:

   **Using mDNS (Simplest):**
   ```bash
   sudo scripts/infrastructure/setup-local-dns.sh --method mdns --hostname homelab-server
   ```

   **Using Dnsmasq (More control):**
   ```bash
   sudo scripts/infrastructure/setup-local-dns.sh --method dnsmasq --hostname homelab-server
   ```

4. Follow the on-screen prompts to confirm settings.

### Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `--method` | DNS resolution method (`mdns` or `dnsmasq`) | `--method mdns` |
| `--hostname` | Server hostname | `--hostname proxmox-server` |
| `--domain` | Local domain name | `--domain mylab.local` |
| `--server-ip` | Server IP address (auto-detected if omitted) | `--server-ip 192.168.1.10` |
| `--router-ip` | Router IP address (for Dnsmasq, auto-detected if omitted) | `--router-ip 192.168.1.1` |

## Method Comparison

### mDNS (Avahi)

**Pros:**
- True zero-configuration
- No client configuration required for many systems
- Works across network segments
- Native support in many operating systems

**Cons:**
- Only works with `.local` domains
- Some Windows clients may need additional software
- Limited to discovery, not full DNS functionality

**Best for:**
- Small homelabs
- Environments where client configuration is difficult
- Setups where only `.local` domains are needed

### Dnsmasq

**Pros:**
- Full DNS server capabilities
- Works with any domain (not just `.local`)
- Can provide DHCP services
- More control over resolution rules
- Can forward to upstream DNS

**Cons:**
- Requires client configuration or router changes
- More complex setup
- Potential conflicts with existing DHCP

**Best for:**
- Larger homelabs
- Environments needing multiple domains
- Integration with other services

## Client Configuration

### For mDNS:

**Linux:**
```bash
sudo apt install avahi-daemon
```

**macOS:**
- Native support via Bonjour

**Windows:**
- Install "Bonjour Print Services" or iTunes
- Or use the Bonjour SDK

### For Dnsmasq:

**Option 1: Router Configuration (Recommended)**
1. Access your router admin page
2. Find DHCP or DNS settings
3. Set the primary DNS server to your server's IP address
4. Keep a secondary public DNS (e.g., 1.1.1.1)

**Option 2: Per-Client Configuration**

**Linux/macOS:**
```bash
# Edit resolv.conf (temporary)
echo "nameserver 192.168.1.100" | sudo tee /etc/resolv.conf

# Permanent change depends on your distribution
# For NetworkManager:
sudo nmcli connection modify "Your Connection" ipv4.dns "192.168.1.100"
```

**Windows:**
1. Open Network Connections
2. Right-click your adapter → Properties
3. Select "Internet Protocol Version 4"
4. Use the following DNS server: [Your Server IP]

## Troubleshooting

### Common Issues

1. **Cannot resolve .local domains**
   - Ensure Avahi/Dnsmasq service is running: `systemctl status avahi-daemon` or `systemctl status dnsmasq`
   - Check firewall settings: mDNS uses UDP port 5353
   - Verify the client supports mDNS or is configured to use your DNS server

2. **Name resolution works for some clients but not others**
   - For mDNS: Install appropriate client software (Avahi/Bonjour)
   - For Dnsmasq: Verify DNS settings on problematic clients

3. **Configuration gets reset after reboot**
   - For resolv.conf issues: `sudo chattr +i /etc/resolv.conf` to make it immutable
   - Check if NetworkManager or DHCP is overriding settings

### Testing Resolution

**From Linux/macOS:**
```bash
# Test mDNS resolution
ping hostname.local
avahi-resolve -n hostname.local

# Test regular DNS (Dnsmasq)
host hostname.local
dig hostname.local
```

**From Windows:**
```cmd
ping hostname.local
nslookup hostname.local
```

## Advanced Configuration

### Adding Custom Domain Records

For Dnsmasq, edit /etc/dnsmasq.conf:
```
# Add static DNS entries
address=/custom.homelab.local/192.168.1.50
```

Then restart Dnsmasq:
```bash
sudo systemctl restart dnsmasq
```

### Integration with Other Services

The script automatically sets up entries for:
- Your main server
- Code-server
- Nginx
- Proxmox (if detected)

For additional services, add entries to:
- `/etc/hosts` file
- Dnsmasq configuration
- Create Avahi service definitions in `/etc/avahi/services/`

## Security Considerations

- mDNS and local DNS servers are intended for private networks only
- Consider network segmentation for public-facing services
- For internet access, use proper DNS and domain registration
- The `.local` TLD is reserved for local networks and should not be used on the internet 