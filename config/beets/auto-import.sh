#!/bin/bash
# Beets auto-import from all music download sources
# Usage: docker exec -u abc beets bash /config/auto-import.sh
# Cron: docker exec -u abc beets bash /config/auto-import.sh 2>&1

set -euo pipefail

LOG=/config/auto-import.log
STAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo "$STAMP Starting auto-import" >> "$LOG"

# SpotiFLAC (primary, reliable metadata) - quiet mode safe
if [ -d /downloads/spotiflac ] && [ "$(ls -A /downloads/spotiflac 2>/dev/null)" ]; then
    echo "$STAMP Importing spotiflac..." >> "$LOG"
    beet import -q /downloads/spotiflac >> "$LOG" 2>&1 || echo "$STAMP spotiflac import failed or partial" >> "$LOG"
fi

# slskd (P2P, variable quality) - quiet mode with auto-apply
if [ -d /downloads/slskd ] && [ "$(ls -A /downloads/slskd 2>/dev/null)" ]; then
    echo "$STAMP Importing slskd..." >> "$LOG"
    beet import -q /downloads/slskd >> "$LOG" 2>&1 || echo "$STAMP slskd import failed or partial" >> "$LOG"
fi

# storage/downloads (secondary HDD staging)
if [ -d /storage-downloads ] && [ "$(ls -A /storage-downloads 2>/dev/null)" ]; then
    echo "$STAMP Importing storage-downloads..." >> "$LOG"
    beet import -q /storage-downloads >> "$LOG" 2>&1 || echo "$STAMP storage-downloads import failed or partial" >> "$LOG"
fi

echo "$STAMP Auto-import complete" >> "$LOG"
