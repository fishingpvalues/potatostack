#!/bin/bash

################################################################################
# Gluetun VPN Monitor - Auto-restart dependent containers on VPN reconnect
# FIXED version - uses docker CLI to avoid Docker-in-Docker network issues
# - Handles VPN status changes with container recreation (not just restart)
# - Verifies services can actually connect after recovery
# - Detects VPN routing issues even when API reports "running"
################################################################################

# Install wget if not present (docker:cli image has docker already)
if ! command -v wget >/dev/null 2>&1; then
	echo "Installing wget..."
	apk add --no-cache wget >/dev/null 2>&1
fi

GLUETUN_URL="${GLUETUN_URL:-http://gluetun:8008}"
CHECK_INTERVAL="${CHECK_INTERVAL:-10}"
RESTART_CONTAINERS="${RESTART_CONTAINERS:-prowlarr sonarr radarr lidarr bookshelf bazarr qbittorrent slskd pyload spotiflac stash}"
RESTART_ON_STOP="${RESTART_ON_STOP:-true}"
RESTART_ON_FAILURE="${RESTART_ON_FAILURE:-true}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-120}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_event() {
	local title="$1"
	local message="$2"
	local priority="${3:-default}"
	local tags="${4:-vpn,gluetun}"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$tags"
}

echo "=========================================="
echo "Gluetun VPN Monitor Started (Fixed Version)"
echo "=========================================="
echo "Monitoring: $GLUETUN_URL/v1/vpn/status"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Will recreate: $RESTART_CONTAINERS"
echo "=========================================="

LAST_STATUS=""
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3
LAST_RESTART_AT=0
LAST_GLUETUN_ID=""

# Get gluetun container ID
get_gluetun_id() {
	docker inspect gluetun --format '{{.Id}}' 2>/dev/null | head -c 12
}

# Check if container has stale network attachment
check_network_stale() {
	local container="$1"
	local gluetun_id="$2"
	local network_mode
	network_mode=$(docker inspect "$container" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null)

	# Extract container ID from network mode (format: container:CONTAINER_ID)
	if echo "$network_mode" | grep -q "^container:"; then
		local attached_id
		attached_id=$(echo "$network_mode" | cut -d: -f2 | head -c 12)
		if [ "$attached_id" != "$gluetun_id" ]; then
			return 0 # Stale - IDs don't match
		fi
	fi
	return 1 # Not stale
}

# Test if services can actually connect after recreation
verify_service_connectivity() {
	local test_service="qbittorrent"
	local max_attempts=3
	local attempt=0

	# Skip if test service doesn't exist
	if ! docker inspect "$test_service" >/dev/null 2>&1; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Test service $test_service not available, skipping connectivity test"
		return 0
	fi

	while [ $attempt -lt $max_attempts ]; do
		attempt=$((attempt + 1))

		# Try to reach external endpoint
		if docker exec "$test_service" wget -q -O- --timeout=5 ifconfig.me/ip >/dev/null 2>&1; then
			return 0 # Connected
		fi

		sleep 2
	done

	return 1 # Cannot connect
}

# Force recreate containers (FIXED: uses docker CLI to avoid DinD issues)
recreate_containers() {
	local reason="$1"
	local now
	now=$(date +%s)

	if [ $((now - LAST_RESTART_AT)) -lt "$RESTART_COOLDOWN" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ Recreate cooldown active (${RESTART_COOLDOWN}s)"
		return
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Force recreating containers ($reason)..."
	notify_event "PotatoStack - VPN container recreation" "Reason: ${reason}. Containers: ${RESTART_CONTAINERS}" "high" "vpn,gluetun,critical"

	# Stop all containers
	for container in $RESTART_CONTAINERS; do
		if docker inspect "$container" >/dev/null 2>&1; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Stopping $container..."
			docker stop "$container" 2>&1 | sed "s/^/    /" || true
		fi
	done

	# Remove all containers
	for container in $RESTART_CONTAINERS; do
		if docker inspect "$container" >/dev/null 2>&1; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Removing $container..."
			docker rm "$container" 2>&1 | sed "s/^/    /" || true
		fi
	done

	# Wait for gluetun to be healthy before starting
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for gluetun to be healthy..."
	local attempts=0
	while [ $attempts -lt 30 ]; do
		if docker inspect gluetun --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
			break
		fi
		sleep 2
		attempts=$((attempts + 1))
	done

	# Wait a bit more for network to stabilize
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for gluetun to stabilize..."
	sleep 5

	# Recreate containers via docker compose from host directory
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Recreating containers via docker compose..."

	# Try multiple approaches in order of reliability
	local success=false

	# Approach 1: Try docker compose from /compose
	if [ -d /compose ] && [ -f /compose/docker-compose.yml ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   Trying docker compose from /compose..."
		if docker compose -f /compose/docker-compose.yml up -d --force-recreate "$RESTART_CONTAINERS" 2>&1 | sed "s/^/    /"; then
			success=true
		fi
	fi

	# Approach 2: Try docker compose from /home/daniel/potatostack
	if [ "$success" = "false" ] && [ -d /home/daniel/potatostack ] && [ -f /home/daniel/potatostack/docker-compose.yml ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   Trying docker compose from /home/daniel/potatostack..."
		# Use -f flag to specify compose file, don't cd
		if docker compose -f "/home/daniel/potatostack/docker-compose.yml" up -d --force-recreate "$RESTART_CONTAINERS" 2>&1 | sed "s/^/    /"; then
			success=true
		else
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]     Docker compose from /home/daniel/potatostack failed"
		fi
	fi

	# Approach 3: Fallback to docker restart if compose fails
	if [ "$success" = "false" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   ⚠ Docker compose failed, using docker restart as fallback..."
		for container in $RESTART_CONTAINERS; do
			if docker inspect "$container" >/dev/null 2>&1; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Restarting $container..."
				docker restart "$container" 2>&1 | sed "s/^/    /" || true
			fi
		done
	else
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   ✓ Docker compose succeeded"
	fi

	# Wait for containers to initialize
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for containers to initialize..."
	sleep 10

	# Verify services can connect after recreation (FIXED: added connectivity check)
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Verifying service connectivity..."

	if verify_service_connectivity; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Services verified to be connected"
	else
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Warning: Services may have connectivity issues"
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Containers recreated"
	notify_event "PotatoStack - VPN containers recreated" "Recreated: ${RESTART_CONTAINERS}" "default" "vpn,gluetun,maintenance"
	LAST_RESTART_AT="$now"
}

restart_containers() {
	local reason="$1"
	local now
	now=$(date +%s)

	if [ $((now - LAST_RESTART_AT)) -lt "$RESTART_COOLDOWN" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ Restart cooldown active (${RESTART_COOLDOWN}s)"
		return
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting dependent containers ($reason)..."
	notify_event "PotatoStack - VPN dependent restart" "Reason: ${reason}. Containers: ${RESTART_CONTAINERS}" "high" "vpn,gluetun,warning"
	for container in $RESTART_CONTAINERS; do
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Restarting $container..."
		docker restart "$container" 2>&1 | sed "s/^/    /"
	done
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ All containers restarted"
	notify_event "PotatoStack - VPN restart complete" "Containers restarted: ${RESTART_CONTAINERS}" "default" "vpn,gluetun"
	LAST_RESTART_AT="$now"
}

while true; do
	# Query Gluetun VPN status
	RESPONSE=$(wget -qO- --timeout=5 "$GLUETUN_URL/v1/vpn/status" 2>/dev/null)

	if [ $? -ne 0 ]; then
		CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Failed to reach Gluetun API (attempt $CONSECUTIVE_FAILURES/$MAX_FAILURES)"

		if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ Gluetun unreachable after $MAX_FAILURES attempts"
			notify_event "PotatoStack - VPN API unreachable" "Gluetun API unreachable after ${MAX_FAILURES} attempts." "urgent" "vpn,gluetun,critical"
			if [ "$RESTART_ON_FAILURE" = "true" ]; then
				# FIXED: Use recreate_containers to force network namespace refresh
				recreate_containers "gluetun-unreachable"
			fi
			LAST_STATUS=""
		fi

		sleep "$CHECK_INTERVAL"
		continue
	fi

	# Reset failure counter on successful response
	CONSECUTIVE_FAILURES=0

	# Extract status from JSON response
	CURRENT_STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

	if [ -z "$CURRENT_STATUS" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Invalid response from Gluetun: $RESPONSE"
		sleep "$CHECK_INTERVAL"
		continue
	fi

	# Detect status change
	if [ "$CURRENT_STATUS" != "$LAST_STATUS" ] && [ -n "$LAST_STATUS" ]; then
		echo ""
		echo "=========================================="
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔄 VPN STATUS CHANGE DETECTED"
		echo "Previous: $LAST_STATUS → Current: $CURRENT_STATUS"
		echo "=========================================="

		if [ "$CURRENT_STATUS" = "running" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ VPN connection restored!"
			notify_event "PotatoStack - VPN restored" "VPN status: running. Containers: ${RESTART_CONTAINERS}" "default" "vpn,gluetun,recovered"
			# FIXED: Use recreate_containers to force network namespace refresh
			recreate_containers "vpn-restored"

		elif [ "$CURRENT_STATUS" = "stopped" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ VPN connection lost!"
			notify_event "PotatoStack - VPN down" "VPN status: stopped. Containers: ${RESTART_CONTAINERS}" "urgent" "vpn,gluetun,critical"
			if [ "$RESTART_ON_STOP" = "true" ]; then
				# FIXED: Use recreate_containers to force network namespace refresh
				recreate_containers "vpn-stopped"
			else
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for reconnection..."
			fi
		fi

		echo "=========================================="
		echo ""
	elif [ -z "$LAST_STATUS" ]; then
		# Initial status
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Initial VPN status: $CURRENT_STATUS"

		# FIXED: Verify initial service connectivity
		if [ "$CURRENT_STATUS" = "running" ]; then
			sleep 5
			if ! verify_service_connectivity; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Services have connectivity issues, recreating..."
				recreate_containers "initial-connectivity-check"
			fi
		fi
	fi

	LAST_STATUS="$CURRENT_STATUS"

	# Check for gluetun container ID change (indicates restart/recreate)
	CURRENT_GLUETUN_ID=$(get_gluetun_id)
	if [ -n "$LAST_GLUETUN_ID" ] && [ "$CURRENT_GLUETUN_ID" != "$LAST_GLUETUN_ID" ]; then
		echo ""
		echo "=========================================="
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔄 GLUETUN CONTAINER ID CHANGED"
		echo "Previous: $LAST_GLUETUN_ID → Current: $CURRENT_GLUETUN_ID"
		echo "=========================================="
		notify_event "PotatoStack - Gluetun restarted" "Container ID changed: ${LAST_GLUETUN_ID} -> ${CURRENT_GLUETUN_ID}" "warning" "vpn,gluetun"
		recreate_containers "gluetun-recreated"
		echo "=========================================="
		echo ""
	elif [ -z "$LAST_GLUETUN_ID" ]; then
		LAST_GLUETUN_ID="$CURRENT_GLUETUN_ID"
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Initial Gluetun container ID: $CURRENT_GLUETUN_ID"

		# Check for stale network attachments on startup
		for container in $RESTART_CONTAINERS; do
			if docker inspect "$container" >/dev/null 2>&1; then
				if check_network_stale "$container" "$CURRENT_GLUETUN_ID"; then
					echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $container has stale network attachment"
					recreate_containers "stale-network-on-startup"
					break
				fi
			fi
		done
	fi
	LAST_GLUETUN_ID="$CURRENT_GLUETUN_ID"

	sleep "$CHECK_INTERVAL"
done
