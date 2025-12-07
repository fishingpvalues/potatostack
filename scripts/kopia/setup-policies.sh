#!/bin/bash
################################################################################
# Kopia Policy Configuration - Reasonable Defaults
# Sets up retention, scheduling, and compression policies for Kopia backups
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
KOPIA_CONTAINER="${KOPIA_CONTAINER:-kopia_server}"

log_info "Setting up Kopia backup policies with reasonable defaults..."

################################################################################
# 1. GLOBAL RETENTION POLICY
# Follows the 3-2-1 backup rule with GFS (Grandfather-Father-Son) rotation
################################################################################
log_info "Configuring retention policy (GFS rotation)..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --keep-latest 7 \
  --keep-hourly 24 \
  --keep-daily 14 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --keep-annual 3 \
  || log_warn "Failed to set retention policy (may need repository connection)"

log_success "Retention: 7 latest, 24 hourly, 14 daily, 8 weekly, 12 monthly, 3 annual"

################################################################################
# 2. COMPRESSION SETTINGS
# Use efficient compression for storage optimization
################################################################################
log_info "Configuring compression settings..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --compression=zstd \
  --compression-min-size=1048576 \
  --compression-max-size=134217728 \
  || log_warn "Failed to set compression policy"

log_success "Compression: zstd (files 1MB-128MB)"

################################################################################
# 3. SNAPSHOT SCHEDULING
# Daily backups at 3 AM with automatic cleanup
################################################################################
log_info "Configuring snapshot schedule..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --snapshot-time="03:00" \
  || log_warn "Failed to set snapshot schedule"

log_success "Schedule: Daily at 3:00 AM"

################################################################################
# 4. PERFORMANCE OPTIMIZATION
# Tuned for SBC with limited RAM (2GB)
################################################################################
log_info "Configuring performance settings..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --parallel-upload-above-size-mib=16 \
  || log_warn "Failed to set performance policy"

log_success "Performance: Parallel uploads for files >16MB"

################################################################################
# 5. ERROR HANDLING & SAFETY
################################################################################
log_info "Configuring error handling..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --ignore-dir-errors \
  --ignore-file-errors \
  || log_warn "Failed to set error handling policy"

log_success "Error handling: Ignore inaccessible files/dirs (continue on errors)"

################################################################################
# DISPLAY CURRENT POLICY
################################################################################
log_info "Current global policy:"
docker exec "$KOPIA_CONTAINER" kopia policy show --global || log_warn "Failed to show policy"

log_success "Kopia policies configured successfully!"
echo ""
log_info "Next steps:"
echo "  1. Review policies: docker exec $KOPIA_CONTAINER kopia policy show --global"
echo "  2. Create snapshots: docker exec $KOPIA_CONTAINER kopia snapshot create /host/path"
echo "  3. Verify backups: ./scripts/kopia/verify-backups.sh"
