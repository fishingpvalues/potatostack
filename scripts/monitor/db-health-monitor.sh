#!/bin/sh
################################################################################
# DB Health Monitor - Restart services on repeated failures
################################################################################

set -eu

# docker:cli image already has docker command

CHECK_INTERVAL="${DB_MONITOR_INTERVAL:-30}"
FAIL_THRESHOLD="${DB_FAIL_THRESHOLD:-3}"
RESTART_COOLDOWN="${DB_RESTART_COOLDOWN:-180}"
RESTART_ON_FAILURE="${DB_RESTART_ON_FAILURE:-true}"

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-redis-cache}"
MONGO_CONTAINER="${MONGO_CONTAINER:-mongo}"

CHECK_POSTGRES="${DB_CHECK_POSTGRES:-true}"
CHECK_REDIS="${DB_CHECK_REDIS:-true}"
CHECK_MONGO="${DB_CHECK_MONGO:-false}"

pg_fail=0
redis_fail=0
mongo_fail=0
last_restart=0

echo "=========================================="
echo "DB Health Monitor Started"
echo "Interval: ${CHECK_INTERVAL}s  Fail threshold: ${FAIL_THRESHOLD}"
echo "Restart on failure: ${RESTART_ON_FAILURE}"
echo "=========================================="

restart_container() {
	local name="$1"
	local now
	now=$(date +%s)
	if [ $((now - last_restart)) -lt "$RESTART_COOLDOWN" ]; then
		return
	fi
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting $name"
	docker restart "$name" >/dev/null 2>&1 || true
	last_restart=$now
}

while true; do
	if [ "$CHECK_POSTGRES" = "true" ]; then
		if docker exec "$POSTGRES_CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then
			pg_fail=0
		else
			pg_fail=$((pg_fail + 1))
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Postgres health failed ($pg_fail/$FAIL_THRESHOLD)"
			if [ "$RESTART_ON_FAILURE" = "true" ] && [ "$pg_fail" -ge "$FAIL_THRESHOLD" ]; then
				restart_container "$POSTGRES_CONTAINER"
				pg_fail=0
			fi
		fi
	fi

	if [ "$CHECK_REDIS" = "true" ]; then
		if docker exec "$REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; then
			redis_fail=0
		else
			redis_fail=$((redis_fail + 1))
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Redis health failed ($redis_fail/$FAIL_THRESHOLD)"
			if [ "$RESTART_ON_FAILURE" = "true" ] && [ "$redis_fail" -ge "$FAIL_THRESHOLD" ]; then
				restart_container "$REDIS_CONTAINER"
				redis_fail=0
			fi
		fi
	fi

	if [ "$CHECK_MONGO" = "true" ]; then
		if docker exec "$MONGO_CONTAINER" mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
			mongo_fail=0
		else
			mongo_fail=$((mongo_fail + 1))
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Mongo health failed ($mongo_fail/$FAIL_THRESHOLD)"
			if [ "$RESTART_ON_FAILURE" = "true" ] && [ "$mongo_fail" -ge "$FAIL_THRESHOLD" ]; then
				restart_container "$MONGO_CONTAINER"
				mongo_fail=0
			fi
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
