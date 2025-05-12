#!/bin/bash

# Script to download popular server distribution ISO files
# Author: restuhaqza
# Date: $(date +%Y-%m-%d)

set -e

# Default download directory
DOWNLOAD_DIR="$HOME/Downloads/server-isos"

# Default color settings for both light and dark themes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
function show_usage {
    echo -e "${BLUE}Usage:${NC} $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -d, --directory DIR        Set download directory (default: $DOWNLOAD_DIR)"
    echo "  -a, --all                  Download all distributions"
    echo "  --ubuntu                   Download Ubuntu Server (latest and LTS versions)"
    echo "  --debian                   Download Debian (latest and stable versions)"
    echo "  --centos                   Download CentOS Stream (latest version)"
    echo "  --rocky                    Download Rocky Linux (latest versions)"
    echo "  --alma                     Download AlmaLinux (latest versions)"
    echo "  --proxmox                  Download Proxmox VE (latest versions)"
    echo "  --opensuse                 Download openSUSE (latest versions)"
    echo "  --fedora                   Download Fedora Server (latest versions)"
    echo
}

# Function to create directory if it doesn't exist
function create_dir_if_not_exists {
    if [ ! -d "$1" ]; then
        echo -e "${YELLOW}Creating directory:${NC} $1"
        mkdir -p "$1"
    fi
}

# Function to check if a file exists and its size
function check_file {
    local FILE="$1"
    local EXPECTED_SIZE="$2"
    
    if [ -f "$FILE" ]; then
        local ACTUAL_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
        if [ "$ACTUAL_SIZE" -eq "$EXPECTED_SIZE" ]; then
            return 0 # File exists and has correct size
        else
            return 1 # File exists but has incorrect size
        fi
    else
        return 2 # File does not exist
    fi
}

# Function to download file
function download_file {
    local URL="$1"
    local OUTPUT="$2"
    local DESCRIPTION="$3"
    
    echo -e "${YELLOW}Downloading ${DESCRIPTION}...${NC}"
    
    # First, get the file size from the header
    local FILE_SIZE=$(curl -sI "$URL" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
    
    # If file size was obtained
    if [ -n "$FILE_SIZE" ]; then
        # Check if file already exists with correct size
        check_file "$OUTPUT" "$FILE_SIZE"
        local FILE_STATUS=$?
        
        if [ $FILE_STATUS -eq 0 ]; then
            echo -e "${GREEN}File already exists and has correct size:${NC} $OUTPUT"
        elif [ $FILE_STATUS -eq 1 ]; then
            echo -e "${RED}File exists but has incorrect size. Re-downloading...${NC}"
            curl -L --progress-bar -o "$OUTPUT" "$URL"
        else
            # File doesn't exist, download it
            curl -L --progress-bar -o "$OUTPUT" "$URL"
        fi
    else
        # If couldn't get file size, just download
        echo -e "${YELLOW}Couldn't determine file size, downloading...${NC}"
        curl -L --progress-bar -o "$OUTPUT" "$URL"
    fi
}

# Function to download Ubuntu ISOs
function download_ubuntu {
    local UBUNTU_DIR="$DOWNLOAD_DIR/ubuntu"
    create_dir_if_not_exists "$UBUNTU_DIR"
    
    # Latest LTS is Ubuntu 22.04.5
    download_file "https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso" \
                 "$UBUNTU_DIR/ubuntu-22.04.5-live-server-amd64.iso" \
                 "Ubuntu 22.04.5 LTS Server (Jammy Jellyfish)"
    
    # Latest release is Ubuntu 24.04.2
    download_file "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso" \
                 "$UBUNTU_DIR/ubuntu-24.04.2-live-server-amd64.iso" \
                 "Ubuntu 24.04.2 Server (Noble Numbat)"
}

# Function to download Debian ISOs
function download_debian {
    local DEBIAN_DIR="$DOWNLOAD_DIR/debian"
    create_dir_if_not_exists "$DEBIAN_DIR"
    
    # Current stable version 12.10.0 (Bookworm)
    download_file "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.10.0-amd64-netinst.iso" \
                 "$DEBIAN_DIR/debian-12.10.0-amd64-netinst.iso" \
                 "Debian 12.10.0 (Bookworm) - Stable"
    
    # Testing version
    download_file "https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso" \
                 "$DEBIAN_DIR/debian-testing-amd64-netinst.iso" \
                 "Debian Testing (Trixie) - Weekly Build"
}

# Function to download CentOS ISOs
function download_centos {
    local CENTOS_DIR="$DOWNLOAD_DIR/centos"
    create_dir_if_not_exists "$CENTOS_DIR"
    
    # CentOS Stream 9 (latest)
    download_file "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-boot.iso&redirect=1" \
                 "$CENTOS_DIR/CentOS-Stream-9-latest-x86_64-boot.iso" \
                 "CentOS Stream 9 (Latest)"
}

# Function to download Rocky Linux ISOs
function download_rocky {
    local ROCKY_DIR="$DOWNLOAD_DIR/rocky"
    create_dir_if_not_exists "$ROCKY_DIR"
    
    # Rocky Linux 9.5 (latest)
    download_file "https://download.rockylinux.org/pub/rocky/9.5/isos/x86_64/Rocky-9.5-x86_64-minimal.iso" \
                 "$ROCKY_DIR/Rocky-9.5-x86_64-minimal.iso" \
                 "Rocky Linux 9.5 (Latest)"
    
    # Rocky Linux 8.10 (latest)
    download_file "https://download.rockylinux.org/pub/rocky/8.10/isos/x86_64/Rocky-8.10-x86_64-minimal.iso" \
                 "$ROCKY_DIR/Rocky-8.10-x86_64-minimal.iso" \
                 "Rocky Linux 8.10 (Latest)"
}

# Function to download AlmaLinux ISOs
function download_alma {
    local ALMA_DIR="$DOWNLOAD_DIR/alma"
    create_dir_if_not_exists "$ALMA_DIR"
    
    # AlmaLinux 9.5 (latest)
    download_file "https://repo.almalinux.org/almalinux/9.5/isos/x86_64/AlmaLinux-9.5-x86_64-minimal.iso" \
                 "$ALMA_DIR/AlmaLinux-9.5-x86_64-minimal.iso" \
                 "AlmaLinux 9.5 (Latest)"
    
    # AlmaLinux 8.10 (latest)
    download_file "https://repo.almalinux.org/almalinux/8.10/isos/x86_64/AlmaLinux-8.10-x86_64-minimal.iso" \
                 "$ALMA_DIR/AlmaLinux-8.10-x86_64-minimal.iso" \
                 "AlmaLinux 8.10 (Latest)"
}

# Function to download Proxmox VE ISOs
function download_proxmox {
    local PROXMOX_DIR="$DOWNLOAD_DIR/proxmox"
    create_dir_if_not_exists "$PROXMOX_DIR"
    
    # Proxmox VE 8.4 (latest)
    download_file "https://enterprise.proxmox.com/iso/proxmox-ve_8.4-1.iso" \
                 "$PROXMOX_DIR/proxmox-ve_8.4-1.iso" \
                 "Proxmox VE 8.4 (Latest)"
    
    # Proxmox VE 7.4 (previous stable)
    download_file "https://enterprise.proxmox.com/iso/proxmox-ve_7.4-1.iso" \
                 "$PROXMOX_DIR/proxmox-ve_7.4-1.iso" \
                 "Proxmox VE 7.4 (Previous stable)"
}

# Function to download openSUSE ISOs
function download_opensuse {
    local OPENSUSE_DIR="$DOWNLOAD_DIR/opensuse"
    create_dir_if_not_exists "$OPENSUSE_DIR"
    
    # openSUSE Leap 15.5 (stable)
    download_file "https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Current.iso" \
                 "$OPENSUSE_DIR/openSUSE-Leap-15.5-DVD-x86_64.iso" \
                 "openSUSE Leap 15.5 (Stable)"
    
    # openSUSE Tumbleweed (rolling)
    download_file "https://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-DVD-x86_64-Current.iso" \
                 "$OPENSUSE_DIR/openSUSE-Tumbleweed-DVD-x86_64.iso" \
                 "openSUSE Tumbleweed (Rolling Release)"
}

# Function to download Fedora Server ISOs
function download_fedora {
    local FEDORA_DIR="$DOWNLOAD_DIR/fedora"
    create_dir_if_not_exists "$FEDORA_DIR"
    
    # Fedora Server 40 (latest)
    download_file "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-dvd-x86_64-40-1.6.iso" \
                 "$FEDORA_DIR/Fedora-Server-40-x86_64.iso" \
                 "Fedora Server 40 (Latest)"
    
    # Fedora Server 39 (previous)
    download_file "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-dvd-x86_64-39-1.5.iso" \
                 "$FEDORA_DIR/Fedora-Server-39-x86_64.iso" \
                 "Fedora Server 39 (Previous)"
}

# Parse command line arguments
DOWNLOAD_ALL=false
DOWNLOAD_UBUNTU=false
DOWNLOAD_DEBIAN=false
DOWNLOAD_CENTOS=false
DOWNLOAD_ROCKY=false
DOWNLOAD_ALMA=false
DOWNLOAD_PROXMOX=false
DOWNLOAD_OPENSUSE=false
DOWNLOAD_FEDORA=false

# If no arguments, show usage
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--directory)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -a|--all)
            DOWNLOAD_ALL=true
            shift
            ;;
        --ubuntu)
            DOWNLOAD_UBUNTU=true
            shift
            ;;
        --debian)
            DOWNLOAD_DEBIAN=true
            shift
            ;;
        --centos)
            DOWNLOAD_CENTOS=true
            shift
            ;;
        --rocky)
            DOWNLOAD_ROCKY=true
            shift
            ;;
        --alma)
            DOWNLOAD_ALMA=true
            shift
            ;;
        --proxmox)
            DOWNLOAD_PROXMOX=true
            shift
            ;;
        --opensuse)
            DOWNLOAD_OPENSUSE=true
            shift
            ;;
        --fedora)
            DOWNLOAD_FEDORA=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option:${NC} $1"
            show_usage
            exit 1
            ;;
    esac
done

# Create main download directory
create_dir_if_not_exists "$DOWNLOAD_DIR"

# Download ISOs based on options
if [ "$DOWNLOAD_ALL" = true ]; then
    echo -e "${GREEN}Downloading all distributions...${NC}"
    download_ubuntu
    download_debian
    download_centos
    download_rocky
    download_alma
    download_proxmox
    download_opensuse
    download_fedora
else
    # Download individual distributions if selected
    [ "$DOWNLOAD_UBUNTU" = true ] && download_ubuntu
    [ "$DOWNLOAD_DEBIAN" = true ] && download_debian
    [ "$DOWNLOAD_CENTOS" = true ] && download_centos
    [ "$DOWNLOAD_ROCKY" = true ] && download_rocky
    [ "$DOWNLOAD_ALMA" = true ] && download_alma
    [ "$DOWNLOAD_PROXMOX" = true ] && download_proxmox
    [ "$DOWNLOAD_OPENSUSE" = true ] && download_opensuse
    [ "$DOWNLOAD_FEDORA" = true ] && download_fedora
fi

echo -e "${GREEN}All downloads completed!${NC}"

# Make this script executable if it's not already
if [ ! -x "$0" ]; then
    chmod +x "$0" 
    echo -e "${YELLOW}Made the script executable.${NC}"
fi 