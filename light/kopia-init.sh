#!/bin/sh
################################################################################
# Kopia Init Script - Auto-initialize repository if not exists
################################################################################

echo "Initializing Kopia repository..."

# Check if repository directory exists and is non-empty
if [ ! -f /repository/f.kopia.repository ] && [ ! -d /repository/.kopia ]; then
	echo "Repository not initialized. Creating new repository..."

	# Create the repository (uses KOPIA_PASSWORD env var)
	kopia repository create filesystem --path=/repository

	if [ $? -eq 0 ]; then
		echo "✓ Repository created successfully"
	else
		echo "✗ Repository creation failed"
		exit 1
	fi
else
	echo "✓ Repository already exists, connecting..."

	# Connect to existing repository (uses KOPIA_PASSWORD env var)
	kopia repository connect filesystem --path=/repository

	if [ $? -eq 0 ]; then
		echo "✓ Connected to repository"
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
	--server-username=${KOPIA_SERVER_USER} \
	--server-password=${KOPIA_SERVER_PASSWORD} \
	--log-level=warning \
	--file-log-level=warning \
	--override-hostname=kopia-server \
	--override-username=all-users
