#!/bin/bash
# Seafile entrypoint - cleans up symlink loops
set -e

# Clean up broken symlinks before starting Seafile
if [ -d "/shared/logs" ]; then
    find /shared/logs -type l -xtype l -delete 2>/dev/null || true
    rm -rf /shared/logs/var-log 2>/dev/null || true
fi

# Execute original Seafile entrypoint
exec /sbin/my_init
