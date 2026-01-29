#!/bin/sh
################################################################################
# Tailscale Connectivity Monitor - Restart on repeated ping failures
################################################################################

set -eu

# docker:cli image already has docker command

TAILSCALE_CONTAINER="${TAILSCALE_CONTAINER:-tailscale}"
PING_TARGET="${TAILSCALE_PING_TARGET:-}"
CHECK_INTERVAL="${TAILSCALE_PING_INTERVAL:-60}"
FAIL_THRESHOLD="${TAILSCALE_PING_FAIL_THRESHOLD:-3}"
RESTART_COOLDOWN="${TAILSCALE_RESTART_COOLDOWN:-300}"
NTFY_TAGS="${TAILSCALE_NTFY_TAGS:-tailscale,vpn}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_tailscale() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

if [ -z "$PING_TARGET" ]; then
	echo "TAILSCALE_PING_TARGET not set; sleeping indefinitely."
	echo "Set TAILSCALE_PING_TARGET to enable monitoring."
	exec sleep infinity
fi

echo "=========================================="
echo "Tailscale Connectivity Monitor Started"
echo "Target: $PING_TARGET"
echo "Interval: ${CHECK_INTERVAL}s  Fail threshold: ${FAIL_THRESHOLD}"
echo "Cooldown: ${RESTART_COOLDOWN}s"
echo "=========================================="

fail_count=0
last_restart=0
last_state="unknown"

while true; do
	if docker exec "$TAILSCALE_CONTAINER" tailscale ping -c 1 "$PING_TARGET" >/dev/null 2>&1; then
		if [ "$last_state" = "down" ]; then
			notify_tailscale "PotatoStack - Tailscale restored" "Ping to ${PING_TARGET} succeeded again." "low"
		fi
		fail_count=0
		last_state="up"
	else
		fail_count=$((fail_count + 1))
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Tailscale ping failed ($fail_count/$FAIL_THRESHOLD)"
		if [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
			now=$(date +%s)
			if [ "$last_state" != "down" ]; then
				notify_tailscale "PotatoStack - Tailscale down" "Ping to ${PING_TARGET} failed ${FAIL_THRESHOLD} times." "high"
				last_state="down"
			fi
			if [ $((now - last_restart)) -ge "$RESTART_COOLDOWN" ]; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] → Restarting $TAILSCALE_CONTAINER"
				docker restart "$TAILSCALE_CONTAINER" >/dev/null 2>&1 || true
				notify_tailscale "PotatoStack - Tailscale restarted" "Restarted ${TAILSCALE_CONTAINER} after connectivity failures." "warning"
				last_restart=$now
			fi
			fail_count=0
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
