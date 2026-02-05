#!/bin/bash
################################################################################
# Install PotatoStack Auto-Fix Systemd Services
# This script installs systemd services to automatically fix log errors
# after stack restarts and on a periodic basis
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "PotatoStack Auto-Fix System Installer"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Error: This script must be run as root${NC}"
	echo "Please run: sudo $0"
	exit 1
fi

# Install post-start service
echo -e "${YELLOW}Installing potatostack-fixes.service...${NC}"
cp "$SCRIPT_DIR/potatostack-fixes.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/potatostack-fixes.service
systemctl daemon-reload
systemctl enable potatostack-fixes.service
echo -e "${GREEN}✓ potatostack-fixes.service installed and enabled${NC}"
echo "  This service will run fixes after Docker starts"
echo ""

# Install periodic service
echo -e "${YELLOW}Installing potatostack-periodic-fixes.service...${NC}"
cp "$SCRIPT_DIR/potatostack-periodic-fixes.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/potatostack-periodic-fixes.service
systemctl daemon-reload
systemctl enable potatostack-periodic-fixes.service
echo -e "${GREEN}✓ potatostack-periodic-fixes.service installed and enabled${NC}"
echo ""

# Install timer
echo -e "${YELLOW}Installing potatostack-fixes.timer...${NC}"
cp "$SCRIPT_DIR/potatostack-fixes.timer" /etc/systemd/system/
chmod 644 /etc/systemd/system/potatostack-fixes.timer
systemctl daemon-reload
systemctl enable potatostack-fixes.timer
systemctl start potatostack-fixes.timer
echo -e "${GREEN}✓ potatostack-fixes.timer installed, enabled, and started${NC}"
echo "  This timer runs fixes every hour"
echo ""

# Create log file
touch /var/log/potatostack-fixes.log
chmod 644 /var/log/potatostack-fixes.log
touch /var/log/potatostack-restarts.log
chmod 644 /var/log/potatostack-restarts.log
echo -e "${GREEN}✓ Log files created${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================="
echo ""
echo "Services installed:"
echo "  • potatostack-fixes.service - Runs after Docker starts"
echo "  • potatostack-periodic-fixes.service - Runs periodically"
echo "  • potatostack-fixes.timer - Triggers periodic fixes every hour"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u potatostack-fixes -f"
echo "  sudo tail -f /var/log/potatostack-fixes.log"
echo ""
echo "To manually run fixes:"
echo "  sudo systemctl start potatostack-fixes"
echo "  sudo systemctl start potatostack-periodic-fixes"
echo ""
echo "To disable:"
echo "  sudo systemctl disable --now potatostack-fixes.timer"
echo ""
