#!/bin/bash
################################################################################
# Transmission Init Script - Configure incomplete directory on startup
################################################################################

CONFIG_FILE="/config/settings.json"

# Wait for config directory
mkdir -p /config

# Function to update or add JSON setting
update_json_setting() {
	local key=$1
	local value=$2
	local file=$3

	if grep -q "\"$key\"" "$file" 2>/dev/null; then
		# Update existing key
		sed -i "s|\"$key\":.*|\"$key\": $value,|g" "$file"
	else
		# Add new key before closing brace
		sed -i "s|}|\n    \"$key\": $value\n}|g" "$file"
	fi
}

# Configure incomplete directory if config exists
if [ -f "$CONFIG_FILE" ]; then
	echo "Configuring Transmission incomplete directory..."

	# Backup config
	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

	# Set incomplete directory settings
	update_json_setting "download-dir" '"/downloads/torrent"' "$CONFIG_FILE"
	update_json_setting "incomplete-dir" '"/incomplete"' "$CONFIG_FILE"
	update_json_setting "incomplete-dir-enabled" 'true' "$CONFIG_FILE"

	# Optimize peer discovery and connectivity
	update_json_setting "dht-enabled" 'true' "$CONFIG_FILE"
	update_json_setting "lpd-enabled" 'true' "$CONFIG_FILE"
	update_json_setting "pex-enabled" 'true' "$CONFIG_FILE"
	update_json_setting "utp-enabled" 'true' "$CONFIG_FILE"

	# Port settings (51413 forwarded through gluetun)
	# Note: Surfshark doesn't support port forwarding, so we rely on DHT/PEX/LPD
	update_json_setting "peer-port" '51413' "$CONFIG_FILE"
	update_json_setting "peer-port-random-on-start" 'false' "$CONFIG_FILE"
	update_json_setting "port-forwarding-enabled" 'false' "$CONFIG_FILE"

	# Connection limits
	update_json_setting "peer-limit-global" '200' "$CONFIG_FILE"
	update_json_setting "peer-limit-per-torrent" '50' "$CONFIG_FILE"

	# Scrape settings
	update_json_setting "scrape-paused-torrents-enabled" 'true' "$CONFIG_FILE"

	# Encryption (prefer encrypted peers but allow unencrypted)
	update_json_setting "encryption" '1' "$CONFIG_FILE"

	# Tracker settings
	update_json_setting "announce-ip-enabled" 'false' "$CONFIG_FILE"
	update_json_setting "tracker-add" '[]' "$CONFIG_FILE"

	# Speed and queue settings for better performance
	update_json_setting "download-queue-enabled" 'true' "$CONFIG_FILE"
	update_json_setting "download-queue-size" '10' "$CONFIG_FILE"
	update_json_setting "queue-stalled-enabled" 'true' "$CONFIG_FILE"
	update_json_setting "queue-stalled-minutes" '30' "$CONFIG_FILE"

	echo "✓ Transmission configured with optimized peer discovery (DHT/PEX/LPD enabled)"
fi

# Continue with normal startup
exec /init "$@"
