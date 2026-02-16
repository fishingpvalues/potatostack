#!/bin/bash
################################################################################
# Fix Backrest SSH Permissions
# Corrects ownership and permissions for SSH keys used by backrest
################################################################################

set -euo pipefail

BACKREST_SSH="/mnt/ssd/docker-data/backrest/ssh"
BACKREST_CONTAINER="backrest"

echo "=========================================="
echo "Fixing Backrest SSH Permissions"
echo "=========================================="

if [ ! -d "$BACKREST_SSH" ]; then
	echo "❌ SSH directory not found: $BACKREST_SSH"
	echo "   Please set up SSH keys first"
	exit 1
fi

echo "Current permissions:"
ls -la "$BACKREST_SSH"

echo ""
echo "Fixing ownership to root:root..."
sudo chown -R root:root "$BACKREST_SSH"

echo "Fixing permissions..."
sudo chmod 700 "$BACKREST_SSH"
sudo chmod 600 "$BACKREST_SSH/config" 2>/dev/null || echo "  (config not found)"
sudo chmod 600 "$BACKREST_SSH/id_ed25519" 2>/dev/null || echo "  (id_ed25519 not found)"
sudo chmod 644 "$BACKREST_SSH/id_ed25519.pub" 2>/dev/null || echo "  (id_ed25519.pub not found)"
sudo chmod 600 "$BACKREST_SSH/known_hosts" 2>/dev/null || echo "  (known_hosts not found)"

echo ""
echo "Fixed permissions:"
ls -la "$BACKREST_SSH"

echo ""
echo "=========================================="
echo "Restarting backrest container..."
echo "=========================================="
docker compose restart backrest

echo ""
echo "✓ SSH permissions fixed and backrest restarted"
echo ""
echo "Test SSH connection:"
echo "  docker exec backrest ssh -oBatchMode=yes -oConnectTimeout=5 u546612@u546612.your-storagebox.de echo 'Success'"
