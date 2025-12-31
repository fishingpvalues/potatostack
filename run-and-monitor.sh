#!/bin/bash
# Production-grade Docker Compose Stack Runner & Monitor
# Starts stack, monitors health, checks logs for failures, reports issues

set -e

MONITOR_TIME=${1:-60}  # Monitor for 60 seconds by default
STACK_DIR="/data/data/com.termux/files/home/workdir/potatostack"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              DOCKER COMPOSE STACK - RUN & MONITOR                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script must be run on the target server (192.168.178.40)"
echo "Monitor duration: ${MONITOR_TIME}s"
echo ""

# Check if running on server or local
if [ ! -f /var/run/docker.sock ]; then
    echo "⚠ Docker not available on this system"
    echo ""
    echo "To run this on your server (192.168.178.40):"
    echo "1. Copy this script to the server:"
    echo "   scp run-and-monitor.sh daniel@192.168.178.40:~/light/"
    echo ""
    echo "2. SSH to server and run:"
    echo "   ssh daniel@192.168.178.40"
    echo "   cd ~/light && ./run-and-monitor.sh"
    echo ""
    exit 1
fi

cd "$STACK_DIR" || exit 1

# Phase 1: Pre-flight checks
echo "[1/8] Pre-flight Checks..."
if [ ! -f docker-compose.yml ]; then
    echo "✗ docker-compose.yml not found"
    exit 1
fi
echo "  ✓ docker-compose.yml found"

if [ ! -f .env ]; then
    echo "  ⚠ .env not found, using .env.example"
    cp .env.example .env
fi
echo "  ✓ Environment file ready"

# Phase 2: Validate config
echo ""
echo "[2/8] Validating Docker Compose Config..."
if docker compose config > /dev/null 2>&1; then
    echo "  ✓ Config valid"
else
    echo "  ✗ Config invalid"
    docker compose config 2>&1 | head -20
    exit 1
fi

# Phase 3: Start core infrastructure first
echo ""
echo "[3/8] Starting Core Infrastructure (Phase 1)..."
docker compose up -d postgres redis-cache mongo pgbouncer 2>&1 | grep -v "^$"
echo "  ✓ Databases starting..."
sleep 5

# Check database health
echo "  Checking database health..."
for db in postgres redis-cache mongo pgbouncer; do
    if docker ps --filter name=$db --filter status=running | grep -q $db; then
        echo "    ✓ $db running"
    else
        echo "    ✗ $db failed to start"
        docker logs $db --tail 50
    fi
done

# Phase 4: Start networking
echo ""
echo "[4/8] Starting Networking (Phase 2)..."
docker compose up -d traefik gluetun adguardhome crowdsec 2>&1 | grep -v "^$"
sleep 3

# Phase 5: Start monitoring
echo ""
echo "[5/8] Starting Monitoring (Phase 3)..."
docker compose up -d prometheus grafana loki netdata uptime-kuma 2>&1 | grep -v "^$"
sleep 3

# Phase 6: Start everything else
echo ""
echo "[6/8] Starting All Services (Phase 4)..."
docker compose up -d 2>&1 | grep -v "^$"
echo "  ✓ All services starting..."

# Phase 7: Monitor startup
echo ""
echo "[7/8] Monitoring Startup (${MONITOR_TIME}s)..."
echo ""

START_TIME=$(date +%s)
END_TIME=$((START_TIME + MONITOR_TIME))

# Arrays to track issues
declare -a FAILED_SERVICES
declare -a ERROR_SERVICES
declare -a WARNING_SERVICES

while [ $(date +%s) -lt $END_TIME ]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Get container stats
    TOTAL=$(docker compose ps -a | tail -n +2 | wc -l)
    RUNNING=$(docker compose ps --filter status=running | tail -n +2 | wc -l)
    UNHEALTHY=$(docker compose ps --filter health=unhealthy | tail -n +2 | wc -l)
    EXITED=$(docker compose ps --filter status=exited | tail -n +2 | wc -l)

    echo "[$ELAPSED/${MONITOR_TIME}s] Running: $RUNNING/$TOTAL | Unhealthy: $UNHEALTHY | Exited: $EXITED"

    # Check for failed containers
    FAILED=$(docker compose ps --filter status=exited --format '{{.Service}}')
    if [ -n "$FAILED" ]; then
        for service in $FAILED; do
            if [[ ! " ${FAILED_SERVICES[@]} " =~ " ${service} " ]]; then
                FAILED_SERVICES+=("$service")
                echo "  ✗ $service exited!"
            fi
        done
    fi

    sleep 5
done

echo ""
echo "[8/8] Log Analysis..."

# Check logs for common error patterns
ERROR_PATTERNS=(
    "error"
    "fatal"
    "panic"
    "exception"
    "failed"
    "refused"
    "timeout"
    "cannot connect"
    "permission denied"
)

echo ""
echo "Scanning logs for errors (last 100 lines per service)..."

docker compose ps --format '{{.Service}}' | while read service; do
    # Skip if service not running
    if ! docker compose ps --filter name=$service --filter status=running | grep -q $service; then
        continue
    fi

    # Get recent logs
    LOGS=$(docker compose logs --tail 100 $service 2>&1)

    # Check for errors
    ERROR_COUNT=0
    for pattern in "${ERROR_PATTERNS[@]}"; do
        if echo "$LOGS" | grep -qi "$pattern"; then
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    done

    if [ $ERROR_COUNT -gt 0 ]; then
        echo ""
        echo "⚠ $service has errors in logs:"
        echo "$LOGS" | grep -i -E "error|fatal|panic|exception|failed" | tail -5 | sed 's/^/  /'
        ERROR_SERVICES+=("$service")
    fi
done

# Phase 8: Generate report
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                            MONITORING REPORT                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Overall stats
TOTAL=$(docker compose ps -a | tail -n +2 | wc -l)
RUNNING=$(docker compose ps --filter status=running | tail -n +2 | wc -l)
HEALTHY=$(docker compose ps --filter health=healthy | tail -n +2 | wc -l)
UNHEALTHY=$(docker compose ps --filter health=unhealthy | tail -n +2 | wc -l)
EXITED=$(docker compose ps --filter status=exited | tail -n +2 | wc -l)

echo "Service Status:"
echo "  Total services:    $TOTAL"
echo "  Running:           $RUNNING"
echo "  Healthy:           $HEALTHY"
echo "  Unhealthy:         $UNHEALTHY"
echo "  Exited/Failed:     $EXITED"
echo ""

# Resource usage
echo "Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
echo ""

# Failed services
if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo "⚠ Failed Services (${#FAILED_SERVICES[@]}):"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  ✗ $service"
        echo "    Last logs:"
        docker compose logs --tail 10 $service 2>&1 | sed 's/^/      /'
    done
    echo ""
fi

# Services with errors
if [ ${#ERROR_SERVICES[@]} -gt 0 ]; then
    echo "⚠ Services with Error Logs (${#ERROR_SERVICES[@]}):"
    for service in "${ERROR_SERVICES[@]}"; do
        echo "  - $service"
    done
    echo ""
fi

# Health summary
echo "Health Summary:"
if [ $EXITED -eq 0 ] && [ $UNHEALTHY -eq 0 ]; then
    echo "  ✅ All services healthy"
elif [ $EXITED -gt 0 ]; then
    echo "  ❌ $EXITED services failed"
elif [ $UNHEALTHY -gt 0 ]; then
    echo "  ⚠ $UNHEALTHY services unhealthy"
fi

echo ""
echo "To view logs for a specific service:"
echo "  docker compose logs -f <service-name>"
echo ""
echo "To restart failed services:"
echo "  docker compose restart <service-name>"
echo ""
echo "To stop all:"
echo "  docker compose down"
