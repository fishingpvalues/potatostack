#!/bin/sh
################################################################################
# FileBrowser Init Script - Ensures admin user exists on startup
################################################################################

ADMIN_USER="${FILEBROWSER_ADMIN_USER:-admin}"
ADMIN_PASS="${FILEBROWSER_ADMIN_PASS:-adminadminadmin}"
DB_PATH="/database/filebrowser.db"

echo "Initializing FileBrowser..."

# Create database directory
mkdir -p /database

# Create admin user if it doesn't exist (ignore error if exists)
/bin/filebrowser users add "$ADMIN_USER" "$ADMIN_PASS" --perm.admin --database "$DB_PATH" 2>/dev/null || true

# Update password if user already exists (ensures password is correct)
/bin/filebrowser users update "$ADMIN_USER" --password "$ADMIN_PASS" --database "$DB_PATH" 2>/dev/null || true

echo "Admin user ready: $ADMIN_USER"

# Start FileBrowser with database path
exec /bin/filebrowser --database "$DB_PATH" --root /srv "$@"
