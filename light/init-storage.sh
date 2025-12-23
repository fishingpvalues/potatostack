#!/bin/bash
################################################################################
# PotatoStack Light - Storage Init Container
# Runs before stack starts to ensure directories exist
################################################################################

STORAGE_BASE="/mnt/storage"
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Initializing storage directories..."

# Create all required directories
mkdir -p \
    "${STORAGE_BASE}/downloads" \
    "${STORAGE_BASE}/transmission-incomplete" \
    "${STORAGE_BASE}/slskd-shared" \
    "${STORAGE_BASE}/slskd-incomplete" \
    "${STORAGE_BASE}/immich/upload" \
    "${STORAGE_BASE}/immich/library" \
    "${STORAGE_BASE}/immich/thumbs" \
    "${STORAGE_BASE}/kopia/repository" \
    "${STORAGE_BASE}/kopia/cache" \
    "${STORAGE_BASE}/seafile" \
    "${STORAGE_BASE}/rustypaste"

# Set ownership
chown -R ${PUID}:${PGID} "${STORAGE_BASE}"

# Set permissions
chmod -R 755 "${STORAGE_BASE}"

echo "Storage initialization complete!"
