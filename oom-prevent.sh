#!/bin/bash
################################################################################
# System OOM Prevention & Monitoring Script
# Monitors memory usage and prevents OOM conditions in PotatoStack
# Installed as systemd timer: potatostack-oom-prevent.timer
################################################################################

set -euo pipefail

# Configuration
ALERT_THRESHOLD="${OOM_ALERT_THRESHOLD:-80}"
KILL_THRESHOLD="${OOM_KILL_THRESHOLD:-90}"
LOG_FILE="/var/log/potatostack-oom.log"
NTFY_URL="${OOM_NTFY_URL:-http://localhost:8060/potatostack}"

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
	local title="$1"
	local message="$2"
	local priority="${3:-high}"
	log "ALERT: $message"

	curl -s -X POST "$NTFY_URL" \
		-H "Title: ${title}" \
		-H "Priority: ${priority}" \
		-H "Tags: memory,warning,potatostack" \
		-d "$message" 2>/dev/null || true
}

check_memory() {
	local total used available percent
	total=$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo)
	available=$(awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
	used=$((total - available))
	percent=$((used * 100 / total))

	if [ "$percent" -ge "$KILL_THRESHOLD" ]; then
		log "CRITICAL: Memory at ${percent}% (${used}MB/${total}MB, ${available}MB avail)"
		alert "CRITICAL: Memory ${percent}%" \
			"Memory: ${used}MB/${total}MB (${available}MB available)\nAction: Dropping caches and stopping heavy containers" \
			"urgent"

		# Emergency: drop caches
		sync
		echo 3 >/proc/sys/vm/drop_caches 2>/dev/null || true

		# Stop known memory hogs
		for container in qbittorrent article-extractor immich-ml jellyfin bitmagnet; do
			local mem_bytes
			mem_bytes=$(docker inspect --format '{{.HostConfig.Memory}}' "$container" 2>/dev/null) || continue
			local mem_mb=$((mem_bytes / 1024 / 1024))
			if [ "$mem_mb" -gt 512 ] || [ "$mem_bytes" -eq 0 ]; then
				log "Stopping $container (limit: ${mem_mb}MB)"
				docker stop --time 10 "$container" 2>/dev/null || true
			fi
		done

	elif [ "$percent" -ge "$ALERT_THRESHOLD" ]; then
		log "WARNING: Memory at ${percent}% (${used}MB/${total}MB, ${available}MB avail)"
		alert "Memory Warning: ${percent}%" \
			"Memory: ${used}MB/${total}MB (${available}MB available)" \
			"high"
	else
		log "OK: Memory at ${percent}% (${used}MB/${total}MB, ${available}MB avail)"
	fi

	echo "$percent"
}

check_docker_health() {
	local restarting
	restarting=$(docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null | wc -l || echo "0")

	if [ "$restarting" -gt 3 ]; then
		local names
		names=$(docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null | head -10 | tr '\n' ', ')
		alert "Containers Restarting" \
			"${restarting} containers restarting: ${names}\nPossible memory pressure or crash loop" \
			"high"
	fi
}

check_swap() {
	local swap_total swap_used swap_percent
	swap_total=$(awk '/^SwapTotal:/{print int($2/1024)}' /proc/meminfo)
	swap_used=$(awk '/^SwapFree:/{print int($2/1024)}' /proc/meminfo)
	swap_used=$((swap_total - swap_used))

	if [ "$swap_total" -gt 0 ] && [ "$swap_used" -gt 0 ]; then
		swap_percent=$((swap_used * 100 / swap_total))
		if [ "$swap_percent" -gt 50 ]; then
			log "WARNING: Swap at ${swap_percent}% (${swap_used}MB/${swap_total}MB)"
			alert "Swap Warning: ${swap_percent}%" \
				"Swap: ${swap_used}MB/${swap_total}MB (${swap_percent}%)\nSystem under heavy memory pressure" \
				"high"
		elif [ "$swap_used" -gt 100 ]; then
			log "INFO: Swap in use: ${swap_used}MB/${swap_total}MB (${swap_percent}%)"
		fi
	fi
}

main() {
	local mem_percent
	mem_percent=$(check_memory)

	if [ "$mem_percent" -gt 70 ]; then
		check_docker_health
	fi

	check_swap
}

main "$@"
