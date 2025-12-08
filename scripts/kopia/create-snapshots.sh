#!/bin/bash
################################################################################
# Kopia Automated Snapshot Creation
# Creates snapshots of all critical Potato Stack data
# Optimized for Le Potato (ARM64, 2GB RAM)
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
log_error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }

# Configuration
KOPIA_CONTAINER="${KOPIA_CONTAINER:-kopia_server}"
LOG_FILE="/mnt/seconddrive/kopia/logs/snapshots-$(date +%Y-%m-%d).log"
SNAPSHOT_TAG="automated-$(date +%Y%m%d-%H%M%S)"

# Error handling
trap 'log_error "Snapshot creation failed at line $LINENO"' ERR

################################################################################
# HEALTH CHECK
################################################################################
log_info "Starting Kopia snapshot creation process..."

if ! docker ps --filter "name=$KOPIA_CONTAINER" --filter "status=running" | grep -q "$KOPIA_CONTAINER"; then
    log_error "Kopia container is not running!"
    exit 1
fi

log_success "Kopia container is healthy"

################################################################################
# SNAPSHOT PATHS - Potato Stack Critical Data
################################################################################

# Define backup targets with descriptions
declare -A BACKUP_TARGETS=(
    # Configuration files
    ["/host/mnt/seconddrive/kopia/config"]="Kopia configuration"
    ["/host/mnt/seconddrive/nextcloud"]="Nextcloud data"
    ["/host/mnt/seconddrive/gitea"]="Gitea repositories"
    ["/host/mnt/seconddrive/qbittorrent/config"]="qBittorrent configuration"
    ["/host/mnt/seconddrive/slskd/config"]="slskd configuration"
    ["/host/mnt/seconddrive/uptime-kuma"]="Uptime Kuma data"

    # Database backups (already dumped by backup containers)
    ["/host/mnt/seconddrive/backups/db"]="Database dumps"
    ["/host/mnt/seconddrive/backups/vaultwarden"]="Vaultwarden backups"

    # Docker configs and compose files
    ["/host/Users/dfischer/workdir/potatostack/config"]="Potato Stack configs"
    ["/host/Users/dfischer/workdir/potatostack/docker-compose.yml"]="Docker Compose main file"
    ["/host/Users/dfischer/workdir/potatostack/.env"]="Environment variables"
    ["/host/Users/dfischer/workdir/potatostack/scripts"]="Management scripts"
)

################################################################################
# CREATE SNAPSHOTS
################################################################################

TOTAL_TARGETS=${#BACKUP_TARGETS[@]}
CURRENT_TARGET=0
SUCCESSFUL_SNAPSHOTS=0
FAILED_SNAPSHOTS=0

log_info "Creating snapshots for $TOTAL_TARGETS targets..."
echo ""

for target in "${!BACKUP_TARGETS[@]}"; do
    CURRENT_TARGET=$((CURRENT_TARGET + 1))
    description="${BACKUP_TARGETS[$target]}"

    log_info "[$CURRENT_TARGET/$TOTAL_TARGETS] Creating snapshot: $description"
    log_info "  Path: $target"

    # Check if path exists (some paths may not exist on all systems)
    if docker exec "$KOPIA_CONTAINER" test -e "$target" 2>/dev/null; then
        # Create snapshot with tags
        if docker exec "$KOPIA_CONTAINER" kopia snapshot create "$target" \
            --tags="type:automated,stack:potatostack,run:$SNAPSHOT_TAG" \
            --description="$description - $(date +'%Y-%m-%d %H:%M:%S')" \
            2>&1 | tee -a "$LOG_FILE"; then

            log_success "  Snapshot created successfully"
            SUCCESSFUL_SNAPSHOTS=$((SUCCESSFUL_SNAPSHOTS + 1))
        else
            log_warn "  Snapshot creation failed"
            FAILED_SNAPSHOTS=$((FAILED_SNAPSHOTS + 1))
        fi
    else
        log_warn "  Path does not exist, skipping"
        FAILED_SNAPSHOTS=$((FAILED_SNAPSHOTS + 1))
    fi

    echo ""
done

################################################################################
# MAINTENANCE - Run Kopia Maintenance Tasks
################################################################################

log_info "Running maintenance tasks..."

# Quick maintenance (runs in <5 minutes on typical homelab)
if docker exec "$KOPIA_CONTAINER" kopia maintenance run --safety=full --full=false 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Maintenance tasks completed"
else
    log_warn "Maintenance tasks failed (non-critical)"
fi

################################################################################
# SUMMARY
################################################################################

echo ""
log_info "=========================================="
log_info "  SNAPSHOT CREATION SUMMARY"
log_info "=========================================="
log_success "Successful snapshots: $SUCCESSFUL_SNAPSHOTS"

if [ "$FAILED_SNAPSHOTS" -gt 0 ]; then
    log_warn "Failed/Skipped snapshots: $FAILED_SNAPSHOTS"
fi

log_info "Total targets: $TOTAL_TARGETS"
log_info "Snapshot tag: $SNAPSHOT_TAG"
log_info "Log file: $LOG_FILE"
echo ""

# List recent snapshots
log_info "Recent snapshots:"
docker exec "$KOPIA_CONTAINER" kopia snapshot list --all --max-results=5 2>/dev/null || log_warn "Could not list snapshots"

echo ""
log_success "Snapshot creation process completed!"

# Exit with error if any snapshots failed
if [ "$FAILED_SNAPSHOTS" -gt 0 ]; then
    exit 1
fi

exit 0
