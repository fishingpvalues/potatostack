#!/bin/bash
# Beets auto-import from all music download sources
# Usage: docker exec -u abc beets bash /config/auto-import.sh
# Cron: docker exec -u abc beets bash /config/auto-import.sh 2>&1

set -euo pipefail

LOG=/config/auto-import.log
STAMP="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo "$STAMP Starting auto-import" >> "$LOG"

# SpotiFLAC (primary, reliable metadata)
# -s: singleton mode (individual tracks, not albums)
# -A: no autotag (MusicBrainz matching fails for comma-separated multi-artists)
# Move mode is set in config.yaml (move: yes)
if [ -d /downloads/spotiflac ] && [ "$(ls -A /downloads/spotiflac 2>/dev/null)" ]; then
    echo "$STAMP Importing spotiflac (singleton, noautotag)..." >> "$LOG"
    beet import -q -s -A /downloads/spotiflac >> "$LOG" 2>&1 || echo "$STAMP spotiflac import failed or partial" >> "$LOG"
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

# Remove SpotiFLAC/Qobuz comment watermarks from all library tracks
echo "$STAMP Clearing SpotiFLAC comment tags..." >> "$LOG"
beet modify -y "comments=" "comments::github.com/afkarxyz" >> "$LOG" 2>&1 || true
beet modify -y "comments=" "comments::qobuz.com" >> "$LOG" 2>&1 || true

echo "$STAMP Auto-import complete" >> "$LOG"
