#!/bin/sh
################################################################################
# Tailscale HTTPS Setup - Wrap local HTTP ports with Tailscale TLS
# Uses "tailscale serve --https=<port> http://127.0.0.1:<port>" for each port
################################################################################

export PATH="/usr/bin:$PATH"

# Install Docker CLI if needed
if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker CLI..."
	apk add --no-cache docker-cli >/dev/null 2>&1
	echo "✓ Docker CLI installed"
fi

TAILSCALE_CONTAINER="${TAILSCALE_CONTAINER:-tailscale}"
PORTS="${TAILSCALE_SERVE_PORTS:-}"
TAILSCALE_SERVE_LOOP="${TAILSCALE_SERVE_LOOP:-false}"
TAILSCALE_SERVE_INTERVAL="${TAILSCALE_SERVE_INTERVAL:-300}"
TAILSCALE_MARKER_FILE="${TAILSCALE_MARKER_FILE:-/https-marker/setup-complete}"

if [ -z "$PORTS" ]; then
	echo "No TAILSCALE_SERVE_PORTS set; nothing to configure."
	exit 0
fi

create_marker() {
	if [ -n "$TAILSCALE_MARKER_FILE" ]; then
		mkdir -p "$(dirname "$TAILSCALE_MARKER_FILE")" 2>/dev/null || true
		touch "$TAILSCALE_MARKER_FILE" 2>/dev/null || true
	fi
}

wait_for_tailscale() {
	echo "Waiting for Tailscale to be ready..."
	for i in $(seq 1 30); do
		if docker exec "$TAILSCALE_CONTAINER" tailscale status >/dev/null 2>&1; then
			echo "✓ Tailscale is ready"
			return 0
		fi
		sleep 2
	done
	echo "⚠ Tailscale not ready after 60s"
	return 1
}

apply_rules() {
	echo "Configuring Tailscale HTTPS for ports: $PORTS"
	# Ports that serve HTTPS on the backend (need https+insecure://)
	HTTPS_BACKEND_PORTS="9443 8443 8080"
	for port in $(echo "$PORTS" | tr ',' ' '); do
		if [ -z "$port" ]; then
			continue
		fi
		echo "→ Enabling HTTPS on port $port"
		# Check if this port serves HTTPS on backend
		BACKEND_URL="http://127.0.0.1:$port"
		for https_port in $HTTPS_BACKEND_PORTS; do
			if [ "$port" = "$https_port" ]; then
				BACKEND_URL="https+insecure://127.0.0.1:$port"
				break
			fi
		done
		if docker exec "$TAILSCALE_CONTAINER" \
			tailscale serve --bg --https="$port" "$BACKEND_URL" 2>&1; then
			echo "  ✓ Port $port mapped -> $BACKEND_URL"
		else
			echo "  ⚠ Failed to map port $port (service may be down or already mapped)"
		fi
	done
	echo "✓ Tailscale HTTPS port mapping configured"
}

# Wait for tailscale first
if ! wait_for_tailscale; then
	echo "Continuing anyway..."
fi

if [ "$TAILSCALE_SERVE_LOOP" = "true" ]; then
	echo "Loop mode enabled (interval: ${TAILSCALE_SERVE_INTERVAL}s)"
	create_marker
	while true; do
		apply_rules
		if [ -n "$TAILSCALE_MARKER_FILE" ]; then
			touch "$TAILSCALE_MARKER_FILE"
		fi
		sleep "$TAILSCALE_SERVE_INTERVAL"
	done
else
	apply_rules
	create_marker
	echo "✓ Tailscale HTTPS setup complete"
fi
