#!/bin/bash
################################################################################
# qBittorrent Init Script - Configure WebUI auth and incomplete directory
################################################################################

CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"
QB_USER="${QBITTORRENT_USER:-${QB_USER:-admin}}"
QB_PASSWORD="${QBITTORRENT_PASSWORD:-}"

# Wait for config directory
mkdir -p /config/qBittorrent

# Function to set config value
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

# Generate PBKDF2 hash for qBittorrent WebUI password
generate_password_hash() {
	local password="$1"
	local python_bin=""

	if command -v python3 >/dev/null 2>&1; then
		python_bin="python3"
	elif command -v python >/dev/null 2>&1; then
		python_bin="python"
	else
		# Try to install python if possible
		if command -v apk >/dev/null 2>&1; then
			apk add --no-cache python3 >/dev/null 2>&1 && python_bin="python3"
		elif command -v apt-get >/dev/null 2>&1; then
			apt-get update -qq >/dev/null 2>&1
			apt-get install -y python3 >/dev/null 2>&1 && python_bin="python3"
		fi
	fi

	if [ -z "$python_bin" ]; then
		echo ""
		return
	fi

	"$python_bin" - <<PY "$password"
import base64, hashlib, os, sys
password = sys.argv[1].encode()
iters = 10000
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha1", password, salt, iters, dklen=20)
print(f"PBKDF2${iters}${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}")
PY
}

# Wait for initial config to be created by linuxserver init
sleep 2

# Configure settings if config exists or create basic one
if [ -f "$CONFIG_FILE" ]; then
	echo "Configuring qBittorrent settings..."
	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
else
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

# Configure WebUI settings - disable localhost bypass for remote access
set_config "Preferences" "WebUI\\\\LocalHostAuth" "false"
set_config "Preferences" "WebUI\\\\AuthSubnetWhitelistEnabled" "false"
set_config "Preferences" "WebUI\\\\HostHeaderValidation" "false"
set_config "Preferences" "WebUI\\\\ServerDomains" "*"
set_config "Preferences" "WebUI\\\\Address" "*"
set_config "Preferences" "WebUI\\\\Port" "8282"

# Configure paths
set_config "BitTorrent" "Session\\\\DefaultSavePath" "/downloads"
set_config "BitTorrent" "Session\\\\TempPath" "/incomplete"
set_config "BitTorrent" "Session\\\\TempPathEnabled" "true"

if [ -n "$QB_PASSWORD" ]; then
	HASH=$(generate_password_hash "$QB_PASSWORD")
	if [ -n "$HASH" ]; then
		set_config "Preferences" "WebUI\\\\Username" "$QB_USER"
		set_config "Preferences" "WebUI\\\\Password_PBKDF2" "@ByteArray($HASH)"
		echo "✓ WebUI credentials set from env for user: $QB_USER"
	else
		echo "⚠ Unable to generate WebUI password hash (python missing)"
		echo "⚠ Leaving existing WebUI password unchanged"
	fi
else
	echo "⚠ QBITTORRENT_PASSWORD not set; keeping existing WebUI password"
fi

echo "✓ qBittorrent WebUI configured on port 8282"
echo "✓ Default save path: /downloads"
echo "✓ Incomplete path: /incomplete"
echo "NOTE: If password wasn't set here, check container logs for temporary password"

# Continue with normal startup
exec /init "$@"
