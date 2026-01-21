#!/bin/sh
################################################################################
# Tailscale HTTPS Setup - Wrap local HTTP ports with Tailscale TLS
# Uses "tailscale serve --https=<port> 127.0.0.1:<port>" for each port
################################################################################

set -u

if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker CLI..."
	apk add --no-cache docker-cli >/dev/null 2>&1
fi

TAILSCALE_CONTAINER="${TAILSCALE_CONTAINER:-tailscale}"
PORTS="${TAILSCALE_SERVE_PORTS:-}"

if [ -z "$PORTS" ]; then
	echo "No TAILSCALE_SERVE_PORTS set; nothing to configure."
	exit 0
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${TAILSCALE_CONTAINER}\$"; then
	echo "Tailscale container '${TAILSCALE_CONTAINER}' not running."
	exit 1
fi

echo "Configuring Tailscale HTTPS for ports: $PORTS"

for port in $(echo "$PORTS" | tr ',' ' '); do
	if [ -z "$port" ]; then
		continue
	fi
	echo "→ Enabling HTTPS on port $port"
	if docker exec "$TAILSCALE_CONTAINER" \
		tailscale serve --https="$port" "127.0.0.1:$port" >/dev/null; then
		echo "  ✓ Port $port mapped"
	else
		echo "  ⚠ Failed to map port $port (service may be down)"
	fi
done

echo "✓ Tailscale HTTPS port mapping configured"
