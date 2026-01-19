#!/bin/bash
################################################################################
# qBittorrent Init Script - Configure WebUI auth and incomplete directory
################################################################################

CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"
QB_USER="${QB_USER:-Daniel}"
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
set_config "Preferences" "WebUI\\\\Port" "8282"

# Configure paths
set_config "BitTorrent" "Session\\\\DefaultSavePath" "/downloads"
set_config "BitTorrent" "Session\\\\TempPath" "/incomplete"
set_config "BitTorrent" "Session\\\\TempPathEnabled" "true"

echo "✓ qBittorrent WebUI configured on port 8282"
echo "✓ Default save path: /downloads"
echo "✓ Incomplete path: /incomplete"
echo "NOTE: First login uses admin/adminadmin, then change password in WebUI settings"

# Continue with normal startup
exec /init "$@"
