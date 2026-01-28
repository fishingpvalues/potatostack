#!/bin/bash

################################################################################
# Gluetun VPN Monitor - Auto-restart dependent containers on VPN reconnect
# Improved version based on testing learnings
# - Handles VPN status changes with container recreation (not just restart)
# - Verifies services can actually connect after recovery
# - Detects VPN routing issues even when API reports "running"
################################################################################

# Install wget if not present
if ! command -v wget >/dev/null 2>&1; then
	echo "Installing wget..."
	apk add --no-cache wget >/dev/null 2>&1
fi

GLUETUN_URL="${GLUETUN_URL:-http://gluetun:8008}"
CHECK_INTERVAL="${CHECK_INTERVAL:-10}"
RESTART_CONTAINERS="${RESTART_CONTAINERS:-prowlarr sonarr radarr lidarr bookshelf bazarr qbittorrent slskd pyload pinchflat spotiflac stash}"
RESTART_ON_STOP="${RESTART_ON_STOP:-true}"
RESTART_ON_FAILURE="${RESTART_ON_FAILURE:-true}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-120}"

echo "=========================================="
echo "Gluetun VPN Monitor Started (Improved)"
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

# Test if services can actually connect (NEW: verify routing)
verify_service_connectivity() {
	local test_service="qbittorrent"
	local max_attempts=3
	local attempt=0

	while [ $attempt -lt $max_attempts ]; do
		attempt=$((attempt + 1))

		# Try to reach external endpoint
		if docker exec "$test_service" wget -q -O- --timeout=3 ifconfig.me/ip >/dev/null 2>&1; then
			return 0 # Connected
		fi

		sleep 2
	done

	return 1 # Cannot connect
}

# Force recreate containers (restart won't fix stale network)
recreate_containers() {
	local reason="$1"
	local now
	now=$(date +%s)

	if [ $((now - LAST_RESTART_AT)) -lt "$RESTART_COOLDOWN" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ Recreate cooldown active (${RESTART_COOLDOWN}s)"
		return
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Force recreating containers ($reason)..."
	for container in $RESTART_CONTAINERS; do
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Stopping $container..."
		docker stop "$container" 2>&1 | sed "s/^/    /" || true
		docker rm "$container" 2>&1 | sed "s/^/    /" || true
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

	# Wait for gluetun container to exist and be healthy
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for gluetun..."
	sleep 5

	# Recreate containers via docker compose
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Recreating containers via docker compose..."
	cd /compose 2>/dev/null || cd /home/daniel/potatostack 2>/dev/null || true

	# shellcheck disable=SC2086
	docker compose up -d --force-recreate $RESTART_CONTAINERS 2>&1 | sed "s/^/    /"

	# Verify services can connect after recreation (NEW)
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Verifying service connectivity..."
	sleep 10

	if verify_service_connectivity; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Services verified to be connected"
	else
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Warning: Services may have connectivity issues"
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Containers recreated"
	LAST_RESTART_AT="$now"
}

# Restart containers (simple restart, doesn't fix network)
restart_containers() {
	local reason="$1"
	local now
	now=$(date +%s)

	if [ $((now - LAST_RESTART_AT)) -lt "$RESTART_COOLDOWN" ]; then
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⏳ Restart cooldown active (${RESTART_COOLDOWN}s)"
		return
	fi

	echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting dependent containers ($reason)..."
	for container in $RESTART_CONTAINERS; do
		echo "[$(date +'%Y-%m-%d %H:%M:%S')]   • Restarting $container..."
		docker restart "$container" 2>&1 | sed "s/^/    /"
	done
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ All containers restarted"
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
			if [ "$RESTART_ON_FAILURE" = "true" ]; then
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

	# Detect status change - CHANGED: use recreate_containers for any status change
	if [ "$CURRENT_STATUS" != "$LAST_STATUS" ] && [ -n "$LAST_STATUS" ]; then
		echo ""
		echo "=========================================="
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔄 VPN STATUS CHANGE DETECTED"
		echo "Previous: $LAST_STATUS → Current: $CURRENT_STATUS"
		echo "=========================================="

		if [ "$CURRENT_STATUS" = "running" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ VPN connection restored!"
			# Use recreate_containers to force network namespace refresh
			recreate_containers "vpn-restored"

		elif [ "$CURRENT_STATUS" = "stopped" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ VPN connection lost!"
			if [ "$RESTART_ON_STOP" = "true" ]; then
				# Use recreate_containers to force network namespace refresh
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

		# Verify initial service connectivity
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
