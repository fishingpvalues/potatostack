#!/bin/sh
set -eu

################################################################################
# PostgreSQL Wrapper Script
# Fixes permissions issues before starting PostgreSQL
################################################################################

echo "[PostgreSQL Wrapper] Fixing permissions..."

# Fix pg_filenode.map permissions (should be 600, not 700)
if [ -f /var/lib/postgresql/data/global/pg_filenode.map ]; then
	chmod 600 /var/lib/postgresql/data/global/pg_filenode.map
	echo "[PostgreSQL Wrapper] Fixed pg_filenode.map permissions to 600"
fi

# Fix other permission issues in base directory
find /var/lib/postgresql/data/base -name "*.map" -type f -exec chmod 600 {} \; 2>/dev/null || true
find /var/lib/postgresql/data/base -name "pg_*" -type f -exec chmod 600 {} \; 2>/dev/null || true

echo "[PostgreSQL Wrapper] Permissions fix complete, starting PostgreSQL..."

# Execute docker-entrypoint.sh with all arguments
exec /usr/local/bin/docker-entrypoint.sh "$@"
