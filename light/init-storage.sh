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
    "${STORAGE_BASE}/syncthing/Privates/porn" \
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

################################################################################
# Swap File Setup (2GB on Cache HDD)
################################################################################
SWAP_FILE="${CACHE_BASE}/swapfile"
SWAP_SIZE="2G"

echo ""
echo "Setting up 2GB swap on cache HDD..."

# Check if swap file already exists and is the right size
if [ -f "$SWAP_FILE" ]; then
    CURRENT_SIZE=$(stat -c%s "$SWAP_FILE" 2>/dev/null || echo "0")
    EXPECTED_SIZE=$((2 * 1024 * 1024 * 1024))  # 2GB in bytes

    if [ "$CURRENT_SIZE" -eq "$EXPECTED_SIZE" ]; then
        echo "✓ Swap file already exists (2GB)"
    else
        echo "⚠ Swap file exists but wrong size, recreating..."
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE"
    fi
fi

# Create swap file if it doesn't exist
if [ ! -f "$SWAP_FILE" ]; then
    echo "Creating 2GB swap file (this may take a moment)..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=2048 2>&1 | grep -E '(copied|bytes)' || true
    chmod 600 "$SWAP_FILE"
    echo "✓ Swap file created"
fi

# Initialize as swap if not already
if ! file "$SWAP_FILE" 2>/dev/null | grep -q "swap file"; then
    echo "Initializing swap file..."
    mkswap "$SWAP_FILE"
    echo "✓ Swap file initialized"
fi

# Enable swap if not already enabled
if ! swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
    echo "Enabling swap..."
    if swapon "$SWAP_FILE" 2>/dev/null; then
        echo "✓ Swap enabled: 2GB active"
    else
        echo "⚠ Could not enable swap (may need host privileges)"
        echo "  Run on host: sudo swapon $SWAP_FILE"
    fi
else
    echo "✓ Swap already enabled"
fi

# Show swap status
echo "Current swap status:"
swapon --show 2>/dev/null || free -h | grep -i swap

# Set ownership
echo "Setting ownership to ${PUID}:${PGID}..."
chown -R ${PUID}:${PGID} "${STORAGE_BASE}"
# Set ownership but exclude swapfile (must stay root:root)
find "${CACHE_BASE}" -not -name "swapfile" -exec chown ${PUID}:${PGID} {} + 2>/dev/null || chown -R ${PUID}:${PGID} "${CACHE_BASE}"

# Set permissions
echo "Setting permissions..."
chmod -R 755 "${STORAGE_BASE}"
# Set permissions but keep swapfile at 600
find "${CACHE_BASE}" -not -name "swapfile" -exec chmod 755 {} + 2>/dev/null || true
chmod -R 755 "${CACHE_BASE}" 2>/dev/null || true
# Ensure swapfile stays 600 root:root
if [ -f "$SWAP_FILE" ]; then
    chown root:root "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
fi

# Special permissions for versioning directories
chmod 775 "${CACHE_BASE}/syncthing-versions"

echo "✓ Storage initialization complete with full OneDrive mirror!"
echo "✓ Main HDD: VPN, P2P, Syncthing (OneDrive mirror + media folders), Kopia repository"
echo "✓ Cache HDD: Incomplete downloads, Kopia cache, Syncthing file versioning, 2GB swap"
echo "✓ OneDrive folders: Desktop, Obsidian-Vault, Bilder, Dokumente, workdir, Attachments, Privates, Berufliches"
echo "✓ Swap: 2GB on cache HDD - reduces OOM errors"

################################################################################
# Generate API Keys for Homepage Widget Integration
################################################################################
echo ""
echo "Generating API keys for Homepage widgets..."

# Install openssl if not available
apk add --no-cache openssl >/dev/null 2>&1

# Generate slskd API key if not set
if [ -z "$SLSKD_API_KEY" ] || [ ! -f "/keys/slskd-api-key" ]; then
    SLSKD_API_KEY=$(openssl rand -base64 48 | tr -d '\n')
    echo "$SLSKD_API_KEY" > /keys/slskd-api-key
    echo "✓ Generated slskd API key"
else
    echo "$SLSKD_API_KEY" > /keys/slskd-api-key
    echo "✓ Using existing slskd API key from env"
fi

# Generate Syncthing API key if not set
if [ -z "$SYNCTHING_API_KEY" ] || [ ! -f "/keys/syncthing-api-key" ]; then
    SYNCTHING_API_KEY=$(openssl rand -hex 32 | tr -d '\n')
    echo "$SYNCTHING_API_KEY" > /keys/syncthing-api-key
    echo "✓ Generated Syncthing API key"
else
    echo "$SYNCTHING_API_KEY" > /keys/syncthing-api-key
    echo "✓ Using existing Syncthing API key from env"
fi

chmod 644 /keys/*
echo ""
echo "✓ API keys ready at /keys/ for all containers"
