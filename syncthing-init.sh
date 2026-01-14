#!/bin/bash
################################################################################
# Syncthing Init Script - Auto-configure API key on startup
################################################################################

set -euo pipefail

CONFIG_DIR="/config"
CONFIG_FILE="$CONFIG_DIR/config.xml"

echo "Initializing Syncthing configuration..."

# Create config directory
mkdir -p "$CONFIG_DIR"

# Read API key from shared volume
if [ -f "/keys/syncthing-api-key" ]; then
	SYNCTHING_API_KEY=$(cat /keys/syncthing-api-key)
	echo "✓ Loaded Syncthing API key from shared volume"
else
	echo "⚠ Warning: API key not found at /keys/syncthing-api-key"
	echo "Generating temporary key..."
	SYNCTHING_API_KEY=$(openssl rand -hex 32)
fi

export SYNCTHING_API_KEY

# Wait for Syncthing to create initial config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
	echo "Starting Syncthing to generate initial config..."
	timeout 10 /init &
	sleep 5
	killall syncthing 2>/dev/null || true
	sleep 2
fi

# Update API key in config if file exists
if [ -f "$CONFIG_FILE" ]; then
	echo "Configuring Syncthing API key..."

	# Backup config
	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

	# Update or add API key in <gui> section
	if grep -q "<apikey>" "$CONFIG_FILE"; then
		# Replace existing key
		sed -i "s|<apikey>.*</apikey>|<apikey>$SYNCTHING_API_KEY</apikey>|g" "$CONFIG_FILE"
	else
		# Add key to gui section
		sed -i "s|</gui>|    <apikey>$SYNCTHING_API_KEY</apikey>\n    </gui>|g" "$CONFIG_FILE"
	fi

	echo "✓ Syncthing API key configured"
fi

# Continue with normal startup
exec /init "$@"
