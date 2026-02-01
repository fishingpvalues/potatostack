#!/bin/bash
################################################################################
# qBittorrent Init Script - Configure WebUI auth and settings
# Mounted to /custom-cont-init.d/ (runs during LSIO init, before app starts)
################################################################################

CONFIG_DIR="/config/qBittorrent"
CONFIG_FILE="${CONFIG_DIR}/qBittorrent.conf"
QB_USER="${QBITTORRENT_USER:-admin}"
QB_PASSWORD="${QBITTORRENT_PASSWORD:-}"

mkdir -p "$CONFIG_DIR"

# Function to set config value under a section
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
		echo -e "\n[${section}]\n${key}=${value}" >> "$CONFIG_FILE"
	fi
}

# Generate PBKDF2-SHA512 hash (qBittorrent 4.6.1+ / 5.x format)
generate_password_hash() {
	local password="$1"
	local python_bin=""

	for bin in python3 python; do
		command -v "$bin" >/dev/null 2>&1 && python_bin="$bin" && break
	done

	if [ -z "$python_bin" ]; then
		if command -v apk >/dev/null 2>&1; then
			apk add --no-cache python3 >/dev/null 2>&1 && python_bin="python3"
		fi
	fi

	[ -z "$python_bin" ] && return 1

	"$python_bin" -c "
import base64, hashlib, os, sys
pw = sys.argv[1].encode()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha512', pw, salt, 100000, dklen=64)
print(base64.b64encode(salt).decode() + ':' + base64.b64encode(dk).decode())
" "$password"
}

# Create config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
	echo "Creating initial qBittorrent config..."
	cat > "$CONFIG_FILE" << 'EOF'
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

# WebUI settings
set_config "Preferences" "WebUI\\\\LocalHostAuth" "false"
set_config "Preferences" "WebUI\\\\AuthSubnetWhitelistEnabled" "false"
set_config "Preferences" "WebUI\\\\HostHeaderValidation" "false"
set_config "Preferences" "WebUI\\\\ServerDomains" "*"
set_config "Preferences" "WebUI\\\\Address" "*"
set_config "Preferences" "WebUI\\\\Port" "8282"

# Paths
set_config "BitTorrent" "Session\\\\DefaultSavePath" "/downloads"
set_config "BitTorrent" "Session\\\\TempPath" "/incomplete"
set_config "BitTorrent" "Session\\\\TempPathEnabled" "true"

# Set credentials
if [ -n "$QB_PASSWORD" ]; then
	HASH=$(generate_password_hash "$QB_PASSWORD")
	if [ -n "$HASH" ]; then
		set_config "Preferences" "WebUI\\\\Username" "${QB_USER}"
		set_config "Preferences" "WebUI\\\\Password_PBKDF2" "\"@ByteArray(${HASH})\""
		echo "[qb-init] WebUI credentials set for user: ${QB_USER}"
	else
		echo "[qb-init] WARNING: Could not generate password hash (python missing)"
	fi
else
	echo "[qb-init] WARNING: QBITTORRENT_PASSWORD not set"
fi

echo "[qb-init] Configuration complete"
