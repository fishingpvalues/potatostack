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
# Cleanup old directory structure
################################################################################
echo "Cleaning up old directory structure..."

# Remove old folders from storage HDD if they exist
if [ -d "${STORAGE_BASE}/slskd-incomplete" ]; then
	echo "Removing old ${STORAGE_BASE}/slskd-incomplete..."
	rm -rf "${STORAGE_BASE}/slskd-incomplete"
fi

if [ -d "${STORAGE_BASE}/transmission-incomplete" ]; then
	echo "Removing old ${STORAGE_BASE}/transmission-incomplete..."
	rm -rf "${STORAGE_BASE}/transmission-incomplete"
fi

# Remove old aria2-downloads folder (now using downloads/aria2)
if [ -d "${STORAGE_BASE}/aria2-downloads" ]; then
	echo "Moving ${STORAGE_BASE}/aria2-downloads to ${STORAGE_BASE}/downloads/aria2..."
	mkdir -p "${STORAGE_BASE}/downloads"
	if [ "$(ls -A ${STORAGE_BASE}/aria2-downloads 2>/dev/null)" ]; then
		# Move contents if folder is not empty
		mv "${STORAGE_BASE}/aria2-downloads"/* "${STORAGE_BASE}/downloads/aria2/" 2>/dev/null || true
	fi
	rm -rf "${STORAGE_BASE}/aria2-downloads"
fi

# Remove old downloads folder structure and migrate to downloads/torrent
if [ -d "${STORAGE_BASE}/downloads" ] && [ ! -d "${STORAGE_BASE}/downloads/torrent" ]; then
	echo "Migrating downloads to downloads/torrent structure..."
	mkdir -p "${STORAGE_BASE}/downloads/torrent"
	# Move any existing torrent files to the new location
	find "${STORAGE_BASE}/downloads" -maxdepth 1 -type f \( -name "*.torrent" -o -name "*.iso" -o -name "*.zip" -o -name "*.tar.*" \) -exec mv {} "${STORAGE_BASE}/downloads/torrent/" \; 2>/dev/null || true
fi

echo "✓ Cleanup complete"

################################################################################
# SOTA Directory Structure
################################################################################

# VPN & P2P Downloads (final storage)
echo "Creating VPN & P2P directories..."
mkdir -p \
	"${STORAGE_BASE}/downloads/torrent" \
	"${STORAGE_BASE}/downloads/aria2" \
	"${STORAGE_BASE}/slskd-shared" \
	"${STORAGE_BASE}/transmission-config" \
	"${STORAGE_BASE}/transmission-watch"

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
	"${CACHE_BASE}/aria2-incomplete" \
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
	EXPECTED_SIZE=$((2 * 1024 * 1024 * 1024)) # 2GB in bytes

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
	# Use fallocate if available (fast, low memory), otherwise dd with small blocks
	if command -v fallocate >/dev/null 2>&1; then
		fallocate -l 2G "$SWAP_FILE" 2>&1
	else
		# Use small block size to avoid OOM
		dd if=/dev/zero of="$SWAP_FILE" bs=1024 count=2097152 2>&1 | tail -1 || true
	fi
	chmod 600 "$SWAP_FILE"
	echo "✓ Swap file created"
fi

# Check if swap is already enabled
if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
	echo "✓ Swap already enabled: 2GB active"
else
	# Initialize as swap if not already
	if ! file "$SWAP_FILE" 2>/dev/null | grep -q "swap file"; then
		echo "Initializing swap file..."
		mkswap "$SWAP_FILE"
		echo "✓ Swap file initialized"
	fi

	# Enable swap
	echo "Enabling swap..."
	if swapon "$SWAP_FILE" 2>/dev/null; then
		echo "✓ Swap enabled: 2GB active"
	else
		echo "⚠ Could not enable swap (may need host privileges)"
		echo "  Run on host: sudo swapon $SWAP_FILE"
	fi
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

# Generate random key using /dev/urandom (no openssl needed)
generate_key() {
	# Generate 48 bytes from /dev/urandom, encode as base64
	head -c 48 /dev/urandom | base64 | tr -d '\n='
}

generate_hex_key() {
	# Generate 32 bytes from /dev/urandom, encode as hex
	head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"' | tr -d '\n'
}

# Generate slskd API key if not set
if [ -f "/keys/slskd-api-key" ]; then
	echo "✓ Using existing slskd API key from volume"
elif [ -n "$SLSKD_API_KEY" ]; then
	echo "$SLSKD_API_KEY" >/keys/slskd-api-key
	echo "✓ Using existing slskd API key from env"
else
	SLSKD_API_KEY=$(generate_key)
	echo "$SLSKD_API_KEY" >/keys/slskd-api-key
	echo "✓ Generated slskd API key"
fi

# Generate Syncthing API key if not set
if [ -f "/keys/syncthing-api-key" ]; then
	echo "✓ Using existing Syncthing API key from volume"
elif [ -n "$SYNCTHING_API_KEY" ]; then
	echo "$SYNCTHING_API_KEY" >/keys/syncthing-api-key
	echo "✓ Using existing Syncthing API key from env"
else
	SYNCTHING_API_KEY=$(generate_hex_key)
	echo "$SYNCTHING_API_KEY" >/keys/syncthing-api-key
	echo "✓ Generated Syncthing API key"
fi

# Generate Aria2 RPC secret if not set (use hex for URL-safe secret)
if [ -f "/keys/aria2-rpc-secret" ]; then
	echo "✓ Using existing Aria2 RPC secret from volume"
elif [ -n "$ARIA2_RPC_SECRET" ]; then
	echo "$ARIA2_RPC_SECRET" >/keys/aria2-rpc-secret
	echo "✓ Using existing Aria2 RPC secret from env"
else
	ARIA2_RPC_SECRET=$(generate_hex_key)
	echo "$ARIA2_RPC_SECRET" >/keys/aria2-rpc-secret
	echo "✓ Generated Aria2 RPC secret"
fi

chmod 644 /keys/*
echo ""
echo "✓ API keys ready at /keys/ for all containers"
