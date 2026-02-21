#!/bin/sh
################################################################################
# Unpackerr Entrypoint - Handles startup cleanup and launches Unpackerr
################################################################################

set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo "[$(date)] Starting Unpackerr with enhanced configuration..."

# Trap signals for graceful shutdown
trap 'echo "[$(date)] Caught signal, exiting..."; exit 0' TERM INT

# 1. Run cleanup (remove partial extractions from crashes)
echo "[$(date)] Running pre-startup cleanup..."
if [ -f "/cleanup.sh" ]; then
	/cleanup.sh
fi

# 2. Launch Unpackerr with original binary
echo "[$(date)] Launching Unpackerr..."
exec /app/unpackerr "$@"
