#!/bin/sh
################################################################################
# slskd Queue & Download Monitor - Queue thresholds + download complete alerts
################################################################################

set -eu

DB_PATH="${SLSKD_DB_PATH:-/slskd/data/transfers.db}"
CHECK_INTERVAL="${SLSKD_QUEUE_CHECK_INTERVAL:-60}"
QUEUE_LIMIT="${SLSKD_QUEUE_FILES:-500}"
WARN_PERCENT="${SLSKD_QUEUE_WARN_PERCENT:-80}"
NOTIFY_LIMIT="${SLSKD_NOTIFY_LIMIT:-5}"
NTFY_TAGS="${SLSKD_NTFY_TAGS:-slskd,downloads}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_slskd() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

if ! command -v sqlite3 >/dev/null 2>&1; then
	echo "Installing sqlite3..."
	apk add --no-cache sqlite >/dev/null 2>&1 || true
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
	echo "sqlite3 not available; sleeping indefinitely."
	exec sleep infinity
fi

if [ ! -f "$DB_PATH" ]; then
	echo "Transfers DB not found at $DB_PATH; sleeping."
	exec sleep infinity
fi

echo "=========================================="
echo "slskd Queue Monitor Started"
echo "DB: $DB_PATH"
echo "Queue limit: ${QUEUE_LIMIT}  Warn at: ${WARN_PERCENT}%"
echo "Interval: ${CHECK_INTERVAL}s"
echo "=========================================="

STATE_FILE="/tmp/slskd-queue-state"
if [ ! -f "$STATE_FILE" ]; then
	echo "state=ok" > "$STATE_FILE"
	echo "last_seen=0" >> "$STATE_FILE"
fi

get_state() {
	grep -E "^state=" "$STATE_FILE" | cut -d= -f2
}

get_last_seen() {
	grep -E "^last_seen=" "$STATE_FILE" | cut -d= -f2
}

set_state() {
	state="$1"
	last_seen="$2"
	echo "state=${state}" > "$STATE_FILE"
	echo "last_seen=${last_seen}" >> "$STATE_FILE"
}

while true; do
	queued=$(sqlite3 -noheader -batch "$DB_PATH" "select count(*) from Transfers where Direction='Download' and Removed=0 and EnqueuedAt is not null and StartedAt is null;" 2>/dev/null || echo 0)
	if [ -z "$queued" ]; then
		queued=0
	fi

	warn_threshold=$((QUEUE_LIMIT * WARN_PERCENT / 100))
	if [ "$queued" -ge "$QUEUE_LIMIT" ]; then
		new_state="full"
	elif [ "$queued" -ge "$warn_threshold" ]; then
		new_state="warn"
	else
		new_state="ok"
	fi

	prev_state=$(get_state)
	if [ "$new_state" != "$prev_state" ]; then
		case "$new_state" in
			full)
				notify_slskd "PotatoStack - slskd queue full" "Queued downloads: ${queued}/${QUEUE_LIMIT} (limit reached)." "urgent"
				;;
			warn)
				notify_slskd "PotatoStack - slskd queue warning" "Queued downloads: ${queued}/${QUEUE_LIMIT} (>${WARN_PERCENT}%)." "high"
				;;
			ok)
				if [ "$prev_state" != "ok" ]; then
					notify_slskd "PotatoStack - slskd queue recovered" "Queue back to normal: ${queued}/${QUEUE_LIMIT}." "low"
				fi
				;;
			esac
	fi

	last_seen=$(get_last_seen)
	latest=$(sqlite3 -noheader -batch "$DB_PATH" "select max(strftime('%s', EndedAt)) from Transfers where Direction='Download' and EndedAt is not null and StateDescription like 'Completed%';" 2>/dev/null || echo 0)
	if [ -z "$latest" ] || [ "$latest" = "" ]; then
		latest=0
	fi

	if [ "$latest" -gt "$last_seen" ]; then
		new_downloads=$(sqlite3 -noheader -batch "$DB_PATH" "select Filename from Transfers where Direction='Download' and EndedAt is not null and StateDescription like 'Completed%' and strftime('%s', EndedAt) > ${last_seen} order by EndedAt desc limit ${NOTIFY_LIMIT};" 2>/dev/null || true)
		count_new=$(sqlite3 -noheader -batch "$DB_PATH" "select count(*) from Transfers where Direction='Download' and EndedAt is not null and StateDescription like 'Completed%' and strftime('%s', EndedAt) > ${last_seen};" 2>/dev/null || echo 0)
		if [ -n "$new_downloads" ] && [ "$count_new" -gt 0 ]; then
			list=$(echo "$new_downloads" | sed 's/^/- /')
			if [ "$count_new" -gt "$NOTIFY_LIMIT" ]; then
				list="$list\n...and $((count_new - NOTIFY_LIMIT)) more"
			fi
			notify_slskd "PotatoStack - slskd downloads complete" "${count_new} download(s) completed:\n${list}" "default"
		fi
	fi

	set_state "$new_state" "$latest"
	sleep "$CHECK_INTERVAL"
done
