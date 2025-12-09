#!/bin/bash
################################################################################
# Setup Test Drives Script
# Creates temporary directory structure to emulate /mnt/seconddrive and /mnt/cachehdd
# for testing PotatoStack on any PC
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  PotatoStack - Test Drive Emulation Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Determine test directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_MOUNTS_DIR="${PROJECT_ROOT}/test-mounts"

echo -e "${YELLOW}Creating test mount directories...${NC}"
echo "  Location: ${TEST_MOUNTS_DIR}"
echo

# Create base test mounts directory
mkdir -p "${TEST_MOUNTS_DIR}"

# Emulate /mnt/seconddrive (main HDD)
SECONDDRIVE="${TEST_MOUNTS_DIR}/seconddrive"
echo -e "${GREEN}[1/2] Creating seconddrive emulation...${NC}"
mkdir -p "${SECONDDRIVE}"/{kopia/{repository,config,cache,logs,tmp},nextcloud,gitea,backups/{db,vaultwarden},uptime-kuma,immich/{upload,library},qbittorrent/config,slskd/{config,logs}}

# Emulate /mnt/cachehdd (cache HDD)
CACHEHDD="${TEST_MOUNTS_DIR}/cachehdd"
echo -e "${GREEN}[2/2] Creating cachehdd emulation...${NC}"
mkdir -p "${CACHEHDD}"/{torrents/{incomplete,pr0n,music,tv-shows,movies},soulseek/{incomplete,pr0n,music,tv-shows,movies}}

# Set permissions (using current user)
echo
echo -e "${YELLOW}Setting permissions...${NC}"
chmod -R 755 "${TEST_MOUNTS_DIR}"
chown -R $(id -u):$(id -g) "${TEST_MOUNTS_DIR}"

# Create symbolic links to emulate actual mount points (requires sudo)
echo
echo -e "${YELLOW}Creating symbolic links (requires sudo)...${NC}"

# Check if running with sudo
if [ "$EUID" -eq 0 ]; then
    # Remove existing links/mounts if they exist
    [ -L "/mnt/seconddrive" ] && rm -f /mnt/seconddrive
    [ -L "/mnt/cachehdd" ] && rm -f /mnt/cachehdd
    [ -d "/mnt/seconddrive" ] && [ ! "$(ls -A /mnt/seconddrive)" ] && rmdir /mnt/seconddrive
    [ -d "/mnt/cachehdd" ] && [ ! "$(ls -A /mnt/cachehdd)" ] && rmdir /mnt/cachehdd

    # Create mount points if they don't exist
    mkdir -p /mnt

    # Create symbolic links
    ln -sf "${SECONDDRIVE}" /mnt/seconddrive
    ln -sf "${CACHEHDD}" /mnt/cachehdd

    echo -e "${GREEN}✓ Symbolic links created:${NC}"
    echo "  /mnt/seconddrive -> ${SECONDDRIVE}"
    echo "  /mnt/cachehdd -> ${CACHEHDD}"
else
    echo -e "${RED}Warning: Not running as root. Symbolic links will not be created.${NC}"
    echo -e "${YELLOW}You have two options:${NC}"
    echo "  1. Re-run with sudo: sudo $0"
    echo "  2. Or use bind mounts manually:"
    echo "     sudo mkdir -p /mnt/seconddrive /mnt/cachehdd"
    echo "     sudo mount --bind ${SECONDDRIVE} /mnt/seconddrive"
    echo "     sudo mount --bind ${CACHEHDD} /mnt/cachehdd"
    echo
    echo -e "${BLUE}For testing without sudo, you can update docker-compose.yml volumes:${NC}"
    echo "  Replace '/mnt/seconddrive' with '${SECONDDRIVE}'"
    echo "  Replace '/mnt/cachehdd' with '${CACHEHDD}'"
fi

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Test drive structure created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${YELLOW}Directory Structure:${NC}"
tree -L 3 -d "${TEST_MOUNTS_DIR}" 2>/dev/null || find "${TEST_MOUNTS_DIR}" -type d -maxdepth 3 | sort

echo
echo -e "${GREEN}Ready for testing!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review .env.test file"
echo "  2. Run: ./tests/test-stack.sh"
