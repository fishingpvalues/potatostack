#!/bin/bash
################################################################################
# Gluetun Monitor Host Service Init Script
# Ensures gluetun-monitor systemd service is properly configured and running
# Runs as init container in docker-compose (like init-storage.sh)
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_NAME="gluetun-monitor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}-startup.timer"
SETUP_SCRIPT="/home/daniel/potatostack/scripts/setup/setup-gluetun-monitor-host.sh"

echo "========================================="
echo "Gluetun Monitor Host Service Init"
echo "========================================="
echo ""

# Check if running as root (required for systemd management)
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}ERROR${NC}: This script must be run as root to manage systemd"
	echo "Use: sudo $0"
	exit 1
fi

################################################################################
# Step 1: Check if systemd service exists
################################################################################
echo -e "${BLUE}[INFO]${NC} Checking if gluetun-monitor systemd service exists..."
echo ""

if [ ! -f "$SERVICE_FILE" ]; then
	echo -e "${YELLOW}⊙${NC} Service file not found: $SERVICE_FILE"
	echo -e "${BLUE}[INFO]${NC} Running setup script to create service..."

	# Run setup script
	if [ -x "$SETUP_SCRIPT" ]; then
		"$SETUP_SCRIPT"
	else
		echo -e "${RED}ERROR${NC}: Setup script not found: $SETUP_SCRIPT"
		exit 1
	fi

	# Check if service was created successfully
	if [ -f "$SERVICE_FILE" ]; then
		echo -e "${GREEN}✓${NC} Service created successfully"
	else
		echo -e "${RED}ERROR${NC}: Service creation failed"
		exit 1
	fi
else
	echo -e "${GREEN}✓${NC} Service file exists: $SERVICE_FILE"
fi

################################################################################
# Step 2: Check if service is enabled
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking if gluetun-monitor service is enabled..."
echo ""

if systemctl is-enabled --quiet "${SERVICE_NAME}.service"; then
	echo -e "${GREEN}✓${NC} Service is enabled"
else
	echo -e "${YELLOW}⊙${NC} Service is not enabled, enabling now..."
	systemctl enable "${SERVICE_NAME}.service" 2>/dev/null
	if systemctl is-enabled --quiet "${SERVICE_NAME}.service"; then
		echo -e "${GREEN}✓${NC} Service enabled"
	else
		echo -e "${RED}ERROR${NC}: Failed to enable service"
		exit 1
	fi
fi

################################################################################
# Step 3: Check if startup timer is enabled
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking if startup timer is enabled..."
echo ""

if systemctl is-enabled --quiet "${SERVICE_NAME}-startup.timer"; then
	echo -e "${GREEN}✓${NC} Startup timer is enabled"
else
	echo -e "${YELLOW}⊙${NC} Startup timer is not enabled, enabling now..."
	systemctl enable "${SERVICE_NAME}-startup.timer" 2>/dev/null
	if systemctl is-enabled --quiet "${SERVICE_NAME}-startup.timer"; then
		echo -e "${GREEN}✓${NC} Startup timer enabled"
	else
		echo -e "${YELLOW}⊙${NC} Failed to enable startup timer (may not be critical)"
	fi
fi

################################################################################
# Step 4: Check if Docker daemon is running
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking if Docker daemon is running..."
echo ""

if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
	echo -e "${GREEN}✓${NC} Docker daemon is running"
else
	echo -e "${YELLOW}⚠${NC} Docker daemon is not running"
	echo -e "${BLUE}[INFO]${NC} Skipping monitor service management until Docker is available"
	echo -e "${BLUE}[INFO]${NC} Service will auto-start when Docker becomes available"
	exit 0
fi

################################################################################
# Step 5: Check if gluetun container is running
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking if Gluetun container is running..."
echo ""

if docker ps --filter "name=gluetun" --format '{{.Names}}' 2>/dev/null | grep -q gluetun; then
	echo -e "${GREEN}✓${NC} Gluetun is running"

	# Check gluetun health
	HEALTH_STATUS=$(docker inspect gluetun --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

	if [ "$HEALTH_STATUS" = "healthy" ]; then
		echo -e "${GREEN}✓${NC} Gluetun is healthy"
	else
		echo -e "${YELLOW}⚠${NC} Gluetun is running but health: ${HEALTH_STATUS}"
	fi
else
	echo -e "${YELLOW}⊙${NC} Gluetun is not running"
	echo -e "${BLUE}[INFO]${NC} Monitor will wait for Gluetun to become available"
fi

################################################################################
# Step 6: Check monitor service status
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking gluetun-monitor service status..."
echo ""

if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
	echo -e "${GREEN}✓${NC} Monitor service is running"
else
	echo -e "${YELLOW}⊙${NC} Monitor service is not running"

	# Check if we should start it (only if gluetun is running and healthy)
	if docker ps --filter "name=gluetun" --format '{{.Names}}' 2>/dev/null | grep -q gluetun; then
		HEALTH_STATUS=$(docker inspect gluetun --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

		if [ "$HEALTH_STATUS" = "healthy" ]; then
			echo -e "${BLUE}[INFO]${NC} Starting monitor service..."
			systemctl start "${SERVICE_NAME}.service" 2>/dev/null

			if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
				echo -e "${GREEN}✓${NC} Monitor service started successfully"
			else
				echo -e "${YELLOW}⚠${NC} Monitor service failed to start"
			fi
		else
			echo -e "${YELLOW}⊙${NC} Not starting monitor (gluetun not healthy)"
		fi
	else
		echo -e "${YELLOW}⊙${NC} Not starting monitor (gluetun not running)"
	fi
fi

################################################################################
# Step 7: Verify VPN services are running
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Checking VPN-dependent services..."
echo ""

VPN_SERVICES="prowlarr sonarr radarr lidarr bookshelf bazarr spotiflac qbittorrent slskd pyload stash"
RUNNING_COUNT=0

for service in $VPN_SERVICES; do
	if docker ps --filter "name=$service" --format '{{.Names}}' 2>/dev/null | grep -q "$service"; then
		RUNNING_COUNT=$((RUNNING_COUNT + 1))
	fi
done

echo -e "${GREEN}✓${NC} VPN services running: ${RUNNING_COUNT}/12"

if [ $RUNNING_COUNT -lt 12 ]; then
	echo -e "${YELLOW}⚠${NC} Some VPN services are not running"
	echo -e "${BLUE}[INFO]${NC} This is normal if VPN is not yet healthy"
else
	echo -e "${GREEN}✓${NC} All VPN services are running"
fi

################################################################################
# Summary
################################################################################
echo ""
echo "========================================="
echo -e "${GREEN}✓ Initialization complete${NC}"
echo "========================================="
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  - Host service: Configured"
echo "  - Service file: $SERVICE_FILE"
echo "  - Service enabled: $(systemctl is-enabled --quiet "${SERVICE_NAME}.service" && echo "YES" || echo "NO")"
echo "  - Timer enabled: $(systemctl is-enabled --quiet "${SERVICE_NAME}-startup.timer" && echo "YES" || echo "NO")"
echo "  - Docker: $(command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1 && echo "RUNNING" || echo "NOT RUNNING")"
echo "  - Gluetun: $(docker ps --filter "name=gluetun" --format '{{.Names}}' 2>/dev/null | grep -q gluetun && echo "RUNNING" || echo "NOT RUNNING")"
echo "  - Monitor: $(systemctl is-active --quiet "${SERVICE_NAME}.service" && echo "RUNNING" || echo "NOT RUNNING")"
echo "  - VPN services: ${RUNNING_COUNT}/12 running"
echo ""
echo -e "${BLUE}[INFO]${NC} Monitor is ready and will automatically manage VPN services"
echo ""
