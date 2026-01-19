#!/bin/sh
################################################################################
# Kopia Init Script - Auto-initialize repository if not exists
################################################################################

set -eu

KOPIA_SERVER_USER="${KOPIA_SERVER_USER:-admin}"
KOPIA_SERVER_PASSWORD="${KOPIA_SERVER_PASSWORD:-}"

echo "Initializing Kopia repository..."

# Check if repository directory exists and is non-empty
if [ ! -f /repository/kopia.repository.f ] && [ ! -d /repository/.kopia ]; then
	echo "Repository not initialized. Creating new repository..."
	if [ -z "$KOPIA_PASSWORD" ]; then
		echo "ERROR: KOPIA_PASSWORD is not set. Cannot create repository."
		exit 1
	fi

	if kopia repository create filesystem --path=/repository --password="$KOPIA_PASSWORD" --override-hostname="potatostack" --override-username="root"; then
		echo "✓ Repository created successfully"

		if kopia repository status >/dev/null 2>&1; then
			echo "✓ Repository status verified"
		else
			echo "✗ Repository created but status check failed"
			exit 1
		fi
	else
		echo "✗ Repository creation failed"
		exit 1
	fi
else
	echo "✓ Repository already exists, connecting..."
	if [ -z "$KOPIA_PASSWORD" ]; then
		echo "ERROR: KOPIA_PASSWORD is not set. Cannot connect to repository."
		exit 1
	fi

	if kopia repository connect filesystem --path=/repository --password="$KOPIA_PASSWORD" --override-hostname="potatostack" --override-username="root"; then
		echo "✓ Connected to repository"

		if kopia repository status >/dev/null 2>&1; then
			echo "✓ Repository status verified"
		else
			echo "✗ Repository connection succeeded but status check failed"
			exit 1
		fi
	else
		echo "✗ Repository connection failed"
		exit 1
	fi
fi

if [ ! -f "/app/config/tls.crt" ] || [ ! -f "/app/config/tls.key" ]; then
	echo "Generating self-signed certificate for Kopia server..."
	openssl req -x509 -newkey rsa:4096 -keyout "/app/config/tls.key" -out "/app/config/tls.crt" -days 365 -nodes -subj "/CN=kopia-server"
	echo "✓ Self-signed certificate generated."
fi

# Start Kopia server
echo "Starting Kopia server..."
exec kopia server start --address "0.0.0.0:51515" \
	--server-username "$KOPIA_SERVER_USER" \
	--server-password "$KOPIA_SERVER_PASSWORD" \
	--tls-cert-file "/app/config/tls.crt" \
	--tls-key-file "/app/config/tls.key"
