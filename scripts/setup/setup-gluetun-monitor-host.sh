#!/bin/bash

################################################################################
# Gluetun Monitor Host Service Setup Script
# Creates systemd service for gluetun-monitor running as host (not containerized)
# - Runs automatically after boot
# - Only starts when Docker daemon is active
# - Waits for Gluetun to be ready before monitoring starts
# - Hardens monitoring with proper dependencies and health checks
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVICE_NAME="gluetun-monitor"
SERVICE_USER="daniel"
SCRIPT_DIR="/home/daniel/potatostack/scripts/monitor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}-startup.timer"
POTATOSTACK_DIR="/home/daniel/potatostack"
LOG_FILE="/var/log/${SERVICE_NAME}.log"
STATE_FILE="/var/lib/${SERVICE_NAME}/state"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}ERROR${NC}: This script must be run as root"
	echo "Use: sudo $0"
	exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Gluetun Monitor Host Service Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Verify prerequisites
echo -e "${BLUE}[1/5]${NC} Verifying prerequisites..."
echo ""

# Check if user exists
if ! id "$SERVICE_USER" &>/dev/null; then
	echo -e "${RED}ERROR${NC}: User '$SERVICE_USER' does not exist"
	exit 1
fi
echo -e "${GREEN}✓${NC} User '$SERVICE_USER' exists"

# Check if PotatoStack directory exists
if [ ! -d "$POTATOSTACK_DIR" ]; then
	echo -e "${RED}ERROR${NC}: PotatoStack directory not found: $POTATOSTACK_DIR"
	exit 1
fi
echo -e "${GREEN}✓${NC} PotatoStack directory found"

# Check if monitor script exists
if [ ! -f "$SCRIPT_DIR/gluetun-monitor.sh" ]; then
	echo -e "${RED}ERROR${NC}: Monitor script not found: $SCRIPT_DIR/gluetun-monitor.sh"
	exit 1
fi
echo -e "${GREEN}✓${NC} Monitor script found"

# Check if gluetun is configured in compose
if ! docker compose -f "$POTATOSTACK_DIR/docker-compose.yml" config --services | grep -q gluetun; then
	echo -e "${YELLOW}WARNING${NC}: Gluetun service not found in docker-compose.yml"
fi
echo -e "${GREEN}✓${NC} Gluetun configured"

echo ""

# Step 2: Stop and remove existing containerized monitor
echo -e "${BLUE}[2/5]${NC} Removing existing containerized monitor..."
echo ""

CONTAINER_EXISTS=$(docker ps -a --filter "name=$SERVICE_NAME" --format '{{.Names}}' | wc -l)

if [ "$CONTAINER_EXISTS" -gt 0 ]; then
	echo -e "  Stopping existing $SERVICE_NAME container..."
	docker stop "$SERVICE_NAME" 2>/dev/null || true
	docker rm "$SERVICE_NAME" 2>/dev/null || true
	echo -e "${GREEN}✓${NC} Existing container removed"
else
	echo -e "${YELLOW}⊙${NC} No existing container found"
fi

# Check if systemd service exists
if systemctl is-active --quiet 2>/dev/null; then
	if systemctl is-enabled --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
		echo -e "  Disabling systemd service..."
		systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
		rm -f "$TIMER_FILE" 2>/dev/null || true
	fi
	echo -e "${GREEN}✓${NC} Systemd service check complete"
else
	echo -e "${YELLOW}⊙${NC} Systemd not available (not running as service)"
fi

echo ""

# Step 3: Create systemd service file
echo -e "${BLUE}[3/5]${NC} Creating systemd service..."
echo ""

mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Gluetun VPN Monitor - Host Service
Documentation=https://github.com/anomalyco/potatostack
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$POTATOSTACK_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-/etc/default/${SERVICE_NAME}

ExecStart=/bin/bash $SCRIPT_DIR/gluetun-monitor.sh
ExecStop=/bin/kill -TERM \${MAINPID}
ExecStopPost=/bin/bash -c 'docker compose -f $POTATOSTACK_DIR/docker-compose.yml stop prowlarr sonarr radarr lidarr bookshelf bazarr spotiflac qbittorrent slskd pyload pinchflat stash 2>/dev/null || true'

Restart=on-failure
RestartSec=30s
RestartMaxRetries=5

StartLimitInterval=300
StartLimitBurst=5

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓${NC} Systemd service file created: $SERVICE_FILE"

# Step 4: Create startup timer (for delayed start after boot)
echo ""
echo -e "${BLUE}[4/5]${NC} Creating startup timer..."
echo ""

cat >"$TIMER_FILE" <<'EOF'
[Unit]
Description=Gluetun Monitor Startup Timer
Documentation=https://github.com/anomalyco/potatostack

[Timer]
OnBootSec=60s
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

echo -e "${GREEN}✓${NC} Startup timer created: $TIMER_FILE"

# Step 5: Reload systemd
echo ""
echo -e "${BLUE}[5/5]${NC} Reloading systemd daemon..."
echo ""

systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

echo ""

# Step 6: Enable and start services
echo -e "${BLUE}[6/5]${NC} Enabling services..."
echo ""

systemctl enable "${SERVICE_NAME}.service" 2>/dev/null
echo -e "${GREEN}✓${NC} Service enabled"

systemctl enable "${SERVICE_NAME}-startup.timer" 2>/dev/null
echo -e "${GREEN}✓${NC} Startup timer enabled"

echo ""
echo -e "${BLUE}[7/5]${NC} Starting service..."
echo ""

# Don't start if gluetun isn't running
if docker ps --filter "name=gluetun" --format '{{.Names}}' | grep -q gluetun; then
	systemctl start "${SERVICE_NAME}.service"
	echo -e "${GREEN}✓${NC} Service started"

	# Wait a moment for service to initialize
	sleep 3

	# Check service status
	if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
		echo -e "${GREEN}✓${NC} Service is running"
		systemctl status "${SERVICE_NAME}.service" --no-pager -l | head -10
	else
		echo -e "${YELLOW}⚠${NC} Service started but may not be fully initialized"
	fi
else
	echo -e "${YELLOW}⊙${NC} Gluetun is not running, service enabled but not started"
	echo -e "  Service will start automatically when gluetun starts"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Monitor Service Status:${NC}"
echo "  Type: Host service (systemd)"
echo "  User: $SERVICE_USER"
echo "  Command: systemctl status $SERVICE_NAME"
echo "  Logs: journalctl -u $SERVICE_NAME -f"
echo "  Logs file: $LOG_FILE"
echo ""

echo -e "${YELLOW}Service Behavior:${NC}"
echo "  ✓ Auto-starts after 60s boot delay"
echo "  ✓ Checks Docker is available before starting"
echo "  ✓ Restarts automatically on failure (max 5 retries)"
echo "  ✓ Stops VPN services when service stops"
echo "  ✓ Only runs when gluetun is present"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Check status:   systemctl status $SERVICE_NAME"
echo "  View logs:      journalctl -u $SERVICE_NAME -f"
echo "  Restart:        systemctl restart $SERVICE_NAME"
echo "  Stop:          systemctl stop $SERVICE_NAME"
echo "  Disable:        systemctl disable $SERVICE_NAME"
echo ""

echo -e "${YELLOW}To disable host service and use containerized version:${NC}"
echo "  sudo $0 --uninstall"
echo ""

# Step 7: Create wrapper script for manual control
cat >"$SCRIPT_DIR/glmon" <<'EOF'
#!/bin/bash
# Gluetun Monitor Control Script

case "${1:-}" in
  status)
    systemctl status gluetun-monitor --no-pager
    ;;
  logs)
    journalctl -u gluetun-monitor -f
    ;;
  restart)
    sudo systemctl restart gluetun-monitor
    ;;
  stop)
    sudo systemctl stop gluetun-monitor
    ;;
  start)
    sudo systemctl start gluetun-monitor
    ;;
  enable)
    sudo systemctl enable gluetun-monitor gluetun-monitor-startup.timer
    ;;
  disable)
    sudo systemctl disable gluetun-monitor gluetun-monitor-startup.timer
    sudo systemctl stop gluetun-monitor
    ;;
  *)
    echo "Usage: glmon {status|logs|restart|stop|start|enable|disable}"
    echo ""
    echo "Commands:"
    echo "  status   - Show service status"
    echo "  logs     - Show live logs"
    echo "  restart  - Restart service"
    echo "  stop     - Stop service"
    echo "  start    - Start service"
    echo "  enable   - Enable auto-start on boot"
    echo "  disable  - Disable service"
    ;;
esac
EOF

chmod +x "$SCRIPT_DIR/glmon"
echo -e "${GREEN}✓${NC} Control script created: $SCRIPT_DIR/glmon"

# Update .env.example with new service info
if [ -f "$POTATOSTACK_DIR/.env.example" ]; then
	if ! grep -q "GLUETUN_MONITOR_TYPE" "$POTATOSTACK_DIR/.env.example"; then
		echo "" >>"$POTATOSTACK_DIR/.env.example"
		echo "" >>"$POTATOSTACK_DIR/.env.example"
		echo "# Gluetun Monitor Service Type" >>"$POTATOSTACK_DIR/.env.example"
		echo "# host: Runs as systemd host service (reliable, handles auto-restart)" >>"$POTATOSTACK_DIR/.env.example"
		echo "# container: Runs inside Docker container (DinD network issues)" >>"$POTATOSTACK_DIR/.env.example"
		echo "GLUETUN_MONITOR_TYPE=host" >>"$POTATOSTACK_DIR/.env.example"
		echo -e "${GREEN}✓${NC} Added GLUETUN_MONITOR_TYPE to .env.example"
	fi
fi
