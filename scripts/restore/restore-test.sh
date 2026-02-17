#!/bin/bash
# Dry-run restore validation — verify backup integrity without modifying anything
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

DEEP_CHECK=false

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --deep     Also run restic check --read-data-subset=2%"
	echo "  -h, --help Show this help"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--deep) DEEP_CHECK=true; shift ;;
	-h | --help) usage; exit 0 ;;
	*) log_error "Unknown option: $1"; usage; exit 1 ;;
	esac
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PotatoStack Restore Test (Dry-Run Validation)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

ensure_backrest_running

# Resolve latest snapshot
log_info "Resolving latest snapshot..."
SNAPSHOT=$(restic_exec snapshots --json 2>/dev/null |
	python3 -c "import sys,json; snaps=json.load(sys.stdin); print(snaps[-1]['short_id'] if snaps else '')" 2>/dev/null) || true
if [[ -z "$SNAPSHOT" ]]; then
	log_error "No snapshots found"
	exit 1
fi
log_ok "Latest snapshot: $SNAPSHOT"

TEMP_DIR="/tmp/restore-test-$$"
TESTS_PASSED=0
TESTS_FAILED=0

pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); log_ok "$*"; }
fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); log_error "$*"; }

cleanup() {
	log_info "Cleaning up temp dir..."
	docker exec "$BACKREST_CONTAINER" rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Create temp dir inside backrest container
docker exec "$BACKREST_CONTAINER" mkdir -p "$TEMP_DIR"

# Define marker files to test
declare -A MARKERS=(
	["postgres/PG_VERSION"]="/mnt/ssd/docker-data/postgres/PG_VERSION"
	["postgres/pg_control"]="/mnt/ssd/docker-data/postgres/global/pg_control"
	["docker-compose.yml"]="/mnt/potatostack/docker-compose.yml"
	[".env"]="/mnt/potatostack/.env"
	["mongo/WiredTiger"]="/mnt/ssd/docker-data/mongo/WiredTiger"
	["backrest/config.json"]="/mnt/ssd/docker-data/backrest/config/config.json"
)

echo ""
log_info "Testing marker file restores from snapshot $SNAPSHOT..."
echo ""

for name in "${!MARKERS[@]}"; do
	path="${MARKERS[$name]}"
	log_info "Testing: $name ($path)"

	# Try to dump the file from backup
	if restic_exec dump "$SNAPSHOT" "$path" >"$TEMP_DIR/$RANDOM" 2>/dev/null; then
		# Check file was non-empty
		CONTENT=$(restic_exec dump "$SNAPSHOT" "$path" 2>/dev/null | head -c 100)
		if [[ -n "$CONTENT" ]]; then
			pass "$name — present and non-empty"
		else
			fail "$name — exists but empty"
		fi
	else
		fail "$name — not found in snapshot"
	fi
done

# Deep check — verify repo integrity
if [[ "$DEEP_CHECK" == true ]]; then
	echo ""
	log_info "Running deep integrity check (restic check --read-data-subset=2%)..."
	log_info "This may take several minutes..."
	echo ""
	if restic_exec check --read-data-subset=2% 2>&1; then
		pass "Repository integrity check passed"
	else
		fail "Repository integrity check failed"
	fi
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  Tests passed: ${GREEN}${TESTS_PASSED}${NC}  Failed: ${RED}${TESTS_FAILED}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [[ "$TESTS_FAILED" -gt 0 ]]; then
	log_error "Some tests failed. Backup may be incomplete."
	exit 1
fi

log_ok "All restore tests passed. Backup is viable."
