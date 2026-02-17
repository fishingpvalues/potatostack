#!/bin/bash
# Common functions and constants for restore scripts
# Source this file: source "$(dirname "$0")/_common.sh"

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Constants
BACKREST_CONTAINER="backrest"
BACKREST_CONFIG_PATH="/config/config.json"
SSD_BASE="/mnt/ssd/docker-data"
STORAGE_BASE="/mnt/storage"
STACK_DIR="/home/daniel/potatostack"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Detect docker compose command
detect_compose() {
	if command -v docker-compose &>/dev/null; then
		echo "docker-compose"
	else
		echo "docker compose"
	fi
}

DOCKER_COMPOSE=$(detect_compose)

# Ensure backrest container is running
ensure_backrest_running() {
	if ! docker inspect -f '{{.State.Running}}' "$BACKREST_CONTAINER" 2>/dev/null | grep -q true; then
		log_error "Backrest container is not running"
		log_info "Start it with: docker compose up -d backrest"
		return 1
	fi
	log_ok "Backrest container is running"
}

# Extract restic repository URI from backrest config
get_restic_repo() {
	docker exec "$BACKREST_CONTAINER" cat "$BACKREST_CONFIG_PATH" 2>/dev/null |
		python3 -c "import sys,json; repos=json.load(sys.stdin).get('repos',[]); print(repos[0]['uri'] if repos else '')" 2>/dev/null ||
		docker exec "$BACKREST_CONTAINER" cat "$BACKREST_CONFIG_PATH" 2>/dev/null |
		grep -o '"uri":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Extract restic password from backrest config
get_restic_password() {
	docker exec "$BACKREST_CONTAINER" cat "$BACKREST_CONFIG_PATH" 2>/dev/null |
		python3 -c "import sys,json; repos=json.load(sys.stdin).get('repos',[]); print(repos[0].get('password','') if repos else '')" 2>/dev/null ||
		docker exec "$BACKREST_CONTAINER" cat "$BACKREST_CONFIG_PATH" 2>/dev/null |
		grep -o '"password":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Run restic command inside backrest container
restic_exec() {
	local repo password
	repo=$(get_restic_repo)
	password=$(get_restic_password)

	if [[ -z "$repo" || -z "$password" ]]; then
		log_error "Could not extract restic repo or password from backrest config"
		return 1
	fi

	docker exec -e RESTIC_PASSWORD="$password" "$BACKREST_CONTAINER" \
		restic -r "$repo" "$@"
}

# Map restore target to filesystem path (as seen inside backrest container)
target_to_path() {
	local target="$1"
	case "$target" in
	all) echo "/" ;;
	ssd) echo "/mnt/ssd/docker-data" ;;
	storage) echo "/mnt/storage" ;;
	stack) echo "/mnt/potatostack" ;;
	postgres) echo "/mnt/ssd/docker-data/postgres" ;;
	mongo) echo "/mnt/ssd/docker-data/mongo" ;;
	couchdb) echo "/mnt/ssd/docker-data/couchdb" ;;
	gitea) echo "/mnt/ssd/docker-data/gitea" ;;
	grafana) echo "/mnt/ssd/docker-data/grafana" ;;
	immich) echo "/mnt/ssd/docker-data/immich" ;;
	syncthing) echo "/mnt/storage/syncthing" ;;
	redis) echo "/mnt/ssd/docker-data/redis" ;;
	backrest) echo "/mnt/ssd/docker-data/backrest" ;;
	authentik) echo "/mnt/ssd/docker-data/authentik" ;;
	miniflux) echo "/mnt/ssd/docker-data/miniflux" ;;
	*)
		# Try as a service name — check SSD first, then storage
		if [[ -d "${SSD_BASE}/${target}" ]]; then
			echo "/mnt/ssd/docker-data/${target}"
		elif [[ -d "${STORAGE_BASE}/${target}" ]]; then
			echo "/mnt/storage/${target}"
		else
			log_error "Unknown target: $target"
			log_info "Valid targets: all, ssd, storage, stack, postgres, mongo, couchdb, gitea, grafana, immich, syncthing, redis, backrest, authentik, miniflux"
			return 1
		fi
		;;
	esac
}

# Service dependency map — returns space-separated list of services to stop
services_to_stop() {
	local target="$1"
	case "$target" in
	postgres)
		echo "postgres pgbouncer authentik-server authentik-worker miniflux immich-server grafana postgres-exporter healthchecks karakeep atuin gitea woodpecker-server homarr infisical freqtrade-bot regime-classifier ghostfolio baikal"
		;;
	mongo)
		echo "mongo karakeep"
		;;
	couchdb)
		echo "couchdb obsidian-livesync"
		;;
	gitea)
		echo "gitea woodpecker-server"
		;;
	grafana)
		echo "grafana"
		;;
	immich)
		echo "immich-server immich-machine-learning"
		;;
	syncthing)
		echo "syncthing"
		;;
	redis)
		echo "redis-cache"
		;;
	all | ssd | storage)
		echo "__all_except_backrest__"
		;;
	stack)
		echo "__none__"
		;;
	*)
		# Single service — stop just that service
		echo "$target"
		;;
	esac
}

# Stop services for a restore target
stop_services() {
	local target="$1"
	local services
	services=$(services_to_stop "$target")

	if [[ "$services" == "__none__" ]]; then
		log_info "No services need stopping for target: $target"
		return 0
	fi

	if [[ "$services" == "__all_except_backrest__" ]]; then
		log_info "Stopping all services except backrest..."
		local all_services
		all_services=$($DOCKER_COMPOSE -f "${STACK_DIR}/docker-compose.yml" config --services 2>/dev/null | grep -v "^backrest$" | grep -v "^storage-init$" | grep -v "^tailscale-https" || true)
		if [[ -n "$all_services" ]]; then
			# shellcheck disable=SC2086
			$DOCKER_COMPOSE -f "${STACK_DIR}/docker-compose.yml" stop $all_services 2>/dev/null || true
		fi
		return 0
	fi

	log_info "Stopping services: $services"
	# shellcheck disable=SC2086
	$DOCKER_COMPOSE -f "${STACK_DIR}/docker-compose.yml" stop $services 2>/dev/null || true
}

# Start services after restore
start_services() {
	log_info "Starting all services..."
	cd "$STACK_DIR"
	$DOCKER_COMPOSE rm -f storage-init tailscale-https-setup 2>/dev/null || true
	$DOCKER_COMPOSE up -d
}
