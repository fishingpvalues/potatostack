#!/bin/bash
set -euo pipefail

################################################################################
# PostgreSQL Permissions Fix Script
# Runs on container startup to fix file permissions issues
################################################################################

echo "[PostgreSQL Init] Checking and fixing file permissions..."

# Fix pg_filenode.map permissions (should be 600, not 700)
if [ -f /var/lib/postgresql/data/global/pg_filenode.map ]; then
	chmod 600 /var/lib/postgresql/data/global/pg_filenode.map
	echo "[PostgreSQL Init] Fixed pg_filenode.map permissions to 600"
fi

# Fix other permission issues in base directory
find /var/lib/postgresql/data/base -name "*.map" -type f -exec chmod 600 {} \; 2>/dev/null || true
find /var/lib/postgresql/data/base -name "pg_*" -type f -exec chmod 600 {} \; 2>/dev/null || true

echo "[PostgreSQL Init] Permissions check complete"

# Exit so PostgreSQL can continue normally
exit 0
