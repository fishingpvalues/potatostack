#!/bin/bash
################################################################################
# qBittorrent SOTA Init Script (2026 Mini PC Optimized)
# Target: Intel N250 4-core, 16GB system → 5+ parallel downloads
# Expected RAM: 600-900MB RSS under load
################################################################################

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Fix permissions on incomplete directory
if [ -d "/incomplete" ]; then
	current_owner=$(stat -c "%u:%g" "/incomplete" 2>/dev/null || echo "0:0")
	if [ "$current_owner" != "${PUID}:${PGID}" ]; then
		chown -R "${PUID}:${PGID}" "/incomplete" 2>/dev/null || true
	fi
	chmod -R 755 "/incomplete" 2>/dev/null || true
fi

CONFIG_DIR="/config/qBittorrent"
CONFIG_FILE="${CONFIG_DIR}/qBittorrent.conf"
QB_USER="${QBITTORRENT_USER:-daniel}"
QB_PASSWORD="${QBITTORRENT_PASSWORD:-}"

mkdir -p "$CONFIG_DIR"

set_config() {
	local section="$1"
	local key="$2"
	local value="$3"
	if grep -q "^\[${section}\]" "$CONFIG_FILE" 2>/dev/null; then
		if grep -q "^${key}=" "$CONFIG_FILE"; then
			sed -i "s|^${key}=.*|${key}=${value}|g" "$CONFIG_FILE"
		else
			sed -i "/^\[${section}\]/a ${key}=${value}" "$CONFIG_FILE"
		fi
	else
		echo -e "\n[${section}]\n${key}=${value}" >>"$CONFIG_FILE"
	fi
}

generate_password_hash() {
	local password="$1"
	local python_bin=$(command -v python3 || command -v python)
	if [ -z "$python_bin" ] && command -v apk >/dev/null; then
		apk add --no-cache python3 >/dev/null 2>&1 && python_bin="python3"
	fi
	[ -z "$python_bin" ] && return 1

	"$python_bin" -c '
import base64, hashlib, os, sys
pw = sys.argv[1].encode()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", pw, salt, 100000, dklen=64)
print(base64.b64encode(salt).decode() + ":" + base64.b64encode(dk).decode())
' "$password"
}

# Create minimal config if missing
if [ ! -f "$CONFIG_FILE" ]; then
	cat >"$CONFIG_FILE" <<'EOF'
[LegalNotice]
Accepted=true
[Preferences]
WebUI\Port=8282
WebUI\LocalHostAuth=false
[BitTorrent]
Session\DefaultSavePath=/downloads
Session\TempPath=/incomplete
Session\TempPathEnabled=true
EOF
fi

# WebUI & auth
set_config "Preferences" "WebUI\\\\LocalHostAuth" "false"
set_config "Preferences" "WebUI\\\\Address" "*"
set_config "Preferences" "WebUI\\\\Port" "8282"
set_config "Preferences" "WebUI\\\\ServerDomains" "*"
set_config "Preferences" "WebUI\\\\Username" "${QB_USER}"

if [ -n "$QB_PASSWORD" ]; then
	HASH=$(generate_password_hash "$QB_PASSWORD")
	if [ -n "$HASH" ]; then
		set_config "Preferences" "WebUI\\\\Password_PBKDF2" "\"@ByteArray(${HASH})\""
	fi
fi

# === QUEUEING — 5 parallel downloads target ===
set_config "BitTorrent" "Session\\\\MaxActiveTorrents" "25"  # Total active (DL + UL)
set_config "BitTorrent" "Session\\\\MaxActiveDownloads" "8"  # Allow bursting above 5
set_config "BitTorrent" "Session\\\\MaxActiveUploads" "12"   # More seeding slots

# Connections (N250 4-core can handle this)
set_config "BitTorrent" "Session\\\\MaxConnections" "400"
set_config "BitTorrent" "Session\\\\MaxConnectionsPerTorrent" "80"
set_config "BitTorrent" "Session\\\\MaxUploads" "40"
set_config "BitTorrent" "Session\\\\MaxUploadsPerTorrent" "8"

# Disk cache & I/O — tuned for 5+ concurrent HDD writers
set_config "BitTorrent" "Session\\\\DiskCacheSize" "128"        # 128MB — prevents I/O stalls with 5 torrents
set_config "BitTorrent" "Session\\\\AsyncIOThreads" "4"         # Match N250 core count
set_config "BitTorrent" "Session\\\\UseMemoryMapping" "true"
set_config "BitTorrent" "Session\\\\CoalesceReadWrite" "true"
set_config "BitTorrent" "Session\\\\PieceExtentAffinity" "true"
set_config "BitTorrent" "Session\\\\SendBufferWatermark" "1024" # Larger send buffer for multi-DL
set_config "BitTorrent" "Session\\\\SendBufferLowWatermark" "64"
set_config "BitTorrent" "Session\\\\SendBufferWatermarkFactor" "150"

# Disable network features that consume RAM (safe behind Gluetun)
set_config "Preferences" "BitTorrent\\\\DHT" "false"
set_config "Preferences" "BitTorrent\\\\PeX" "false"
set_config "Preferences" "BitTorrent\\\\LSD" "false"

# Paths
set_config "BitTorrent" "Session\\\\DefaultSavePath" "/downloads"
set_config "BitTorrent" "Session\\\\TempPath" "/incomplete"
set_config "BitTorrent" "Session\\\\TempPathEnabled" "true"

# Fix ownership on media and downloads directories
for dir in /media /downloads /incomplete; do
	if [ -d "$dir" ]; then
		current_owner=$(stat -c "%u:%g" "$dir" 2>/dev/null || echo "0:0")
		if [ "$current_owner" != "${PUID}:${PGID}" ]; then
			chown "${PUID}:${PGID}" "$dir" 2>/dev/null || true
		fi
		chmod 755 "$dir" 2>/dev/null || true
	fi
done

# Create categories with save paths matching media folders
CATEGORIES_FILE="${CONFIG_DIR}/categories.json"
cat >"$CATEGORIES_FILE" <<'CATEOF'
{
    "movies": {"save_path": "/media/movies"},
    "tv": {"save_path": "/media/tv"},
    "music": {"save_path": "/media/music"},
    "audiobooks": {"save_path": "/media/audiobooks"},
    "books": {"save_path": "/media/books"},
    "adult": {"save_path": "/media/adult"},
    "podcasts": {"save_path": "/media/podcasts"},
    "youtube": {"save_path": "/media/youtube"}
}
CATEOF
chown "${PUID}:${PGID}" "$CATEGORIES_FILE" 2>/dev/null || true

# Auto-run hook
set_config "AutoRun" "enabled" "true"
set_config "AutoRun" "program" "/hooks/post-torrent.sh \\\"%N\\\" \\\"%C\\\" \\\"%F\\\" \\\"%D\\\" \\\"%G\\\""

echo "[qb-init] SOTA configuration applied (5+ parallel DLs, 128MB cache, 4 IO threads)"
