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

# Syncthing P2P File Sync - Full OneDrive Mirror Structure
echo "Creating Syncthing OneDrive mirror directories..."
mkdir -p \
    "${STORAGE_BASE}/syncthing/Desktop" \
    "${STORAGE_BASE}/syncthing/Obsidian-Vault" \
    "${STORAGE_BASE}/syncthing/Bilder" \
    "${STORAGE_BASE}/syncthing/Dokumente" \
    "${STORAGE_BASE}/syncthing/workdir" \
    "${STORAGE_BASE}/syncthing/nvim" \
    "${STORAGE_BASE}/syncthing/Microsoft-Copilot-Chat-Dateien" \
    "${STORAGE_BASE}/syncthing/Attachments" \
    "${STORAGE_BASE}/syncthing/Privates" \
    "${STORAGE_BASE}/syncthing/Studium" \
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

echo "✓ Storage initialization complete with full OneDrive mirror!"
echo "✓ Created: VPN, P2P, Syncthing (OneDrive mirror + media folders), Kopia"
echo "✓ OneDrive folders: Desktop, Obsidian-Vault, Bilder, Dokumente, workdir, nvim, etc."
