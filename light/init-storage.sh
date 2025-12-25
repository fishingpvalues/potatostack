#!/bin/bash
################################################################################
# PotatoStack Light - Storage Init Container
# Runs before stack starts to ensure directories exist with SOTA structure
################################################################################

STORAGE_BASE="/mnt/storage"
CACHE_BASE="/mnt/cachehdd"
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Initializing storage directories with SOTA structure..."

################################################################################
# SOTA Directory Structure
################################################################################

# VPN & P2P Downloads (final storage)
echo "Creating VPN & P2P directories..."
mkdir -p \
    "${STORAGE_BASE}/downloads" \
    "${STORAGE_BASE}/slskd-shared"

# Syncthing P2P File Sync - Full OneDrive Mirror Structure
echo "Creating Syncthing OneDrive mirror directories..."
mkdir -p \
    "${STORAGE_BASE}/syncthing/Desktop" \
    "${STORAGE_BASE}/syncthing/Obsidian-Vault" \
    "${STORAGE_BASE}/syncthing/Bilder" \
    "${STORAGE_BASE}/syncthing/Dokumente" \
    "${STORAGE_BASE}/syncthing/workdir" \
    "${STORAGE_BASE}/syncthing/Attachments" \
    "${STORAGE_BASE}/syncthing/Privates" \
    "${STORAGE_BASE}/syncthing/Berufliches" \
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
    "${STORAGE_BASE}/syncthing/books" \
    "${STORAGE_BASE}/syncthing/shared" \
    "${STORAGE_BASE}/syncthing/backup"

# Kopia Backup
echo "Creating Kopia directories..."
mkdir -p \
    "${STORAGE_BASE}/kopia/repository"

################################################################################
# Cache HDD Directories (500GB - High I/O operations)
################################################################################
echo "Creating Cache HDD directories for high-speed temporary operations..."
mkdir -p \
    "${CACHE_BASE}/transmission-incomplete" \
    "${CACHE_BASE}/slskd-incomplete" \
    "${CACHE_BASE}/kopia-cache" \
    "${CACHE_BASE}/syncthing-versions"

# Set ownership
echo "Setting ownership to ${PUID}:${PGID}..."
chown -R ${PUID}:${PGID} "${STORAGE_BASE}"
chown -R ${PUID}:${PGID} "${CACHE_BASE}"

# Set permissions
echo "Setting permissions..."
chmod -R 755 "${STORAGE_BASE}"
chmod -R 755 "${CACHE_BASE}"

# Special permissions for versioning directories
chmod 775 "${CACHE_BASE}/syncthing-versions"

echo "✓ Storage initialization complete with full OneDrive mirror!"
echo "✓ Main HDD: VPN, P2P, Syncthing (OneDrive mirror + media folders), Kopia repository"
echo "✓ Cache HDD: Incomplete downloads, Kopia cache, Syncthing file versioning"
echo "✓ OneDrive folders: Desktop, Obsidian-Vault, Bilder, Dokumente, workdir, Attachments, Privates, Berufliches"
