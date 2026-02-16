#!/bin/sh
################################################################################
# Autoheal Monitor
# Watches Docker health_status events for unhealthy→healthy transitions
# (autoheal restarts) and sends ntfy notifications
################################################################################
set -eu

. /notify.sh

NOTIFY_COOLDOWN="${AUTOHEAL_NOTIFY_COOLDOWN:-300}"
COOLDOWN_DIR="/tmp/autoheal-cooldowns"
mkdir -p "$COOLDOWN_DIR"

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

should_notify() {
	container="$1"
	now=$(date +%s)
	cooldown_file="${COOLDOWN_DIR}/${container}"

	if [ -f "$cooldown_file" ]; then
		last=$(cat "$cooldown_file")
		elapsed=$((now - last))
		if [ "$elapsed" -lt "$NOTIFY_COOLDOWN" ]; then
			log "Suppressing notification for ${container} (${elapsed}s since last, cooldown=${NOTIFY_COOLDOWN}s)"
			return 1
		fi
	fi

	echo "$now" >"$cooldown_file"
	return 0
}

log "Autoheal monitor started (cooldown=${NOTIFY_COOLDOWN}s)"

# Watch for container restart events (autoheal restarts unhealthy containers)
docker events \
	--filter event=restart \
	--format '{{.Actor.Attributes.name}}' | while read -r container; do

	log "Container restarted: ${container}"

	if ! should_notify "$container"; then
		continue
	fi

	# Get container health status
	health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$container" 2>/dev/null) || health="unknown"

	body="Container: ${container}
Health: ${health}
Action: Restarted by autoheal

Check logs: docker logs --tail 50 ${container}"

	log "Sending autoheal notification for ${container}"
	ntfy_send \
		"Autoheal Restart: ${container}" \
		"$body" \
		"high" \
		"autoheal,restart,warning,${NTFY_DEFAULT_TAGS}" \
		"${NTFY_TOPIC_WARNING}"
done
