#!/bin/sh
set -eu

# --- Config ---
SKIP_DIR="/downloads/.skip-index"
LOG_FILE="/downloads/tdl-download.log"
MAX_LOG_SIZE=10485760
RETRY_DELAY=10
MAX_RETRY_DELAY=300
VPN_WAIT_TIMEOUT=300
DOWNLOAD_TIMEOUT=21600          # 6h — large batch headroom

EXPORT_JSON="/downloads/saved-messages-all.json"
FILTERED_JSON="/downloads/saved-messages-filtered.json"
BLOCKLIST="/etc/tdl/blocklist.txt"              # user-managed permanent exclusions (never touched by script)
AUTO_BLOCKLIST="/downloads/.tdl-auto-blocklist.txt"  # script-managed, resets on success or weekly
STRIKE_FILE="/downloads/.tdl-strikes.txt"            # "ID count" — promoted at threshold
RESET_TIMESTAMP="/downloads/.tdl-last-reset"

STRIKE_THRESHOLD=3              # consecutive 0 B/s failures before auto-block
AUTO_RESET_INTERVAL=604800      # 7 days in seconds — reset auto-blocklist regardless

log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): $*"; }

# ---------------------------------------------------------------------------
# Filter: build combined sed script from both blocklists, single-pass
# ---------------------------------------------------------------------------
build_filtered_json() {
	cp "$EXPORT_JSON" "$FILTERED_JSON"
	local tmpids tmpscript perm_count auto_count
	tmpids=$(mktemp)
	tmpscript=$(mktemp)

	{ cat "$BLOCKLIST" 2>/dev/null; cat "$AUTO_BLOCKLIST" 2>/dev/null; } \
		| grep -E '^[0-9]+$' | sort -u > "$tmpids"

	perm_count=$(grep -c '.' "$BLOCKLIST" 2>/dev/null || echo 0)
	auto_count=$(grep -c '.' "$AUTO_BLOCKLIST" 2>/dev/null || echo 0)
	log "Filtering $(wc -l < "$tmpids") IDs (${perm_count} permanent + ${auto_count} auto)"

	while IFS= read -r id; do
		[ -z "$id" ] && continue
		# Three patterns cover all array positions (middle, first, only element)
		printf 's/,{"id":%s,"type":"message","file":"[^"]*"}//g\n' "$id" >> "$tmpscript"
		printf 's/{"id":%s,"type":"message","file":"[^"]*"},//g\n'  "$id" >> "$tmpscript"
		printf 's/{"id":%s,"type":"message","file":"[^"]*"}//g\n'   "$id" >> "$tmpscript"
	done < "$tmpids"

	if [ -s "$tmpscript" ]; then
		sed -i -f "$tmpscript" "$FILTERED_JSON"
	fi
	rm -f "$tmpids" "$tmpscript"
}

# ---------------------------------------------------------------------------
# Strike system: 3 hits → auto-block; returns 0 if newly blocked
# ---------------------------------------------------------------------------
record_strike() {
	local id="$1"
	local current new tmpfile

	current=$(grep "^${id} " "$STRIKE_FILE" 2>/dev/null | awk '{print $2}' || echo 0)
	new=$((current + 1))

	# Update strike file atomically
	tmpfile=$(mktemp)
	grep -v "^${id} " "$STRIKE_FILE" 2>/dev/null > "$tmpfile" || true
	if [ "$new" -lt "$STRIKE_THRESHOLD" ]; then
		echo "${id} ${new}" >> "$tmpfile"
	fi
	mv "$tmpfile" "$STRIKE_FILE"

	if [ "$new" -ge "$STRIKE_THRESHOLD" ]; then
		if ! grep -qxF "$id" "$AUTO_BLOCKLIST" 2>/dev/null; then
			echo "$id" >> "$AUTO_BLOCKLIST"
			log "AUTO-BLOCKED: message $id (${new}/${STRIKE_THRESHOLD} strikes)"
		fi
		return 0
	else
		log "STRIKE ${new}/${STRIKE_THRESHOLD}: message $id"
		return 1
	fi
}

# ---------------------------------------------------------------------------
# Process stuck files after a failed/timed-out run
# ---------------------------------------------------------------------------
process_stuck_files() {
	local tmplog="$1"
	local new_blocks=0 new_strikes=0

	stuck_ids=$(tr -d '\033' < "$tmplog" \
		| sed 's/\[[0-9;?]*[mGKABCDHFJPsuhl]//g' | tr '\r' '\n' \
		| grep -E '\([0-9]+\):[0-9]+ ->' \
		| grep '0 B/s' \
		| grep -oE '\([0-9]+\):[0-9]+' \
		| grep -oE ':[0-9]+$' \
		| tr -d ':' | sort -u 2>/dev/null || true)

	for id in $stuck_ids; do
		[ -z "$id" ] && continue
		# Skip IDs already in any blocklist
		if grep -qxF "$id" "$BLOCKLIST" 2>/dev/null \
			|| grep -qxF "$id" "$AUTO_BLOCKLIST" 2>/dev/null; then
			continue
		fi
		if record_strike "$id"; then
			new_blocks=$((new_blocks + 1))
		else
			new_strikes=$((new_strikes + 1))
		fi
	done

	if [ "$new_blocks" -gt 0 ]; then
		log "Blocked $new_blocks IDs this run, $new_strikes new strikes — rebuilding filter"
		build_filtered_json
		return 0  # signal: filter changed
	elif [ "$new_strikes" -gt 0 ]; then
		log "Recorded $new_strikes new strikes (no new blocks yet)"
	fi
	return 1  # no filter change
}

# ---------------------------------------------------------------------------
# Auto-blocklist reset
# ---------------------------------------------------------------------------
reset_auto_blocklist() {
	local reason="$1"
	local auto_count strike_count
	auto_count=$(grep -c '.' "$AUTO_BLOCKLIST" 2>/dev/null || echo 0)
	strike_count=$(grep -c '.' "$STRIKE_FILE" 2>/dev/null || echo 0)
	> "$AUTO_BLOCKLIST"
	> "$STRIKE_FILE"
	date +%s > "$RESET_TIMESTAMP"
	log "RESET (${reason}): cleared ${auto_count} auto-blocked IDs and ${strike_count} strikes"
}

check_weekly_reset() {
	local now last_reset
	now=$(date +%s)
	last_reset=$(cat "$RESET_TIMESTAMP" 2>/dev/null || echo 0)
	if [ $((now - last_reset)) -ge "$AUTO_RESET_INTERVAL" ]; then
		reset_auto_blocklist "weekly scheduled"
		build_filtered_json
	fi
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
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

rotate_log() {
	if [ -f "$LOG_FILE" ]; then
		local size
		size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
		if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
			tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp"
			mv "${LOG_FILE}.tmp" "$LOG_FILE"
			log "Log rotated (was ${size} bytes)"
		fi
	fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
rotate_log

if pgrep -f "tdl download" > /dev/null 2>&1; then
	log "Killing stale tdl process from previous run"
	pkill -f "tdl download" 2>/dev/null || true
	sleep 3
	pkill -9 -f "tdl download" 2>/dev/null || true
	sleep 1
fi

cleanup

log "=== Starting Saved Messages download (timeout: ${DOWNLOAD_TIMEOUT}s, strike threshold: ${STRIKE_THRESHOLD}) ==="

if ! wait_for_internet; then
	log "FATAL: No internet after ${VPN_WAIT_TIMEOUT}s, aborting"
	exit 1
fi

# Check weekly reset before export
check_weekly_reset

# Export and build initial filtered list
tdl chat export -c 1015621977 -o "$EXPORT_JSON"
build_filtered_json

# Build skip-index from existing files (dedup)
mkdir -p "$SKIP_DIR"
find /adult -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.avi' \
	-o -name '*.mov' -o -name '*.wmv' -o -name '*.webm' \) \
	-exec ln -sf {} "$SKIP_DIR/" \;
log "Indexed $(ls "$SKIP_DIR" | wc -l) existing videos for dedup"

attempt=0
delay=$RETRY_DELAY
tmplog=$(mktemp /tmp/tdl-run-XXXXXX)

while true; do
	attempt=$((attempt + 1))
	log "=== Download attempt $attempt ==="

	if ! wait_for_internet; then
		log "ERROR: No internet, retrying in ${delay}s..."
		sleep "$delay"
		delay=$((delay * 2))
		[ "$delay" -gt "$MAX_RETRY_DELAY" ] && delay=$MAX_RETRY_DELAY
		continue
	fi

	timeout "$DOWNLOAD_TIMEOUT" tdl download \
		-f "$FILTERED_JSON" \
		-d "$SKIP_DIR" \
		-i mp4,mkv,avi,mov,wmv,webm \
		--skip-same \
		--desc \
		-l 2 > "$tmplog" 2>&1 && tdl_exit=0 || tdl_exit=$?
	cat "$tmplog"

	if [ "$tdl_exit" -eq 0 ]; then
		log "All downloads complete on attempt $attempt"
		# Success: reset auto-blocklist so next run retries previously stuck files
		reset_auto_blocklist "successful run"
		break
	fi

	if [ "$tdl_exit" -eq 124 ] || [ "$tdl_exit" -eq 143 ]; then
		log "ERROR: Timed out after ${DOWNLOAD_TIMEOUT}s on attempt $attempt"
	else
		log "ERROR: Download failed (exit ${tdl_exit}) on attempt $attempt"
	fi

	# Record strikes; if new blocks were promoted, filter is already rebuilt
	process_stuck_files "$tmplog" || true

	pkill -f "tdl download" 2>/dev/null || true
	sleep 2
	pkill -9 -f "tdl download" 2>/dev/null || true

	log "Retrying in ${delay}s..."
	sleep "$delay"
	delay=$((delay * 2))
	[ "$delay" -gt "$MAX_RETRY_DELAY" ] && delay=$MAX_RETRY_DELAY
done

rm -f "$tmplog"

# Move newly downloaded files out of skip-index to final destination
moved=0
for f in "$SKIP_DIR"/*; do
	[ -e "$f" ] || continue
	[ -L "$f" ] && continue   # skip existing-file symlinks
	mv "$f" /adult-telegram/
	moved=$((moved + 1))
done

log "Done. Moved $moved new videos to /adult-telegram/"
