#!/bin/bash
################################################################################
# PotatoStack Light - Directory Setup Script
# Creates required directory structure on mounted HDDs
################################################################################

set -e

echo "🥔 PotatoStack Light - Setting up directories..."
echo ""

# Check if drives are mounted
if [ ! -d "/mnt/seconddrive" ]; then
    echo "❌ ERROR: /mnt/seconddrive not found!"
    echo "   Please mount your 14TB drive to /mnt/seconddrive"
    exit 1
fi

if [ ! -d "/mnt/cachehdd" ]; then
    echo "❌ ERROR: /mnt/cachehdd not found!"
    echo "   Please mount your 500GB drive to /mnt/cachehdd"
    exit 1
fi

echo "✅ Drives detected:"
echo "   - /mnt/seconddrive ($(df -h /mnt/seconddrive | tail -1 | awk '{print $2}'))"
echo "   - /mnt/cachehdd ($(df -h /mnt/cachehdd | tail -1 | awk '{print $2}'))"
echo ""

# Create directories on main drive (14TB)
echo "📁 Creating directories on /mnt/seconddrive..."
sudo mkdir -p /mnt/seconddrive/downloads
sudo mkdir -p /mnt/seconddrive/slskd-shared
sudo mkdir -p /mnt/seconddrive/immich/upload
sudo mkdir -p /mnt/seconddrive/immich/library
sudo mkdir -p /mnt/seconddrive/seafile
sudo mkdir -p /mnt/seconddrive/kopia/repository

# Create directories on cache drive (500GB)
echo "📁 Creating directories on /mnt/cachehdd..."
sudo mkdir -p /mnt/cachehdd/transmission-incomplete
sudo mkdir -p /mnt/cachehdd/slskd-incomplete
sudo mkdir -p /mnt/cachehdd/immich/thumbs
sudo mkdir -p /mnt/cachehdd/kopia/cache
sudo mkdir -p /mnt/cachehdd/rustypaste

# Set ownership (PUID/PGID 1000)
echo "🔐 Setting ownership to 1000:1000..."
sudo chown -R 1000:1000 /mnt/seconddrive
sudo chown -R 1000:1000 /mnt/cachehdd

echo ""
echo "✅ Directory structure created successfully!"
echo ""
echo "Storage layout:"
echo ""
echo "📦 /mnt/seconddrive (Main Storage - 14TB):"
echo "   ├── downloads          (Transmission completed)"
echo "   ├── slskd-shared       (Soulseek shared files)"
echo "   ├── immich/upload      (Photo uploads)"
echo "   ├── immich/library     (Photo library)"
echo "   ├── seafile            (File sync & share)"
echo "   └── kopia/repository   (Backup repository)"
echo ""
echo "⚡ /mnt/cachehdd (Cache Storage - 500GB):"
echo "   ├── transmission-incomplete  (Transmission temp)"
echo "   ├── slskd-incomplete         (Soulseek temp)"
echo "   ├── immich/thumbs            (Photo thumbnails)"
echo "   ├── kopia/cache              (Backup cache)"
echo "   └── rustypaste               (Pastebin uploads)"
echo ""
echo "🚀 Ready to start: docker compose up -d"
