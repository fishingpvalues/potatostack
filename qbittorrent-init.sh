#!/bin/bash
################################################################################
# qBittorrent Init Script - Configure incomplete directory on startup
################################################################################

CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"

# Wait for config directory to exist
mkdir -p /config/qBittorrent

# If config doesn't exist or needs updating
if [ ! -f "$CONFIG_FILE" ] || ! grep -q "TempPathEnabled=true" "$CONFIG_FILE"; then
    echo "Configuring qBittorrent incomplete directory..."

    # Backup existing config
    [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Set incomplete directory settings
    if [ -f "$CONFIG_FILE" ]; then
        # Update existing config
        sed -i '/\[Preferences\]/a Downloads\\TempPath=/incomplete\nDownloads\\TempPathEnabled=true\nDownloads\\SavePath=/downloads' "$CONFIG_FILE"
    else
        # Create new config with incomplete settings
        cat > "$CONFIG_FILE" <<'EOF'
[Preferences]
Downloads\SavePath=/downloads
Downloads\TempPath=/incomplete
Downloads\TempPathEnabled=true
EOF
    fi

    echo "✓ qBittorrent configured to use /incomplete for temporary files"
fi

# Continue with normal startup
exec /init
