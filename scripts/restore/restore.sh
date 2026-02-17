#!/bin/bash
# Main restore orchestrator for PotatoStack
# Restores from Backrest (restic) backups on Hetzner Storage Box
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

# Defaults
SNAPSHOT="latest"
TARGET="all"
DRY_RUN=false
SKIP_START=false
YES=false
LIST_SNAPSHOTS=false

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Restore PotatoStack from Backrest (restic) backup."
	echo ""
	echo "Options:"
	echo "  --snapshot <id|latest>   Snapshot to restore (default: latest)"
	echo "  --target <target>        What to restore (default: all)"
	echo "  --dry-run                Show what would happen without restoring"
	echo "  --skip-start             Don't restart services after restore"
	echo "  --yes                    Skip confirmation prompt"
	echo "  --list-snapshots         List snapshots and exit"
	echo "  -h, --help               Show this help"
	echo ""
	echo "Targets:"
	echo "  all        Full restore (SSD + storage + stack config)"
	echo "  ssd        All SSD data (/mnt/ssd/docker-data)"
	echo "  storage    All HDD data (/mnt/storage)"
	echo "  stack      Stack config (docker-compose.yml, .env, scripts)"
	echo "  postgres   PostgreSQL data directory"
	echo "  mongo      MongoDB data directory"
	echo "  couchdb    CouchDB data directory"
	echo "  gitea      Gitea data + repos"
	echo "  grafana    Grafana data"
	echo "  immich     Immich data"
	echo "  syncthing  Syncthing data"
	echo "  <service>  Any service by name"
	echo ""
	echo "Examples:"
	echo "  $0 --list-snapshots"
	echo "  $0 --dry-run"
	echo "  $0 --target postgres --snapshot latest"
	echo "  $0 --target all --yes"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--snapshot) SNAPSHOT="$2"; shift 2 ;;
	--target) TARGET="$2"; shift 2 ;;
	--dry-run) DRY_RUN=true; shift ;;
	--skip-start) SKIP_START=true; shift ;;
	--yes) YES=true; shift ;;
	--list-snapshots) LIST_SNAPSHOTS=true; shift ;;
	-h | --help) usage; exit 0 ;;
	*) log_error "Unknown option: $1"; usage; exit 1 ;;
	esac
done

# Error handler
on_error() {
	log_error "Restore failed! Services may be stopped."
	log_info "To start services manually: make startup"
	log_info "To retry: $0 --target $TARGET --snapshot $SNAPSHOT"
}
trap on_error ERR

echo ""
echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo -e "${RED}  PotatoStack Emergency Restore${NC}"
echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo ""

# Preflight
log_info "Running preflight checks..."
ensure_backrest_running

# List snapshots and exit
if [[ "$LIST_SNAPSHOTS" == true ]]; then
	log_info "Available snapshots:"
	echo ""
	restic_exec snapshots --compact
	exit 0
fi

# Resolve 'latest' snapshot
if [[ "$SNAPSHOT" == "latest" ]]; then
	log_info "Resolving latest snapshot..."
	SNAPSHOT=$(restic_exec snapshots --json 2>/dev/null |
		python3 -c "import sys,json; snaps=json.load(sys.stdin); print(snaps[-1]['short_id'] if snaps else '')" 2>/dev/null) || true
	if [[ -z "$SNAPSHOT" ]]; then
		log_error "Could not resolve latest snapshot"
		exit 1
	fi
	log_ok "Latest snapshot: $SNAPSHOT"
fi

# Resolve restore path
RESTORE_PATH=$(target_to_path "$TARGET")
SERVICES=$(services_to_stop "$TARGET")

# Build restic restore args
RESTIC_ARGS=("restore" "$SNAPSHOT" "--target" "/")
if [[ "$RESTORE_PATH" != "/" ]]; then
	RESTIC_ARGS+=("--include" "$RESTORE_PATH")
fi

# Display restore plan
echo ""
echo -e "${YELLOW}Restore Plan:${NC}"
echo "  Snapshot:  $SNAPSHOT"
echo "  Target:    $TARGET"
echo "  Path:      $RESTORE_PATH"
if [[ "$SERVICES" == "__all_except_backrest__" ]]; then
	echo "  Stop:      All services except backrest"
elif [[ "$SERVICES" == "__none__" ]]; then
	echo "  Stop:      None"
else
	echo "  Stop:      $SERVICES"
fi
echo "  Command:   restic ${RESTIC_ARGS[*]}"
echo ""

# Dry run — show plan and exit
if [[ "$DRY_RUN" == true ]]; then
	log_info "[DRY RUN] Would execute: restic ${RESTIC_ARGS[*]}"
	log_info "[DRY RUN] No changes made."
	exit 0
fi

# Confirmation
if [[ "$YES" != true ]]; then
	echo -e "${RED}WARNING: This will overwrite existing data at ${RESTORE_PATH}${NC}"
	printf "Continue? [y/N] "
	read -r reply
	case "$reply" in
	[Yy]*) ;;
	*)
		echo "Aborted."
		exit 0
		;;
	esac
fi

# PostgreSQL version safety check
if [[ "$TARGET" == "postgres" || "$TARGET" == "all" || "$TARGET" == "ssd" ]]; then
	PG_VERSION_FILE="${SSD_BASE}/postgres/PG_VERSION"
	if [[ -f "$PG_VERSION_FILE" ]]; then
		CURRENT_PG=$(cat "$PG_VERSION_FILE")
		log_info "Current PostgreSQL version: $CURRENT_PG"
		# Check backup PG_VERSION
		BACKUP_PG=$(restic_exec dump "$SNAPSHOT" "/mnt/ssd/docker-data/postgres/PG_VERSION" 2>/dev/null || echo "")
		if [[ -n "$BACKUP_PG" && "$BACKUP_PG" != "$CURRENT_PG" ]]; then
			log_error "PostgreSQL version mismatch!"
			log_error "Current: $CURRENT_PG, Backup: $BACKUP_PG"
			log_error "Restoring incompatible PG data will corrupt the database."
			exit 1
		fi
		if [[ -n "$BACKUP_PG" ]]; then
			log_ok "PostgreSQL versions match: $CURRENT_PG"
		fi
	fi
fi

# STOP services
echo ""
log_info "Phase 1: Stopping services..."
stop_services "$TARGET"
log_ok "Services stopped"

# RESTORE
echo ""
log_info "Phase 2: Restoring from backup..."
log_info "Running: restic ${RESTIC_ARGS[*]}"
echo ""
restic_exec "${RESTIC_ARGS[@]}"
echo ""
log_ok "Restore complete"

# FIX permissions
echo ""
log_info "Phase 3: Fixing permissions and configs..."

if [[ -x "${STACK_DIR}/scripts/init/init-storage.sh" ]]; then
	log_info "Running init-storage.sh..."
	"${STACK_DIR}/scripts/init/init-storage.sh" 2>/dev/null || true
fi

if [[ -x "${STACK_DIR}/scripts/init/fix-volume-permissions.sh" ]]; then
	log_info "Running fix-volume-permissions.sh..."
	"${STACK_DIR}/scripts/init/fix-volume-permissions.sh" 2>/dev/null || true
fi

if [[ -x "${STACK_DIR}/scripts/init/fix-service-configs.sh" ]]; then
	log_info "Running fix-service-configs.sh..."
	"${STACK_DIR}/scripts/init/fix-service-configs.sh" 2>/dev/null || true
fi

if [[ "$TARGET" == "postgres" || "$TARGET" == "all" || "$TARGET" == "ssd" ]]; then
	if [[ -x "${STACK_DIR}/scripts/init/fix-postgres-permissions.sh" ]]; then
		log_info "Running fix-postgres-permissions.sh..."
		"${STACK_DIR}/scripts/init/fix-postgres-permissions.sh" 2>/dev/null || true
	fi
fi

log_ok "Permissions fixed"

# START services
if [[ "$SKIP_START" == true ]]; then
	log_info "Skipping service start (--skip-start)"
else
	echo ""
	log_info "Phase 4: Starting services..."
	start_services
	log_ok "Services started"

	# VERIFY
	echo ""
	log_info "Phase 5: Verifying health (waiting 30s)..."
	sleep 30

	UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
	EXITED=$(docker ps --filter "status=exited" --format "{{.Names}}" | grep -v "storage-init\|tailscale-https" || true)

	if [[ -n "$UNHEALTHY" ]]; then
		log_warn "Unhealthy containers:"
		echo "  $UNHEALTHY"
	fi
	if [[ -n "$EXITED" ]]; then
		log_warn "Exited containers:"
		echo "  $EXITED"
	fi
	if [[ -z "$UNHEALTHY" && -z "$EXITED" ]]; then
		log_ok "All containers healthy"
	fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Restore complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Snapshot: $SNAPSHOT"
echo "  Target:   $TARGET"
echo ""
log_info "Run 'make health' to check service status."
