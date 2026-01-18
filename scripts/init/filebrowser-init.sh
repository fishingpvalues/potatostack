#!/bin/sh
################################################################################
# Filebrowser Init Script - Create config if not exists
################################################################################

set -eu

CONFIG_DIR="/config"
CONFIG_FILE="${CONFIG_DIR}/.filebrowser.json"
DB_FILE="${CONFIG_DIR}/database.db"

echo "Initializing Filebrowser configuration..."

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
	echo "Creating default Filebrowser configuration..."
	cat >"$CONFIG_FILE" <<EOF
{
  "port": 80,
  "baseURL": "",
  "address": "0.0.0.0",
  "log": "stdout",
  "database": "${DB_FILE}",
  "root": "/srv",
  "auth": {
    "method": "json"
  },
  "branding": {
    "name": "PotatoStack Files",
    "disableExternal": false
  },
  "commands": [],
  "shell": "",
  "rules": []
}
EOF
	echo "Created default config at $CONFIG_FILE"
fi

# Create admin user if specified in environment variables
if [ -n "${FILEBROWSER_USER:-}" ] && [ -n "${FILEBROWSER_PASSWORD:-}" ]; then
	# Only create user if database doesn't exist yet (first run)
	if [ ! -f "$DB_FILE" ]; then
		echo "Creating Filebrowser admin user..."
		/bin/filebrowser config init --database "$DB_FILE"
		/bin/filebrowser users add "$FILEBROWSER_USER" "$FILEBROWSER_PASSWORD" --perm.admin --database "$DB_FILE"
		echo "✓ Admin user '$FILEBROWSER_USER' created with admin permissions"
	else
		echo "Database exists, skipping user creation"
	fi
else
	echo "⚠ FILEBROWSER_USER and/or FILEBROWSER_PASSWORD not set - skipping user creation"
fi

echo "Filebrowser initialization complete"

# Start filebrowser
exec /bin/filebrowser --config "$CONFIG_FILE" --database "$DB_FILE"
