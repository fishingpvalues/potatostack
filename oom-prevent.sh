#!/bin/bash
################################################################################
# System OOM Prevention & Monitoring Script
# Monitors memory usage and prevents OOM conditions in PotatoStack
# Use with: sudo ./oom-prevent.sh
#
# RECOMMENDED: Run this as a cron job every 5 minutes:
# */5 * * * * /home/daniel/potatostack/oom-prevent.sh
################################################################################

set -euo pipefail

# Configuration
ALERT_THRESHOLD=80 # Alert when memory usage exceeds this percentage
KILL_THRESHOLD=90  # Consider killing heavy processes when exceeding this
LOG_FILE="/var/log/potatostack-oom.log"
NOTIFY_SERVICE="ntfy" # Service to send alerts to
NOTIFY_URL="http://localhost:8060/potatostack-oom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
	local message="$1"
	log "ALERT: $message"

	# Send notification via ntfy
	curl -s -X POST "$NOTIFY_URL" \
		-d "message=$message" \
		-d "title=⚠️ PotatoStack OOM Warning" \
		-d "priority=3" 2>/dev/null || true
}

check_memory() {
	local total=$(free -m | awk '/^Mem:/{print $2}')
	local used=$(free -m | awk '/^Mem:/{print $3}')
	local percent=$((used * 100 / total))

	log "Memory: ${used}MB/${total}MB (${percent}%)"

	if [ "$percent" -ge "$ALERT_THRESHOLD" ]; then
		alert "Memory usage at ${percent}% (used: ${used}MB / total: ${total}MB)"
	fi

	if [ "$percent" -ge "$KILL_THRESHOLD" ]; then
		log "CRITICAL: Memory at ${percent}%, killing heavy processes..."
		kill_heavy_processes
	fi

	echo "$percent"
}

kill_heavy_processes() {
	local threshold_mb=512

	# Kill qbittorrent if using > 1GB
	local qb_mem=$(docker stats --no-stream --format "{{.MemUsage}}" qbittorrent 2>/dev/null | sed 's/MiB//' || echo "0")
	if [ "$qb_mem" -gt 1024 ]; then
		log "Killing qbittorrent (${qb_mem}MB > 1GB)"
		docker stop qbittorrent 2>/dev/null || true
	fi

	# Kill article-extractor if using > 500MB
	local ae_mem=$(docker stats --no-stream --format "{{.MemUsage}}" article-extractor 2>/dev/null | sed 's/MiB//' || echo "0")
	if [ "$ae_mem" -gt "$threshold_mb" ]; then
		log "Killing article-extractor (${ae_mem}MB > ${threshold_mb}MB)"
		docker stop article-extractor 2>/dev/null || true
	fi
}

check_docker_health() {
	local unhealthy=$(docker ps --format "{{.State}}" | grep -c "unhealthy" || echo "0")
	local restarting=$(docker ps --format "{{.State}}" | grep -c "Restarting" || echo "0")

	if [ "$unhealthy" -gt 5 ]; then
		alert "$unhealthy containers are unhealthy - possible OOM condition"
	fi

	if [ "$restarting" -gt 3 ]; then
		alert "$restarting containers are restarting - possible memory pressure"
	fi
}

check_swap() {
	local swap_total=$(free -m | awk '/^Swap:/{print $2}')
	local swap_used=$(free -m | awk '/^Swap:/{print $3}')

	if [ "$swap_used" -gt 0 ]; then
		log "Swap in use: ${swap_used}MB/${swap_total}MB"
	fi
}

# Main execution
main() {
	log "=== OOM Prevention Check ==="

	local mem_percent=$(check_memory)

	# Only check Docker health if memory is high
	if [ "$mem_percent" -gt 70 ]; then
		check_docker_health
	fi

	check_swap

	# Show top memory consumers
	log "Top 10 memory consumers:"
	docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | head -11 || log "Could not get docker stats"

	log "=== Check Complete ==="
}

main "$@"
