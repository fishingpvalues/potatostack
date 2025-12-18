#!/bin/bash

################################################################################
# Setup Directory Structure for Production - Single Disk
# Creates all required directories on /mnt/storage
################################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PotatoStack Production Directory Setup           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root (sudo ./setup-directories-production.sh)${NC}"
    exit 1
fi

MAIN_DISK="/mnt/storage"
BACKUP_DISK="/mnt/backup"

# Check if main disk is mounted
if ! mountpoint -q "$MAIN_DISK" 2>/dev/null; then
    echo -e "${YELLOW}WARNING: $MAIN_DISK is not a mount point!${NC}"
    read -p "Create directory anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please mount your disk first."
        exit 1
    fi
fi

# Show disk information
echo -e "${CYAN}Main Storage Disk:${NC}"
df -h "$MAIN_DISK" 2>/dev/null || echo "Not mounted yet"
echo ""

if mountpoint -q "$BACKUP_DISK" 2>/dev/null; then
    echo -e "${CYAN}Backup Storage Disk:${NC}"
    df -h "$BACKUP_DISK"
    echo ""
else
    echo -e "${YELLOW}Backup disk not mounted at $BACKUP_DISK${NC}"
    echo "You can mount it later for nightly backups"
    echo ""
fi

# Define directory structure
DIRECTORIES=(
    "$MAIN_DISK/downloads"
    "$MAIN_DISK/transmission-incomplete"
    "$MAIN_DISK/slskd-shared"
    "$MAIN_DISK/slskd-incomplete"
    "$MAIN_DISK/immich/upload"
    "$MAIN_DISK/immich/library"
    "$MAIN_DISK/immich/thumbs"
    "$MAIN_DISK/seafile"
    "$MAIN_DISK/kopia/repository"
    "$MAIN_DISK/kopia/cache"
    "$MAIN_DISK/rustypaste"
)

echo -e "${CYAN}Creating directory structure...${NC}"
echo ""

# Create directories
for DIR in "${DIRECTORIES[@]}"; do
    if [ -d "$DIR" ]; then
        echo -e "${YELLOW}  ⚠ Already exists: $DIR${NC}"
    else
        mkdir -p "$DIR"
        echo -e "${GREEN}  ✓ Created: $DIR${NC}"
    fi
done

echo ""
echo -e "${CYAN}Setting ownership (PUID=1000, PGID=1000)...${NC}"
chown -R 1000:1000 "$MAIN_DISK"
echo -e "${GREEN}✓ Ownership set${NC}"

echo ""
echo -e "${CYAN}Setting permissions...${NC}"
chmod -R 755 "$MAIN_DISK"
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Directory structure created successfully         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Show disk usage
echo -e "${CYAN}Disk Usage:${NC}"
df -h "$MAIN_DISK"

if mountpoint -q "$BACKUP_DISK" 2>/dev/null; then
    df -h "$BACKUP_DISK"
fi

echo ""
echo -e "${CYAN}Directory Structure:${NC}"
tree -L 3 -d "$MAIN_DISK" 2>/dev/null || find "$MAIN_DISK" -type d -maxdepth 3 | sed 's|[^/]*/| |g'

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Generate .env file: ./generate-env.sh"
echo "  2. Setup cron jobs: ./setup-cron.sh"
echo "  3. Start the stack: docker compose -f docker-compose.production.yml --env-file .env.production up -d"
echo ""
