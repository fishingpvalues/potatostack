#!/bin/bash
################################################################################
# PotatoStack Light - Storage Init Container
# Runs before stack starts to ensure directories exist with SOTA structure
################################################################################

STORAGE_BASE="/mnt/storage"
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Initializing storage directories with SOTA structure..."

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

# Syncthing P2P File Sync - SOTA Content-Based Structure
# Based on best practices from Syncthing community and media organization
echo "Creating Syncthing SOTA content-based directories..."
mkdir -p \
    "${STORAGE_BASE}/syncthing/camera-sync/android" \
    "${STORAGE_BASE}/syncthing/camera-sync/ios" \
    "${STORAGE_BASE}/syncthing/photos/2024" \
    "${STORAGE_BASE}/syncthing/photos/2025" \
    "${STORAGE_BASE}/syncthing/photos/albums" \
    "${STORAGE_BASE}/syncthing/videos/personal" \
    "${STORAGE_BASE}/syncthing/videos/projects" \
    "${STORAGE_BASE}/syncthing/videos/raw" \
    "${STORAGE_BASE}/syncthing/music/albums" \
    "${STORAGE_BASE}/syncthing/music/playlists" \
    "${STORAGE_BASE}/syncthing/audiobooks" \
    "${STORAGE_BASE}/syncthing/podcasts" \
    "${STORAGE_BASE}/syncthing/documents/personal" \
    "${STORAGE_BASE}/syncthing/documents/receipts" \
    "${STORAGE_BASE}/syncthing/documents/scans" \
    "${STORAGE_BASE}/syncthing/books" \
    "${STORAGE_BASE}/syncthing/shared" \
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
echo "✓ Created: VPN, P2P, Syncthing (camera-sync/photos/videos/music/audiobooks/podcasts/documents/books/shared/backup), Kopia"
