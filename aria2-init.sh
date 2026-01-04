#!/bin/sh
################################################################################
# Aria2 Init Script - Auto-configure RPC secret on startup
################################################################################

CONFIG_DIR="/config"

echo "Initializing Aria2 configuration..."

# Create config directory
mkdir -p "$CONFIG_DIR"

# Read RPC secret from shared volume
if [ -f "/keys/aria2-rpc-secret" ]; then
	ARIA2_RPC_SECRET=$(cat /keys/aria2-rpc-secret)
	echo "✓ Loaded Aria2 RPC secret from shared volume"
else
	echo "⚠ Warning: RPC secret not found at /keys/aria2-rpc-secret"
	echo "Using environment variable or generating temporary secret..."
	if [ -z "$RPC_SECRET" ]; then
		ARIA2_RPC_SECRET=$(head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"' | tr -d '\n')
		echo "✓ Generated temporary RPC secret (hex)"
	else
		ARIA2_RPC_SECRET="$RPC_SECRET"
	fi
fi

# Export for aria2 to use
export RPC_SECRET="$ARIA2_RPC_SECRET"

# Create session file if it doesn't exist
touch "$CONFIG_DIR/aria2.session"

echo "✓ Aria2 RPC secret configured"

# Continue with normal startup
exec /init "$@"
