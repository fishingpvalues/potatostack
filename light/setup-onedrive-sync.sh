#!/bin/bash
################################################################################
# Setup OneDrive Sync - Configure and Authenticate
# Downloads entire OneDrive to /mnt/storage/onedrive-temp
################################################################################

set -e

SYNC_DIR="/mnt/storage/onedrive-temp"
CONFIG_DIR="$HOME/.config/onedrive"
CONFIG_FILE="$CONFIG_DIR/config"

echo "================================"
echo "OneDrive Sync Configuration"
echo "================================"
echo ""

# Check if onedrive is installed
if ! command -v onedrive >/dev/null 2>&1; then
    echo "✗ onedrive client not found"
    echo "  Run: ./install-onedrive-client.sh first"
    exit 1
fi

# Create config directory
echo "Creating configuration directory..."
mkdir -p "$CONFIG_DIR"

# Download default config template
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Downloading configuration template..."
    wget -q https://raw.githubusercontent.com/abraunegg/onedrive/master/config -O "$CONFIG_FILE"
    echo "✓ Configuration template downloaded"
else
    echo "⚠ Configuration file already exists"
    read -p "Overwrite with fresh template? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
        wget -q https://raw.githubusercontent.com/abraunegg/onedrive/master/config -O "$CONFIG_FILE"
        echo "✓ Backed up old config and downloaded new template"
    fi
fi

# Create sync directory
echo ""
echo "Creating sync directory: $SYNC_DIR"
sudo mkdir -p "$SYNC_DIR"
sudo chown daniel:daniel "$SYNC_DIR"
sudo chmod 755 "$SYNC_DIR"

# Configure sync_dir
echo ""
echo "Configuring sync directory..."
if grep -q "^sync_dir" "$CONFIG_FILE"; then
    sed -i "s|^sync_dir.*|sync_dir = \"$SYNC_DIR\"|" "$CONFIG_FILE"
else
    echo "sync_dir = \"$SYNC_DIR\"" >> "$CONFIG_FILE"
fi

# Enable logging
if grep -q "^# enable_logging" "$CONFIG_FILE"; then
    sed -i 's/^# enable_logging.*/enable_logging = "true"/' "$CONFIG_FILE"
elif ! grep -q "^enable_logging" "$CONFIG_FILE"; then
    echo 'enable_logging = "true"' >> "$CONFIG_FILE"
fi

# Set log directory
LOG_DIR="$HOME/.config/onedrive/logs"
mkdir -p "$LOG_DIR"
if grep -q "^# log_dir" "$CONFIG_FILE"; then
    sed -i "s|^# log_dir.*|log_dir = \"$LOG_DIR\"|" "$CONFIG_FILE"
elif ! grep -q "^log_dir" "$CONFIG_FILE"; then
    echo "log_dir = \"$LOG_DIR\"" >> "$CONFIG_FILE"
fi

echo "✓ Configuration updated"

# Display configuration
echo ""
echo "================================"
echo "Current Configuration"
echo "================================"
onedrive --display-config | grep -E "(sync_dir|enable_logging|log_dir)"

echo ""
echo "================================"
echo "Authentication Required"
echo "================================"
echo ""
echo "Steps to authenticate:"
echo "1. A URL will be displayed - open it in your web browser"
echo "2. Sign in to your Microsoft account"
echo "3. Grant permissions to the OneDrive client"
echo "4. After authorization, copy the ENTIRE redirect URL from browser"
echo "5. Paste it back here when prompted"
echo ""
read -p "Ready to authenticate? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Authentication cancelled. Run this script again when ready."
    exit 0
fi

echo ""
echo "Starting authentication..."
echo "================================"
onedrive --synchronize --verbose --dry-run

echo ""
echo "================================"
echo "Authentication Complete!"
echo "================================"
echo ""
echo "Configuration summary:"
echo "  Sync directory: $SYNC_DIR"
echo "  Config file: $CONFIG_FILE"
echo "  Log directory: $LOG_DIR"
echo ""
echo "Next step: Download OneDrive content"
echo "  Run: ./download-onedrive.sh"
echo ""
