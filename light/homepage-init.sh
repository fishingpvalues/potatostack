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

echo "Starting Homepage..."

# Continue with normal startup
exec node server.js
