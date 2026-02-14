#!/bin/sh
################################################################################
# OOM Watcher - monitors Docker OOM kills and sends ntfy notifications
################################################################################
set -eu

. /notify.sh

OOM_NOTIFY_COOLDOWN="${OOM_NOTIFY_COOLDOWN:-300}"

# Track last notification time per container (in /tmp)
COOLDOWN_DIR="/tmp/oom-cooldowns"
mkdir -p "$COOLDOWN_DIR"

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

round_up_32() {
	mb="$1"
	remainder=$((mb % 32))
	if [ "$remainder" -eq 0 ]; then
		echo "$mb"
	else
		echo $(((mb / 32 + 1) * 32))
	fi
}

should_notify() {
	container="$1"
	now=$(date +%s)
	cooldown_file="${COOLDOWN_DIR}/${container}"

	if [ -f "$cooldown_file" ]; then
		last=$(cat "$cooldown_file")
		elapsed=$((now - last))
		if [ "$elapsed" -lt "$OOM_NOTIFY_COOLDOWN" ]; then
			log "Suppressing notification for ${container} (${elapsed}s since last, cooldown=${OOM_NOTIFY_COOLDOWN}s)"
			return 1
		fi
	fi

	echo "$now" >"$cooldown_file"
	return 0
}

handle_oom() {
	container="$1"
	log "OOM kill detected: ${container}"

	# Get memory limit in bytes
	mem_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$container" 2>/dev/null) || mem_limit=0

	if [ "$mem_limit" -gt 0 ] 2>/dev/null; then
		limit_mb=$((mem_limit / 1024 / 1024))
		recommended_mb=$(round_up_32 $((limit_mb * 3 / 2)))
	else
		limit_mb="unknown"
		recommended_mb="unknown"
	fi

	if ! should_notify "$container"; then
		return 0
	fi

	if [ "$limit_mb" != "unknown" ]; then
		body="Container: ${container}
Memory limit: ${limit_mb}MB
Recommendation: Increase to ${recommended_mb}MB

docker-compose.yml: update memory limit for ${container}"
	else
		body="Container: ${container}
Memory limit: not set
Recommendation: Add a memory limit

docker-compose.yml: add memory limit for ${container}"
	fi

	log "Sending notification for ${container} (limit=${limit_mb}MB, recommended=${recommended_mb}MB)"
	ntfy_send \
		"OOM Kill: ${container}" \
		"$body" \
		"urgent" \
		"oom,memory,critical,${NTFY_DEFAULT_TAGS}"
}

log "OOM watcher started (cooldown=${OOM_NOTIFY_COOLDOWN}s)"

docker events --filter event=oom --format '{{.Actor.Attributes.name}}' | while read -r container; do
	handle_oom "$container"
done
