#!/bin/sh
################################################################################
# Disk Space Monitor - Warn on high disk usage
################################################################################

set -eu

DISK_MONITOR_PATHS="${DISK_MONITOR_PATHS:-/mnt/storage /mnt/ssd /mnt/cachehdd}"
CHECK_INTERVAL="${DISK_MONITOR_INTERVAL:-300}"
WARN_THRESHOLD="${DISK_MONITOR_WARN:-80}"
CRIT_THRESHOLD="${DISK_MONITOR_CRIT:-90}"
NTFY_TAGS="${DISK_MONITOR_NTFY_TAGS:-storage,disk}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_disk() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

echo "=========================================="
echo "Disk Space Monitor Started"
echo "Paths: $DISK_MONITOR_PATHS"
echo "Warn: ${WARN_THRESHOLD}%  Crit: ${CRIT_THRESHOLD}%"
echo "Interval: ${CHECK_INTERVAL}s"
echo "=========================================="

STATE_FILE="/tmp/disk-monitor-state"
touch "$STATE_FILE"

while true; do
	for path in $DISK_MONITOR_PATHS; do
		if [ ! -d "$path" ]; then
			continue
		fi

		usage=$(df -P "$path" | awk 'NR==2 {gsub("%","",$5); print $5}')
		if [ -z "$usage" ]; then
			continue
		fi

		level="ok"
		if [ "$usage" -ge "$CRIT_THRESHOLD" ]; then
			level="crit"
		elif [ "$usage" -ge "$WARN_THRESHOLD" ]; then
			level="warn"
		fi

		prev=$(grep -F "${path}=" "$STATE_FILE" | tail -n1 | cut -d= -f2 || true)
		if [ "$level" != "$prev" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] $path usage ${usage}% ($level)"
			case "$level" in
			crit)
				notify_disk "PotatoStack - Disk critical" "${path} usage ${usage}% (>${CRIT_THRESHOLD}%)" "urgent"
				;;
			warn)
				notify_disk "PotatoStack - Disk warning" "${path} usage ${usage}% (>${WARN_THRESHOLD}%)" "high"
				;;
			ok)
				if [ -n "$prev" ] && [ "$prev" != "ok" ]; then
					notify_disk "PotatoStack - Disk recovered" "${path} usage ${usage}% back to normal" "low"
				fi
				;;
			esac
			grep -v -F "${path}=" "$STATE_FILE" >"${STATE_FILE}.tmp" || true
			mv "${STATE_FILE}.tmp" "$STATE_FILE"
			echo "${path}=${level}" >>"$STATE_FILE"
		fi
	done

	sleep "$CHECK_INTERVAL"
done
