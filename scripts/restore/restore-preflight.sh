#!/bin/bash
# Pre-restore checks: verify backrest, test repo access, list snapshots, check disk space
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

SNAPSHOT=""
TARGET=""

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --snapshot <id>    Snapshot to inspect"
	echo "  --target <target>  Restore target to check (all, ssd, storage, postgres, ...)"
	echo "  -h, --help         Show this help"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--snapshot) SNAPSHOT="$2"; shift 2 ;;
	--target) TARGET="$2"; shift 2 ;;
	-h | --help) usage; exit 0 ;;
	*) log_error "Unknown option: $1"; usage; exit 1 ;;
	esac
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PotatoStack Restore Preflight Checks${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0

pass() { CHECKS_PASSED=$((CHECKS_PASSED + 1)); log_ok "$*"; }
fail() { CHECKS_FAILED=$((CHECKS_FAILED + 1)); log_error "$*"; }

# 1. Backrest container
log_info "Checking backrest container..."
if docker inspect -f '{{.State.Running}}' "$BACKREST_CONTAINER" 2>/dev/null | grep -q true; then
	pass "Backrest container is running"
else
	fail "Backrest container is not running"
	log_info "Start with: docker compose up -d backrest"
	echo ""
	echo -e "${RED}Cannot continue without backrest. Exiting.${NC}"
	exit 1
fi

# 2. Backrest health
log_info "Checking backrest health..."
HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "$BACKREST_CONTAINER" 2>/dev/null || echo "unknown")
if [[ "$HEALTH" == "healthy" ]]; then
	pass "Backrest is healthy"
else
	log_warn "Backrest health: $HEALTH (continuing anyway)"
fi

# 3. Config readable
log_info "Checking backrest config..."
if docker exec "$BACKREST_CONTAINER" test -f "$BACKREST_CONFIG_PATH" 2>/dev/null; then
	pass "Backrest config exists"
else
	fail "Backrest config not found at $BACKREST_CONFIG_PATH"
	exit 1
fi

# 4. Restic repo access
log_info "Testing restic repository access..."
REPO=$(get_restic_repo)
if [[ -n "$REPO" ]]; then
	pass "Repo URI: $REPO"
else
	fail "Could not extract repo URI from config"
	exit 1
fi

PASSWORD=$(get_restic_password)
if [[ -n "$PASSWORD" ]]; then
	pass "Repo password extracted"
else
	fail "Could not extract repo password from config"
	exit 1
fi

# 5. SSH connectivity (if SFTP repo)
if [[ "$REPO" == sftp:* ]]; then
	log_info "Testing SSH connectivity..."
	SSH_HOST=$(echo "$REPO" | sed 's|sftp:\([^:]*\):.*|\1|')
	if docker exec "$BACKREST_CONTAINER" ssh -oBatchMode=yes -oConnectTimeout=10 -oStrictHostKeyChecking=no "$SSH_HOST" echo 'ok' 2>/dev/null | grep -q ok; then
		pass "SSH connection to $SSH_HOST successful"
	else
		fail "SSH connection to $SSH_HOST failed"
		log_info "Try: make fix-backrest-ssh"
	fi
fi

# 6. Restic repo unlock/access check
log_info "Testing restic repo access (cat config)..."
if restic_exec cat config >/dev/null 2>&1; then
	pass "Restic repo is accessible"
else
	fail "Cannot access restic repo (wrong password or network issue)"
fi

# 7. List snapshots
echo ""
log_info "Available snapshots:"
echo ""
restic_exec snapshots --compact 2>/dev/null || {
	fail "Could not list snapshots"
}
echo ""

# 8. If snapshot + target given, show details
if [[ -n "$SNAPSHOT" && -n "$TARGET" ]]; then
	RESTORE_PATH=$(target_to_path "$TARGET")
	echo ""
	log_info "Snapshot $SNAPSHOT details for target '$TARGET' (path: $RESTORE_PATH):"
	echo ""
	if [[ "$RESTORE_PATH" == "/" ]]; then
		restic_exec ls "$SNAPSHOT" --compact 2>/dev/null | head -30 || true
	else
		restic_exec ls "$SNAPSHOT" "$RESTORE_PATH" --compact 2>/dev/null | head -30 || true
	fi
	echo "  ..."
	echo ""

	log_info "Services that will need stopping:"
	SERVICES=$(services_to_stop "$TARGET")
	if [[ "$SERVICES" == "__all_except_backrest__" ]]; then
		echo "  All services except backrest"
	elif [[ "$SERVICES" == "__none__" ]]; then
		echo "  None"
	else
		echo "  $SERVICES"
	fi
fi

# 9. Disk space
echo ""
log_info "Disk space:"
df -h /mnt/ssd 2>/dev/null | tail -1 | awk '{printf "  SSD:     %s used / %s total (%s available)\n", $3, $2, $4}' || echo "  SSD: not mounted"
df -h /mnt/storage 2>/dev/null | tail -1 | awk '{printf "  Storage: %s used / %s total (%s available)\n", $3, $2, $4}' || echo "  Storage: not mounted"

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  Checks passed: ${GREEN}${CHECKS_PASSED}${NC}  Failed: ${RED}${CHECKS_FAILED}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [[ "$CHECKS_FAILED" -gt 0 ]]; then
	log_error "Some preflight checks failed. Fix issues before restoring."
	exit 1
fi

log_ok "All preflight checks passed. Ready to restore."
