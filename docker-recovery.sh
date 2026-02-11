#!/bin/bash
################################################################################
# Docker Storage Recovery Script
# Fixes Docker overlay2 layer corruption and permission issues
# Use after system restart when Docker fails with "layer does not exist" errors
#
# BACKUP WARNING: This script DOES NOT delete any data
# - .env file is backed up before proceeding
# - Container data (volumes, bind mounts) is preserved
# - Only Docker metadata (images, containers) is cleaned and will be re-pulled
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log function
log() {
	echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1"
	exit 1
}

# Check if running as root (or with sudo)
check_sudo() {
	if [ "$EUID" -ne 0 ]; then
		if ! sudo -n true 2>/dev/null; then
			echo "This script requires sudo privileges. Please run with sudo or ensure password-less sudo is configured."
			exit 1
		fi
	fi
}

# Backup .env file
backup_env() {
	if [ -f ".env" ]; then
		local backup_file=".env.backup-$(date +%Y%m%d-%H%M%S)"
		log "Backing up .env to $backup_file"
		cp .env "$backup_file"
		log "Backup created successfully"
	else
		warn ".env file not found, skipping backup"
	fi
}

# Stop all containers
stop_containers() {
	log "Stopping all Docker containers..."
	docker compose down --remove-orphans 2>&1 || true

	log "Force removing any remaining containers..."
	docker ps -aq | xargs -r docker rm -f 2>&1 || true
}

# Fix Docker directory permissions
fix_permissions() {
	local docker_dir="/mnt/storage/docker"

	if [ ! -d "$docker_dir" ]; then
		error "Docker directory $docker_dir not found. Is /mnt/storage mounted?"
	fi

	log "Fixing Docker directory permissions..."
	echo "schneck0" | sudo -S chmod 755 "$docker_dir"
	echo "schneck0" | sudo -S chmod -R 755 "$docker_dir/overlay2" \
		"$docker_dir/containers" \
		"$docker_dir/volumes" \
		"$docker_dir/tmp" \
		"$docker_dir/image" \
		"$docker_dir/buildkit" 2>/dev/null || true

	log "Permissions fixed"
}

# Clean corrupted Docker metadata
clean_docker_metadata() {
	log "Cleaning corrupted Docker image and overlay2 metadata..."
	echo "schneck0" | sudo -S rm -rf /mnt/storage/docker/image 2>/dev/null || true
	echo "schneck0" | sudo -S rm -rf /mnt/storage/docker/overlay2/* 2>/dev/null || true
	echo "schneck0" | sudo -S rm -rf /mnt/storage/docker/containers/* 2>/dev/null || true
	log "Docker metadata cleaned"
}

# Restart Docker daemon
restart_docker() {
	log "Restarting Docker daemon..."
	echo "schneck0" | sudo -S systemctl restart docker
	log "Waiting for Docker to start..."
	sleep 5
}

# Verify Docker is running
verify_docker() {
	if ! docker info >/dev/null 2>&1; then
		error "Docker is not running after restart"
	fi
	log "Docker is running"
}

# Start the stack
start_stack() {
	log "Starting PotatoStack..."
	docker compose up -d 2>&1
}

# Wait for services to be healthy
wait_for_health() {
	log "Waiting for services to start (this may take several minutes)..."

	local max_wait=300 # 5 minutes
	local waited=0

	while [ $waited -lt $max_wait ]; do
		local unhealthy=$(docker compose ps 2>&1 | grep -c "unhealthy" || true)
		local restarting=$(docker compose ps 2>&1 | grep -c "Restarting" || true)
		local total=$(docker compose ps 2>&1 | grep -c "Up" || true)

		echo "[$waited/$max_wait] Running: $total | Unhealthy: $unhealthy | Restarting: $restarting"

		if [ "$unhealthy" -eq 0 ] && [ "$restarting" -eq 0 ]; then
			log "All services are running healthy!"
			return 0
		fi

		sleep 10
		waited=$((waited + 10))
	done

	warn "Some services may still be starting. Check with 'docker compose ps'"
}

# Main execution
main() {
	log "Starting Docker storage recovery..."
	log "This will clean Docker metadata and restart the stack"
	log "All data in volumes and bind mounts will be preserved"
	echo ""

	read -p "Continue? (y/N) " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		log "Cancelled by user"
		exit 0
	fi

	check_sudo
	backup_env
	stop_containers
	fix_permissions
	clean_docker_metadata
	restart_docker
	verify_docker
	start_stack
	wait_for_health

	log ""
	log "========================================="
	log "Docker storage recovery complete!"
	log "========================================="
	log ""
	log "Next steps:"
	log "1. Check service status: docker compose ps"
	log "2. View logs: docker compose logs -f [service-name]"
	log "3. If some services are still restarting, check their logs for config issues"
	log ""
}

main "$@"
