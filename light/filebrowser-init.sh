#!/bin/sh
################################################################################
# FileBrowser Init Script - Ensures admin user exists on startup
################################################################################

ADMIN_USER="${FILEBROWSER_ADMIN_USER:-admin}"
ADMIN_PASS="${FILEBROWSER_ADMIN_PASS:-adminadminadmin}"

echo "Initializing FileBrowser..."

# Create admin user if it doesn't exist (ignore error if exists)
/filebrowser users add "$ADMIN_USER" "$ADMIN_PASS" --perm.admin 2>/dev/null || true

# Update password if user already exists (ensures password is correct)
/filebrowser users update "$ADMIN_USER" --password "$ADMIN_PASS" 2>/dev/null || true

echo "Admin user ready: $ADMIN_USER"

# Start FileBrowser
exec /filebrowser "$@"
