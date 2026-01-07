#!/usr/bin/with-contenv bash
################################################################################
# Transmission Init Script - Configure incomplete directory on startup
# This runs after transmission creates its initial config
################################################################################

CONFIG_FILE="/config/settings.json"

# Wait for config file to exist and be valid
echo "Waiting for Transmission config file..."
timeout=30
while [ $timeout -gt 0 ]; do
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        if grep -q "download-dir" "$CONFIG_FILE" 2>/dev/null; then
            echo "✓ Config file found and valid"
            break
        fi
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "⚠ Timeout waiting for config file, using defaults"
    exit 0
fi

echo "Configuring Transmission settings..."

# Check if daemon is running (shouldn't be during init, but check anyway)
DAEMON_RUNNING=false
if pgrep transmission-daemon > /dev/null; then
    echo "⚠ Daemon already running, stopping to modify config safely..."
    killall transmission-daemon
    sleep 2
    DAEMON_RUNNING=true
fi

# Backup config
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Use jq if available, otherwise sed
if command -v jq > /dev/null; then
    # Use jq for safe JSON modification
    jq '. + {
        "download-dir": "/downloads/torrent",
        "incomplete-dir": "/incomplete",
        "incomplete-dir-enabled": true,
        "dht-enabled": true,
        "lpd-enabled": true,
        "pex-enabled": true,
        "utp-enabled": true,
        "peer-port": 51413,
        "peer-port-random-on-start": false,
        "port-forwarding-enabled": false,
        "peer-limit-global": 200,
        "peer-limit-per-torrent": 50,
        "scrape-paused-torrents-enabled": true,
        "encryption": 1,
        "download-queue-enabled": true,
        "download-queue-size": 10,
        "queue-stalled-enabled": true,
        "queue-stalled-minutes": 30
    }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    # Fallback to sed (less safe but works)
    sed -i 's|"download-dir": "[^"]*"|"download-dir": "/downloads/torrent"|' "$CONFIG_FILE"
    sed -i 's|"incomplete-dir": "[^"]*"|"incomplete-dir": "/incomplete"|' "$CONFIG_FILE"
    sed -i 's|"incomplete-dir-enabled": [^,]*|"incomplete-dir-enabled": true|' "$CONFIG_FILE"
    sed -i 's|"dht-enabled": [^,]*|"dht-enabled": true|' "$CONFIG_FILE"
    sed -i 's|"lpd-enabled": [^,]*|"lpd-enabled": true|' "$CONFIG_FILE"
    sed -i 's|"pex-enabled": [^,]*|"pex-enabled": true|' "$CONFIG_FILE"
    sed -i 's|"peer-port": [^,]*|"peer-port": 51413|' "$CONFIG_FILE"
    sed -i 's|"port-forwarding-enabled": [^,]*|"port-forwarding-enabled": false|' "$CONFIG_FILE"
fi

echo "✓ Transmission configured successfully"

# Restart daemon if it was running before we stopped it
if [ "$DAEMON_RUNNING" = "true" ]; then
    echo "Restarting transmission daemon..."
    transmission-daemon --config-dir /config &
    sleep 2
    echo "✓ Daemon restarted"
else
    echo "✓ Config ready for s6-overlay to start daemon"
fi
