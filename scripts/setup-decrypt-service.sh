#!/bin/bash
################################################################################
# Systemd Service Setup - Auto-decrypt .env on boot
# Run with: sudo ./setup-decrypt-service.sh
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
    echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE_FILE="/etc/systemd/system/potatostack-decrypt-env.service"

# Get the actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Auto-Decrypt Service Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Validate inputs
echo -e "${BLUE}Configuration:${NC}"
echo "  User: $ACTUAL_USER"
echo "  Home: $ACTUAL_HOME"
echo "  Project: $PROJECT_ROOT"
echo ""

read -p "Is this correct? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled${NC}"
    exit 1
fi

# Create systemd service
echo -e "${BLUE}Creating systemd service...${NC}"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Decrypt PotatoStack environment file
Before=docker.service
After=local-fs.target

[Service]
Type=oneshot
User=$ACTUAL_USER
Environment="SOPS_AGE_KEY_FILE=$ACTUAL_HOME/.config/sops/age/keys.txt"
ExecStart=/usr/local/bin/sops --decrypt $PROJECT_ROOT/.env.enc --output $PROJECT_ROOT/.env
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Service file created at: $SERVICE_FILE${NC}"
echo ""

# Reload systemd
echo -e "${BLUE}Reloading systemd daemon...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"
echo ""

# Enable service
echo -e "${BLUE}Enabling service to run on boot...${NC}"
systemctl enable potatostack-decrypt-env.service
echo -e "${GREEN}✓ Service enabled${NC}"
echo ""

# Test service
echo -e "${BLUE}Testing service...${NC}"
systemctl start potatostack-decrypt-env.service

if systemctl is-active --quiet potatostack-decrypt-env.service; then
    echo -e "${GREEN}✓ Service started successfully${NC}"

    # Check if .env was created
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo -e "${GREEN}✓ .env file decrypted successfully${NC}"
    else
        echo -e "${RED}✗ .env file not found after decryption${NC}"
        echo -e "${YELLOW}  Check service logs: journalctl -u potatostack-decrypt-env.service${NC}"
    fi
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo -e "${YELLOW}  Check service logs: journalctl -u potatostack-decrypt-env.service${NC}"
    exit 1
fi
echo ""

# Show status
echo -e "${BLUE}Service status:${NC}"
systemctl status potatostack-decrypt-env.service --no-pager
echo ""

# Final instructions
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✓ Auto-decrypt service installed and enabled${NC}"
echo -e "${GREEN}✓ .env will be automatically decrypted on boot${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Check status:  ${YELLOW}sudo systemctl status potatostack-decrypt-env${NC}"
echo "  View logs:     ${YELLOW}sudo journalctl -u potatostack-decrypt-env${NC}"
echo "  Restart:       ${YELLOW}sudo systemctl restart potatostack-decrypt-env${NC}"
echo "  Disable:       ${YELLOW}sudo systemctl disable potatostack-decrypt-env${NC}"
echo ""

exit 0
