#!/bin/bash
################################################################################
# Transmission Init Script - Configure incomplete directory on startup
################################################################################

CONFIG_FILE="/config/settings.json"

# Wait for config directory
mkdir -p /config

# Function to update or add JSON setting
update_json_setting() {
	local key=$1
	local value=$2
	local file=$3

	if grep -q "\"$key\"" "$file" 2>/dev/null; then
		# Update existing key
		sed -i "s|\"$key\":.*|\"$key\": $value,|g" "$file"
	else
		# Add new key before closing brace
		sed -i "s|}|\n    \"$key\": $value\n}|g" "$file"
	fi
}

# Configure incomplete directory if config exists
if [ -f "$CONFIG_FILE" ]; then
	echo "Configuring Transmission incomplete directory..."

	# Backup config
	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

	# Set incomplete directory settings
	update_json_setting "download-dir" '"/downloads"' "$CONFIG_FILE"
	update_json_setting "incomplete-dir" '"/incomplete"' "$CONFIG_FILE"
	update_json_setting "incomplete-dir-enabled" 'true' "$CONFIG_FILE"

	echo "✓ Transmission configured to use /incomplete for temporary files"
fi

# Continue with normal startup
exec /init "$@"
