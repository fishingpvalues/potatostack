#!/bin/bash
################################################################################
# Kopia Backup Verification Script
# Verifies backup integrity using Kopia's built-in verification features
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
VERIFY_PERCENT="${VERIFY_PERCENT:-10}"  # Verify 10% of files by default
MAX_ERRORS="${MAX_ERRORS:-5}"           # Stop after 5 errors
PARALLEL="${PARALLEL:-4}"               # Use 4 parallel threads (ARM64 friendly)

# Parse arguments
FULL_VERIFY=false
SPECIFIC_SNAPSHOT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --full)
      FULL_VERIFY=true
      VERIFY_PERCENT=100
      shift
      ;;
    --snapshot)
      SPECIFIC_SNAPSHOT="$2"
      shift 2
      ;;
    --percent)
      VERIFY_PERCENT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --full              Verify 100% of files (slow, comprehensive)"
      echo "  --snapshot ID       Verify specific snapshot ID"
      echo "  --percent N         Verify N% of files (default: 10)"
      echo "  --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                  # Quick verification (10% of files)"
      echo "  $0 --full           # Full verification (all files)"
      echo "  $0 --percent 25     # Verify 25% of files"
      echo "  $0 --snapshot k123  # Verify specific snapshot"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

################################################################################
# VERIFICATION CHECKS
################################################################################

log_info "Starting Kopia backup verification..."
echo "  Verify percent: ${VERIFY_PERCENT}%"
echo "  Max errors: $MAX_ERRORS"
echo "  Parallel threads: $PARALLEL"
echo ""

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
ERRORS=0

################################################################################
# 1. CHECK REPOSITORY STATUS
################################################################################
log_info "Step 1/4: Checking repository status..."

if ! docker exec "$KOPIA_CONTAINER" kopia repository status &>/dev/null; then
  log_error "Repository not connected or unavailable"
  exit 1
fi

log_success "Repository is connected and accessible"

################################################################################
# 2. LIST SNAPSHOTS
################################################################################
log_info "Step 2/4: Listing available snapshots..."

SNAPSHOT_COUNT=$(docker exec "$KOPIA_CONTAINER" kopia snapshot list --json 2>/dev/null | jq -r 'length' || echo "0")

if [ "$SNAPSHOT_COUNT" -eq 0 ]; then
  log_warn "No snapshots found - nothing to verify"
  exit 0
fi

log_success "Found $SNAPSHOT_COUNT snapshots"

# Show recent snapshots
log_info "Recent snapshots:"
docker exec "$KOPIA_CONTAINER" kopia snapshot list | tail -n 10

################################################################################
# 3. VERIFY SNAPSHOTS
################################################################################
log_info "Step 3/4: Verifying snapshot integrity..."

if [ -n "$SPECIFIC_SNAPSHOT" ]; then
  log_info "Verifying specific snapshot: $SPECIFIC_SNAPSHOT"

  if docker exec "$KOPIA_CONTAINER" kopia snapshot verify "$SPECIFIC_SNAPSHOT" \
      --verify-files-percent="$VERIFY_PERCENT" \
      --parallel="$PARALLEL" \
      --max-errors="$MAX_ERRORS"; then
    log_success "Snapshot $SPECIFIC_SNAPSHOT verified successfully"
  else
    log_error "Snapshot $SPECIFIC_SNAPSHOT verification failed"
    ((ERRORS++))
  fi
else
  log_info "Verifying all snapshots (${VERIFY_PERCENT}% of files each)..."

  # Get all snapshot IDs
  SNAPSHOT_IDS=$(docker exec "$KOPIA_CONTAINER" kopia snapshot list --json 2>/dev/null | \
                 jq -r '.[].id' 2>/dev/null || echo "")

  if [ -z "$SNAPSHOT_IDS" ]; then
    log_error "Failed to retrieve snapshot IDs"
    exit 1
  fi

  VERIFIED=0
  FAILED=0

  while IFS= read -r snapshot_id; do
    [ -z "$snapshot_id" ] && continue

    log_info "Verifying snapshot: $snapshot_id"

    if docker exec "$KOPIA_CONTAINER" kopia snapshot verify "$snapshot_id" \
        --verify-files-percent="$VERIFY_PERCENT" \
        --parallel="$PARALLEL" \
        --max-errors="$MAX_ERRORS" 2>&1 | tee /tmp/kopia_verify_$$.log; then
      log_success "✓ $snapshot_id"
      ((VERIFIED++))
    else
      log_error "✗ $snapshot_id - FAILED"
      ((FAILED++))
      ((ERRORS++))
    fi
  done <<< "$SNAPSHOT_IDS"

  log_info "Verification summary: $VERIFIED passed, $FAILED failed"
fi

################################################################################
# 4. CHECK REPOSITORY CONSISTENCY
################################################################################
log_info "Step 4/4: Checking repository consistency..."

if docker exec "$KOPIA_CONTAINER" kopia repository validate-provider 2>&1 | tee /tmp/kopia_validate_$$.log; then
  log_success "Repository consistency check passed"
else
  log_error "Repository consistency check failed"
  ((ERRORS++))
fi

################################################################################
# FINAL REPORT
################################################################################
echo ""
echo "========================================================================"
log_info "Kopia Backup Verification Report"
echo "========================================================================"
echo "Timestamp: $TIMESTAMP"
echo "Total snapshots: $SNAPSHOT_COUNT"
echo "Verification coverage: ${VERIFY_PERCENT}%"
echo "Errors encountered: $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
  log_success "All verification checks passed! ✓"
  echo ""
  log_info "Recommendations:"
  echo "  - Run full verification monthly: $0 --full"
  echo "  - Monitor Kopia logs: docker logs $KOPIA_CONTAINER"
  echo "  - Test restores periodically to ensure recoverability"
  exit 0
else
  log_error "Verification completed with $ERRORS errors!"
  echo ""
  log_warn "Troubleshooting steps:"
  echo "  1. Check Kopia logs: docker logs $KOPIA_CONTAINER"
  echo "  2. Review verification logs: /tmp/kopia_*.log"
  echo "  3. Run repository repair: docker exec $KOPIA_CONTAINER kopia repository repair"
  echo "  4. Contact support if issues persist"
  exit 1
fi
