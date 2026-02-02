#!/bin/bash
################################################################################
# Fix Docker Named Volume Permissions
# Run this if services fail with permission errors on named volumes
################################################################################

set -euo pipefail

echo "Fixing named volume permissions..."

# PostgreSQL (UID 999) - uses bind mount, handled by init-storage.sh

# Alertmanager (UID 65534)
docker run --rm -v potatostack_alertmanager-data:/data alpine chown -R 65534:65534 /data 2>/dev/null || true

# Grafana (UID 472)
docker run --rm -v potatostack_grafana-data:/data alpine chown -R 472:472 /data 2>/dev/null || true

echo "✓ Named volume permissions fixed"
