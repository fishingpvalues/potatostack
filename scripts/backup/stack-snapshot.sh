#!/bin/sh
################################################################################
# PotatoStack - Kopia Snapshot Runner
# Runs a full snapshot inside the Kopia container for mounted /data paths
################################################################################

set -eu

KOPIA_CONTAINER="${KOPIA_CONTAINER:-kopia}"
SNAPSHOT_PATHS="${SNAPSHOT_PATHS:-/data}"
SNAPSHOT_LOG_FILE="${SNAPSHOT_LOG_FILE:-/mnt/storage/kopia/stack-snapshot.log}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "${SNAPSHOT_LOG_FILE}")"
exec >>"${SNAPSHOT_LOG_FILE}" 2>&1

printf '[%s] Starting snapshot run\n' "${timestamp}"

if ! command -v docker >/dev/null 2>&1; then
	printf '[%s] ERROR: docker not found in PATH\n' "${timestamp}"
	exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${KOPIA_CONTAINER}"; then
	printf '[%s] ERROR: Kopia container not running: %s\n' "${timestamp}" "${KOPIA_CONTAINER}"
	exit 1
fi

for path in ${SNAPSHOT_PATHS}; do
	printf '[%s] Snapshotting %s\n' "${timestamp}" "${path}"
	docker exec "${KOPIA_CONTAINER}" kopia snapshot create "${path}"
done

printf '[%s] Snapshot run completed\n' "${timestamp}"
