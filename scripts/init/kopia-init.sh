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

	if kopia repository create filesystem --path=/repository; then
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

	if kopia repository connect filesystem --path=/repository; then
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

# Start the Kopia server
echo "Starting Kopia server..."
exec /bin/kopia server start \
	--address=0.0.0.0:51515 \
	--tls-generate-cert \
	--tls-generate-rsa-key-size=2048 \
	--server-username="${KOPIA_SERVER_USER}" \
	--server-password="${KOPIA_SERVER_PASSWORD}" \
	--log-level=warning \
	--file-log-level=warning \
	--override-hostname=kopia-server \
	--override-username=all-users
