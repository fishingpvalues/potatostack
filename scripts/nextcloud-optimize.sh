#!/bin/bash
# Optimize Nextcloud caching: enable APCu and Redis (if configured)
# Usage: ./scripts/nextcloud-optimize.sh

set -euo pipefail

NC_CONTAINER=${NC_CONTAINER:-nextcloud}
REDIS_HOST_ENV=${REDIS_HOST:-}

echo "Configuring Nextcloud caching inside container: $NC_CONTAINER"

if ! docker ps --format '{{.Names}}' | grep -q "^${NC_CONTAINER}$"; then
  echo "Container '$NC_CONTAINER' not running. Start the stack first." >&2
  exit 1
fi

echo "Enabling APCu local cache..."
docker exec -u www-data "$NC_CONTAINER" php occ config:system:set memcache.local --value='\\OC\\Memcache\\APCu'

if [ -n "$REDIS_HOST_ENV" ]; then
  echo "Enabling Redis file locking using host '$REDIS_HOST_ENV'..."
  docker exec -u www-data "$NC_CONTAINER" php occ config:system:set memcache.locking --value='\\OC\\Memcache\\Redis'
  docker exec -u www-data "$NC_CONTAINER" php occ config:system:set redis host --value="$REDIS_HOST_ENV"
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    docker exec -u www-data "$NC_CONTAINER" php occ config:system:set redis password --value="$REDIS_PASSWORD"
  fi
else
  echo "REDIS_HOST not set; skipping Redis locking config."
fi

echo "Done. Consider setting up background jobs in Nextcloud admin settings."

