#!/bin/sh
################################################################################
# Backup Monitor - Warn if backups are stale
################################################################################

set -eu

BACKUP_PATHS="${BACKUP_MONITOR_PATHS:-/mnt/storage/kopia/stack-snapshot.log /mnt/storage/velld/backups}"
MAX_AGE_HOURS="${BACKUP_MAX_AGE_HOURS:-48}"
CHECK_INTERVAL="${BACKUP_MONITOR_INTERVAL:-3600}"

echo "=========================================="
echo "Backup Monitor Started"
echo "Paths: $BACKUP_PATHS"
echo "Max age: ${MAX_AGE_HOURS}h"
echo "Interval: ${CHECK_INTERVAL}s"
echo "=========================================="

MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 3600))

while true; do
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

		if [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Backup stale: $path (age ${age}s)"
		fi
	done

	sleep "$CHECK_INTERVAL"
done
