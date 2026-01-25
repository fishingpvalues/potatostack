#!/bin/bash
################################################################################
# Install rclone
# Fast and reliable cloud storage sync tool
################################################################################

set -eu

echo "============================================================"
echo "Installing rclone"
echo "============================================================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run as regular user (not root)"
    echo "  sudo will be used where needed"
    exit 1
fi

# Check if already installed
if command -v rclone >/dev/null 2>&1; then
    VERSION=$(rclone version | head -1)
    echo "✓ rclone already installed: $VERSION"
    echo ""
    read -p "Reinstall/update? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing installation"
        exit 0
    fi
fi

# Install rclone
echo "[1/2] Downloading and installing rclone..."
curl -s https://rclone.org/install.sh | sudo bash

# Verify installation
echo ""
echo "[2/2] Verifying installation..."
if command -v rclone >/dev/null 2>&1; then
    VERSION=$(rclone version | head -1)
    echo "✓ rclone installed: $VERSION"
else
    echo "✗ Installation failed"
    exit 1
fi

echo ""
echo "============================================================"
echo "Installation complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. Run: ./setup-rclone-onedrive.sh"
echo "  2. Follow browser authentication prompts"
echo "  3. Run: ./download-onedrive.sh"
echo "  4. Run: ./migrate-onedrive-to-syncthing.sh"
echo ""
