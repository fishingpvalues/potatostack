#!/bin/bash
################################################################################
# Download OneDrive Content
# Download-only sync (no uploads) from OneDrive to local storage
################################################################################

set -e

SYNC_DIR="/mnt/storage/onedrive-temp"
LOG_FILE="$HOME/.config/onedrive/logs/download-$(date +%Y%m%d-%H%M%S).log"

echo "================================"
echo "OneDrive Download"
echo "================================"
echo ""

# Check if onedrive is configured
if [ ! -f "$HOME/.config/onedrive/config" ]; then
    echo "✗ OneDrive not configured"
    echo "  Run: ./setup-onedrive-sync.sh first"
    exit 1
fi

# Check if authenticated
if [ ! -f "$HOME/.config/onedrive/refresh_token" ]; then
    echo "✗ Not authenticated"
    echo "  Run: ./setup-onedrive-sync.sh to authenticate"
    exit 1
fi

echo "Sync directory: $SYNC_DIR"
echo "Log file: $LOG_FILE"
echo ""
echo "This will download ALL content from your OneDrive."
echo "Estimated time: Depends on your OneDrive size and network speed"
echo ""

# Check available space
AVAILABLE_SPACE=$(df -BG "$SYNC_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
echo "Available space: ${AVAILABLE_SPACE}GB"
echo ""

read -p "Start download? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
fi

echo ""
echo "================================"
echo "Downloading from OneDrive..."
echo "================================"
echo ""

# Download-only sync
onedrive --synchronize --download-only --verbose 2>&1 | tee "$LOG_FILE"

echo ""
echo "================================"
echo "Download Complete!"
echo "================================"
echo ""

# Show what was downloaded
echo "Downloaded content:"
ls -lh "$SYNC_DIR"

echo ""
echo "Download log: $LOG_FILE"
echo ""
echo "Directory sizes:"
du -sh "$SYNC_DIR"/* 2>/dev/null || echo "No subdirectories found"

echo ""
echo "Next step: Migrate to Syncthing folders"
echo "  Run: ./migrate-onedrive-to-syncthing.sh"
echo ""
