#!/bin/bash

################################################################################
# PotatoStack Setup Script for Le Potato SBC
# This script prepares your system for running the PotatoStack
################################################################################

set -euo pipefail

echo "========================================"
echo "PotatoStack Setup for Le Potato SBC"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Args
NONINTERACTIVE=false
SKIP_PULL=false
for arg in "$@"; do
  case "$arg" in
    --non-interactive)
      NONINTERACTIVE=true
      ;;
    --skip-pull)
      SKIP_PULL=true
      ;;
    *) ;;
  esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo ./setup.sh)${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Checking system requirements...${NC}"

# Determine docker compose command
if command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DC="docker compose"
else
    DC="docker-compose" # will be installed below
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
    rm get-docker.sh
    echo -e "${GREEN}Docker installed successfully${NC}"
else
    echo -e "${GREEN}Docker is already installed${NC}"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    apt-get update
    apt-get install -y docker-compose-plugin docker-compose
    echo -e "${GREEN}Docker Compose installed successfully${NC}"
else
    echo -e "${GREEN}Docker Compose is already installed${NC}"
fi

echo ""
echo -e "${GREEN}Step 2: Checking HDD mounts...${NC}"

# Check if HDDs are mounted
if [ ! -d "/mnt/seconddrive" ]; then
    echo -e "${RED}ERROR: /mnt/seconddrive not found!${NC}"
    echo "Please mount your main HDD to /mnt/seconddrive first"
    echo "Add to /etc/fstab for automatic mounting"
    exit 1
else
    echo -e "${GREEN}/mnt/seconddrive found${NC}"
fi

if [ ! -d "/mnt/cachehdd" ]; then
    echo -e "${RED}ERROR: /mnt/cachehdd not found!${NC}"
    echo "Please mount your cache HDD to /mnt/cachehdd first"
    echo "Add to /etc/fstab for automatic mounting"
    exit 1
else
    echo -e "${GREEN}/mnt/cachehdd found${NC}"
fi

echo ""
echo -e "${GREEN}Step 3: Creating directory structure...${NC}"

# Create all necessary directories on main HDD
mkdir -p /mnt/seconddrive/{kopia/{repository,config,cache,logs,tmp},qbittorrent/{config,logs},slskd/{config,logs},nextcloud,gitea,uptime-kuma}

# Create cache directories
mkdir -p /mnt/cachehdd/{torrents/{incomplete,pr0n,music,tv-shows,movies},soulseek/{incomplete,pr0n,music,tv-shows,movies}}

# Create log directories for Promtail monitoring
mkdir -p /var/log/netdata

# Set permissions
chmod -R 755 /mnt/seconddrive
chmod -R 755 /mnt/cachehdd
chown -R 1000:1000 /mnt/seconddrive
chown -R 1000:1000 /mnt/cachehdd

echo -e "${GREEN}Directory structure created${NC}"

echo ""
echo -e "${GREEN}Step 4: Setting up environment file...${NC}"

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo -e "${YELLOW}Created .env file from template${NC}"
    if [ "$NONINTERACTIVE" = false ]; then
        echo -e "${RED}IMPORTANT: Edit .env file and fill in your passwords!${NC}"
        echo -e "${RED}Use: nano .env${NC}"
        echo ""
        read -p "Press enter to edit .env now, or Ctrl+C to exit and edit later..."
        nano .env
    else
        echo -e "${YELLOW}Non-interactive mode: Skipping editor${NC}"
    fi
else
    echo -e "${GREEN}.env file already exists${NC}"
fi

echo ""
echo -e "${GREEN}Step 5: Preflight checks...${NC}"

# Run preflight (non-blocking)
if [ -x "./preflight-check.sh" ]; then
    set +e
    ./preflight-check.sh || true
    set -e
else
    echo -e "${YELLOW}Preflight script not found; skipping${NC}"
fi

echo ""
echo -e "${GREEN}Step 6: Installing required tools...${NC}"

# Install smartmontools for SMART monitoring
if ! command -v smartctl &> /dev/null; then
    apt-get update
    apt-get install -y smartmontools
    echo -e "${GREEN}smartmontools installed${NC}"
else
    echo -e "${GREEN}smartmontools already installed${NC}"
fi

echo ""
echo -e "${GREEN}Step 7: Initializing Kopia repository...${NC}"

# Check if Kopia repo already exists
if [ ! -f "/mnt/seconddrive/kopia/config/repository.config" ]; then
    echo -e "${YELLOW}Kopia repository not found. Creating...${NC}"
    echo "Enter a strong password for your Kopia repository:"
    read -s KOPIA_REPO_PASSWORD

    docker run --rm \
        -e KOPIA_PASSWORD="$KOPIA_REPO_PASSWORD" \
        -v /mnt/seconddrive/kopia/repository:/repository \
        -v /mnt/seconddrive/kopia/config:/app/config \
        -v /mnt/seconddrive/kopia/cache:/app/cache \
        -v /mnt/seconddrive/kopia/logs:/app/logs \
        -v /mnt/seconddrive/kopia/tmp:/tmp \
        kopia/kopia:latest \
        repository create filesystem --path=/repository

    echo -e "${GREEN}Kopia repository created${NC}"
else
    echo -e "${GREEN}Kopia repository already exists${NC}"
fi

echo ""
echo -e "${GREEN}Step 8: Optimizing system for containerized workloads...${NC}"

# Increase inotify limits for containers (idempotent)
grep -q '^fs.inotify.max_user_watches=524288' /etc/sysctl.conf || echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
grep -q '^fs.inotify.max_user_instances=512' /etc/sysctl.conf || echo "fs.inotify.max_user_instances=512" >> /etc/sysctl.conf

# Enable IP forwarding for VPN (idempotent)
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

sysctl -p >/dev/null 2>&1 || true

echo -e "${GREEN}System optimizations applied${NC}"

echo ""
if [ "$SKIP_PULL" = false ]; then
    echo -e "${GREEN}Step 9: Pulling Docker images (this may take a while)...${NC}"
    $DC pull
else
    echo -e "${YELLOW}Skipping image pull (requested)${NC}"
fi

echo ""
echo -e "${GREEN}Step 10: Optional systemd auto-start...${NC}"
if [ "$NONINTERACTIVE" = true ]; then
    if [ -d "systemd" ]; then
        echo -e "${YELLOW}Non-interactive: Installing systemd services automatically${NC}"
        (cd systemd && yes | ./install-systemd-services.sh) || echo -e "${YELLOW}Systemd install encountered an issue; continue manually if needed${NC}"
    else
        echo -e "${YELLOW}systemd/ not found; skipping auto-install${NC}"
    fi
else
    echo -e "${YELLOW}Run: cd systemd && sudo ./install-systemd-services.sh  to enable auto-start on boot${NC}"
fi

echo ""
echo "========================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review and update your .env file if you haven't already"
echo "2. Start the stack: make up    (or: docker compose up -d)"
echo "3. Check logs:    make logs  (or: docker compose logs -f)"
echo "4. Access Homepage dashboard at: http://<HOST_ADDR>:3003 (set in .env)"
echo ""
echo "Recommended Grafana dashboards to import:"
echo "  - Node Exporter Full: 1860"
echo "  - Docker Container Monitoring: 193"
echo "  - SMART HDD: 20204"
echo "  - Loki Dashboard: 13639"
echo ""
echo -e "${YELLOW}IMPORTANT: Configure Nginx Proxy Manager for HTTPS and proper reverse proxy${NC}"
echo -e "${YELLOW}IMPORTANT: Set up 2FA in Nextcloud and other services${NC}"
echo -e "${YELLOW}IMPORTANT: Configure WireGuard VPN on your Fritzbox for external access${NC}"
echo ""
