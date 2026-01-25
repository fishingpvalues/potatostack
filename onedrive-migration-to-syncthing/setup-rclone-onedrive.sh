#!/bin/bash
################################################################################
# Setup rclone for OneDrive (Headless Support)
# Configures rclone with Microsoft OneDrive authentication
# Works on headless servers - authenticate from any machine with a browser
################################################################################

set -eu

RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
REMOTE_NAME="onedrive"

echo "============================================================"
echo "Setup rclone for OneDrive"
echo "============================================================"
echo ""

# Check if rclone is installed
if ! command -v rclone >/dev/null 2>&1; then
    echo "✗ rclone not found"
    echo "  Please run: ./install-rclone.sh"
    exit 1
fi

# Check if already configured
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
    echo "⚠ OneDrive remote already configured"
    echo ""
    echo "Testing connection..."
    if rclone lsd ${REMOTE_NAME}: --max-depth 1 2>/dev/null; then
        echo ""
        echo "✓ Connection working!"
        echo ""
        echo "Your OneDrive folders:"
        rclone lsd ${REMOTE_NAME}: --max-depth 1 2>/dev/null | head -10
        echo ""
        read -p "Reconfigure anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing configuration"
            exit 0
        fi
        # Remove old config
        rclone config delete "$REMOTE_NAME" 2>/dev/null || true
    else
        echo "⚠ Connection failed, reconfiguring..."
        rclone config delete "$REMOTE_NAME" 2>/dev/null || true
    fi
fi

# Create config directory
mkdir -p "$(dirname "$RCLONE_CONFIG")"

echo ""
echo "============================================================"
echo "HEADLESS AUTHENTICATION"
echo "============================================================"
echo ""
echo "Since this is a headless server, you have two options:"
echo ""
echo "Option 1: Use the link shown below (easiest)"
echo "  - Copy the URL that appears"
echo "  - Open it in ANY browser (phone, laptop, etc.)"
echo "  - Login to Microsoft"
echo "  - Copy the authorization code back here"
echo ""
echo "Option 2: Run rclone on a machine with a browser"
echo "  - On your laptop/desktop, run: rclone authorize onedrive"
echo "  - Copy the token JSON back here"
echo ""
echo "============================================================"
echo ""
read -p "Press Enter to continue..."
echo ""

# Run rclone config interactively
echo "Starting rclone configuration..."
echo ""
echo "Answer the prompts as follows:"
echo "  - name: onedrive"
echo "  - Storage: onedrive (or number for Microsoft OneDrive)"
echo "  - client_id: (leave blank, press Enter)"
echo "  - client_secret: (leave blank, press Enter)"
echo "  - region: global (or 1)"
echo "  - Edit advanced config: n"
echo "  - Use auto config: n (for headless)"
echo "  - Then follow the URL instructions"
echo ""

rclone config

# Verify configuration
echo ""
echo "Verifying configuration..."
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
    if rclone lsd ${REMOTE_NAME}: --max-depth 1 2>/dev/null; then
        echo ""
        echo "============================================================"
        echo "✓ OneDrive connected successfully!"
        echo "============================================================"
        echo ""
        echo "Your OneDrive root folders:"
        rclone lsd ${REMOTE_NAME}: --max-depth 1 2>/dev/null | head -20
        echo ""
        echo "Configuration saved to: $RCLONE_CONFIG"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ./download-onedrive.sh"
        echo "  2. Run: ./migrate-onedrive-to-syncthing.sh"
    else
        echo ""
        echo "✗ Connection test failed"
        echo "Try running this script again"
        exit 1
    fi
else
    echo ""
    echo "✗ Configuration not found"
    echo "Try running: rclone config"
    exit 1
fi
