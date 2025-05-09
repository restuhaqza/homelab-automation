# Nginx Setup Guide

This guide covers the installation and configuration of Nginx for your homelab, including options for setting up a reverse proxy.

## Overview

Nginx is a powerful web server and reverse proxy that can be used to:
- Serve static websites and applications
- Act as a reverse proxy for other services
- Provide SSL/TLS termination
- Load balance between multiple backend servers
- Cache content for improved performance

## Installation

### Automated Installation (Recommended)

Our script provides a flexible Nginx installation with options for reverse proxy configuration:

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/homelab-automation.git
   cd homelab-automation
   ```

2. Make the script executable:
   ```bash
   chmod +x scripts/infrastructure/install-nginx.sh
   ```

3. Run the script with desired options:

   **Basic web server:**
   ```bash
   sudo scripts/infrastructure/install-nginx.sh --server-name homelab.local
   ```

   **With SSL:**
   ```bash
   sudo scripts/infrastructure/install-nginx.sh --server-name homelab.local --enable-ssl
   ```

   **As reverse proxy:**
   ```bash
   sudo scripts/infrastructure/install-nginx.sh --server-name homelab.local --setup-reverse-proxy --proxy-target localhost --proxy-port 8080
   ```

   **Reverse proxy with SSL:**
   ```bash
   sudo scripts/infrastructure/install-nginx.sh --server-name homelab.local --setup-reverse-proxy --proxy-target localhost --proxy-port 8080 --enable-ssl
   ```

4. Follow the on-screen prompts to confirm settings.

### Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `--server-name` | Domain name for the server | `--server-name example.com` |
| `--enable-ssl` | Enable SSL with self-signed certificates | `--enable-ssl` |
| `--setup-reverse-proxy` | Configure as reverse proxy | `--setup-reverse-proxy` |
| `--proxy-target` | Target host for reverse proxy | `--proxy-target localhost` |
| `--proxy-port` | Target port for reverse proxy | `--proxy-port 8080` |

## Common Use Cases

### Setting up a Reverse Proxy for Code-Server

To set up Nginx as a reverse proxy for code-server (installed on the same machine):

```bash
sudo scripts/infrastructure/install-nginx.sh --server-name code.homelab.local --setup-reverse-proxy --proxy-target localhost --proxy-port 8080 --enable-ssl
```

This will create a secure (HTTPS) reverse proxy to your code-server instance.

### Hosting Multiple Services

To host multiple services on the same Nginx instance:

1. Install Nginx using the script:
   ```bash
   sudo scripts/infrastructure/install-nginx.sh --server-name homelab.local --enable-ssl
   ```

2. Create additional server configurations:
   ```bash
   sudo nano /etc/nginx/sites-available/service1.homelab.local
   ```

3. Add content for the new service, for example:
   ```nginx
   server {
       listen 80;
       server_name service1.homelab.local;
       
       location / {
           proxy_pass http://localhost:8001;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

4. Enable the new site:
   ```bash
   sudo ln -s /etc/nginx/sites-available/service1.homelab.local /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## SSL Configuration

### Using Let's Encrypt (Recommended for Production)

For public-facing services, replace the self-signed certificate with Let's Encrypt:

1. Install Certbot:
   ```bash
   sudo apt update
   sudo apt install certbot python3-certbot-nginx
   ```

2. Obtain a certificate:
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

3. Auto-renewal will be configured by Certbot

### Using Self-Signed Certificates (Development)

The installation script creates self-signed certificates automatically when the `--enable-ssl` option is used. These are suitable for testing but will show security warnings in browsers.

## Performance Optimization

The installation script includes several performance optimizations:

- Worker process auto-scaling
- Gzip compression
- Connection keepalive
- Efficient event handling
- Browser caching headers

For additional performance tuning, consider:

1. Enabling FastCGI caching for dynamic content
2. Adjusting worker connections based on available RAM
3. Implementing microcaching for frequently accessed content

## Troubleshooting

### Common Issues

1. **"502 Bad Gateway" error**
   - Check if the backend service is running
   - Verify the proxy_pass target is correct
   - Examine Nginx error logs: `sudo tail -f /var/log/nginx/error.log`

2. **"Permission denied" errors**
   - Check file permissions on web root directories
   - Verify SELinux settings if applicable

3. **Configuration test fails**
   - Run `sudo nginx -t` to identify syntax errors
   - Fix the reported issues and retest

### Viewing Logs

- Access logs: `sudo tail -f /var/log/nginx/access.log`
- Error logs: `sudo tail -f /var/log/nginx/error.log`
- Site-specific logs: `sudo tail -f /var/log/nginx/site-name-access.log`

## Security Recommendations

1. **Disable unnecessary modules**
   - Only include modules you actually need

2. **Implement rate limiting**
   ```nginx
   limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;
   
   server {
       location / {
           limit_req zone=mylimit burst=20 nodelay;
       }
   }
   ```

3. **Set security headers**
   ```nginx
   add_header X-Content-Type-Options nosniff;
   add_header X-Frame-Options SAMEORIGIN;
   add_header X-XSS-Protection "1; mode=block";
   add_header Content-Security-Policy "default-src 'self'";
   ```

4. **Regular updates**
   ```bash
   sudo apt update && sudo apt upgrade
   ``` 