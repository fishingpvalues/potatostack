#!/bin/sh
set -eu

SKIP_DIR="/downloads/.skip-index"
LOG_FILE="/downloads/tdl-download.log"
MAX_LOG_SIZE=10485760  # 10MB
MAX_RETRIES=0  # 0 = infinite retries
RETRY_DELAY=60
MAX_RETRY_DELAY=900    # cap at 15 min
VPN_WAIT_TIMEOUT=300   # 5 min max wait for VPN/internet
DOWNLOAD_TIMEOUT=600   # 10 min per attempt — kills hung tdl process
EXPORT_JSON="/downloads/saved-messages-all.json"
FILTERED_JSON="/downloads/saved-messages-filtered.json"
BLOCKLIST="/etc/tdl/blocklist.txt"  # message IDs to skip (one per line)

log() { echo "$(date): $*"; }

cleanup() {
  # Kill any lingering tdl download processes
  pkill -f "tdl download" 2>/dev/null || true
  # Clean up skip-index (remove symlinks first, then dir)
  if [ -d "$SKIP_DIR" ]; then
    find "$SKIP_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true
    rm -rf "$SKIP_DIR" 2>/dev/null || true
  fi
  # Clean up incomplete .tmp files older than 7 days
  find /adult-telegram -name '*.tmp' -mtime +7 -delete 2>/dev/null || true
}

# Always clean up on exit
trap cleanup EXIT

# Wait for internet connectivity (VPN through gluetun)
wait_for_internet() {
  local waited=0
  while [ "$waited" -lt "$VPN_WAIT_TIMEOUT" ]; do
    if wget -q -O /dev/null --timeout=5 http://1.1.1.1 2>/dev/null; then
      return 0
    fi
    sleep 10
    waited=$((waited + 10))
    log "Waiting for internet... (${waited}s/${VPN_WAIT_TIMEOUT}s)"
  done
  return 1
}

# --- Self-management ---

# Log rotation: keep last 500 lines if over 10MB
if [ -f "$LOG_FILE" ]; then
  log_size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$log_size" -gt "$MAX_LOG_SIZE" ]; then
    tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
    log "Log rotated (was ${log_size} bytes)"
  fi
fi

# Kill any stale tdl processes from previous failed runs
if pgrep -f "tdl download" >/dev/null 2>&1; then
  log "Killing stale tdl process from previous run"
  pkill -f "tdl download" 2>/dev/null || true
  sleep 3
  pkill -9 -f "tdl download" 2>/dev/null || true
  sleep 1
fi

# Clean stale skip-index from previous failed runs
cleanup

# --- Main ---

log "Starting Saved Messages video download"

# Wait for VPN/internet before doing anything
if ! wait_for_internet; then
  log "FATAL: No internet after ${VPN_WAIT_TIMEOUT}s, aborting"
  exit 1
fi

# Export all saved messages
tdl chat export -c 1015621977 -o "$EXPORT_JSON"

# Filter out blocked message IDs (broken/hung files)
if [ -f "$BLOCKLIST" ] && [ -s "$BLOCKLIST" ]; then
  log "Filtering out $(wc -l < "$BLOCKLIST") blocked message IDs"
  # Build awk pattern from blocklist
  awk_pattern=$(awk '{printf "%s|", $1}' "$BLOCKLIST" | sed 's/|$//')
  awk -v ids="$awk_pattern" '
    BEGIN { split(ids, blocked, "|"); for (i in blocked) b[blocked[i]]=1 }
    /"id":/ { match($0, /"id": *([0-9]+)/, m); if (m[1] in b) { skip=1; next } }
    !skip { print }
    skip && /\}/ { skip=0 }
  ' "$EXPORT_JSON" > "$FILTERED_JSON"
else
  cp "$EXPORT_JSON" "$FILTERED_JSON"
fi

# Build skip directory with symlinks to all existing videos in /adult
# so --skip-same can detect duplicates across the entire adult tree
mkdir -p "$SKIP_DIR"
find /adult -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.avi' \
  -o -name '*.mov' -o -name '*.wmv' -o -name '*.webm' \) \
  -exec ln -sf {} "$SKIP_DIR/" \;
log "Indexed $(ls "$SKIP_DIR" | wc -l) existing videos for dedup"

# Download with retries (infinite until success)
attempt=0
success=false
delay=$RETRY_DELAY
while true; do
  attempt=$((attempt + 1))
  log "=== TDL Download (attempt $attempt) ==="

  # Wait for internet before each attempt (VPN may have dropped)
  if ! wait_for_internet; then
    log "ERROR: No internet, retrying..."
    sleep "$delay"
    continue
  fi

  if timeout "$DOWNLOAD_TIMEOUT" tdl download \
    -f "$FILTERED_JSON" \
    -d "$SKIP_DIR" \
    -i mp4,mkv,avi,mov,wmv,webm \
    --skip-same \
    --desc \
    -l 2; then
    log "Download succeeded on attempt $attempt"
    success=true
    break
  fi
  exit_code=$?

  if [ "$exit_code" -eq 143 ]; then
    log "ERROR: Download timed out after ${DOWNLOAD_TIMEOUT}s (hung), killing and retrying"
  else
    log "ERROR: Download failed on attempt $attempt (exit $exit_code)"
  fi

  # Kill stale tdl process before retry (fixes "database used by another process")
  pkill -f "tdl download" 2>/dev/null || true
  sleep 3
  pkill -9 -f "tdl download" 2>/dev/null || true
  sleep 2

  log "Waiting ${delay}s before retry..."
  sleep "$delay"

  # Exponential backoff capped at MAX_RETRY_DELAY
  delay=$((delay * 2))
  if [ "$delay" -gt "$MAX_RETRY_DELAY" ]; then
    delay=$MAX_RETRY_DELAY
  fi
done

# Move only real files (not symlinks) to the telegram folder
moved=0
for f in "$SKIP_DIR"/*; do
  [ -e "$f" ] || continue
  [ -L "$f" ] && continue
  mv "$f" /adult-telegram/
  moved=$((moved + 1))
done

log "Done. Moved $moved new videos to /adult-telegram/"
