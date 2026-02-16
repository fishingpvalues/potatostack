#!/bin/bash
################################################################################
# pyLoad Init Script - Configure user credentials from environment
################################################################################

PYLOAD_USER="${PYLOAD_USER:-pyload}"
PYLOAD_PASSWORD="${PYLOAD_PASSWORD:-}"
DB_FILE="/config/data/pyload.db"
REALDEBRID_API_KEY="${REALDEBRID_API_KEY:-}"
TORBOX_API_KEY="${TORBOX_API_KEY:-}"
NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
PYLOAD_ENABLE_NTFY_HOOKS="${PYLOAD_ENABLE_NTFY_HOOKS:-true}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                      pyLoad Init Script                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

setup_ntfy_hooks() {
	if [ "$PYLOAD_ENABLE_NTFY_HOOKS" != "true" ] || [ -z "$NTFY_TOPIC" ]; then
		return
	fi

	hook_dir="/config/scripts/download_finished"
	hook_script="${hook_dir}/ntfy.sh"
	mkdir -p "$hook_dir"

	cat >"$hook_script" <<EOF
#!/bin/sh
NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL}"
NTFY_TOPIC="${NTFY_TOPIC}"
NTFY_TOKEN="${NTFY_TOKEN}"

title="PotatoStack - pyLoad download finished"
file_name="\${2:-unknown}"
file_path="\${3:-unknown}"
plugin="\${4:-unknown}"
url="\${5:-unknown}"
package="\${6:-unknown}"
message="File: \${file_name}\\nPackage: \${package}\\nPlugin: \${plugin}\\nPath: \${file_path}\\nURL: \${url}"

url_target="\${NTFY_INTERNAL_URL%/}/\${NTFY_TOPIC}"

if command -v curl >/dev/null 2>&1; then
    if [ -n "\$NTFY_TOKEN" ]; then
        curl -fsS -X POST "\$url_target" -H "Title: \$title" -H "Tags: pyload,download" -H "Priority: default" -H "Authorization: Bearer \$NTFY_TOKEN" -d "\$message" >/dev/null 2>&1 || true
    else
        curl -fsS -X POST "\$url_target" -H "Title: \$title" -H "Tags: pyload,download" -H "Priority: default" -d "\$message" >/dev/null 2>&1 || true
    fi
elif command -v wget >/dev/null 2>&1; then
    headers="--header=Title: \$title --header=Tags: pyload,download --header=Priority: default"
    if [ -n "\$NTFY_TOKEN" ]; then
        headers="\$headers --header=Authorization: Bearer \$NTFY_TOKEN"
    fi
    # shellcheck disable=SC2086
    wget -q --post-data "\$message" \$headers "\$url_target" >/dev/null 2>&1 || true
fi
EOF

	chmod +x "$hook_script"
	echo "✓ pyLoad ntfy hook installed: $hook_script"
}

# Install ntfy hook for download finished events
setup_ntfy_hooks

# Wait for initial setup to create database
MAX_WAIT=30
WAITED=0
while [ ! -f "$DB_FILE" ] && [ $WAITED -lt $MAX_WAIT ]; do
	echo "Waiting for pyLoad database to be created..."
	sleep 2
	WAITED=$((WAITED + 2))
done

if [ ! -f "$DB_FILE" ]; then
	echo "⚠ Database not found after ${MAX_WAIT}s, will configure on next restart"
	exec /init "$@"
fi

# Configure user if password is set
if [ -n "$PYLOAD_PASSWORD" ]; then
	echo "Configuring pyLoad user credentials..."

	# Generate PBKDF2-HMAC-SHA256 hash (pyload-ng format: 32-char salt hex + 64-char derived key hex)
	HASH=$(printf '%s' "$PYLOAD_PASSWORD" | python3 -c "
import hashlib, os, sys
password = sys.stdin.read()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100000)
print(salt.hex() + dk.hex())
" 2>/dev/null)

	if [ -n "$HASH" ]; then
		# Check if user exists
		USER_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name='$PYLOAD_USER';" 2>/dev/null)

		if [ "$USER_EXISTS" = "0" ]; then
			# Create new user with admin role (role=0 is ADMIN in pyload-ng)
			sqlite3 "$DB_FILE" "INSERT INTO users (name, password, role, permission, template) VALUES ('$PYLOAD_USER', '$HASH', 0, 0, 'default');"
			echo "✓ Created user: $PYLOAD_USER (admin)"
		else
			# Update existing user password and ensure admin role
			sqlite3 "$DB_FILE" "UPDATE users SET password='$HASH', role=0, permission=0 WHERE name='$PYLOAD_USER';"
			echo "✓ Updated password for user: $PYLOAD_USER"
		fi

		# Also update default 'pyload' user if different
		if [ "$PYLOAD_USER" != "pyload" ]; then
			sqlite3 "$DB_FILE" "UPDATE users SET password='$HASH' WHERE name='pyload';" 2>/dev/null || true
		fi
	else
		echo "⚠ Failed to generate password hash"
	fi
else
	echo "⚠ PYLOAD_PASSWORD not set; keeping existing credentials"
	echo "  Default login: pyload / pyload"
fi

################################################################################
# Debrid Account Setup (Real-Debrid, Torbox)
################################################################################
setup_debrid_accounts() {
	if [ ! -f "$DB_FILE" ]; then
		echo "⚠ Database not available, skipping debrid account setup"
		return
	fi

	# Real-Debrid: plugin name is "RealDebridCom"
	if [ -n "$REALDEBRID_API_KEY" ]; then
		ACCOUNT_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM accounts WHERE plugin='RealDebridCom' AND loginname='api';" 2>/dev/null || echo "0")
		if [ "$ACCOUNT_EXISTS" = "0" ]; then
			sqlite3 "$DB_FILE" "INSERT INTO accounts (plugin, loginname, owner, activated, password, shared) VALUES ('RealDebridCom', 'api', 1, 1, '$REALDEBRID_API_KEY', 0);" 2>/dev/null &&
				echo "✓ Real-Debrid account added" || echo "⚠ Failed to add Real-Debrid account"
		else
			sqlite3 "$DB_FILE" "UPDATE accounts SET password='$REALDEBRID_API_KEY', activated=1 WHERE plugin='RealDebridCom' AND loginname='api';" 2>/dev/null &&
				echo "✓ Real-Debrid account updated" || echo "⚠ Failed to update Real-Debrid account"
		fi
	fi

	# Torbox: no pyload-ng plugin yet (https://github.com/pyload/pyload/issues/4578)
	if [ -n "$TORBOX_API_KEY" ]; then
		echo "⚠ Torbox: pyload-ng plugin not yet available (github.com/pyload/pyload/issues/4578)"
		echo "  API key stored — will auto-configure when plugin is released"
	fi
}

setup_debrid_accounts

echo "✓ pyLoad configured"
echo "  WebUI: http://localhost:8000"
echo "  User: $PYLOAD_USER"
[ -n "$REALDEBRID_API_KEY" ] && echo "  Real-Debrid: enabled"
[ -n "$TORBOX_API_KEY" ] && echo "  Torbox: pending plugin support"

# Continue with normal startup
exec /init "$@"
