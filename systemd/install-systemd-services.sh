#!/bin/bash
################################################################################
# PotatoStack Systemd Services Installer
# Installs automated swap management and auto-start services
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo ./install-systemd-services.sh)${NC}"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POTATOSTACK_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PotatoStack Systemd Services Installer          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}[1/5]${NC} Detected configuration:"
echo "      User: $ACTUAL_USER"
echo "      PotatoStack directory: $POTATOSTACK_DIR"
echo ""

# Confirm
read -p "Is this correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo ""
echo -e "${GREEN}[2/5]${NC} Installing swap management script..."

# Copy swap script
cp "$SCRIPT_DIR/ensure-potatostack-swap.sh" /usr/local/bin/
chmod +x /usr/local/bin/ensure-potatostack-swap.sh
echo "      ✓ Copied to /usr/local/bin/ensure-potatostack-swap.sh"

# Install swap service
cp "$SCRIPT_DIR/potatostack-swap.service" /etc/systemd/system/
echo "      ✓ Copied to /etc/systemd/system/potatostack-swap.service"

echo ""
echo -e "${GREEN}[3/5]${NC} Installing PotatoStack auto-start service..."

# Update potatostack.service with actual user and path
sed "s|/home/USER|$POTATOSTACK_DIR|g; s|User=USER|User=$ACTUAL_USER|g; s|Group=USER|Group=$ACTUAL_USER|g" \
    "$SCRIPT_DIR/potatostack.service" > /etc/systemd/system/potatostack.service

echo "      ✓ Copied to /etc/systemd/system/potatostack.service"
echo "      ✓ Configured for user: $ACTUAL_USER"

echo ""
echo -e "${GREEN}[4/5]${NC} Enabling systemd services..."

systemctl daemon-reload
echo "      ✓ Reloaded systemd daemon"

systemctl enable potatostack-swap.service
echo "      ✓ Enabled potatostack-swap.service"

systemctl enable potatostack.service
echo "      ✓ Enabled potatostack.service"

echo ""
echo -e "${GREEN}[5/5]${NC} Starting services..."

# Start swap service
systemctl start potatostack-swap.service
if systemctl is-active --quiet potatostack-swap.service; then
    echo "      ✓ Started potatostack-swap.service"
else
    echo -e "      ${YELLOW}⚠ Swap service failed to start (check: systemctl status potatostack-swap)${NC}"
fi

# Ask if user wants to start the stack now
echo ""
read -p "Start PotatoStack now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl start potatostack.service
    if systemctl is-active --quiet potatostack.service; then
        echo "      ✓ Started potatostack.service"
    else
        echo -e "      ${YELLOW}⚠ PotatoStack service failed to start (check: systemctl status potatostack)${NC}"
    fi
else
    echo "      Skipped starting PotatoStack (will auto-start on next boot)"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Installation Complete!                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ Systemd services installed successfully${NC}"
echo ""
echo "Services installed:"
echo "  • potatostack-swap.service  - Manages swap file"
echo "  • potatostack.service       - Auto-starts PotatoStack"
echo ""
echo "Useful commands:"
echo "  • Check swap status:        free -h"
echo "  • Check swap service:       sudo systemctl status potatostack-swap"
echo "  • Check stack service:      sudo systemctl status potatostack"
echo "  • View stack logs:          sudo journalctl -u potatostack -f"
echo "  • Restart stack:            sudo systemctl restart potatostack"
echo "  • Stop stack:               sudo systemctl stop potatostack"
echo ""
echo "Your PotatoStack will now automatically start on boot!"
echo ""
