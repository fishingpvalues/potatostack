#!/bin/bash
set -euo pipefail

# Install PotatoStack systemd service
# Run with sudo: sudo bash install-systemd-service.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run with sudo: sudo bash $0${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/../init/potatostack.service"

echo "Installing PotatoStack systemd service..."

# Copy service file
cp "$SERVICE_FILE" /etc/systemd/system/potatostack.service

# Create log file with proper permissions
touch /var/log/potatostack-startup.log
chown daniel:daniel /var/log/potatostack-startup.log

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable potatostack.service

echo -e "${GREEN}Service installed and enabled!${NC}"
echo ""
echo "Commands:"
echo "  systemctl status potatostack    # Check status"
echo "  systemctl start potatostack     # Start manually"
echo "  journalctl -u potatostack -f    # View logs"
echo ""
echo "The service will auto-start on boot and fix any crashed containers."
