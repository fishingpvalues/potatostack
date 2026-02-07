#!/bin/sh
################################################################################
# Storage Initialization Script
# Creates required directory structure for PotatoStack
# Runs once at startup via storage-init container
#
# Structure (2025 consolidated):
# - /mnt/storage: Main HDD - media, downloads (complete + incomplete), syncthing, obsidian
# - /mnt/cachehdd: Cache HDD - organized by function (media caches, observability, sync, system)
# - /mnt/ssd/docker-data: SSD - databases and app configs
#
# Note: All incomplete downloads moved from cachehdd to storagehdd:
#   /mnt/storage/downloads/incomplete/{sonarr,radarr,lidarr,qbittorrent,sabnzbd,aria2,slskd,pyload,pinchflat}
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

# Migrate incomplete dirs from cachehdd to storagehdd (service-specific subdirs)
printf '%s\n' "Migrating incomplete download directories from cachehdd to storagehdd..."

# Migrate torrent downloads to service-specific directories
if [ -d "${CACHE_BASE}/downloads/torrent" ]; then
	printf '%s\n' "Migrating torrent downloads to service-specific storage directories..."
	# Migrate to sonarr
	mkdir -p "${STORAGE_BASE}/downloads/incomplete/sonarr"
	if [ "$(ls -A "${CACHE_BASE}/downloads/torrent" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/downloads/torrent"/* "${STORAGE_BASE}/downloads/incomplete/sonarr/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/downloads/torrent"
fi

# Migrate aria2 incomplete
if [ -d "${CACHE_BASE}/downloads/aria2" ]; then
	printf '%s\n' "Migrating aria2 incomplete downloads to storage..."
	mkdir -p "${STORAGE_BASE}/downloads/incomplete/aria2"
	if [ "$(ls -A "${CACHE_BASE}/downloads/aria2" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/downloads/aria2"/* "${STORAGE_BASE}/downloads/incomplete/aria2/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/downloads/aria2"
fi

# Migrate slskd incomplete
if [ -d "${CACHE_BASE}/downloads/slskd" ]; then
	printf '%s\n' "Migrating slskd incomplete downloads to storage..."
	mkdir -p "${STORAGE_BASE}/downloads/incomplete/slskd"
	if [ "$(ls -A "${CACHE_BASE}/downloads/slskd" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/downloads/slskd"/* "${STORAGE_BASE}/downloads/incomplete/slskd/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/downloads/slskd"
fi

# Migrate usenet incomplete
if [ -d "${CACHE_BASE}/downloads/usenet" ]; then
	printf '%s\n' "Migrating usenet incomplete downloads to storage..."
	mkdir -p "${STORAGE_BASE}/downloads/incomplete/sabnzbd"
	if [ "$(ls -A "${CACHE_BASE}/downloads/usenet" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/downloads/usenet"/* "${STORAGE_BASE}/downloads/incomplete/sabnzbd/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/downloads/usenet"
fi

# Migrate pyload incomplete
if [ -d "${CACHE_BASE}/downloads/pyload" ]; then
	printf '%s\n' "Migrating pyload incomplete downloads to storage..."
	mkdir -p "${STORAGE_BASE}/downloads/incomplete/pyload"
	if [ "$(ls -A "${CACHE_BASE}/downloads/pyload" 2>/dev/null)" ]; then
		mv "${CACHE_BASE}/downloads/pyload"/* "${STORAGE_BASE}/downloads/incomplete/pyload/" 2>/dev/null || true
	fi
	rm -rf "${CACHE_BASE}/downloads/pyload"
fi

# Clean up old legacy directories if they still exist
if [ -d "${CACHE_BASE}/qbittorrent-incomplete" ]; then
	printf '%s\n' "Removing legacy qbittorrent-incomplete directory..."
	rm -rf "${CACHE_BASE}/qbittorrent-incomplete"
fi

if [ -d "${CACHE_BASE}/aria2-incomplete" ]; then
	printf '%s\n' "Removing legacy aria2-incomplete directory..."
	rm -rf "${CACHE_BASE}/aria2-incomplete"
fi

if [ -d "${CACHE_BASE}/slskd-incomplete" ]; then
	printf '%s\n' "Removing legacy slskd-incomplete directory..."
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
	"${STORAGE_BASE}/downloads/torrent" \
	"${STORAGE_BASE}/downloads/incomplete" \
	"${STORAGE_BASE}/downloads/pyload" \
	"${STORAGE_BASE}/velld/backups" \
	"${STORAGE_BASE}/rustypaste/uploads" \
	"${STORAGE_BASE}/downloads/slskd" \
	"${STORAGE_BASE}/downloads/rdt-client" \
	"${STORAGE_BASE}/photos" \
	"${STORAGE_BASE}/backrest/repos"

################################################################################
# Service-Specific Incomplete Download Directories (moved from cachehdd)
################################################################################
printf '%s\n' "Creating service-specific incomplete download directories..."
mkdir -p \
	"${STORAGE_BASE}/downloads/incomplete/sonarr" \
	"${STORAGE_BASE}/downloads/incomplete/radarr" \
	"${STORAGE_BASE}/downloads/incomplete/lidarr" \
	"${STORAGE_BASE}/downloads/incomplete/qbittorrent" \
	"${STORAGE_BASE}/downloads/incomplete/sabnzbd" \
	"${STORAGE_BASE}/downloads/incomplete/aria2" \
	"${STORAGE_BASE}/downloads/incomplete/slskd" \
	"${STORAGE_BASE}/downloads/incomplete/pyload" \
	"${STORAGE_BASE}/downloads/incomplete/pinchflat"

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

# Note: All incomplete downloads moved to storagehdd: /mnt/storage/downloads/incomplete/<service>
# Downloads cache directories removed - now handled in storage section

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
	"${CACHE_BASE}/backrest/tmp" \
	"${CACHE_BASE}/bitmagnet"

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
	"${SSD_BASE}/paperless-data" \
	"${SSD_BASE}/crowdsec-db" \
	"${SSD_BASE}/pairdrop" \
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
	"${SSD_BASE}/backrest/config" \
	"${SSD_BASE}/recyclarr" \
	"${SSD_BASE}/notifiarr"
# "${SSD_BASE}/uptime-kuma" # DISABLED

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
################################################################################
# Home Assistant - Ensure http config for Tailscale access
################################################################################
printf '%s\n' "Configuring Home Assistant http settings..."
HA_CONFIG="${SSD_BASE}/home-assistant/configuration.yaml"
if [ -f "$HA_CONFIG" ]; then
	if ! grep -q "^http:" "$HA_CONFIG"; then
		cat >>"$HA_CONFIG" <<HAEOF

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - 100.64.0.0/10
  server_host: 127.0.0.1
HAEOF
		printf '%s\n' "✓ Home Assistant http config added"
	else
		printf '%s\n' "✓ Home Assistant http config already exists"
	fi
fi

# Exclude docker directory (overlay2 data) from recursive operations
# Check if ownership is already correct before running chown
set_ownership() {
	target="$1"
	if [ -d "$target" ]; then
		current_owner=$(stat -c "%u:%g" "$target" 2>/dev/null || echo "0:0")
		if [ "$current_owner" != "${PUID}:${PGID}" ]; then
			chown -R "${PUID}:${PGID}" "$target" 2>/dev/null || true
		fi
	fi
}

for dir in "${STORAGE_BASE}"/*; do
	[ -e "$dir" ] && [ "$(basename "$dir")" != "docker" ] && set_ownership "$dir"
done
set_ownership "${SSD_BASE}"
set_ownership "/mnt/ssd/system"

for item in "${CACHE_BASE}"/*; do
	[ -e "$item" ] && [ "$(basename "$item")" != "swapfile" ] && chown "${PUID}:${PGID}" "$item" 2>/dev/null || true
done

printf '%s\n' "Setting permissions..."
for dir in "${STORAGE_BASE}"/*; do
	[ -e "$dir" ] && [ "$(basename "$dir")" != "docker" ] && chmod -R 755 "$dir" 2>/dev/null || true
done
chmod -R 755 "${SSD_BASE}" 2>/dev/null || true
chmod -R 755 "/mnt/ssd/system" 2>/dev/null || true
for item in "${CACHE_BASE}"/*; do
	[ -e "$item" ] && [ "$(basename "$item")" != "swapfile" ] && chmod 755 "$item" 2>/dev/null || true
done

if [ -f "$SWAP_FILE" ]; then
	chown root:root "$SWAP_FILE"
	chmod 600 "$SWAP_FILE"
fi

chmod 775 "${CACHE_BASE}/sync/syncthing-versions"

################################################################################
# Fix Gluetun post-rules.txt directory issue
################################################################################
printf '%s\n' "Fixing gluetun post-rules.txt..."

# Ensure /compose/config/gluetun/post-rules.txt is a file, not a directory
GLUETUN_COMPOSE_CONFIG="/compose/config/gluetun"
GLUETUN_PROJECT_CONFIG="/home/daniel/potatostack/config/gluetun"

# Fix in /compose/config/gluetun if it exists as a directory
if [ -d "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt" ]; then
	printf '%s\n' "  Removing directory ${GLUETUN_COMPOSE_CONFIG}/post-rules.txt"
	rm -rf "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt"
fi

# Copy from project config if exists
if [ -f "${GLUETUN_PROJECT_CONFIG}/post-rules.txt" ]; then
	mkdir -p "${GLUETUN_COMPOSE_CONFIG}"
	cp "${GLUETUN_PROJECT_CONFIG}/post-rules.txt" "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt"
	printf '%s\n' "  ✓ Copied post-rules.txt from project config"
fi

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

# Loki (UID 10001)
[ -d "${CACHE_BASE}/observability/loki" ] && chown -R 10001:10001 "${CACHE_BASE}/observability/loki"

# Grafana (UID 472) - ensure plugins dir exists
mkdir -p "${SSD_BASE}/grafana/plugins"
chown -R 472:472 "${SSD_BASE}/grafana"

# Alertmanager (UID 65534)
[ -d "${CACHE_BASE}/observability/alertmanager" ] && chown -R 65534:65534 "${CACHE_BASE}/observability/alertmanager"

# Homarr (UID 1000)
[ -d "${SSD_BASE}/homarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/homarr"

# Authentik (UID 1000)
[ -d "${SSD_BASE}/authentik" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/authentik"

# Code-server (UID 1000)
[ -d "${SSD_BASE}/code-server" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/code-server"

# Recyclarr (UID 1000) - needs PUID/PGID ownership for /config/cache
[ -d "${SSD_BASE}/recyclarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/recyclarr"

# Notifiarr (UID 1000) - ensure proper ownership
[ -d "${SSD_BASE}/notifiarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/notifiarr"

# Bitmagnet (UID 1000) - DHT crawler (on cachehdd due to large DB growth)
[ -d "${CACHE_BASE}/bitmagnet" ] && chown -R "${PUID}:${PGID}" "${CACHE_BASE}/bitmagnet"

# Uptime-Kuma (UID 1000) - DISABLED
# [ -d "${SSD_BASE}/uptime-kuma" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/uptime-kuma"

# Velld (UID 1000)
[ -d "${SSD_BASE}/velld" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/velld"

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
printf '%s\n' "  /mnt/storage     - Main HDD (media, downloads, syncthing, obsidian)"
printf '%s\n' "  /mnt/cachehdd    - Cache HDD (downloads/media/observability/sync/system)"
printf '%s\n' "  /mnt/ssd         - SSD (docker-data, system)"
