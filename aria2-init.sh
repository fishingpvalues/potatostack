#!/bin/bash
################################################################################
# Aria2 Init Script - Configure download and incomplete directories
################################################################################

CONFIG_FILE="/config/aria2.conf"

mkdir -p /config

# Create aria2 config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating aria2 configuration..."
    cat > "$CONFIG_FILE" <<EOF
# Download directories
dir=/downloads
input-file=/config/aria2.session
save-session=/config/aria2.session

# Connection settings
max-concurrent-downloads=5
max-connection-per-server=10
split=10
min-split-size=10M
continue=true
max-overall-download-limit=0
max-download-limit=0

# RPC settings
enable-rpc=true
rpc-listen-all=true
rpc-allow-origin-all=true
rpc-secret=${RPC_SECRET}

# BT settings
bt-enable-lpd=true
bt-max-peers=55
follow-torrent=true
enable-dht=true
enable-dht6=false
bt-require-crypto=true
seed-ratio=1.0
seed-time=0

# Advanced
auto-file-renaming=true
allow-overwrite=false
always-resume=true
EOF
    echo "✓ aria2 configuration created"
fi

# Create session file if it doesn't exist
touch /config/aria2.session

echo "✓ aria2 configured"
exec /init "$@"
