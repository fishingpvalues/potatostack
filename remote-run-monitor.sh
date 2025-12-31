#!/bin/bash
# Remote Stack Runner - Executes run-and-monitor.sh on target server via SSH

SERVER="192.168.178.40"
USER="daniel"
PASSWORD="schneck0"
REMOTE_DIR="~/light"
MONITOR_TIME=${1:-60}

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║         REMOTE STACK RUNNER - SSH to $SERVER                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if sshpass is installed
if ! command -v sshpass &>/dev/null; then
	echo "Installing sshpass..."
	pkg install -y sshpass
fi

echo "[1/4] Copying files to server..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
	docker-compose.yml \
	.env.example \
	run-and-monitor.sh \
	$USER@$SERVER:$REMOTE_DIR/

echo ""
echo "[2/4] Making script executable..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$SERVER \
	"chmod +x $REMOTE_DIR/run-and-monitor.sh"

echo ""
echo "[3/4] Executing run-and-monitor.sh on server..."
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$SERVER \
	"cd $REMOTE_DIR && ./run-and-monitor.sh $MONITOR_TIME"

EXIT_CODE=$?

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "[4/4] Complete!"

if [ $EXIT_CODE -eq 0 ]; then
	echo "✓ Stack monitoring completed successfully"
else
	echo "✗ Stack monitoring had issues (exit code: $EXIT_CODE)"
fi

echo ""
echo "To view live logs:"
echo "  sshpass -p '$PASSWORD' ssh $USER@$SERVER 'cd $REMOTE_DIR && docker compose logs -f'"
echo ""
echo "To check stack status:"
echo "  sshpass -p '$PASSWORD' ssh $USER@$SERVER 'cd $REMOTE_DIR && docker compose ps'"
