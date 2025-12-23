#!/bin/bash
# Immich entrypoint - auto-creates required directories
set -e

# Create required directory structure
mkdir -p /usr/src/app/upload/encoded-video
if [ ! -f /usr/src/app/upload/encoded-video/.immich ]; then
    echo "verified" > /usr/src/app/upload/encoded-video/.immich
fi

# Execute original Immich command
exec "$@"
