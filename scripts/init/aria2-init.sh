#!/bin/sh
################################################################################
# Aria2 Init Script - Auto-configure RPC secret on startup
# AriaNg connection: http://potatostack.tale-iwato.ts.net:6800/jsonrpc
################################################################################

CONFIG_DIR="/config"
ARIA_CONF="${CONFIG_DIR}/aria2.conf"

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

# Write RPC secret to environment file for s6-overlay to source
mkdir -p /var/run/s6/container_environment
echo -n "$ARIA2_RPC_SECRET" > /var/run/s6/container_environment/RPC_SECRET

# Create session file if it doesn't exist
touch "$CONFIG_DIR/aria2.session"

# Configure aria2.conf for external access (Tailscale/LAN)
if [ ! -f "$ARIA_CONF" ]; then
	cat > "$ARIA_CONF" << EOF
# Aria2 Configuration - PotatoStack
# RPC endpoint: http://potatostack.tale-iwato.ts.net:6800/jsonrpc

# RPC Settings - allow external connections
rpc-listen-all=true
rpc-allow-origin-all=true
rpc-secret=${ARIA2_RPC_SECRET}

# Enable JSON-RPC
enable-rpc=true
rpc-listen-port=6800

# Download Settings
dir=/downloads
input-file=/config/aria2.session
save-session=/config/aria2.session
save-session-interval=60

# Connection Settings
max-connection-per-server=16
min-split-size=1M
split=16
max-concurrent-downloads=5

# BitTorrent Settings
bt-enable-lpd=true
bt-max-peers=55
bt-request-peer-speed-limit=100K
listen-port=6888
dht-listen-port=6888

# File Settings
file-allocation=falloc
disk-cache=64M
continue=true
EOF
	echo "✓ Created aria2.conf with RPC enabled for external access"
else
	# Ensure rpc-listen-all and rpc-allow-origin-all are enabled
	if ! grep -q "rpc-listen-all=true" "$ARIA_CONF"; then
		echo "rpc-listen-all=true" >> "$ARIA_CONF"
	fi
	if ! grep -q "rpc-allow-origin-all=true" "$ARIA_CONF"; then
		echo "rpc-allow-origin-all=true" >> "$ARIA_CONF"
	fi
	# Update RPC secret
	sed -i "s/^rpc-secret=.*/rpc-secret=${ARIA2_RPC_SECRET}/" "$ARIA_CONF"
	echo "✓ Updated aria2.conf RPC settings"
fi

echo "✓ Aria2 RPC secret configured: ${ARIA2_RPC_SECRET:0:16}..."
echo "✓ AriaNg connection URL: http://potatostack.tale-iwato.ts.net:6800/jsonrpc"
echo "  Use the RPC secret in AriaNg settings"

# Continue with normal startup
exec /init "$@"
