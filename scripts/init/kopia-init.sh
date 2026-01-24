#!/bin/sh
################################################################################
# Kopia Init Script - Auto-initialize repository and start server
#
# Environment Variables:
#   KOPIA_PASSWORD          - Repository encryption password (REQUIRED)
#   KOPIA_SERVER_USER       - Web UI username (default: admin)
#   KOPIA_SERVER_PASSWORD   - Web UI password (REQUIRED)
#   KOPIA_HOSTNAME          - Override hostname for snapshots
#
# The server provides:
#   - Web UI at https://HOST:51515
#   - Repository server for remote clients
#   - Automatic TLS certificate generation
################################################################################

set -eu

KOPIA_SERVER_USER="${KOPIA_SERVER_USER:-admin}"
KOPIA_SERVER_PASSWORD="${KOPIA_SERVER_PASSWORD:-}"
KOPIA_HOSTNAME="${KOPIA_HOSTNAME:-potatostack}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Kopia Backup Server Init                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# Validate required environment variables
if [ -z "${KOPIA_PASSWORD:-}" ]; then
	echo "ERROR: KOPIA_PASSWORD is not set. Cannot initialize repository."
	echo "Set KOPIA_PASSWORD in your .env file."
	exit 1
fi

if [ -z "$KOPIA_SERVER_PASSWORD" ]; then
	echo "ERROR: KOPIA_SERVER_PASSWORD is not set. Cannot start server."
	echo "Set KOPIA_SERVER_PASSWORD in your .env file."
	exit 1
fi

# Initialize or connect to repository
if [ ! -f /repository/kopia.repository.f ]; then
	echo "[1/4] Creating new Kopia repository..."

	if kopia repository create filesystem \
		--path=/repository \
		--password="$KOPIA_PASSWORD" \
		--override-hostname="$KOPIA_HOSTNAME" \
		--override-username="root"; then
		echo "  ✓ Repository created successfully"
	else
		echo "  ✗ Repository creation failed"
		exit 1
	fi
else
	echo "[1/4] Connecting to existing repository..."

	if kopia repository connect filesystem \
		--path=/repository \
		--password="$KOPIA_PASSWORD" \
		--override-hostname="$KOPIA_HOSTNAME" \
		--override-username="root"; then
		echo "  ✓ Connected to repository"
	else
		echo "  ✗ Repository connection failed"
		exit 1
	fi
fi

# Verify repository status
echo "[2/4] Verifying repository status..."
if kopia repository status >/dev/null 2>&1; then
	echo "  ✓ Repository status OK"
	kopia repository status | head -5
else
	echo "  ✗ Repository status check failed"
	exit 1
fi

# Generate TLS certificate if needed
echo "[3/4] Checking TLS certificates..."
if [ ! -f "/app/config/tls.crt" ] || [ ! -f "/app/config/tls.key" ]; then
	echo "  Generating self-signed certificate..."
	openssl req -x509 -newkey rsa:4096 \
		-keyout "/app/config/tls.key" \
		-out "/app/config/tls.crt" \
		-days 3650 -nodes \
		-subj "/CN=kopia-server/O=PotatoStack/C=DE" \
		2>/dev/null
	echo "  ✓ TLS certificate generated (valid for 10 years)"
else
	echo "  ✓ TLS certificates exist"
fi

# Set up default global policy if not exists
echo "[4/4] Configuring default policies..."
if ! kopia policy show --global >/dev/null 2>&1; then
	echo "  Setting up default retention policy..."
	kopia policy set --global \
		--keep-latest 10 \
		--keep-hourly 24 \
		--keep-daily 7 \
		--keep-weekly 4 \
		--keep-monthly 12 \
		--keep-annual 3 \
		--compression pgzip
	echo "  ✓ Default policy configured"
else
	echo "  ✓ Global policy already exists"
fi

# Display server info
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Kopia Server Starting                          ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Web UI:     https://localhost:51515                              ║"
echo "║  Username:   $KOPIA_SERVER_USER"
echo "║  Repository: /repository                                          ║"
echo "║  Hostname:   $KOPIA_HOSTNAME"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Start Kopia server with all features enabled
# Add default user for remote clients
echo "  Adding default remote client user..."
kopia server user add "${KOPIA_SERVER_USER}@potatostack" --user-password="$KOPIA_SERVER_PASSWORD" 2>/dev/null || true

exec kopia server start \
	--address "0.0.0.0:51515" \
	--server-username "$KOPIA_SERVER_USER" \
	--server-password "$KOPIA_SERVER_PASSWORD" \
	--server-control-username "$KOPIA_SERVER_USER" \
	--server-control-password "$KOPIA_SERVER_PASSWORD" \
	--tls-cert-file "/app/config/tls.crt" \
	--tls-key-file "/app/config/tls.key"
