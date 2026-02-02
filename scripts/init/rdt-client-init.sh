#!/bin/bash
################################################################################
# rdt-client Init Script - Create directories and configure hooks
# Mounted to /etc/cont-init.d/ (runs before app starts)
################################################################################
set -euo pipefail

echo "[rdt-init] Setting up rdt-client..."

# Create download/cache directories
mkdir -p /downloads /data/db/logs

# Make hook script executable
chmod +x /hooks/post-download.sh 2>/dev/null || true

echo "[rdt-init] Downloads: /downloads (direct to storage)"
echo "[rdt-init] Database: /data/db"
echo "[rdt-init] Setup complete"
echo "[rdt-init] NOTE: Configure Real-Debrid API key and download paths in WebUI at port 6500"
