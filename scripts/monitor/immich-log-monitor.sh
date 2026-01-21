#!/bin/sh
################################################################################
# Immich Log Monitor - Restart Immich on error patterns
################################################################################

set -eu

if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker CLI..."
	apk add --no-cache docker-cli >/dev/null 2>&1
fi

IMMICH_CONTAINER="${IMMICH_CONTAINER:-immich-server}"
IMMICH_ML_CONTAINER="${IMMICH_ML_CONTAINER:-immich-ml}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"
LOG_PATTERNS="${IMMICH_LOG_PATTERNS:-redis|Redis|ECONNREFUSED|Connection refused|connect ECONNREFUSED|socket hang up}"

echo "=========================================="
echo "Immich Log Monitor Started"
echo "=========================================="
echo "Monitoring: $IMMICH_CONTAINER"
echo "Patterns: $LOG_PATTERNS"
echo "Interval: ${CHECK_INTERVAL}s"
echo "Cooldown: ${RESTART_COOLDOWN}s"
echo "=========================================="

LAST_RESTART=0

while true; do
	now=$(date +%s)
	logs=$(docker logs --since "${CHECK_INTERVAL}s" "$IMMICH_CONTAINER" 2>&1 || true)

	if echo "$logs" | grep -Eqi "$LOG_PATTERNS"; then
		if [ $((now - LAST_RESTART)) -ge "$RESTART_COOLDOWN" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Error pattern detected"
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting $IMMICH_CONTAINER"
			docker restart "$IMMICH_CONTAINER" >/dev/null 2>&1 || true

			if docker ps --format '{{.Names}}' | grep -q "^${IMMICH_ML_CONTAINER}\$"; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting $IMMICH_ML_CONTAINER"
				docker restart "$IMMICH_ML_CONTAINER" >/dev/null 2>&1 || true
			fi

			LAST_RESTART=$now
		else
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Pattern matched but in cooldown"
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
