#!/bin/sh
################################################################################
# OOM & Crash Loop Watcher
# Monitors Docker OOM kills AND container crash loops, sends ntfy notifications
################################################################################
set -eu

. /notify.sh

OOM_NOTIFY_COOLDOWN="${OOM_NOTIFY_COOLDOWN:-300}"
CRASH_LOOP_THRESHOLD="${CRASH_LOOP_THRESHOLD:-5}"
CRASH_LOOP_WINDOW="${CRASH_LOOP_WINDOW:-300}"
CRASH_LOOP_CHECK_INTERVAL="${CRASH_LOOP_CHECK_INTERVAL:-60}"
CRASH_LOOP_AUTO_STOP="${CRASH_LOOP_AUTO_STOP:-true}"

# Track state in /tmp
COOLDOWN_DIR="/tmp/oom-cooldowns"
CRASH_DIR="/tmp/crash-counts"
mkdir -p "$COOLDOWN_DIR" "$CRASH_DIR"

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
	category="${2:-oom}"
	now=$(date +%s)
	cooldown_file="${COOLDOWN_DIR}/${category}-${container}"

	if [ -f "$cooldown_file" ]; then
		last=$(cat "$cooldown_file")
		elapsed=$((now - last))
		if [ "$elapsed" -lt "$OOM_NOTIFY_COOLDOWN" ]; then
			log "Suppressing ${category} notification for ${container} (${elapsed}s since last, cooldown=${OOM_NOTIFY_COOLDOWN}s)"
			return 1
		fi
	fi

	echo "$now" >"$cooldown_file"
	return 0
}

handle_oom() {
	container="$1"
	log "OOM kill detected: ${container}"

	mem_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$container" 2>/dev/null) || mem_limit=0

	if [ "$mem_limit" -gt 0 ] 2>/dev/null; then
		limit_mb=$((mem_limit / 1024 / 1024))
		recommended_mb=$(round_up_32 $((limit_mb * 3 / 2)))
	else
		limit_mb="unknown"
		recommended_mb="unknown"
	fi

	if ! should_notify "$container" "oom"; then
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

	log "Sending OOM notification for ${container} (limit=${limit_mb}MB, recommended=${recommended_mb}MB)"
	ntfy_send \
		"OOM Kill: ${container}" \
		"$body" \
		"urgent" \
		"oom,memory,critical,${NTFY_DEFAULT_TAGS}"
}

handle_die() {
	container="$1"
	now=$(date +%s)
	crash_file="${CRASH_DIR}/${container}"

	# Append timestamp to crash file
	echo "$now" >>"$crash_file"

	# Count recent crashes within the window
	cutoff=$((now - CRASH_LOOP_WINDOW))
	if [ -f "$crash_file" ]; then
		recent_count=0
		tmp_file="${crash_file}.tmp"
		: >"$tmp_file"
		while read -r ts; do
			if [ "$ts" -ge "$cutoff" ] 2>/dev/null; then
				echo "$ts" >>"$tmp_file"
				recent_count=$((recent_count + 1))
			fi
		done <"$crash_file"
		mv "$tmp_file" "$crash_file"
	else
		recent_count=1
	fi

	if [ "$recent_count" -lt "$CRASH_LOOP_THRESHOLD" ]; then
		return 0
	fi

	log "CRASH LOOP detected: ${container} restarted ${recent_count} times in ${CRASH_LOOP_WINDOW}s"

	if ! should_notify "$container" "crashloop"; then
		return 0
	fi

	# Get exit code
	exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$container" 2>/dev/null) || exit_code="unknown"

	body="Container: ${container}
Restarts: ${recent_count} in ${CRASH_LOOP_WINDOW}s (threshold: ${CRASH_LOOP_THRESHOLD})
Exit code: ${exit_code}
Auto-stop: ${CRASH_LOOP_AUTO_STOP}"

	if [ "$CRASH_LOOP_AUTO_STOP" = "true" ]; then
		log "Auto-stopping crash-looping container: ${container}"
		if docker stop "$container" 2>/dev/null; then
			body="${body}
Action: Container STOPPED to prevent system destabilization
Run 'docker start ${container}' to restart manually"
			log "Successfully stopped ${container}"
		else
			body="${body}
Action: Failed to stop container"
			log "Failed to stop ${container}"
		fi
	fi

	ntfy_send \
		"Crash Loop: ${container}" \
		"$body" \
		"urgent" \
		"crash,loop,critical,${NTFY_DEFAULT_TAGS}"

	# Reset crash counter after notification to avoid repeated alerts
	: >"$crash_file"
}

# Monitor OOM events in background
monitor_oom() {
	log "OOM monitor started"
	docker events --filter event=oom --format '{{.Actor.Attributes.name}}' | while read -r container; do
		handle_oom "$container"
	done
}

# Monitor container die events in background
monitor_crashes() {
	log "Crash loop monitor started (threshold=${CRASH_LOOP_THRESHOLD} in ${CRASH_LOOP_WINDOW}s, auto-stop=${CRASH_LOOP_AUTO_STOP})"
	docker events --filter event=die --format '{{.Actor.Attributes.name}}' | while read -r container; do
		handle_die "$container"
	done
}

log "OOM & crash loop watcher started (cooldown=${OOM_NOTIFY_COOLDOWN}s)"

# Run both monitors in parallel
monitor_oom &
monitor_crashes &

# Wait for either to exit
wait
