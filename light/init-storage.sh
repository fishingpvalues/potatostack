#!/bin/bash
################################################################################
# PotatoStack Light - Storage Init Container
# Runs before stack starts to ensure directories exist with SOTA structure
################################################################################

STORAGE_BASE="/mnt/storage"
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Initializing storage directories with SOTA structure..."

# Fix entrypoint script permissions
SCRIPT_DIR="$(dirname "$0")"
if [ -f "${SCRIPT_DIR}/immich-entrypoint.sh" ]; then
    chmod +x "${SCRIPT_DIR}/immich-entrypoint.sh" 2>/dev/null || true
fi

################################################################################
# SOTA Directory Structure
################################################################################

# VPN & P2P Downloads
echo "Creating VPN & P2P directories..."
mkdir -p \
    "${STORAGE_BASE}/downloads" \
    "${STORAGE_BASE}/transmission-incomplete" \
    "${STORAGE_BASE}/slskd-shared" \
    "${STORAGE_BASE}/slskd-incomplete"

# Immich Photo Management
echo "Creating Immich directories..."
mkdir -p \
    "${STORAGE_BASE}/immich/upload" \
    "${STORAGE_BASE}/immich/library" \
    "${STORAGE_BASE}/immich/thumbs"

# Syncthing P2P File Sync
# SOTA Structure: Separate folders for different sync use-cases
echo "Creating Syncthing SOTA directories..."
mkdir -p \
    "${STORAGE_BASE}/syncthing/data" \
    "${STORAGE_BASE}/syncthing/sync1" \
    "${STORAGE_BASE}/syncthing/sync2" \
    "${STORAGE_BASE}/syncthing/backup" \
    "${STORAGE_BASE}/syncthing/.stversions"

# Kopia Backup
echo "Creating Kopia directories..."
mkdir -p \
    "${STORAGE_BASE}/kopia/repository" \
    "${STORAGE_BASE}/kopia/cache"

# Set ownership
echo "Setting ownership to ${PUID}:${PGID}..."
chown -R ${PUID}:${PGID} "${STORAGE_BASE}"

# Set permissions
echo "Setting permissions..."
chmod -R 755 "${STORAGE_BASE}"

# Special permissions for Syncthing versioning
chmod 775 "${STORAGE_BASE}/syncthing/.stversions"

echo "✓ Storage initialization complete with SOTA structure!"
echo "✓ Created: VPN, P2P, Immich, Syncthing (data/sync1/sync2/backup), Kopia"
