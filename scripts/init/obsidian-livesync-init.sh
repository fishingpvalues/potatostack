#!/bin/bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

log_info() {
    printf "%b\n" "${BLUE}[obsidian-init]${NC} $*"
}

log_ok() {
    printf "%b\n" "${GREEN}[obsidian-init]${NC} $*"
}

log_warn() {
    printf "%b\n" "${YELLOW}[obsidian-init]${NC} $*"
}

log_error() {
    printf "%b\n" "${RED}[obsidian-init]${NC} $*"
}

COUCHDB_HOST="${COUCHDB_HOST:-obsidian-livesync}"
COUCHDB_PORT="${COUCHDB_PORT:-5984}"
COUCHDB_USER="${COUCHDB_USER:-}"
COUCHDB_PASSWORD="${COUCHDB_PASSWORD:-}"
COUCHDB_DATABASE="${COUCHDB_DATABASE:-obsidian-vault}"

if [ -z "${COUCHDB_USER}" ] || [ -z "${COUCHDB_PASSWORD}" ]; then
    log_error "COUCHDB_USER or COUCHDB_PASSWORD is not set. Skipping init."
    exit 1
fi

base_url="http://${COUCHDB_HOST}:${COUCHDB_PORT}"
auth="${COUCHDB_USER}:${COUCHDB_PASSWORD}"

wait_for_couchdb() {
    local max_tries=30
    local i=1

    while [ $i -le $max_tries ]; do
        if curl -sf -u "$auth" "${base_url}/_up" >/dev/null; then
            return 0
        fi
        sleep 2
        i=$((i + 1))
    done

    return 1
}

log_info "Waiting for CouchDB at ${COUCHDB_HOST}:${COUCHDB_PORT}..."
if ! wait_for_couchdb; then
    log_error "CouchDB did not become ready in time."
    exit 1
fi
log_ok "CouchDB is reachable."

cluster_state=$(curl -s -u "$auth" "${base_url}/_cluster_setup" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')
if [ -z "$cluster_state" ]; then
    log_warn "Could not read cluster state. Attempting single-node enable anyway."
fi

if [ "$cluster_state" != "single_node_enabled" ] && [ "$cluster_state" != "cluster_finished" ]; then
    log_info "Enabling single-node CouchDB cluster..."
    curl -s -u "$auth"         -H "Content-Type: application/json"         -X POST "${base_url}/_cluster_setup"         -d "{\"action\":\"enable_single_node\",\"bind_address\":\"0.0.0.0\",\"username\":\"${COUCHDB_USER}\",\"password\":\"${COUCHDB_PASSWORD}\",\"port\":${COUCHDB_PORT},\"node_count\":1}"         >/dev/null || true

    curl -s -u "$auth"         -H "Content-Type: application/json"         -X POST "${base_url}/_cluster_setup"         -d "{\"action\":\"finish_cluster\"}"         >/dev/null || true
fi

create_db() {
    local db_name="$1"
    local code

    code=$(curl -s -o /dev/null -w "%{http_code}" -u "$auth" -X PUT "${base_url}/${db_name}")
    case "$code" in
        201|412|409)
            log_ok "Database ready: ${db_name}"
            ;;
        *)
            log_warn "Database not ready: ${db_name} (HTTP ${code})"
            ;;
    esac
}

log_info "Ensuring system databases exist..."
create_db "_users"
create_db "_replicator"
create_db "_global_changes"

log_info "Ensuring Obsidian database exists: ${COUCHDB_DATABASE}"
create_db "${COUCHDB_DATABASE}"

log_ok "Obsidian LiveSync CouchDB init complete."
