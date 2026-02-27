#!/bin/sh
set -eu

SKIP_DIR="/downloads/.skip-index"
LOG_FILE="/downloads/tdl-download.log"
MAX_LOG_SIZE=10485760  # 10MB
RETRY_DELAY=5          # 5s initial (was 60s)
MAX_RETRY_DELAY=60     # 1 min cap (was 15 min)
VPN_WAIT_TIMEOUT=300   # 5 min max wait for VPN/internet
DOWNLOAD_TIMEOUT=120   # 2 min per attempt (was 10 min) — 0 B/s files auto-blacklisted
EXPORT_JSON="/downloads/saved-messages-all.json"
FILTERED_JSON="/downloads/saved-messages-filtered.json"
BLOCKLIST="/etc/tdl/blocklist.txt"

log() { echo "$(date): $*"; }

# Build filtered JSON excluding blocklisted message IDs.
# Uses sed for reliable flat-JSON filtering — the export is ONE line so awk
# multi-line logic never worked. Three-pass sed handles all array positions:
#   pass 1: ,{"id":N,...}   (object preceded by comma — middle/last element)
#   pass 2: {"id":N,...},   (object followed by comma — first element)
#   pass 3: {"id":N,...}    (standalone — only element)
build_filtered_json() {
    cp "$EXPORT_JSON" "$FILTERED_JSON"
    if [ -f "$BLOCKLIST" ] && [ -s "$BLOCKLIST" ]; then
        local count
        count=$(grep -c '[0-9]' "$BLOCKLIST" 2>/dev/null || echo 0)
        log "Filtering out $count blocked message IDs from JSON"
        while IFS= read -r id || [ -n "$id" ]; do
            id=$(echo "$id" | tr -d '[:space:]')
            [ -z "$id" ] && continue
            sed -i \
                -e "s/,{\"id\":${id},[^}]*}//g" \
                -e "s/{\"id\":${id},[^}]*},//g" \
                -e "s/{\"id\":${id},[^}]*}//g" \
                "$FILTERED_JSON"
        done < "$BLOCKLIST"
    fi
}

# Auto-blacklist message IDs stuck at 0 B/s (parse captured tdl output).
# tdl prints: "ChatName(chatid):MSGID -> ~ ... 0.0% ... 0 B/s"
# Files at 0 B/s after DOWNLOAD_TIMEOUT seconds are definitively broken.
auto_blacklist_stuck() {
    local tmplog="$1"
    local new=0
    # Strip ANSI escape codes (\033[Nm etc.) and \r, then extract stuck IDs
    stuck_ids=$(tr -d '\033' < "$tmplog" | \
        sed 's/\[[0-9;?]*[mGKABCDHFJPsuhl]//g' | tr '\r' '\n' | \
        grep -E '\([0-9]+\):[0-9]+ ->' | \
        grep '0 B/s' | \
        grep -oE '\([0-9]+\):[0-9]+' | \
        grep -oE ':[0-9]+$' | \
        tr -d ':' | sort -u 2>/dev/null || true)
    for id in $stuck_ids; do
        [ -z "$id" ] && continue
        if ! grep -qxF "$id" "$BLOCKLIST" 2>/dev/null; then
            echo "$id" >> "$BLOCKLIST"
            log "AUTO-BLACKLISTED: message ID $id (0 B/s after ${DOWNLOAD_TIMEOUT}s)"
            new=$((new + 1))
        fi
    done
    if [ "$new" -gt 0 ]; then
        log "Added $new IDs to blocklist ($(wc -l < "$BLOCKLIST") total) — rebuilding filter"
        build_filtered_json
    fi
}

cleanup() {
    pkill -f "tdl download" 2>/dev/null || true
    if [ -d "$SKIP_DIR" ]; then
        find "$SKIP_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true
        rm -rf "$SKIP_DIR" 2>/dev/null || true
    fi
    find /adult-telegram -name '*.tmp' -mtime +7 -delete 2>/dev/null || true
}

trap cleanup EXIT

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

if [ -f "$LOG_FILE" ]; then
    log_size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$log_size" -gt "$MAX_LOG_SIZE" ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log "Log rotated (was ${log_size} bytes)"
    fi
fi

if pgrep -f "tdl download" >/dev/null 2>&1; then
    log "Killing stale tdl process from previous run"
    pkill -f "tdl download" 2>/dev/null || true
    sleep 3
    pkill -9 -f "tdl download" 2>/dev/null || true
    sleep 1
fi

cleanup

# --- Main ---

log "Starting Saved Messages video download (timeout: ${DOWNLOAD_TIMEOUT}s, retry: ${RETRY_DELAY}s→${MAX_RETRY_DELAY}s)"

if ! wait_for_internet; then
    log "FATAL: No internet after ${VPN_WAIT_TIMEOUT}s, aborting"
    exit 1
fi

tdl chat export -c 1015621977 -o "$EXPORT_JSON"
build_filtered_json

mkdir -p "$SKIP_DIR"
find /adult -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.avi' \
    -o -name '*.mov' -o -name '*.wmv' -o -name '*.webm' \) \
    -exec ln -sf {} "$SKIP_DIR/" \;
log "Indexed $(ls "$SKIP_DIR" | wc -l) existing videos for dedup"

attempt=0
success=false
delay=$RETRY_DELAY
tmplog=$(mktemp /tmp/tdl-run-XXXXXX.log)

while true; do
    attempt=$((attempt + 1))
    log "=== TDL Download (attempt $attempt) ==="

    if ! wait_for_internet; then
        log "ERROR: No internet, retrying in ${delay}s..."
        sleep "$delay"
        continue
    fi

    # Capture output for auto-blacklisting; cat to main log after attempt
    timeout "$DOWNLOAD_TIMEOUT" tdl download \
        -f "$FILTERED_JSON" \
        -d "$SKIP_DIR" \
        -i mp4,mkv,avi,mov,wmv,webm \
        --skip-same \
        --desc \
        -l 2 > "$tmplog" 2>&1 && tdl_exit=0 || tdl_exit=$?
    cat "$tmplog"

    if [ "$tdl_exit" -eq 0 ]; then
        log "Download succeeded on attempt $attempt"
        success=true
        break
    fi

    if [ "$tdl_exit" -eq 124 ] || [ "$tdl_exit" -eq 143 ]; then
        log "ERROR: Download timed out after ${DOWNLOAD_TIMEOUT}s"
    else
        log "ERROR: Download failed on attempt $attempt (exit $tdl_exit)"
    fi

    # Auto-blacklist any files stuck at 0 B/s, then rebuild filtered JSON
    auto_blacklist_stuck "$tmplog"

    pkill -f "tdl download" 2>/dev/null || true
    sleep 2
    pkill -9 -f "tdl download" 2>/dev/null || true
    sleep 1

    log "Retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
    [ "$delay" -gt "$MAX_RETRY_DELAY" ] && delay=$MAX_RETRY_DELAY
done

rm -f "$tmplog"

moved=0
for f in "$SKIP_DIR"/*; do
    [ -e "$f" ] || continue
    [ -L "$f" ] && continue
    mv "$f" /adult-telegram/
    moved=$((moved + 1))
done

log "Done. Moved $moved new videos to /adult-telegram/"
