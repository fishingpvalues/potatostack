#!/bin/sh
################################################################################
# Homepage Init Script - Load API keys from shared volume
################################################################################

echo "Loading API keys for Homepage widgets..."

# Load slskd API key
if [ -f "/keys/slskd-api-key" ]; then
	export HOMEPAGE_VAR_SLSKD_KEY=$(cat /keys/slskd-api-key)
	echo "✓ Loaded slskd API key"
else
	echo "⚠ slskd API key not found, widget may show errors"
fi

# Load Syncthing API key
if [ -f "/keys/syncthing-api-key" ]; then
	export HOMEPAGE_VAR_SYNCTHING_KEY=$(cat /keys/syncthing-api-key)
	echo "✓ Loaded Syncthing API key"
else
	echo "⚠ Syncthing API key not found, widget may show errors"
fi

# Load Aria2 RPC secret
if [ -f "/keys/aria2-rpc-secret" ]; then
	export HOMEPAGE_VAR_ARIA2_SECRET=$(cat /keys/aria2-rpc-secret)
	# Also export base64-encoded version for AriaNg URL (URL-safe base64)
	export HOMEPAGE_VAR_ARIA2_SECRET_B64=$(echo -n "$HOMEPAGE_VAR_ARIA2_SECRET" | base64 | tr -d '=' | tr '+/' '-_')
	echo "✓ Loaded Aria2 RPC secret"
else
	echo "⚠ Aria2 RPC secret not found, widget may show errors"
fi

echo "Starting Homepage..."

# Continue with normal startup
exec node server.js
