#!/bin/bash
################################################################################
# pyLoad Init Script - Configure user credentials from environment
################################################################################

PYLOAD_USER="${PYLOAD_USER:-pyload}"
PYLOAD_PASSWORD="${PYLOAD_PASSWORD:-}"
DB_FILE="/config/data/pyload.db"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                      pyLoad Init Script                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

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

echo "✓ pyLoad configured"
echo "  WebUI: http://localhost:8000"
echo "  User: $PYLOAD_USER"

# Continue with normal startup
exec /init "$@"
