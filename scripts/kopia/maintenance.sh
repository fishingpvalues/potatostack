#!/bin/bash
################################################################################
# Kopia Repository Maintenance & Optimization
# Performs cleanup, verification, and optimization tasks
# Safe for Le Potato (2GB RAM) - runs with memory constraints
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
LOG_FILE="/mnt/seconddrive/kopia/logs/maintenance-$(date +%Y-%m-%d).log"
FULL_MAINTENANCE="${FULL_MAINTENANCE:-false}"  # Set to true for deep maintenance
DRY_RUN="${DRY_RUN:-false}"

################################################################################
# HEALTH CHECK
################################################################################

log_info "Starting Kopia maintenance process..."

if ! docker ps --filter "name=$KOPIA_CONTAINER" --filter "status=running" | grep -q "$KOPIA_CONTAINER"; then
    log_error "Kopia container is not running!"
    exit 1
fi

log_success "Kopia container is healthy"

################################################################################
# 1. REPOSITORY STATISTICS
################################################################################

log_info "=========================================="
log_info "  REPOSITORY STATISTICS"
log_info "=========================================="
echo ""

docker exec "$KOPIA_CONTAINER" kopia repository status 2>&1 | tee -a "$LOG_FILE" || log_warn "Could not get repository status"

echo ""

################################################################################
# 2. SNAPSHOT LIST & CLEANUP
################################################################################

log_info "=========================================="
log_info "  SNAPSHOT MANAGEMENT"
log_info "=========================================="
echo ""

# Count total snapshots
SNAPSHOT_COUNT=$(docker exec "$KOPIA_CONTAINER" kopia snapshot list --all 2>/dev/null | tail -n +2 | wc -l || echo "0")
log_info "Total snapshots: $SNAPSHOT_COUNT"

# List recent snapshots
log_info "Recent snapshots (last 10):"
docker exec "$KOPIA_CONTAINER" kopia snapshot list --all --max-results=10 2>&1 | tee -a "$LOG_FILE"

echo ""

# Apply retention policies and delete expired snapshots
log_info "Applying retention policies and cleaning up old snapshots..."

if [ "$DRY_RUN" = "true" ]; then
    log_warn "DRY RUN MODE - No snapshots will be deleted"
    docker exec "$KOPIA_CONTAINER" kopia snapshot expire --dry-run 2>&1 | tee -a "$LOG_FILE"
else
    docker exec "$KOPIA_CONTAINER" kopia snapshot expire --delete 2>&1 | tee -a "$LOG_FILE"
    log_success "Expired snapshots removed"
fi

echo ""

################################################################################
# 3. CACHE MANAGEMENT
################################################################################

log_info "=========================================="
log_info "  CACHE STATISTICS"
log_info "=========================================="
echo ""

CACHE_DIR="/mnt/seconddrive/kopia/cache"
if [ -d "$CACHE_DIR" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "Cache size: $CACHE_SIZE"
    log_info "Cache location: $CACHE_DIR"

    # Optional: Clear cache if it's too large (>2GB)
    CACHE_SIZE_MB=$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    if [ "$CACHE_SIZE_MB" -gt 2048 ]; then
        log_warn "Cache exceeds 2GB, consider clearing: docker exec $KOPIA_CONTAINER kopia cache clear"
    fi
else
    log_warn "Cache directory not found"
fi

echo ""

################################################################################
# 4. MAINTENANCE TASKS
################################################################################

log_info "=========================================="
log_info "  RUNNING MAINTENANCE TASKS"
log_info "=========================================="
echo ""

if [ "$FULL_MAINTENANCE" = "true" ]; then
    log_info "Running FULL maintenance (this may take 30+ minutes)..."
    log_warn "Full maintenance includes:"
    log_warn "  - Complete repository verification"
    log_warn "  - Index compaction"
    log_warn "  - Blob garbage collection"
    log_warn "  - Content verification"
    echo ""

    if docker exec "$KOPIA_CONTAINER" kopia maintenance run \
        --full \
        --safety=full \
        2>&1 | tee -a "$LOG_FILE"; then
        log_success "Full maintenance completed successfully"
    else
        log_error "Full maintenance failed"
        exit 1
    fi
else
    log_info "Running QUICK maintenance (5-10 minutes)..."
    log_info "Quick maintenance includes:"
    log_info "  - Snapshot GC"
    log_info "  - Quick blob verification"
    log_info "  - Index optimization"
    echo ""

    if docker exec "$KOPIA_CONTAINER" kopia maintenance run \
        --safety=full \
        --full=false \
        2>&1 | tee -a "$LOG_FILE"; then
        log_success "Quick maintenance completed successfully"
    else
        log_warn "Quick maintenance failed (non-critical)"
    fi
fi

echo ""

################################################################################
# 5. REPOSITORY VERIFICATION (QUICK)
################################################################################

log_info "=========================================="
log_info "  REPOSITORY INTEGRITY CHECK"
log_info "=========================================="
echo ""

log_info "Running quick integrity verification..."
if docker exec "$KOPIA_CONTAINER" kopia repository verify \
    --file-parallelism=2 \
    --max-errors=10 \
    2>&1 | tee -a "$LOG_FILE"; then
    log_success "Repository integrity check PASSED"
else
    log_error "Repository integrity check FAILED"
    log_error "Manual investigation required!"
    exit 1
fi

echo ""

################################################################################
# 6. DISK SPACE CHECK
################################################################################

log_info "=========================================="
log_info "  DISK SPACE ANALYSIS"
log_info "=========================================="
echo ""

REPO_DIR="/mnt/seconddrive/kopia/repository"
if [ -d "$REPO_DIR" ]; then
    REPO_SIZE=$(du -sh "$REPO_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    log_info "Repository size: $REPO_SIZE"

    # Check available space
    AVAILABLE_SPACE=$(df -h "$REPO_DIR" | tail -n 1 | awk '{print $4}')
    USED_PERCENT=$(df -h "$REPO_DIR" | tail -n 1 | awk '{print $5}' | tr -d '%')

    log_info "Available space: $AVAILABLE_SPACE"
    log_info "Disk usage: ${USED_PERCENT}%"

    if [ "$USED_PERCENT" -gt 90 ]; then
        log_error "WARNING: Disk usage exceeds 90%!"
        log_error "Free up space immediately to prevent backup failures"
    elif [ "$USED_PERCENT" -gt 80 ]; then
        log_warn "Disk usage exceeds 80% - consider freeing space soon"
    fi
else
    log_warn "Repository directory not found"
fi

echo ""

################################################################################
# 7. LOG CLEANUP
################################################################################

log_info "=========================================="
log_info "  LOG FILE MANAGEMENT"
log_info "=========================================="
echo ""

KOPIA_LOGS_DIR="/mnt/seconddrive/kopia/logs"
if [ -d "$KOPIA_LOGS_DIR" ]; then
    # Count log files
    LOG_COUNT=$(find "$KOPIA_LOGS_DIR" -name "*.log" -type f 2>/dev/null | wc -l)
    LOG_TOTAL_SIZE=$(du -sh "$KOPIA_LOGS_DIR" 2>/dev/null | cut -f1 || echo "N/A")

    log_info "Log files: $LOG_COUNT"
    log_info "Total log size: $LOG_TOTAL_SIZE"

    # Delete logs older than 30 days
    log_info "Cleaning up logs older than 30 days..."
    DELETED_COUNT=$(find "$KOPIA_LOGS_DIR" -name "*.log" -type f -mtime +30 -delete -print 2>/dev/null | wc -l)

    if [ "$DELETED_COUNT" -gt 0 ]; then
        log_success "Deleted $DELETED_COUNT old log files"
    else
        log_info "No old log files to delete"
    fi
fi

echo ""

################################################################################
# 8. PERFORMANCE METRICS
################################################################################

log_info "=========================================="
log_info "  PERFORMANCE METRICS"
log_info "=========================================="
echo ""

# Check Kopia container resource usage
if command -v docker &> /dev/null; then
    log_info "Kopia container stats:"
    docker stats "$KOPIA_CONTAINER" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || log_warn "Could not get container stats"
fi

echo ""

################################################################################
# SUMMARY
################################################################################

log_info "=========================================="
log_info "  MAINTENANCE SUMMARY"
log_info "=========================================="
echo ""

log_success "Maintenance completed successfully!"
log_info "Log file: $LOG_FILE"
echo ""

log_info "Next steps:"
echo "  1. Review maintenance log for any warnings"
echo "  2. Schedule full maintenance monthly: FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh"
echo "  3. Verify backups can be restored: ./scripts/verify-kopia-backups.sh"
echo "  4. Monitor disk space: df -h /mnt/seconddrive"
echo ""

exit 0
