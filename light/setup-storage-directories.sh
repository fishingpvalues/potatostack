#!/bin/bash
################################################################################
# PotatoStack Light - Storage Directory Setup
# Creates all required /mnt/storage directories with proper permissions
################################################################################

set -e

STORAGE_BASE="/mnt/storage"
PUID=1000
PGID=1000

echo "=========================================="
echo "PotatoStack Light - Storage Setup"
echo "=========================================="
echo ""
echo "Creating directory structure in ${STORAGE_BASE}..."
echo ""

# Function to create directory with proper ownership
create_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        echo "  Creating: $dir"
        mkdir -p "$dir"
        chown ${PUID}:${PGID} "$dir"
        chmod 755 "$dir"
    else
        echo "  Exists:   $dir"
        # Fix ownership even if exists
        chown ${PUID}:${PGID} "$dir"
    fi
}

# Check if storage mount point exists
if [ ! -d "${STORAGE_BASE}" ]; then
    echo "ERROR: ${STORAGE_BASE} does not exist!"
    echo "Please create/mount your storage drive first."
    echo ""
    echo "Example:"
    echo "  sudo mkdir -p ${STORAGE_BASE}"
    echo "  sudo mount /dev/sdX ${STORAGE_BASE}"
    exit 1
fi

echo "Storage base exists: ${STORAGE_BASE}"
echo ""

# Transmission directories
echo "[Transmission - Torrent Client]"
create_dir "${STORAGE_BASE}/downloads"
create_dir "${STORAGE_BASE}/transmission-incomplete"
echo ""

# slskd directories
echo "[slskd - Soulseek Client]"
create_dir "${STORAGE_BASE}/slskd-shared"
create_dir "${STORAGE_BASE}/slskd-incomplete"
echo ""

# Immich directories
echo "[Immich - Photo Management]"
create_dir "${STORAGE_BASE}/immich"
create_dir "${STORAGE_BASE}/immich/upload"
create_dir "${STORAGE_BASE}/immich/library"
create_dir "${STORAGE_BASE}/immich/thumbs"
echo ""

# Kopia directories
echo "[Kopia - Backup Server]"
create_dir "${STORAGE_BASE}/kopia"
create_dir "${STORAGE_BASE}/kopia/repository"
create_dir "${STORAGE_BASE}/kopia/cache"
echo ""

# Seafile directories
echo "[Seafile - File Sync & Share]"
create_dir "${STORAGE_BASE}/seafile"
echo ""

# Rustypaste directories
echo "[Rustypaste - Pastebin]"
create_dir "${STORAGE_BASE}/rustypaste"
echo ""

# Summary
echo "=========================================="
echo "Directory structure created successfully!"
echo "=========================================="
echo ""
echo "Total directories created:"
ls -lh ${STORAGE_BASE} | grep "^d" | wc -l
echo ""
echo "Ownership set to: ${PUID}:${PGID}"
echo ""
echo "Directory tree:"
tree -L 2 -d ${STORAGE_BASE} 2>/dev/null || find ${STORAGE_BASE} -maxdepth 2 -type d | sort
echo ""
echo "You can now start the stack:"
echo "  docker compose up -d"
echo ""
