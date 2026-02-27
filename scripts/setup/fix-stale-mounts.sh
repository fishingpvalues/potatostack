#!/bin/bash
################################################################################
# fix-stale-mounts.sh
# Detects containers with stale bind mounts (wrong underlying device) and
# force-recreates them. Runs at boot via potatostack-fix-mounts.service,
# AFTER docker.service and storage mounts are ready.
################################################################################
set -euo pipefail

COMPOSE_FILE="/home/daniel/potatostack/docker-compose.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[fix-stale-mounts]${NC} $*"; }
warn() { echo -e "${YELLOW}[fix-stale-mounts]${NC} $*"; }
err()  { echo -e "${RED}[fix-stale-mounts]${NC} $*"; }

# Get correct major:minor for a mount point directly from /proc/self/mountinfo
# Field 3 in mountinfo is "major:minor"
get_dev() {
    awk -v mnt="$1" '$5 == mnt {print $3; exit}' /proc/self/mountinfo
}

STORAGE_DEV=$(get_dev /mnt/storage)
STORAGE2_DEV=$(get_dev /mnt/storage2)

log "Correct devices: /mnt/storage=$STORAGE_DEV  /mnt/storage2=$STORAGE2_DEV"

if [ -z "$STORAGE_DEV" ] || [ -z "$STORAGE2_DEV" ]; then
    err "Could not determine storage device numbers — are drives mounted?"
    exit 1
fi

# Paths that must be on their correct storage device
# Format: "container_path:expected_dev"
declare -A EXPECTED_DEVS
EXPECTED_DEVS["/mnt/storage"]="$STORAGE_DEV"
EXPECTED_DEVS["/mnt/storage2"]="$STORAGE2_DEV"
EXPECTED_DEVS["/srv/storage"]="$STORAGE_DEV"
EXPECTED_DEVS["/srv/storage2"]="$STORAGE2_DEV"
EXPECTED_DEVS["/storage"]="$STORAGE_DEV"
EXPECTED_DEVS["/media"]="$STORAGE2_DEV"
EXPECTED_DEVS["/downloads"]="$STORAGE2_DEV"
EXPECTED_DEVS["/repos"]="$STORAGE2_DEV"

BAD_CONTAINERS=()

for name in $(docker ps --format '{{.Names}}'); do
    pid=$(docker inspect "$name" --format '{{.State.Pid}}' 2>/dev/null || true)
    [ -z "$pid" ] || [ "$pid" = "0" ] && continue

    mountinfo="/proc/$pid/mountinfo"
    [ -f "$mountinfo" ] || continue

    stale=0
    while IFS= read -r line; do
        maj_min=$(echo "$line" | awk '{print $3}')
        dest=$(echo "$line" | awk '{print $5}')

        for path in "${!EXPECTED_DEVS[@]}"; do
            expected="${EXPECTED_DEVS[$path]}"
            # Match exact path or subpath
            if [ "$dest" = "$path" ] || [[ "$dest" == "$path/"* ]]; then
                if [ "$maj_min" != "$expected" ]; then
                    warn "STALE: $name — $dest uses $maj_min (want $expected)"
                    stale=1
                fi
            fi
        done
    done < "$mountinfo"

    [ "$stale" = "1" ] && BAD_CONTAINERS+=("$name")
done

if [ ${#BAD_CONTAINERS[@]} -eq 0 ]; then
    log "All containers have correct storage mounts."
    exit 0
fi

log "Recreating ${#BAD_CONTAINERS[@]} container(s): ${BAD_CONTAINERS[*]}"

docker compose -f "$COMPOSE_FILE" up -d --force-recreate "${BAD_CONTAINERS[@]}" 2>&1

log "Done. Stale mount fix applied to: ${BAD_CONTAINERS[*]}"
