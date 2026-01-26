#!/bin/bash
################################################################################
# PotatoStack - Docker Storage Recovery Script
#
# Use this script when Docker storage becomes corrupted after a crash.
# Symptoms:
#   - "layer does not exist" errors
#   - "stat /mnt/storage/docker/overlay2/...: no such file or directory"
#   - "No such container: <hash>" errors
#   - Containers fail to start with image errors
#   - Stale container references that won't go away
#
# WARNING: This will remove ALL Docker images, containers, and metadata!
#          Your data volumes (postgres, photos, etc.) are NOT affected.
#
# Run with: sudo bash scripts/setup/fix-docker-storage.sh
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

DOCKER_ROOT="/mnt/storage/docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo ""
echo "=================================================================="
echo "PotatoStack - Docker Storage Recovery (Aggressive Mode)"
echo "=================================================================="
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Please run with sudo: sudo bash $0"
    exit 1
fi

# Confirm with user
warn "This will DELETE all Docker images, containers, and metadata!"
warn "Your data volumes (postgres, photos, configs) are SAFE."
warn ""
warn "Directories to be removed:"
warn "  - $DOCKER_ROOT/containers (container metadata)"
warn "  - $DOCKER_ROOT/overlay2 (image layers)"
warn "  - $DOCKER_ROOT/image (image metadata)"
warn "  - $DOCKER_ROOT/buildkit (build cache)"
warn "  - $DOCKER_ROOT/network/files (network state)"
echo ""
read -rp "Continue? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
info "Starting aggressive Docker storage recovery..."

# Step 1: Stop Docker completely
log "Stopping Docker services..."
systemctl stop docker.socket 2>/dev/null || true
systemctl stop docker 2>/dev/null || true
sleep 3

# Verify Docker is stopped
if pgrep -x dockerd >/dev/null; then
    warn "Docker still running, force killing..."
    pkill -9 dockerd 2>/dev/null || true
    pkill -9 containerd-shim 2>/dev/null || true
    sleep 3
fi

# Double-check
if pgrep -x dockerd >/dev/null; then
    error "Cannot stop Docker. Try: sudo reboot"
    exit 1
fi

log "Docker stopped successfully"

# Step 2: Aggressive cleanup - remove ALL Docker state
log "Removing ALL Docker storage directories..."

# Container metadata (fixes "No such container" errors)
rm -rf "$DOCKER_ROOT/containers" 2>/dev/null || true
log "  Removed containers/"

# Image layers (fixes "layer does not exist" errors)
rm -rf "$DOCKER_ROOT/overlay2" 2>/dev/null || true
log "  Removed overlay2/"

# Image metadata
rm -rf "$DOCKER_ROOT/image" 2>/dev/null || true
log "  Removed image/"

# Build cache
rm -rf "$DOCKER_ROOT/buildkit" 2>/dev/null || true
log "  Removed buildkit/"

# Network state (fixes stale network references)
rm -rf "$DOCKER_ROOT/network/files" 2>/dev/null || true
log "  Removed network/files/"

# Optional: Remove tmp and runtimes if corrupted
rm -rf "$DOCKER_ROOT/tmp" 2>/dev/null || true
rm -rf "$DOCKER_ROOT/runtimes" 2>/dev/null || true

# Step 3: Recreate directories with proper permissions
log "Recreating Docker storage directories..."
mkdir -p "$DOCKER_ROOT/containers"
mkdir -p "$DOCKER_ROOT/overlay2"
mkdir -p "$DOCKER_ROOT/image"
mkdir -p "$DOCKER_ROOT/buildkit"
mkdir -p "$DOCKER_ROOT/network/files"
mkdir -p "$DOCKER_ROOT/tmp"

# Step 4: Start Docker
log "Starting Docker services..."
systemctl start docker.socket
sleep 2
systemctl start docker
sleep 5

# Step 5: Verify Docker is working
if docker info >/dev/null 2>&1; then
    log "Docker is running!"
    docker info 2>&1 | grep -E "(Server Version|Storage Driver|Docker Root Dir)" | sed 's/^/  /'
else
    error "Docker failed to start. Check: journalctl -u docker.service -n 50"
    exit 1
fi

# Step 6: Pull images and start stack
echo ""
info "Docker storage recovered. Starting stack..."
info "This will take a while as all images need to be re-downloaded."
echo ""

cd "$REPO_ROOT"

log "Pulling images..."
if ! docker compose pull 2>&1 | tee /tmp/docker-pull.log | tail -30; then
    warn "Some images failed to pull. Check /tmp/docker-pull.log"
fi

log "Starting containers..."
if ! docker compose up -d --remove-orphans 2>&1 | tee /tmp/docker-up.log | tail -30; then
    warn "Some containers failed to start. Check /tmp/docker-up.log"
fi

# Step 7: Wait and show status
echo ""
log "Waiting 30 seconds for containers to initialize..."
sleep 30

RUNNING=$(docker ps --filter "status=running" --format "{{.Names}}" | wc -l)
TOTAL=$(docker ps -a --format "{{.Names}}" | wc -l)
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)

echo ""
echo "=================================================================="
log "Recovery complete!"
echo "=================================================================="
echo ""
echo "Status: $RUNNING/$TOTAL containers running"
if [ "$UNHEALTHY" -gt 0 ]; then
    warn "$UNHEALTHY containers are unhealthy (may still be starting)"
fi
echo ""
echo "Check status with:"
echo "  docker ps"
echo "  docker compose ps"
echo "  make health"
echo ""
echo "Logs saved to:"
echo "  /tmp/docker-pull.log"
echo "  /tmp/docker-up.log"
echo ""
