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
mkdir -p /mnt/storage/aria2-downloads
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
mkdir -p /mnt/cachehdd/aria2-incomplete
mkdir -p /mnt/cachehdd/jellyfin-cache
mkdir -p /mnt/cachehdd/kopia-cache
mkdir -p /mnt/cachehdd/immich-ml-cache
mkdir -p /mnt/cachehdd/loki/data
mkdir -p /mnt/cachehdd/slskd/logs
mkdir -p /mnt/cachehdd/slskd-incomplete

# SSD directories (for high-I/O database and application data)
mkdir -p /mnt/ssd/docker-data/postgres
mkdir -p /mnt/ssd/docker-data/mongo
mkdir -p /mnt/ssd/docker-data/mongo-config
mkdir -p /mnt/ssd/docker-data/redis-cache
mkdir -p /mnt/ssd/docker-data/immich-postgres
mkdir -p /mnt/ssd/docker-data/gitea
mkdir -p /mnt/ssd/docker-data/n8n
mkdir -p /mnt/ssd/docker-data/paperless-data
mkdir -p /mnt/ssd/docker-data/crowdsec-db
mkdir -p /mnt/ssd/docker-data/crowdsec-config
mkdir -p /mnt/ssd/docker-data/sentry

# Paperless directories on HDD storage
mkdir -p /mnt/storage/paperless/media
mkdir -p /mnt/storage/paperless/consume
mkdir -p /mnt/storage/paperless/export
mkdir -p /mnt/storage/slskd-shared

echo "Setting permissions..."

# Set ownership to PUID:PGID (1000:1000 by default)
chown -R ${PUID:-1000}:${PGID:-1000} /mnt/storage
chown -R ${PUID:-1000}:${PGID:-1000} /mnt/cachehdd
chown -R ${PUID:-1000}:${PGID:-1000} /mnt/ssd/docker-data

echo "Storage initialization complete!"
