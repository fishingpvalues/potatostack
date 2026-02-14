#!/bin/sh
################################################################################
# Backup Monitor - Warn if backups are stale
################################################################################

set -eu

BACKUP_PATHS="${BACKUP_MONITOR_PATHS:-/mnt/storage/stack-snapshot.log /mnt/storage/velld/backups /mnt/storage/backrest/repos}"
MAX_AGE_HOURS="${BACKUP_MAX_AGE_HOURS:-24}"
CHECK_INTERVAL="${BACKUP_MONITOR_INTERVAL:-3600}"
NTFY_TAGS="${BACKUP_MONITOR_NTFY_TAGS:-backup,storage}"
NTFY_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_backup() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

echo "=========================================="
echo "Backup Monitor Started"
echo "Paths: $BACKUP_PATHS"
echo "Max age: ${MAX_AGE_HOURS}h"
echo "Interval: ${CHECK_INTERVAL}s"
echo "=========================================="

MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 3600))
STATE_FILE="/tmp/backup-monitor-state"
touch "$STATE_FILE"

while true; do
	now=$(date +%s)
	now=$(date +%s)
	for path in $BACKUP_PATHS; do
		if [ -f "$path" ]; then
			mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
			age=$((now - mtime))
		elif [ -d "$path" ]; then
			latest=$(ls -1t "$path" 2>/dev/null | head -n1 || true)
			if [ -z "$latest" ]; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ No backups found in $path"
				continue
			fi
			mtime=$(stat -c %Y "$path/$latest" 2>/dev/null || echo 0)
			age=$((now - mtime))
		else
			continue
		fi

		state="ok"
		if [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
			state="stale"
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Backup stale: $path (age ${age}s)"
		fi

		prev=$(grep -F "${path}=" "$STATE_FILE" | tail -n1 | cut -d= -f2 || true)
		if [ "$state" != "$prev" ]; then
			if [ "$state" = "stale" ]; then
				notify_backup "PotatoStack - Backup stale" "Backup stale for ${path} (age ${age}s, limit ${MAX_AGE_SECONDS}s)" "high"
			elif [ "$state" = "ok" ] && [ -n "$prev" ]; then
				notify_backup "PotatoStack - Backup recovered" "Backup updated for ${path}" "low"
			fi
			grep -v -F "${path}=" "$STATE_FILE" >"${STATE_FILE}.tmp" || true
			mv "${STATE_FILE}.tmp" "$STATE_FILE"
			echo "${path}=${state}" >>"$STATE_FILE"
		fi
	done

	sleep "$CHECK_INTERVAL"
done
