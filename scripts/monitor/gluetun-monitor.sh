#!/bin/sh
################################################################################
# Gluetun VPN Monitor - Auto-restart dependent containers on VPN reconnect
# Monitors Gluetun's /v1/vpn/status endpoint and restarts transmission/slskd
# when VPN connection is lost or restored
################################################################################

# Install Docker CLI if not present
if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker CLI..."
	apk add --no-cache docker-cli wget >/dev/null 2>&1
fi

GLUETUN_URL="${GLUETUN_URL:-http://gluetun:8000}"
CHECK_INTERVAL="${CHECK_INTERVAL:-10}"
RESTART_CONTAINERS="${RESTART_CONTAINERS:-transmission slskd}"
RESTART_ON_STOP="${RESTART_ON_STOP:-true}"
RESTART_ON_FAILURE="${RESTART_ON_FAILURE:-true}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-120}"

echo "=========================================="
echo "Gluetun VPN Monitor Started"
echo "=========================================="
echo "Monitoring: $GLUETUN_URL/v1/vpn/status"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Will restart: $RESTART_CONTAINERS"
echo "=========================================="

LAST_STATUS=""
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3
LAST_RESTART_AT=0

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
				restart_containers "gluetun-unreachable"
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
			restart_containers "vpn-restored"

		elif [ "$CURRENT_STATUS" = "stopped" ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ VPN connection lost!"
			if [ "$RESTART_ON_STOP" = "true" ]; then
				restart_containers "vpn-stopped"
			else
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Waiting for reconnection..."
			fi
		fi

		echo "=========================================="
		echo ""
	elif [ -z "$LAST_STATUS" ]; then
		# Initial status
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Initial VPN status: $CURRENT_STATUS"
	fi

	LAST_STATUS="$CURRENT_STATUS"
	sleep "$CHECK_INTERVAL"
done
