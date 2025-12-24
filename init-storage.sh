#!/bin/sh
################################################################################
# Storage Initialization Script
# Creates required directory structure for PotatoStack
# Runs once at startup via storage-init container
################################################################################

set -e

echo "Creating storage directories..."

# Main storage directories
mkdir -p /mnt/storage/nextcloud
mkdir -p /mnt/storage/syncthing
mkdir -p /mnt/storage/downloads
mkdir -p /mnt/storage/photos
mkdir -p /mnt/storage/projects
mkdir -p /mnt/storage/kopia/repository

# Media directories for *arr stack and Jellyfin
mkdir -p /mnt/storage/media/tv
mkdir -p /mnt/storage/media/movies
mkdir -p /mnt/storage/media/music
mkdir -p /mnt/storage/media/audiobooks
mkdir -p /mnt/storage/media/podcasts
mkdir -p /mnt/storage/media/books
mkdir -p /mnt/storage/media/youtube

# Cache HDD directories (for incomplete downloads and temp files)
mkdir -p /mnt/cachehdd/qbittorrent-incomplete
mkdir -p /mnt/cachehdd/jellyfin-cache
mkdir -p /mnt/cachehdd/kopia-cache

echo "Setting permissions..."

# Set ownership to PUID:PGID (1000:1000 by default)
chown -R ${PUID:-1000}:${PGID:-1000} /mnt/storage
chown -R ${PUID:-1000}:${PGID:-1000} /mnt/cachehdd

echo "Storage initialization complete!"
