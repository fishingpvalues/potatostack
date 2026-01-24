#!/bin/sh
################################################################################
# Immich Log Monitor - Restart Immich on error patterns + verify reachability
################################################################################

set -eu

# docker:cli image already has docker command

IMMICH_CONTAINER="${IMMICH_CONTAINER:-immich-server}"
IMMICH_ML_CONTAINER="${IMMICH_ML_CONTAINER:-immich-ml}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"
REACHABILITY_TIMEOUT="${REACHABILITY_TIMEOUT:-120}"
REACHABILITY_RETRIES="${REACHABILITY_RETRIES:-6}"
LOG_PATTERNS="${IMMICH_LOG_PATTERNS:-redis|Redis|ECONNREFUSED|Connection refused|connect ECONNREFUSED|socket hang up}"

echo "=========================================="
echo "Immich Log Monitor Started"
echo "=========================================="
echo "Monitoring: $IMMICH_CONTAINER"
echo "Patterns: $LOG_PATTERNS"
echo "Interval: ${CHECK_INTERVAL}s"
echo "Cooldown: ${RESTART_COOLDOWN}s"
echo "Reachability: ${REACHABILITY_RETRIES} retries, ${REACHABILITY_TIMEOUT}s timeout"
echo "=========================================="

LAST_RESTART=0

# Check if immich-server is reachable via its health endpoint
check_immich_reachable() {
	docker exec "$IMMICH_CONTAINER" sh -c 'curl -sf http://127.0.0.1:2283/api/server/ping >/dev/null 2>&1' 2>/dev/null
}

# Check if immich-ml is reachable via its health endpoint
check_ml_reachable() {
	docker exec "$IMMICH_ML_CONTAINER" sh -c 'python3 -c "import requests; requests.get(\"http://127.0.0.1:3003/ping\")"' 2>/dev/null
}

# Wait for service to become reachable after restart
wait_for_reachable() {
	service_name="$1"
	check_func="$2"
	retry_interval=$((REACHABILITY_TIMEOUT / REACHABILITY_RETRIES))

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ Waiting for $service_name to become reachable..."

	attempts=0
	while [ $attempts -lt "$REACHABILITY_RETRIES" ]; do
		sleep "$retry_interval"
		attempts=$((attempts + 1))

		if $check_func; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $service_name is reachable (attempt $attempts/$REACHABILITY_RETRIES)"
			return 0
		fi
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ $service_name not yet reachable (attempt $attempts/$REACHABILITY_RETRIES)"
	done

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $service_name failed to become reachable after $REACHABILITY_TIMEOUT seconds"
	return 1
}

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

			# Verify services are reachable after restart
			wait_for_reachable "$IMMICH_CONTAINER" check_immich_reachable || true

			if docker ps --format '{{.Names}}' | grep -q "^${IMMICH_ML_CONTAINER}\$"; then
				wait_for_reachable "$IMMICH_ML_CONTAINER" check_ml_reachable || true
			fi

			LAST_RESTART=$now
		else
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Pattern matched but in cooldown"
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
