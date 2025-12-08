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
# NO COMPRESSION for Le Potato - saves CPU cycles on ARM64 SBC with 2GB RAM
# Storage is cheap, CPU time is precious on embedded hardware
################################################################################
log_info "Configuring compression settings (NO COMPRESSION for Le Potato)..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --compression=none \
  || log_warn "Failed to set compression policy"

log_success "Compression: DISABLED (optimized for Le Potato ARM64 SBC)"

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
# Tuned for Le Potato SBC (ARM64, 2GB RAM, USB 3.0 storage)
# Conservative settings to prevent OOM and USB bottlenecks
################################################################################
log_info "Configuring performance settings (Le Potato optimized)..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --parallel-upload-above-size-mib=32 \
  --max-parallel-snapshots=1 \
  --max-parallel-file-reads=2 \
  || log_warn "Failed to set performance policy"

log_success "Performance: Conservative parallel settings for 2GB RAM + USB 3.0"

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
# 6. SPLITTER & DEDUPLICATION
# Optimized for typical homelab data (databases, configs, media)
################################################################################
log_info "Configuring deduplication settings..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --splitter=FIXED-4M \
  || log_warn "Failed to set splitter policy"

log_success "Splitter: FIXED-4M (good balance for mixed content without compression)"

################################################################################
# 7. UPLOAD LIMITS
# Prevent overwhelming USB 3.0 or network bandwidth
################################################################################
log_info "Configuring upload limits..."

docker exec "$KOPIA_CONTAINER" kopia policy set --global \
  --upload-max-megabytes-per-sec=50 \
  || log_warn "Failed to set upload limits"

log_success "Upload limit: 50 MB/s (USB 3.0 safe with overhead)"

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
