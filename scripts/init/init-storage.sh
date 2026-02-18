#!/bin/sh
################################################################################
# Storage Initialization Script
# Creates required directory structure for PotatoStack
# Runs once at startup via storage-init container
#
# Structure (2025 consolidated):
# - /mnt/storage: Main HDD - media, downloads, syncthing, obsidian, caches
# - /mnt/ssd/docker-data: SSD - databases, app configs, observability
# Note: cachehdd decommissioned (bad sectors) - all data moved to SSD/storage
#
# Note: All incomplete downloads moved from cachehdd to storagehdd:
#   /mnt/storage/downloads/incomplete/{sonarr,radarr,lidarr,qbittorrent,sabnzbd,aria2,slskd,pyload,pinchflat}
################################################################################

set -eu

STORAGE_BASE="/mnt/storage"
STORAGE2_BASE="/mnt/storage2"
SSD_BASE="/mnt/ssd/docker-data"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

printf '%s\n' "Initializing storage directories..."

printf '%s\n' "Note: cachehdd decommissioned (bad sectors) - all data on SSD/storage"

################################################################################
# Main Storage Directories (HDD)
################################################################################
printf '%s\n' "Creating main storage directories..."
mkdir -p \
	"${STORAGE_BASE}/syncthing" \
	"${STORAGE_BASE}/obsidian-couchdb" \
	"${STORAGE_BASE}/rustypaste/uploads" \
	"${STORAGE_BASE}/pairdrop" \
	"${STORAGE_BASE}/financial-data"

################################################################################
# Storage2 Directories (16TB HDD - media, downloads, photos, backups)
################################################################################
if [ -d "$STORAGE2_BASE" ]; then
    printf '%s\n' "Creating storage2 directories..."
    mkdir -p \
        "${STORAGE2_BASE}/media/movies" \
        "${STORAGE2_BASE}/media/tv" \
        "${STORAGE2_BASE}/media/adult/telegram" \
        "${STORAGE2_BASE}/downloads/torrents" \
        "${STORAGE2_BASE}/downloads/aria2" \
        "${STORAGE2_BASE}/downloads/slskd" \
        "${STORAGE2_BASE}/downloads/pyload" \
        "${STORAGE2_BASE}/downloads/telegram" \
        "${STORAGE2_BASE}/downloads/incomplete/qbittorrent" \
        "${STORAGE2_BASE}/downloads/incomplete/aria2" \
        "${STORAGE2_BASE}/downloads/incomplete/slskd" \
        "${STORAGE2_BASE}/downloads/incomplete/pyload" \
        "${STORAGE2_BASE}/downloads/incomplete/sonarr" \
        "${STORAGE2_BASE}/downloads/incomplete/radarr" \
        "${STORAGE2_BASE}/downloads/incomplete/pinchflat" \
        "${STORAGE2_BASE}/photos" \
        "${STORAGE2_BASE}/backrest/repos" \
        "${STORAGE2_BASE}/velld/backups"

    # Immich required markers on storage2
    mkdir -p \
        "${STORAGE2_BASE}/photos/encoded-video" \
        "${STORAGE2_BASE}/photos/library" \
        "${STORAGE2_BASE}/photos/upload" \
        "${STORAGE2_BASE}/photos/profile" \
        "${STORAGE2_BASE}/photos/thumbs" \
        "${STORAGE2_BASE}/photos/backups"
    echo "1769366147925" >"${STORAGE2_BASE}/photos/encoded-video/.immich" 2>/dev/null || true
    echo "1769366147925" >"${STORAGE2_BASE}/photos/library/.immich" 2>/dev/null || true
    echo "1769366147925" >"${STORAGE2_BASE}/photos/upload/.immich" 2>/dev/null || true
    echo "1769366147925" >"${STORAGE2_BASE}/photos/profile/.immich" 2>/dev/null || true
    echo "1769366147925" >"${STORAGE2_BASE}/photos/thumbs/.immich" 2>/dev/null || true
    echo "1769366147925" >"${STORAGE2_BASE}/photos/backups/.immich" 2>/dev/null || true

    # Only chown the specific dirs we own (not the full tree — too large)
    for d in \
        "${STORAGE2_BASE}/media" \
        "${STORAGE2_BASE}/downloads" \
        "${STORAGE2_BASE}/photos" \
        "${STORAGE2_BASE}/backrest" \
        "${STORAGE2_BASE}/velld"; do
        chown -R "${PUID}:${PGID}" "$d" 2>/dev/null || true
    done
    printf '%s\n' "✓ Storage2 directories initialized"
else
    printf '%s\n' "⚠ /mnt/storage2 not mounted, skipping storage2 init"
fi

################################################################################
# Media Directories - AUTHORITATIVE source for *arr stack and Jellyfin
################################################################################
printf '%s\n' "Creating media directories..."
mkdir -p \
	"${STORAGE_BASE}/media/music" \
	"${STORAGE_BASE}/media/audiobooks" \
	"${STORAGE_BASE}/media/podcasts" \
	"${STORAGE_BASE}/media/books" \
	"${STORAGE_BASE}/media/youtube"
# NOTE: media/movies, media/tv, media/adult are on /mnt/storage2

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
# Cache Directories (on storage HDD - moved from decommissioned cachehdd)
################################################################################
printf '%s\n' "Creating cache directories on storage..."
mkdir -p \
	"${STORAGE_BASE}/cache/jellyfin" \
	"${STORAGE_BASE}/cache/audiobookshelf/metadata" \
	"${STORAGE_BASE}/cache/immich-ml" \
	"${STORAGE_BASE}/cache/syncthing-versions"

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
	"${SSD_BASE}/backrest/data" \
	"${SSD_BASE}/backrest/config" \
	"${SSD_BASE}/backrest/cache" \
	"${SSD_BASE}/backrest/tmp" \
	"${SSD_BASE}/recyclarr" \
	"${SSD_BASE}/notifiarr" \
	"${SSD_BASE}/unpackerr" \
	"${SSD_BASE}/prometheus" \
	"${SSD_BASE}/loki" \
	"${SSD_BASE}/bitmagnet" \
	"${SSD_BASE}/slskd/logs" \
	"${SSD_BASE}/stash/cache" \
	"${SSD_BASE}/freqtrade/user_data"
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
# Swap File Setup (2GB on SSD)
################################################################################
SWAP_FILE="/mnt/ssd/system/swapfile"
SWAP_SIZE_BYTES=$((2 * 1024 * 1024 * 1024))

printf '%s\n' ""
printf '%s\n' "Setting up 2GB swap on SSD..."

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

printf '%s\n' "Setting permissions..."
for dir in "${STORAGE_BASE}"/*; do
	[ -e "$dir" ] && [ "$(basename "$dir")" != "docker" ] && chmod -R 755 "$dir" 2>/dev/null || true
done
chmod -R 755 "${SSD_BASE}" 2>/dev/null || true
chmod -R 755 "/mnt/ssd/system" 2>/dev/null || true

if [ -f "$SWAP_FILE" ]; then
	if ! swapon --show 2>/dev/null | grep -q "$SWAP_FILE" && ! grep -q "$SWAP_FILE" /proc/swaps 2>/dev/null; then
		chown root:root "$SWAP_FILE" 2>/dev/null || true
		chmod 600 "$SWAP_FILE" 2>/dev/null || true
	fi
fi

chmod 775 "${STORAGE_BASE}/cache/syncthing-versions" 2>/dev/null || true

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
[ -d "${SSD_BASE}/postgres" ] && chown -R 999:999 "${SSD_BASE}/postgres" 2>/dev/null || true
[ -d "${SSD_BASE}/postgres" ] && chmod -R 700 "${SSD_BASE}/postgres" 2>/dev/null || true

# Obsidian LiveSync CouchDB (UID 5984)
[ -d "${STORAGE_BASE}/obsidian-couchdb" ] && chown -R 5984:5984 "${STORAGE_BASE}/obsidian-couchdb" 2>/dev/null || true

# Redis (UID 999, GID 1000)
[ -d "${SSD_BASE}/redis-cache" ] && chown -R 999:1000 "${SSD_BASE}/redis-cache" 2>/dev/null || true

# Prometheus (UID 65534 - nobody)
[ -d "${SSD_BASE}/prometheus" ] && chown -R 65534:65534 "${SSD_BASE}/prometheus" 2>/dev/null || true

# Loki (UID 10001)
[ -d "${SSD_BASE}/loki" ] && chown -R 10001:10001 "${SSD_BASE}/loki" 2>/dev/null || true

# Grafana (UID 472) - ensure plugins dir exists
mkdir -p "${SSD_BASE}/grafana/plugins"
chown -R 472:472 "${SSD_BASE}/grafana" 2>/dev/null || true

# Alertmanager (UID 65534)
[ -d "${SSD_BASE}/alertmanager" ] && chown -R 65534:65534 "${SSD_BASE}/alertmanager" 2>/dev/null || true

# Homarr (UID 1000)
[ -d "${SSD_BASE}/homarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/homarr" 2>/dev/null || true

# Authentik (UID 1000)
[ -d "${SSD_BASE}/authentik" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/authentik" 2>/dev/null || true

# Code-server (UID 1000)
[ -d "${SSD_BASE}/code-server" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/code-server" 2>/dev/null || true

# Recyclarr (UID 1000) - needs PUID/PGID ownership for /config/cache
[ -d "${SSD_BASE}/recyclarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/recyclarr" 2>/dev/null || true

# Notifiarr (UID 1000) - ensure proper ownership
[ -d "${SSD_BASE}/notifiarr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/notifiarr" 2>/dev/null || true

# Unpackerr (UID 1000) - ensure proper ownership
[ -d "${SSD_BASE}/unpackerr" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/unpackerr" 2>/dev/null || true

# Bitmagnet (UID 1000) - DHT crawler
[ -d "${SSD_BASE}/bitmagnet" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/bitmagnet" 2>/dev/null || true

# Freqtrade (UID 1000) - Trading bot user data
[ -d "${SSD_BASE}/freqtrade" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/freqtrade" 2>/dev/null || true

# Uptime-Kuma (UID 1000) - DISABLED
# [ -d "${SSD_BASE}/uptime-kuma" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/uptime-kuma"

# Velld (UID 1000)
[ -d "${SSD_BASE}/velld" ] && chown -R "${PUID}:${PGID}" "${SSD_BASE}/velld" 2>/dev/null || true

# Incomplete download directories are on /mnt/storage2 (chowned in storage2 section above)

# PairDrop (UID 911 - LinuxServer.io image)
[ -d "${STORAGE_BASE}/pairdrop" ] && chown -R 911:911 "${STORAGE_BASE}/pairdrop" 2>/dev/null || true

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

################################################################################
# Backrest SSH Permissions Fix
################################################################################
printf '%s\n' ""
printf '%s\n' "Fixing backrest SSH permissions..."

BACKREST_SSH="/mnt/ssd/docker-data/backrest/ssh"
if [ -d "$BACKREST_SSH" ]; then
	chown -R root:root "$BACKREST_SSH" 2>/dev/null || true
	chmod 700 "$BACKREST_SSH" 2>/dev/null || true
	[ -f "$BACKREST_SSH/config" ] && chmod 600 "$BACKREST_SSH/config" 2>/dev/null || true
	[ -f "$BACKREST_SSH/id_ed25519" ] && chmod 600 "$BACKREST_SSH/id_ed25519" 2>/dev/null || true
	[ -f "$BACKREST_SSH/id_ed25519.pub" ] && chmod 644 "$BACKREST_SSH/id_ed25519.pub" 2>/dev/null || true
	[ -f "$BACKREST_SSH/known_hosts" ] && chmod 600 "$BACKREST_SSH/known_hosts" 2>/dev/null || true
	printf '%s\n' "✓ Backrest SSH permissions fixed"
else
	printf '%s\n' "⚠ Backrest SSH directory not found (will be created on first setup)"
fi

printf '%s\n' ""
printf '%s\n' "✓ Storage initialization complete"
printf '%s\n' ""
printf '%s\n' "Directory structure:"
printf '%s\n' "  /mnt/storage     - Main HDD (music, audiobooks, syncthing, obsidian, caches)"
printf '%s\n' "  /mnt/storage2    - 16TB HDD (media, downloads, photos, backups)"
printf '%s\n' "  /mnt/ssd         - SSD (docker-data, observability, system)"
