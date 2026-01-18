#!/bin/bash
set -euo pipefail

# PotatoStack Startup Script
# Ensures clean startup after reboot/crash by recreating containers
# This fixes the "Created" state issue where containers don't auto-start

COMPOSE_DIR="/home/daniel/potatostack"
LOG_FILE="/var/log/potatostack-startup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cd "$COMPOSE_DIR" || exit 1

log "Starting PotatoStack startup sequence..."

# Force restart storage-init to ensure all directories and permissions are set
force_init() {
    log "Running storage-init to ensure directory structure..."
    docker compose rm -f storage-init 2>/dev/null || true
    docker compose up storage-init 2>&1 | tee -a "$LOG_FILE"
    log "Storage-init completed"
}

# Wait for Docker to be fully ready
max_wait=60
waited=0
while ! docker info >/dev/null 2>&1; do
    if [ $waited -ge $max_wait ]; then
        log "ERROR: Docker not ready after ${max_wait}s"
        exit 1
    fi
    sleep 2
    waited=$((waited + 2))
done
log "Docker is ready (waited ${waited}s)"

# Check for containers stuck in "Created" state (symptom of crash)
created_count=$(docker ps -a --filter "status=created" --format "{{.Names}}" | wc -l)
if [ "$created_count" -gt 0 ]; then
    log "Found $created_count containers in 'Created' state - performing clean restart"
    docker compose down --remove-orphans 2>&1 | tee -a "$LOG_FILE"
fi

# Force run storage-init first
force_init

# Start all services
log "Starting all services..."
docker compose up -d 2>&1 | tee -a "$LOG_FILE"

# Wait a bit and check health
sleep 30
running=$(docker ps --filter "status=running" --format "{{.Names}}" | wc -l)
total=$(docker ps -a --format "{{.Names}}" | wc -l)
log "Startup complete: $running/$total containers running"

# Log any problem containers
problems=$(docker ps -a --filter "status=restarting" --filter "status=exited" --filter "status=created" --format "{{.Names}}: {{.Status}}")
if [ -n "$problems" ]; then
    log "Problem containers:"
    echo "$problems" | while read -r line; do log "  $line"; done
fi
