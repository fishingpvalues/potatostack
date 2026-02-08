#!/bin/bash
################################################################################
# qBittorrent SOTA Low-RAM Init Script (2026 Mini PC Optimized)
# Target: 16GB system, heavy Docker stack → aim for 250-450MB steady RSS
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

# === RAM-CRITICAL SETTINGS ===
# Queueing — the single biggest RAM saver
set_config "BitTorrent" "Session\\\\MaxActiveTorrents" "12" # Total active (DL + UL)
set_config "BitTorrent" "Session\\\\MaxActiveDownloads" "3" # Simultaneous downloads
set_config "BitTorrent" "Session\\\\MaxActiveUploads" "6"   # Simultaneous uploads/seeding

# Connections (moderate)
set_config "BitTorrent" "Session\\\\MaxConnections" "150"
set_config "BitTorrent" "Session\\\\MaxConnectionsPerTorrent" "40"
set_config "BitTorrent" "Session\\\\MaxUploads" "25"
set_config "BitTorrent" "Session\\\\MaxUploadsPerTorrent" "6"

# Disk cache & I/O — keep in RAM low
set_config "BitTorrent" "Session\\\\DiskCacheSize" "32" # 16-32 MB recommended
set_config "BitTorrent" "Session\\\\AsyncIOThreads" "1" # Saves RAM vs 2
set_config "BitTorrent" "Session\\\\UseMemoryMapping" "true"
set_config "BitTorrent" "Session\\\\CoalesceReadWrite" "true"
set_config "BitTorrent" "Session\\\\PieceExtentAffinity" "true"
set_config "BitTorrent" "Session\\\\SendBufferWatermark" "256"
set_config "BitTorrent" "Session\\\\SendBufferLowWatermark" "5"

# Disable network features that consume RAM (safe behind Gluetun)
set_config "Preferences" "BitTorrent\\\\DHT" "false"
set_config "Preferences" "BitTorrent\\\\PeX" "false"
set_config "Preferences" "BitTorrent\\\\LSD" "false"

# Paths
set_config "BitTorrent" "Session\\\\DefaultSavePath" "/downloads"
set_config "BitTorrent" "Session\\\\TempPath" "/incomplete"
set_config "BitTorrent" "Session\\\\TempPathEnabled" "true"

# Fix ownership on downloads directory
if [ -d "/downloads" ]; then
	current_owner=$(stat -c "%u:%g" "/downloads" 2>/dev/null || echo "0:0")
	if [ "$current_owner" != "${PUID}:${PGID}" ]; then
		chown -R "${PUID}:${PGID}" "/downloads" 2>/dev/null || true
	fi
	chmod -R 755 "/downloads" 2>/dev/null || true
fi

# Auto-run hook
set_config "AutoRun" "enabled" "true"
set_config "AutoRun" "program" "/hooks/post-torrent.sh \\\"%N\\\" \\\"%C\\\" \\\"%F\\\" \\\"%D\\\" \\\"%G\\\""

echo "[qb-init] Low-RAM SOTA configuration applied (target ~300-450MB RSS)"
