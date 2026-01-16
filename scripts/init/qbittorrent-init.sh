#!/bin/bash
################################################################################
# qBittorrent Init Script - Configure incomplete directory on startup
################################################################################

CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"

# Wait for config directory
mkdir -p /config/qBittorrent

# Configure incomplete directory if config exists
if [ -f "$CONFIG_FILE" ]; then
	echo "Configuring qBittorrent incomplete directory..."

	# Backup config
	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

	# Use crudini or sed to update config
	if command -v crudini >/dev/null 2>&1; then
		crudini --set "$CONFIG_FILE" BitTorrent "Session\DefaultSavePath" "/downloads"
		crudini --set "$CONFIG_FILE" BitTorrent "Session\TempPath" "/incomplete"
		crudini --set "$CONFIG_FILE" BitTorrent "Session\TempPathEnabled" "true"
	else
		# Fallback to sed
		sed -i 's|Session\\DefaultSavePath=.*|Session\\DefaultSavePath=/downloads|g' "$CONFIG_FILE"
		sed -i 's|Session\\TempPath=.*|Session\\TempPath=/incomplete|g' "$CONFIG_FILE"
		sed -i 's|Session\\TempPathEnabled=.*|Session\\TempPathEnabled=true|g' "$CONFIG_FILE"
	fi

	echo "✓ qBittorrent configured to use /incomplete for temporary files"
fi

# Continue with normal startup
exec /init "$@"
