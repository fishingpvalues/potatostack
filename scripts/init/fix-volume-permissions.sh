#!/bin/bash
################################################################################
# Fix Docker Named Volume and Bind Mount Permissions
# Run this if services fail with permission errors on volumes
################################################################################

set -euo pipefail

SSD_BASE="/mnt/ssd/docker-data"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo "Fixing named volume permissions..."

# PostgreSQL (UID 999) - uses bind mount, handled by init-storage.sh

# Alertmanager (UID 65534)
docker run --rm -v potatostack_alertmanager-data:/data alpine chown -R 65534:65534 /data 2>/dev/null || true

# Grafana (UID 472)
docker run --rm -v potatostack_grafana-data:/data alpine chown -R 472:472 /data 2>/dev/null || true

echo "✓ Named volume permissions fixed"

echo "Fixing bind mount permissions..."

# Recyclarr (UID 1000) - needs proper ownership for /config/cache
if [ -d "${SSD_BASE}/recyclarr" ]; then
	echo "  Fixing recyclarr permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/recyclarr"
fi

# Notifiarr (UID 1000)
if [ -d "${SSD_BASE}/notifiarr" ]; then
	echo "  Fixing notifiarr permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/notifiarr"
fi

# Uptime-Kuma (UID 1000) - DISABLED
# if [ -d "${SSD_BASE}/uptime-kuma" ]; then
# 	echo "  Fixing uptime-kuma permissions..."
# 	chown -R "${PUID}:${PGID}" "${SSD_BASE}/uptime-kuma"
# fi

# Velld (UID 1000)
if [ -d "${SSD_BASE}/velld" ]; then
	echo "  Fixing velld permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/velld"
fi

echo "✓ Bind mount permissions fixed"
