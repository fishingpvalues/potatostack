#!/bin/bash
################################################################################
# Unpackerr Cleanup - Removes partial extractions before startup
################################################################################

set -euo pipefail

DOWNLOADS_BASE="/downloads"

echo "[$(date)] Cleaning up partial extractions..."

# Remove common partial extraction patterns
find "${DOWNLOADS_BASE}" -type d -name ".unpackerr" -exec rm -rf {} + 2>/dev/null || true
find "${DOWNLOADS_BASE}" -type d -name "_UNPACK" -exec rm -rf {} + 2>/dev/null || true
find "${DOWNLOADS_BASE}" -type f -name "extracting_*.tmp" -delete 2>/dev/null || true
find "${DOWNLOADS_BASE}" -type f -name "*.part" -delete 2>/dev/null || true

# Remove empty directories BUT exclude watch folders
find "${DOWNLOADS_BASE}" -type d -empty ! -name "torrents" ! -name "aria2" ! -name "slskd" ! -name "pyload" ! -name "telegram" -delete 2>/dev/null || true

echo "[$(date)] Cleanup complete"
