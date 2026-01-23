#!/bin/sh
################################################################################
# Traefik Log Monitor - Detect TLS/ACME errors and optionally restart
################################################################################

set -eu

# docker:cli image already has docker command

TRAEFIK_CONTAINER="${TRAEFIK_CONTAINER:-traefik}"
CHECK_INTERVAL="${TRAEFIK_LOG_CHECK_INTERVAL:-60}"
LOG_PATTERNS="${TRAEFIK_LOG_PATTERNS:-acme|certificate|x509|tls}"
LEVEL_PATTERN="${TRAEFIK_LOG_LEVEL_PATTERN:-level=error}"
RESTART_ON_ERROR="${TRAEFIK_RESTART_ON_ERROR:-false}"
RESTART_COOLDOWN="${TRAEFIK_RESTART_COOLDOWN:-300}"

echo "=========================================="
echo "Traefik Log Monitor Started"
echo "Container: $TRAEFIK_CONTAINER"
echo "Patterns: $LOG_PATTERNS"
echo "Level filter: $LEVEL_PATTERN"
echo "Restart on error: $RESTART_ON_ERROR"
echo "Interval: ${CHECK_INTERVAL}s"
echo "Cooldown: ${RESTART_COOLDOWN}s"
echo "=========================================="

LAST_RESTART=0

while true; do
	logs=$(docker logs --since "${CHECK_INTERVAL}s" "$TRAEFIK_CONTAINER" 2>&1 || true)
	if [ -n "$LEVEL_PATTERN" ]; then
		matches=$(echo "$logs" | grep -Ei "$LOG_PATTERNS" | grep -Ei "$LEVEL_PATTERN" || true)
	else
		matches=$(echo "$logs" | grep -Ei "$LOG_PATTERNS" || true)
	fi

	if [ -n "$matches" ]; then
		now=$(date +%s)
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Traefik log pattern matched"
		if [ "$RESTART_ON_ERROR" = "true" ] && [ $((now - LAST_RESTART)) -ge "$RESTART_COOLDOWN" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting $TRAEFIK_CONTAINER"
			docker restart "$TRAEFIK_CONTAINER" >/dev/null 2>&1 || true
			LAST_RESTART=$now
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
