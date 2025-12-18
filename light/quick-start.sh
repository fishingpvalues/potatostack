#!/bin/bash

################################################################################
# PotatoStack Light - One-Command Production Setup
# Automates the entire setup process for enterprise-grade deployment
################################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║  ██████╗  ██████╗ ████████╗ █████╗ ████████╗ ██████╗ ███████╗   ║
║  ██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗╚══██╔══╝██╔═══██╗██╔════╝   ║
║  ██████╔╝██║   ██║   ██║   ███████║   ██║   ██║   ██║███████╗   ║
║  ██╔═══╝ ██║   ██║   ██║   ██╔══██║   ██║   ██║   ██║╚════██║   ║
║  ██║     ╚██████╔╝   ██║   ██║  ██║   ██║   ╚██████╔╝███████║   ║
║  ╚═╝      ╚═════╝    ╚═╝   ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝   ║
║                                                                   ║
║          Enterprise-Grade Production Setup - Light Edition       ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}Features:${NC}"
echo "  🏠 Homepage Dashboard with all widgets"
echo "  🔄 Automatic container updates (Watchtower)"
echo "  🏥 Self-healing containers (Autoheal)"
echo "  💾 Nightly backups to second disk"
echo "  🌐 Network resilience (survives reboots)"
echo "  🛡️  100% uptime focus"
echo ""

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}ERROR: This script must run on Linux (Le Potato)${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker is not installed${NC}"
    echo "Install Docker first: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}ERROR: Docker Compose is not available${NC}"
    exit 1
fi

echo -e "${GREEN}✓ System checks passed${NC}"
echo ""

# Step 1: Check disk mounts
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 1: Checking Disk Mounts${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

MAIN_DISK="/mnt/storage"
BACKUP_DISK="/mnt/backup"

if ! mountpoint -q "$MAIN_DISK" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Main disk not mounted at $MAIN_DISK${NC}"
    echo ""
    echo "Please mount your main disk first:"
    echo "  1. Find UUID: sudo blkid"
    echo "  2. Edit fstab: sudo nano /etc/fstab"
    echo "  3. Add: UUID=xxx /mnt/storage ext4 defaults,nofail 0 2"
    echo "  4. Mount: sudo mkdir -p /mnt/storage && sudo mount -a"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Main disk mounted at $MAIN_DISK${NC}"
df -h "$MAIN_DISK"
echo ""

if mountpoint -q "$BACKUP_DISK" 2>/dev/null; then
    echo -e "${GREEN}✓ Backup disk mounted at $BACKUP_DISK${NC}"
    df -h "$BACKUP_DISK"
    echo ""
else
    echo -e "${YELLOW}⚠ Backup disk not mounted at $BACKUP_DISK${NC}"
    echo "Nightly backups will fail until second disk is mounted."
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 2: Setup directories
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 2: Creating Directory Structure${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -f "./setup-directories.sh" ]; then
    echo -e "${RED}ERROR: setup-directories.sh not found${NC}"
    exit 1
fi

chmod +x setup-directories.sh
sudo ./setup-directories.sh

echo ""

# Step 3: Generate .env file
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 3: Generating Secure .env File${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ -f ".env.production" ]; then
    echo -e "${YELLOW}⚠ .env.production already exists${NC}"
    read -p "Keep existing file? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}✓ Using existing .env.production${NC}"
    else
        chmod +x generate-env.sh
        ./generate-env.sh
    fi
else
    chmod +x generate-env.sh
    ./generate-env.sh
fi

echo ""

# Step 4: Setup cron jobs
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 4: Setting Up Cron Jobs${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -f "./setup-cron.sh" ]; then
    echo -e "${RED}ERROR: setup-cron.sh not found${NC}"
    exit 1
fi

chmod +x setup-cron.sh backup-to-second-disk.sh
./setup-cron.sh

echo ""

# Step 5: Start the stack
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 5: Starting Docker Stack${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Pulling Docker images...${NC}"
docker compose --env-file .env.production pull

echo ""
echo -e "${CYAN}Starting containers...${NC}"
docker compose --env-file .env.production up -d

echo ""
echo -e "${GREEN}✓ Stack started successfully${NC}"

# Wait for containers to start
echo ""
echo -e "${CYAN}Waiting for containers to initialize...${NC}"
sleep 10

# Step 6: Show status
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Container Status${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

docker compose ps

# Step 7: Setup homepage configuration
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 6: Configuring Homepage Dashboard${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ -d "homepage-config" ]; then
    echo -e "${CYAN}Copying homepage configuration...${NC}"
    docker cp homepage-config/. homepage:/app/config/
    docker restart homepage
    echo -e "${GREEN}✓ Homepage configured${NC}"
else
    echo -e "${YELLOW}⚠ homepage-config directory not found${NC}"
fi

# Get IP address
HOST_IP=$(grep "^HOST_BIND=" .env.production | cut -d= -f2)

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                    🎉 SETUP COMPLETED! 🎉                         ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}Access Your Services:${NC}"
echo ""
echo -e "${GREEN}  🏠 Homepage Dashboard:    http://$HOST_IP:3000${NC}"
echo "  📊 Portainer:            https://$HOST_IP:9443"
echo "  🔐 Vaultwarden:          http://$HOST_IP:8080"
echo "  📸 Immich:               http://$HOST_IP:2283"
echo "  📁 Seafile:              http://$HOST_IP:8082"
echo "  💾 Kopia:                https://$HOST_IP:51515"
echo "  🌐 Transmission:         http://$HOST_IP:9091"
echo "  🎵 slskd:                http://$HOST_IP:2234"
echo "  📋 Rustypaste:           http://$HOST_IP:8001"
echo ""

echo -e "${CYAN}Automated Features:${NC}"
echo "  ✅ Automatic container updates (daily at 3 AM)"
echo "  ✅ Self-healing unhealthy containers"
echo "  ✅ Nightly backups to second disk (3 AM)"
echo "  ✅ Weekly Docker cleanup (Sunday 4 AM)"
echo "  ✅ Health monitoring (every 5 minutes)"
echo "  ✅ Network resilience (survives reboots)"
echo ""

echo -e "${CYAN}Important Files:${NC}"
echo "  📄 Passwords:        .env.production (chmod 600)"
echo "  📋 Configuration:    docker-compose.yml"
echo "  📝 Documentation:    README.md"
echo "  📊 Backup logs:      /var/log/potatostack/"
echo ""

echo -e "${CYAN}Useful Commands:${NC}"
echo "  View logs:           docker compose logs -f"
echo "  Restart service:     docker compose restart SERVICE"
echo "  Stop stack:          docker compose down"
echo "  Check backups:       ls -lh /mnt/backup/"
echo "  View cron jobs:      crontab -l"
echo ""

echo -e "${YELLOW}⚠ IMPORTANT:${NC}"
echo "  1. Save your passwords from .env.production to a password manager"
echo "  2. Set up Portainer password on first login"
echo "  3. Configure Homepage API keys for Immich and Portainer widgets"
echo "  4. Test manual backup: sudo ./backup-to-second-disk.sh"
echo "  5. Read README.md for advanced configuration"
echo ""

echo -e "${GREEN}Your PotatoStack is now running in production mode!${NC}"
echo -e "${GREEN}Access the Homepage Dashboard to see all services: http://$HOST_IP:3000${NC}"
echo ""
