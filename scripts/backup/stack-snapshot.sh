#!/bin/sh
################################################################################
# PotatoStack - Snapshot Logger
# Logs snapshot activity (backup system migrated)
################################################################################

set -eu

SNAPSHOT_PATHS="${SNAPSHOT_PATHS:-/data}"
SNAPSHOT_LOG_FILE="${SNAPSHOT_LOG_FILE:-/mnt/storage/stack-snapshot.log}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "${SNAPSHOT_LOG_FILE}")"
exec >>"${SNAPSHOT_LOG_FILE}" 2>&1

printf '[%s] Snapshot check - paths: %s\n' "${timestamp}" "${SNAPSHOT_PATHS}"
printf '[%s] Note: Kopia backup system has been removed. Use Velld for database backups.\n' "${timestamp}"
