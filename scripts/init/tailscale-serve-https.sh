#!/bin/sh
################################################################################
# Tailscale HTTPS Setup - Wrap local HTTP ports with Tailscale TLS
# Uses "tailscale serve --https=<port> http://127.0.0.1:<port>" for each port
#
# Features:
# - Automatically re-applies rules after crash/restart
# - Checks if backend ports are listening before mapping
# - Supports special port mappings (e.g., 443->11000 for Nextcloud)
# - Runs in loop mode for continuous monitoring
################################################################################

export PATH="/usr/bin:$PATH"

# Install Docker CLI if needed
if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker CLI..."
	apk add --no-cache docker-cli curl >/dev/null 2>&1
	echo "✓ Docker CLI installed"
fi

TAILSCALE_CONTAINER="${TAILSCALE_CONTAINER:-tailscale}"
PORTS="${TAILSCALE_SERVE_PORTS:-}"
TAILSCALE_SERVE_LOOP="${TAILSCALE_SERVE_LOOP:-false}"
TAILSCALE_SERVE_INTERVAL="${TAILSCALE_SERVE_INTERVAL:-300}"
TAILSCALE_MARKER_FILE="${TAILSCALE_MARKER_FILE:-/https-marker/setup-complete}"
SPECIAL_MAPPINGS="${TAILSCALE_SERVE_SPECIAL:-}"

# Ports that serve HTTPS on the backend (need https+insecure://)
HTTPS_BACKEND_PORTS="9443 8443 8080"

create_marker() {
	if [ -n "$TAILSCALE_MARKER_FILE" ]; then
		mkdir -p "$(dirname "$TAILSCALE_MARKER_FILE")" 2>/dev/null || true
		date > "$TAILSCALE_MARKER_FILE" 2>/dev/null || true
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

# Check if a port is listening on localhost
port_is_listening() {
	local port="$1"
	# Try multiple methods to check port
	if command -v ss >/dev/null 2>&1; then
		ss -tlnH "sport = :$port" 2>/dev/null | grep -q "$port"
	elif command -v netstat >/dev/null 2>&1; then
		netstat -tlnp 2>/dev/null | grep -q ":$port "
	else
		# Fallback: try to connect
		(echo > /dev/tcp/127.0.0.1/$port) 2>/dev/null
	fi
}

# Get the backend URL for a port
get_backend_url() {
	local port="$1"
	local backend_url="http://127.0.0.1:$port"
	for https_port in $HTTPS_BACKEND_PORTS; do
		if [ "$port" = "$https_port" ]; then
			backend_url="https+insecure://127.0.0.1:$port"
			break
		fi
	done
	echo "$backend_url"
}

# Apply serve rule for a single port mapping
apply_serve_rule() {
	local ext_port="$1"
	local int_port="$2"
	local backend_url="$3"

	# Check if backend is listening (skip check for special mappings where AIO manages the port)
	if [ "$ext_port" != "443" ] && ! port_is_listening "$int_port"; then
		echo "  ⏳ Port $int_port not listening yet, skipping"
		return 1
	fi

	# Apply the serve rule
	if docker exec "$TAILSCALE_CONTAINER" \
		tailscale serve --bg --https="$ext_port" "$backend_url" 2>&1 | grep -v "already"; then
		echo "  ✓ Port $ext_port -> $backend_url"
		return 0
	else
		# Rule might already exist, which is fine
		return 0
	fi
}

apply_rules() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuring Tailscale HTTPS..."

	# Apply standard port mappings (same port on both sides)
	if [ -n "$PORTS" ]; then
		echo "Standard ports: $PORTS"
		for port in $(echo "$PORTS" | tr ',' ' '); do
			if [ -z "$port" ]; then
				continue
			fi
			backend_url=$(get_backend_url "$port")
			apply_serve_rule "$port" "$port" "$backend_url"
		done
	fi

	# Apply special port mappings (external_port:internal_port)
	if [ -n "$SPECIAL_MAPPINGS" ]; then
		echo "Special mappings: $SPECIAL_MAPPINGS"
		for mapping in $(echo "$SPECIAL_MAPPINGS" | tr ',' ' '); do
			if [ -z "$mapping" ]; then
				continue
			fi
			ext_port=$(echo "$mapping" | cut -d: -f1)
			int_port=$(echo "$mapping" | cut -d: -f2)
			# Special mappings always use http (reverse proxy handles TLS)
			apply_serve_rule "$ext_port" "$int_port" "http://127.0.0.1:$int_port"
		done
	fi

	echo "✓ Tailscale HTTPS configuration complete"
}

# Reset serve rules for our ports (useful for clean restart)
reset_rules() {
	echo "Resetting Tailscale serve rules..."

	# Reset standard ports
	for port in $(echo "$PORTS" | tr ',' ' '); do
		if [ -n "$port" ]; then
			docker exec "$TAILSCALE_CONTAINER" tailscale serve --https="$port" off 2>/dev/null || true
		fi
	done

	# Reset special mappings
	for mapping in $(echo "$SPECIAL_MAPPINGS" | tr ',' ' '); do
		if [ -n "$mapping" ]; then
			ext_port=$(echo "$mapping" | cut -d: -f1)
			docker exec "$TAILSCALE_CONTAINER" tailscale serve --https="$ext_port" off 2>/dev/null || true
		fi
	done

	echo "✓ Serve rules reset"
}

################################################################################
# Main
################################################################################

if [ -z "$PORTS" ] && [ -z "$SPECIAL_MAPPINGS" ]; then
	echo "No TAILSCALE_SERVE_PORTS or TAILSCALE_SERVE_SPECIAL set; nothing to configure."
	exit 0
fi

# Wait for tailscale first
if ! wait_for_tailscale; then
	echo "Continuing anyway..."
fi

if [ "$TAILSCALE_SERVE_LOOP" = "true" ]; then
	echo "Loop mode enabled (interval: ${TAILSCALE_SERVE_INTERVAL}s)"
	echo "This ensures rules are re-applied after crashes or service restarts"
	create_marker

	# Initial reset and apply
	reset_rules
	sleep 2
	apply_rules

	while true; do
		sleep "$TAILSCALE_SERVE_INTERVAL"
		apply_rules
		create_marker
	done
else
	# One-shot mode: reset and apply
	reset_rules
	sleep 2
	apply_rules
	create_marker
	echo "✓ Tailscale HTTPS setup complete (one-shot mode)"
fi
