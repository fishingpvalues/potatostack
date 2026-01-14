#!/bin/sh
################################################################################
# Storage Initialization Script
# Creates required directory structure for PotatoStack
# Runs once at startup via storage-init container
################################################################################

# shellcheck disable=SC3040
set -euo pipefail

STORAGE_BASE="/mnt/storage"
CACHE_BASE="/mnt/cachehdd"
SSD_BASE="/mnt/ssd/docker-data"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

printf '%s\n' "Initializing storage directories..."

################################################################################
# Cleanup old directory structure
################################################################################
printf '%s\n' "Cleaning up old directory structure..."

if [ -d "${STORAGE_BASE}/slskd-incomplete" ]; then
	printf '%s\n' "Removing old ${STORAGE_BASE}/slskd-incomplete..."
	rm -rf "${STORAGE_BASE}/slskd-incomplete"
fi

if [ -d "${STORAGE_BASE}/transmission-incomplete" ]; then
	printf '%s\n' "Removing old ${STORAGE_BASE}/transmission-incomplete..."
	rm -rf "${STORAGE_BASE}/transmission-incomplete"
fi

if [ -d "${STORAGE_BASE}/aria2-downloads" ]; then
	printf '%s\n' "Moving ${STORAGE_BASE}/aria2-downloads to ${STORAGE_BASE}/downloads/aria2..."
	mkdir -p "${STORAGE_BASE}/downloads/aria2"
	if [ "$(ls -A "${STORAGE_BASE}/aria2-downloads" 2>/dev/null)" ]; then
		mv "${STORAGE_BASE}/aria2-downloads"/* "${STORAGE_BASE}/downloads/aria2/" 2>/dev/null || true
	fi
	rm -rf "${STORAGE_BASE}/aria2-downloads"
fi

if [ -d "${STORAGE_BASE}/downloads" ] && [ ! -d "${STORAGE_BASE}/downloads/torrent" ]; then
	printf '%s\n' "Migrating downloads to downloads/torrent structure..."
	mkdir -p "${STORAGE_BASE}/downloads/torrent"
	find "${STORAGE_BASE}/downloads" -maxdepth 1 -type f \
		\( -name "*.torrent" -o -name "*.iso" -o -name "*.zip" -o -name "*.tar.*" \) \
		-exec mv {} "${STORAGE_BASE}/downloads/torrent/" \; 2>/dev/null || true
fi

printf '%s\n' "✓ Cleanup complete"

################################################################################
# Main Storage Directories
################################################################################
printf '%s\n' "Creating main storage directories..."
mkdir -p \
	"${STORAGE_BASE}/nextcloud" \
	"${STORAGE_BASE}/syncthing" \
	"${STORAGE_BASE}/downloads/torrent" \
	"${STORAGE_BASE}/downloads/aria2" \
	"${STORAGE_BASE}/duckdb" \
	"${STORAGE_BASE}/photos" \
	"${STORAGE_BASE}/projects" \
	"${STORAGE_BASE}/kopia/repository" \
	"${STORAGE_BASE}/velld/backups" \
	"${STORAGE_BASE}/rustypaste/uploads" \
	"${STORAGE_BASE}/slskd-shared" \
	"${STORAGE_BASE}/paperless/media" \
	"${STORAGE_BASE}/paperless/consume" \
	"${STORAGE_BASE}/paperless/export"

################################################################################
# Media Directories for *arr stack and Jellyfin
################################################################################
printf '%s\n' "Creating media directories..."
mkdir -p \
	"${STORAGE_BASE}/media/tv" \
	"${STORAGE_BASE}/media/movies" \
	"${STORAGE_BASE}/media/music" \
	"${STORAGE_BASE}/media/audiobooks" \
	"${STORAGE_BASE}/media/podcasts" \
	"${STORAGE_BASE}/media/books" \
	"${STORAGE_BASE}/media/youtube"

################################################################################
# Syncthing OneDrive Mirror Structure
################################################################################
printf '%s\n' "Creating Syncthing OneDrive mirror directories..."
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
	"${STORAGE_BASE}/syncthing/backup" \
	"${STORAGE_BASE}/syncthing/OneDrive-Archive"

################################################################################
# Cache Directories (High I/O)
################################################################################
printf '%s\n' "Creating cache directories..."
mkdir -p \
	"${CACHE_BASE}/qbittorrent-incomplete" \
	"${CACHE_BASE}/aria2-incomplete" \
	"${CACHE_BASE}/jellyfin-cache" \
	"${CACHE_BASE}/kopia-cache" \
	"${CACHE_BASE}/immich-ml-cache" \
	"${CACHE_BASE}/loki/data" \
	"${CACHE_BASE}/slskd/logs" \
	"${CACHE_BASE}/slskd-incomplete" \
	"${CACHE_BASE}/syncthing-versions" \
	"${CACHE_BASE}/transmission-incomplete"

################################################################################
# SSD Directories (Databases and App Data)
################################################################################
printf '%s\n' "Creating SSD directories..."
mkdir -p \
	"${SSD_BASE}/postgres" \
	"${SSD_BASE}/mongo" \
	"${SSD_BASE}/mongo-config" \
	"${SSD_BASE}/redis-cache" \
	"${SSD_BASE}/gitea" \
	"${SSD_BASE}/velld" \
	"${SSD_BASE}/parseable" \
	"${SSD_BASE}/scrutiny/config" \
	"${SSD_BASE}/scrutiny/influxdb" \
	"${SSD_BASE}/wireguard" \
	"${SSD_BASE}/cron" \
	"${SSD_BASE}/n8n" \
	"${SSD_BASE}/paperless-data" \
	"${SSD_BASE}/crowdsec-db" \
	"${SSD_BASE}/crowdsec-config" \
	"${SSD_BASE}/sentry"

################################################################################
# Snapshot Schedule (Cron for Kopia)
################################################################################
CRON_DIR="${SSD_BASE}/cron"
CRON_FILE="${CRON_DIR}/root"
SNAPSHOT_CRON_SCHEDULE="${SNAPSHOT_CRON_SCHEDULE:-0 3 * * *}"
SNAPSHOT_PATHS="${SNAPSHOT_PATHS:-/data}"
SNAPSHOT_LOG_FILE="${SNAPSHOT_LOG_FILE:-/mnt/storage/kopia/stack-snapshot.log}"

printf '%s\n' "Configuring snapshot cron schedule..."
if [ ! -f "${CRON_FILE}" ]; then
	mkdir -p "${CRON_DIR}"
	cat >"${CRON_FILE}" <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
${SNAPSHOT_CRON_SCHEDULE} SNAPSHOT_PATHS="${SNAPSHOT_PATHS}" SNAPSHOT_LOG_FILE="${SNAPSHOT_LOG_FILE}" /stack-snapshot.sh
EOF
	printf '%s\n' "✓ Snapshot cron created: ${SNAPSHOT_CRON_SCHEDULE}"
else
	printf '%s\n' "✓ Snapshot cron already exists: ${CRON_FILE}"
fi

################################################################################
# Swap File Setup (2GB on Cache HDD)
################################################################################
SWAP_FILE="${CACHE_BASE}/swapfile"
SWAP_SIZE_BYTES=$((2 * 1024 * 1024 * 1024))

printf '%s\n' ""
printf '%s\n' "Setting up 2GB swap on cache HDD..."

if [ -f "$SWAP_FILE" ]; then
	CURRENT_SIZE=$(stat -c%s "$SWAP_FILE" 2>/dev/null || echo "0")
	if [ "$CURRENT_SIZE" -ne "$SWAP_SIZE_BYTES" ]; then
		printf '%s\n' "Swap file exists but wrong size, recreating..."
		swapoff "$SWAP_FILE" 2>/dev/null || true
		rm -f "$SWAP_FILE"
	fi
fi

if [ ! -f "$SWAP_FILE" ]; then
	printf '%s\n' "Creating 2GB swap file (this may take a moment)..."
	if command -v fallocate >/dev/null 2>&1; then
		fallocate -l 2G "$SWAP_FILE" 2>&1
	else
		dd if=/dev/zero of="$SWAP_FILE" bs=1024 count=2097152 2>&1 | tail -1 || true
	fi
	chmod 600 "$SWAP_FILE"
	printf '%s\n' "✓ Swap file created"
fi

if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
	printf '%s\n' "✓ Swap already enabled: 2GB active"
else
	if ! file "$SWAP_FILE" 2>/dev/null | grep -q "swap file"; then
		printf '%s\n' "Initializing swap file..."
		mkswap "$SWAP_FILE"
		printf '%s\n' "✓ Swap file initialized"
	fi

	printf '%s\n' "Enabling swap..."
	if swapon "$SWAP_FILE" 2>/dev/null; then
		printf '%s\n' "✓ Swap enabled: 2GB active"
	else
		printf '%s\n' "⚠ Could not enable swap (may need host privileges)"
		printf '%s\n' "  Run on host: sudo swapon $SWAP_FILE"
	fi
fi

printf '%s\n' "Current swap status:"
swapon --show 2>/dev/null || free -h | grep -i swap

################################################################################
# Permissions
################################################################################
printf '%s\n' "Setting ownership to ${PUID}:${PGID}..."
chown -R "${PUID}:${PGID}" "${STORAGE_BASE}"
chown -R "${PUID}:${PGID}" "${SSD_BASE}"
find "${CACHE_BASE}" -not -name "swapfile" -exec chown "${PUID}:${PGID}" {} + 2>/dev/null || true

printf '%s\n' "Setting permissions..."
chmod -R 755 "${STORAGE_BASE}"
chmod -R 755 "${SSD_BASE}"
find "${CACHE_BASE}" -not -name "swapfile" -exec chmod 755 {} + 2>/dev/null || true

if [ -f "$SWAP_FILE" ]; then
	chown root:root "$SWAP_FILE"
	chmod 600 "$SWAP_FILE"
fi

chmod 775 "${CACHE_BASE}/syncthing-versions"

################################################################################
# Generate API Keys for Shared Services
################################################################################
printf '%s\n' ""
printf '%s\n' "Generating API keys for shared services..."

mkdir -p /keys

generate_key() {
	head -c 48 /dev/urandom | base64 | tr -d '\n='
}

generate_hex_key() {
	head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"' | tr -d '\n'
}

SLSKD_API_KEY="${SLSKD_API_KEY:-}"
SYNCTHING_API_KEY="${SYNCTHING_API_KEY:-}"
ARIA2_RPC_SECRET="${ARIA2_RPC_SECRET:-}"

if [ -f "/keys/slskd-api-key" ]; then
	printf '%s\n' "✓ Using existing slskd API key from volume"
elif [ -n "$SLSKD_API_KEY" ]; then
	echo "$SLSKD_API_KEY" >/keys/slskd-api-key
	printf '%s\n' "✓ Using existing slskd API key from env"
else
	SLSKD_API_KEY=$(generate_key)
	echo "$SLSKD_API_KEY" >/keys/slskd-api-key
	printf '%s\n' "✓ Generated slskd API key"
fi

if [ -f "/keys/syncthing-api-key" ]; then
	printf '%s\n' "✓ Using existing Syncthing API key from volume"
elif [ -n "$SYNCTHING_API_KEY" ]; then
	echo "$SYNCTHING_API_KEY" >/keys/syncthing-api-key
	printf '%s\n' "✓ Using existing Syncthing API key from env"
else
	SYNCTHING_API_KEY=$(generate_hex_key)
	echo "$SYNCTHING_API_KEY" >/keys/syncthing-api-key
	printf '%s\n' "✓ Generated Syncthing API key"
fi

if [ -f "/keys/aria2-rpc-secret" ]; then
	printf '%s\n' "✓ Using existing Aria2 RPC secret from volume"
elif [ -n "$ARIA2_RPC_SECRET" ]; then
	echo "$ARIA2_RPC_SECRET" >/keys/aria2-rpc-secret
	printf '%s\n' "✓ Using existing Aria2 RPC secret from env"
else
	ARIA2_RPC_SECRET=$(generate_hex_key)
	echo "$ARIA2_RPC_SECRET" >/keys/aria2-rpc-secret
	printf '%s\n' "✓ Generated Aria2 RPC secret"
fi

chmod 644 /keys/*

printf '%s\n' ""
printf '%s\n' "✓ Storage initialization complete"
printf '%s\n' "✓ Main HDD: downloads, syncthing mirror, kopia repository, rustypaste, paperless"
printf '%s\n' "✓ Cache HDD: incomplete downloads, kopia cache, syncthing versions, 2GB swap"
printf '%s\n' "✓ SSD: databases and high-I/O app data"
