#!/bin/sh
################################################################################
# Storage Initialization Script
# Creates required directory structure for PotatoStack
# Runs once at startup via storage-init container
#
# Structure (2025 consolidated):
# - /mnt/storage: Main HDD - media, downloads, syncthing, obsidian, mealie
# - /mnt/cachehdd: Cache HDD - organized by function (downloads, media, observability, sync, system)
# - /mnt/ssd/docker-data: SSD - databases and app configs
################################################################################

set -eu

STORAGE_BASE="/mnt/storage"
CACHE_BASE="/mnt/cachehdd"
SSD_BASE="/mnt/ssd/docker-data"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

printf '%s\n' "Initializing storage directories..."

################################################################################
# Cleanup - Remove deprecated directories
################################################################################
printf '%s\n' "Cleaning up deprecated directories..."

# DELETE: /mnt/storage/duckdb - moved to SSD
if [ -d "${STORAGE_BASE}/duckdb" ]; then
	printf '%s\n' "Moving ${STORAGE_BASE}/duckdb to ${SSD_BASE}/duckdb..."
	mkdir -p "${SSD_BASE}/duckdb"
	if [ "$(ls -A "${STORAGE_BASE}/duckdb" 2>/dev/null)" ]; then
		cp -a "${STORAGE_BASE}/duckdb"/* "${SSD_BASE}/duckdb/" 2>/dev/null || true
	fi
	rm -rf "${STORAGE_BASE}/duckdb"
fi

# Migrate old incomplete dirs to new cache structure
if [ -d "${CACHE_BASE}/qbittorrent-incomplete" ] && [ ! -d "${CACHE_BASE}/downloads/torrent" ]; then
	printf '%s\n' "Migrating qbittorrent-incomplete to new cache structure..."
	mkdir -p "${CACHE_BASE}/downloads/torrent"
	if [ "$(ls -A "${CACHE_BASE}/qbittorrent-incomplete" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/qbittorrent-incomplete"/* "${CACHE_BASE}/downloads/torrent/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/qbittorrent-incomplete"
fi

if [ -d "${CACHE_BASE}/aria2-incomplete" ] && [ ! -d "${CACHE_BASE}/downloads/aria2" ]; then
	printf '%s\n' "Migrating aria2-incomplete to new cache structure..."
	mkdir -p "${CACHE_BASE}/downloads/aria2"
	if [ "$(ls -A "${CACHE_BASE}/aria2-incomplete" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/aria2-incomplete"/* "${CACHE_BASE}/downloads/aria2/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/aria2-incomplete"
fi

if [ -d "${CACHE_BASE}/slskd-incomplete" ] && [ ! -d "${CACHE_BASE}/downloads/slskd" ]; then
	printf '%s\n' "Migrating slskd-incomplete to new cache structure..."
	mkdir -p "${CACHE_BASE}/downloads/slskd"
	if [ "$(ls -A "${CACHE_BASE}/slskd-incomplete" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/slskd-incomplete"/* "${CACHE_BASE}/downloads/slskd/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/slskd-incomplete"
fi

# if [ -d "${CACHE_BASE}/pinchflat-incomplete" ] && [ ! -d "${CACHE_BASE}/downloads/pinchflat" ]; then
# 	printf '%s\n' "Migrating pinchflat-incomplete to new cache structure..."
# 	mkdir -p "${CACHE_BASE}/downloads/pinchflat"
# 	if [ "$(ls -A "${CACHE_BASE}/pinchflat-incomplete" 2>/dev/null)" ]; then
# 		mv "${CACHE_BASE}/pinchflat-incomplete"/* "${CACHE_BASE}/downloads/pinchflat/" 2>/dev/null || true
# 	fi
# 	rm -rf "${CACHE_BASE}/pinchflat-incomplete"
# fi

# Migrate jellyfin-cache to new structure
if [ -d "${CACHE_BASE}/jellyfin-cache" ] && [ ! -d "${CACHE_BASE}/media/jellyfin" ]; then
	printf '%s\n' "Migrating jellyfin-cache to new cache structure..."
	mkdir -p "${CACHE_BASE}/media/jellyfin"
	if [ "$(ls -A "${CACHE_BASE}/jellyfin-cache" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/jellyfin-cache"/* "${CACHE_BASE}/media/jellyfin/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/jellyfin-cache"
fi

# Migrate observability dirs
if [ -d "${CACHE_BASE}/loki" ] && [ ! -d "${CACHE_BASE}/observability/loki" ]; then
	printf '%s\n' "Migrating loki to observability namespace..."
	mkdir -p "${CACHE_BASE}/observability"
	mv "${CACHE_BASE}/loki" "${CACHE_BASE}/observability/" 2>/dev/null || true
fi

if [ -d "${CACHE_BASE}/prometheus" ] && [ ! -d "${CACHE_BASE}/observability/prometheus" ]; then
	printf '%s\n' "Migrating prometheus to observability namespace..."
	mkdir -p "${CACHE_BASE}/observability"
	mv "${CACHE_BASE}/prometheus" "${CACHE_BASE}/observability/" 2>/dev/null || true
fi

if [ -d "${CACHE_BASE}/thanos" ] && [ ! -d "${CACHE_BASE}/observability/thanos" ]; then
	printf '%s\n' "Migrating thanos to observability namespace..."
	mkdir -p "${CACHE_BASE}/observability"
	mv "${CACHE_BASE}/thanos" "${CACHE_BASE}/observability/" 2>/dev/null || true
fi

if [ -d "${CACHE_BASE}/alertmanager" ] && [ ! -d "${CACHE_BASE}/observability/alertmanager" ]; then
	printf '%s\n' "Migrating alertmanager to observability namespace..."
	mkdir -p "${CACHE_BASE}/observability"
	mv "${CACHE_BASE}/alertmanager" "${CACHE_BASE}/observability/" 2>/dev/null || true
fi

# Migrate syncthing-versions
if [ -d "${CACHE_BASE}/syncthing-versions" ] && [ ! -d "${CACHE_BASE}/sync/syncthing-versions" ]; then
	printf '%s\n' "Migrating syncthing-versions to sync namespace..."
	mkdir -p "${CACHE_BASE}/sync"
	mv "${CACHE_BASE}/syncthing-versions" "${CACHE_BASE}/sync/" 2>/dev/null || true
fi

printf '%s\n' "✓ Cleanup complete"

################################################################################
# Main Storage Directories (HDD)
################################################################################
printf '%s\n' "Creating main storage directories..."
mkdir -p \
	"${STORAGE_BASE}/syncthing" \
	"${STORAGE_BASE}/obsidian-couchdb" \
	"${STORAGE_BASE}/mealie-data" \
	"${STORAGE_BASE}/downloads/torrent" \
	"${STORAGE_BASE}/downloads/pyload" \
	"${STORAGE_BASE}/projects" \
	"${STORAGE_BASE}/velld/backups" \
	"${STORAGE_BASE}/rustypaste/uploads" \
	"${STORAGE_BASE}/slskd-shared" \
	"${STORAGE_BASE}/paperless/media" \
	"${STORAGE_BASE}/paperless/consume" \
	"${STORAGE_BASE}/paperless/export" \
	"${STORAGE_BASE}/photos" \
	"${STORAGE_BASE}/backrest/repos"

# Create Immich required directories and markers
mkdir -p "${STORAGE_BASE}/photos/encoded-video"
mkdir -p "${STORAGE_BASE}/photos/library"
mkdir -p "${STORAGE_BASE}/photos/upload"
mkdir -p "${STORAGE_BASE}/photos/profile"
mkdir -p "${STORAGE_BASE}/photos/thumbs"
mkdir -p "${STORAGE_BASE}/photos/backups"
echo "1769366147925" >"${STORAGE_BASE}/photos/encoded-video/.immich" 2>/dev/null || true
echo "1769366147925" >"${STORAGE_BASE}/photos/library/.immich" 2>/dev/null || true
echo "1769366147925" >"${STORAGE_BASE}/photos/upload/.immich" 2>/dev/null || true
echo "1769366147925" >"${STORAGE_BASE}/photos/profile/.immich" 2>/dev/null || true
echo "1769366147925" >"${STORAGE_BASE}/photos/thumbs/.immich" 2>/dev/null || true
echo "1769366147925" >"${STORAGE_BASE}/photos/backups/.immich" 2>/dev/null || true

################################################################################
# Media Directories - AUTHORITATIVE source for *arr stack and Jellyfin
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
# Syncthing - INPUT/PERSONAL data (synced from devices)
################################################################################
printf '%s\n' "Creating Syncthing directories..."
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
	"${STORAGE_BASE}/syncthing/photos/2026" \
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
# Cache Directories (HDD) - Organized by function
################################################################################
printf '%s\n' "Creating cache directories with normalized namespace..."

# Downloads - incomplete/in-progress
mkdir -p \
	"${CACHE_BASE}/downloads/torrent" \
	"${CACHE_BASE}/downloads/pyload" \
	"${CACHE_BASE}/downloads/slskd"
# "${CACHE_BASE}/downloads/pinchflat"

# Media caches
mkdir -p \
	"${CACHE_BASE}/media/jellyfin" \
	"${CACHE_BASE}/media/audiobookshelf" \
	"${CACHE_BASE}/media/immich-ml"

# Observability stack
mkdir -p \
	"${CACHE_BASE}/observability/loki/data" \
	"${CACHE_BASE}/observability/loki/wal" \
	"${CACHE_BASE}/observability/prometheus" \
	"${CACHE_BASE}/observability/thanos/store" \
	"${CACHE_BASE}/observability/thanos/compact" \
	"${CACHE_BASE}/observability/alertmanager"

# Sync caches
mkdir -p \
	"${CACHE_BASE}/sync/syncthing-versions"

# System
mkdir -p \
	"${CACHE_BASE}/system"

# Misc app caches
mkdir -p \
	"${CACHE_BASE}/slskd/logs" \
	"${CACHE_BASE}/backrest/cache" \
	"${CACHE_BASE}/backrest/tmp"

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
	"${SSD_BASE}/duckdb" \
	"${SSD_BASE}/n8n" \
	"${SSD_BASE}/paperless-data" \
	"${SSD_BASE}/crowdsec-db" \
	"${SSD_BASE}/crowdsec-config" \
	"${SSD_BASE}/homarr" \
	"${SSD_BASE}/grafana" \
	"${SSD_BASE}/authentik" \
	"${SSD_BASE}/woodpecker" \
	"${SSD_BASE}/code-server" \
	"${SSD_BASE}/filebrowser" \
	"${SSD_BASE}/filestash" \
	"${SSD_BASE}/jellyseerr" \
	"${SSD_BASE}/backrest/data" \
	"${SSD_BASE}/backrest/config"

# System directory on SSD (cron, etc)
mkdir -p "/mnt/ssd/system/cron"

################################################################################
# Snapshot Schedule (Cron for Kopia)
################################################################################
CRON_DIR="/mnt/ssd/system/cron"
CRON_FILE="${CRON_DIR}/root"
SNAPSHOT_CRON_SCHEDULE="${SNAPSHOT_CRON_SCHEDULE:-0 3 * * *}"
SNAPSHOT_PATHS="${SNAPSHOT_PATHS:-/data}"
SNAPSHOT_LOG_FILE="${SNAPSHOT_LOG_FILE:-/mnt/storage/stack-snapshot.log}"

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
SWAP_FILE="${CACHE_BASE}/system/swapfile"
SWAP_SIZE_BYTES=$((2 * 1024 * 1024 * 1024))

printf '%s\n' ""
printf '%s\n' "Setting up 2GB swap on cache HDD..."

# Migrate old swap location
if [ -f "${CACHE_BASE}/swapfile" ] && [ ! -f "$SWAP_FILE" ]; then
	printf '%s\n' "Migrating swap to new location..."
	swapoff "${CACHE_BASE}/swapfile" 2>/dev/null || true
	mv "${CACHE_BASE}/swapfile" "$SWAP_FILE" 2>/dev/null || true
fi

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
elif grep -q "$SWAP_FILE" /proc/swaps 2>/dev/null; then
	printf '%s\n' "✓ Swap already active: 2GB"
else
	if [ -f "$SWAP_FILE" ] && ! file "$SWAP_FILE" 2>/dev/null | grep -q "swap"; then
		printf '%s\n' "Initializing swap file..."
		if mkswap "$SWAP_FILE" 2>/dev/null; then
			printf '%s\n' "✓ Swap file initialized"
		else
			printf '%s\n' "⚠ Swap file may already be in use, skipping mkswap"
		fi
	fi

	printf '%s\n' "Enabling swap..."
	if swapon "$SWAP_FILE" 2>/dev/null; then
		printf '%s\n' "✓ Swap enabled: 2GB active"
	else
		printf '%s\n' "⚠ Could not enable swap (may need host privileges or already active)"
		printf '%s\n' "  Run on host: sudo swapon $SWAP_FILE"
	fi
fi

printf '%s\n' "Current swap status:"
swapon --show 2>/dev/null || free -h | grep -i swap

################################################################################
# Permissions
################################################################################
printf '%s\n' "Setting ownership to ${PUID}:${PGID}..."
# Exclude docker directory (overlay2 data) from recursive operations
find "${STORAGE_BASE}" -maxdepth 1 -mindepth 1 -not -name "docker" -exec chown -R "${PUID}:${PGID}" {} + 2>/dev/null || true
chown -R "${PUID}:${PGID}" "${SSD_BASE}" 2>/dev/null || true
chown -R "${PUID}:${PGID}" "/mnt/ssd/system" 2>/dev/null || true
find "${CACHE_BASE}" -not -path "*swapfile*" -exec chown "${PUID}:${PGID}" {} + 2>/dev/null || true

printf '%s\n' "Setting permissions..."
find "${STORAGE_BASE}" -maxdepth 1 -mindepth 1 -not -name "docker" -exec chmod -R 755 {} + 2>/dev/null || true
chmod -R 755 "${SSD_BASE}" 2>/dev/null || true
chmod -R 755 "/mnt/ssd/system" 2>/dev/null || true
find "${CACHE_BASE}" -not -path "*swapfile*" -exec chmod 755 {} + 2>/dev/null || true

if [ -f "$SWAP_FILE" ]; then
	chown root:root "$SWAP_FILE"
	chmod 600 "$SWAP_FILE"
fi

chmod 775 "${CACHE_BASE}/sync/syncthing-versions"

################################################################################
# Service-specific permissions (UIDs vary by image)
################################################################################
printf '%s\n' "Setting service-specific permissions..."

# PostgreSQL (UID 999)
[ -d "${SSD_BASE}/postgres" ] && chown -R 999:999 "${SSD_BASE}/postgres" && chmod -R 700 "${SSD_BASE}/postgres"

# Obsidian LiveSync CouchDB (UID 5984)
[ -d "${STORAGE_BASE}/obsidian-couchdb" ] && chown -R 5984:5984 "${STORAGE_BASE}/obsidian-couchdb"

# Redis (UID 999, GID 1000)
[ -d "${SSD_BASE}/redis-cache" ] && chown -R 999:1000 "${SSD_BASE}/redis-cache"

# Prometheus (UID 65534 - nobody)
[ -d "${CACHE_BASE}/observability/prometheus" ] && chown -R 65534:65534 "${CACHE_BASE}/observability/prometheus"

# Thanos sidecar needs a writable subdir inside prometheus data
mkdir -p "${CACHE_BASE}/observability/prometheus/thanos"
chown -R 1001:1001 "${CACHE_BASE}/observability/prometheus/thanos"

# Loki (UID 10001)
[ -d "${CACHE_BASE}/observability/loki" ] && chown -R 10001:10001 "${CACHE_BASE}/observability/loki"

# Grafana (UID 472) - ensure plugins dir exists
mkdir -p "${SSD_BASE}/grafana/plugins"
chown -R 472:472 "${SSD_BASE}/grafana"

# Thanos (UID 1001)
[ -d "${CACHE_BASE}/observability/thanos" ] && chown -R 1001:1001 "${CACHE_BASE}/observability/thanos"

# Alertmanager (UID 65534)
[ -d "${CACHE_BASE}/observability/alertmanager" ] && chown -R 65534:65534 "${CACHE_BASE}/observability/alertmanager"

# Homarr (UID 1000)
[ -d "${SSD_BASE}/homarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/homarr"

# Authentik (UID 1000)
[ -d "${SSD_BASE}/authentik" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/authentik"

# Code-server (UID 1000)
[ -d "${SSD_BASE}/code-server" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/code-server"

printf '%s\n' "✓ Service permissions set"

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
printf '%s\n' ""
printf '%s\n' "Directory structure:"
printf '%s\n' "  /mnt/storage     - Main HDD (media, downloads, syncthing, obsidian, mealie)"
printf '%s\n' "  /mnt/cachehdd    - Cache HDD (downloads/media/observability/sync/system)"
printf '%s\n' "  /mnt/ssd         - SSD (docker-data, system)"
