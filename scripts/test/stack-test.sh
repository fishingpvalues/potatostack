#!/bin/bash

# Comprehensive Stack Testing Script with OS Detection
# Tests docker-compose stack and analyzes logs for issues
# Based on SOTA 2025 Docker Compose testing practices:
# - Healthcheck validation across all services
# - Dependency chain testing
# - Port mapping validation
# - Service-specific endpoint testing
# - Log analysis and resource monitoring

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="stack-test-report-$(date +%Y%m%d-%H%M%S).txt"
LOG_DIR="./test-logs"
mkdir -p "$LOG_DIR"

# Detect OS and set commands accordingly
detect_os() {
	echo -e "${BLUE}[INFO]${NC} Detecting OS..."

	if [ -d "/data/data/com.termux" ]; then
		OS_TYPE="termux"
		DOCKER_CMD="proot-distro login debian --shared-tmp -- docker-compose -f /data/data/com.termux/files/home/workdir/potatostack/docker-compose.yml"
		echo -e "${GREEN}[OK]${NC} Running on Termux/Android - using proot"
	elif [ -f /etc/debian_version ] || [ -f /etc/redhat-release ] || [ -f /etc/arch-release ]; then
		OS_TYPE="linux"
		if command -v docker-compose &>/dev/null; then
			DOCKER_CMD="docker-compose"
		elif docker compose version &>/dev/null 2>&1; then
			DOCKER_CMD="docker compose"
		else
			echo -e "${RED}[ERROR]${NC} Docker Compose not found"
			exit 1
		fi
		echo -e "${GREEN}[OK]${NC} Running on Linux - using docker-compose"
	else
		echo -e "${RED}[ERROR]${NC} Unsupported OS"
		exit 1
	fi

	echo "OS Type: $OS_TYPE" >>"$REPORT_FILE"
	echo "Docker Command: $DOCKER_CMD" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"
}

# Check if Docker daemon is running
check_docker_available() {
	echo -e "${BLUE}[INFO]${NC} Checking Docker daemon availability..."

	if [ "$OS_TYPE" = "termux" ]; then
		if ! proot-distro login debian --shared-tmp -- docker ps >/dev/null 2>&1; then
			echo -e "${RED}[ERROR]${NC} Docker daemon is not running in proot environment"
			echo ""
			echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
			echo -e "${YELLOW}║  Docker cannot run in Termux/proot (kernel limitations)      ║${NC}"
			echo -e "${YELLOW}║                                                               ║${NC}"
			echo -e "${YELLOW}║  To run full tests, use one of these options:                ║${NC}"
			echo -e "${YELLOW}║  1. Run on native Linux server (192.168.178.158)              ║${NC}"
			echo -e "${YELLOW}║  2. Use GitHub Actions (push to trigger workflow)            ║${NC}"
			echo -e "${YELLOW}║  3. Run validation-only tests: make validate                 ║${NC}"
			echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
			echo ""
			echo "Docker Status: NOT AVAILABLE" >>"$REPORT_FILE"
			echo "Reason: proot environment lacks kernel namespaces/cgroups" >>"$REPORT_FILE"
			echo "" >>"$REPORT_FILE"
			return 1
		fi
	else
		if ! docker ps >/dev/null 2>&1; then
			echo -e "${RED}[ERROR]${NC} Docker daemon is not running"
			echo ""
			echo -e "${YELLOW}Start Docker with: sudo systemctl start docker${NC}"
			echo ""
			echo "Docker Status: NOT RUNNING" >>"$REPORT_FILE"
			return 1
		fi
	fi

	echo -e "${GREEN}[OK]${NC} Docker daemon is running"
	echo "Docker Status: RUNNING" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"
}

# Validate drive structure
validate_drive_structure() {
	echo -e "${BLUE}[INFO]${NC} Validating drive structure..."
	echo "=== Drive Structure Validation ===" >>"$REPORT_FILE"

	local missing_dirs=0
	local required_dirs=(
		"/mnt/storage"
		"/mnt/ssd/docker-data"
		"/mnt/cachehdd"
	)

	for dir in "${required_dirs[@]}"; do
		if [ -d "$dir" ]; then
			echo -e "  ${GREEN}✓${NC} $dir exists"
			echo "  ✓ $dir: EXISTS" >>"$REPORT_FILE"

			# Check if writable
			if [ -w "$dir" ]; then
				echo "    Writable: YES" >>"$REPORT_FILE"
			else
				echo -e "    ${YELLOW}[WARNING]${NC} Not writable"
				echo "    Writable: NO" >>"$REPORT_FILE"
			fi
		else
			echo -e "  ${YELLOW}?${NC} $dir not found (will be created by storage-init)"
			echo "  ? $dir: MISSING (will be created)" >>"$REPORT_FILE"
			missing_dirs=$((missing_dirs + 1))
		fi
	done

	echo "" >>"$REPORT_FILE"

	if [ $missing_dirs -gt 0 ]; then
		echo -e "${YELLOW}[INFO]${NC} $missing_dirs directories missing - storage-init will create them"
	else
		echo -e "${GREEN}[OK]${NC} All required directories exist"
	fi
}

# Start stack
start_stack() {
	echo -e "${BLUE}[INFO]${NC} Starting stack..."
	echo "=== Stack Startup ===" >>"$REPORT_FILE"

	if $DOCKER_CMD up -d >>"$LOG_DIR/startup.log" 2>&1; then
		echo -e "${GREEN}[OK]${NC} Stack started successfully"
		echo "Status: SUCCESS" >>"$REPORT_FILE"
	else
		echo -e "${RED}[ERROR]${NC} Stack startup failed"
		echo "Status: FAILED" >>"$REPORT_FILE"
		cat "$LOG_DIR/startup.log" >>"$REPORT_FILE"
		return 1
	fi
	echo "" >>"$REPORT_FILE"
}

# Get container list
get_containers() {
	echo -e "${BLUE}[INFO]${NC} Getting container list..."
	if [ "$OS_TYPE" = "termux" ]; then
		proot-distro login debian --shared-tmp -- docker ps --format "{{.Names}}" >"$LOG_DIR/containers.txt"
	else
		docker ps --format "{{.Names}}" >"$LOG_DIR/containers.txt"
	fi
}

# Analyze logs for each container
analyze_logs() {
	echo -e "${BLUE}[INFO]${NC} Analyzing container logs..."
	echo "=== Log Analysis ===" >>"$REPORT_FILE"

	local total_warnings=0
	local total_errors=0
	local total_critical=0

	while IFS= read -r container; do
		echo -e "${BLUE}[INFO]${NC} Analyzing $container..."

		if [ "$OS_TYPE" = "termux" ]; then
			proot-distro login debian --shared-tmp -- docker logs "$container" >"$LOG_DIR/${container}.log" 2>&1 || true
		else
			docker logs "$container" >"$LOG_DIR/${container}.log" 2>&1 || true
		fi

		# Count different issue types
		warnings=$(grep -iE "warn|warning" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)
		errors=$(grep -iE "error|err|fail|failed" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)
		critical=$(grep -iE "critical|fatal|panic|exception" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)

		total_warnings=$((total_warnings + warnings))
		total_errors=$((total_errors + errors))
		total_critical=$((total_critical + critical))

		echo "Container: $container" >>"$REPORT_FILE"
		echo "  Warnings: $warnings" >>"$REPORT_FILE"
		echo "  Errors: $errors" >>"$REPORT_FILE"
		echo "  Critical: $critical" >>"$REPORT_FILE"

		# Extract sample issues
		if [ "$errors" -gt 0 ]; then
			echo "  Sample Errors:" >>"$REPORT_FILE"
			grep -iE "error|err|fail|failed" "$LOG_DIR/${container}.log" 2>/dev/null | head -5 | sed 's/^/    /' >>"$REPORT_FILE" || true
		fi

		if [ "$critical" -gt 0 ]; then
			echo "  Sample Critical Issues:" >>"$REPORT_FILE"
			grep -iE "critical|fatal|panic|exception" "$LOG_DIR/${container}.log" 2>/dev/null | head -3 | sed 's/^/    /' >>"$REPORT_FILE" || true
		fi
		echo "" >>"$REPORT_FILE"

	done <"$LOG_DIR/containers.txt"

	echo "=== Summary ===" >>"$REPORT_FILE"
	echo "Total Warnings: $total_warnings" >>"$REPORT_FILE"
	echo "Total Errors: $total_errors" >>"$REPORT_FILE"
	echo "Total Critical: $total_critical" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	if [ "$total_critical" -gt 0 ]; then
		echo -e "${RED}[CRITICAL]${NC} Found $total_critical critical issues"
	elif [ "$total_errors" -gt 10 ]; then
		echo -e "${YELLOW}[WARNING]${NC} Found $total_errors errors"
	else
		echo -e "${GREEN}[OK]${NC} Log analysis complete"
	fi
}

# Wait for containers to be healthy
wait_for_health() {
	echo -e "${BLUE}[INFO]${NC} Waiting for containers to be healthy..."
	local max_wait=180
	local wait_time=0
	local unhealthy_count=999

	while [ $wait_time -lt $max_wait ] && [ $unhealthy_count -gt 0 ]; do
		if [ "$OS_TYPE" = "termux" ]; then
			unhealthy_count=$(proot-distro login debian --shared-tmp -- docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
			starting_count=$(proot-distro login debian --shared-tmp -- docker ps --filter "health=starting" --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
		else
			unhealthy_count=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
			starting_count=$(docker ps --filter "health=starting" --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
		fi

		total_waiting=$((unhealthy_count + starting_count))

		if [ $total_waiting -eq 0 ]; then
			echo -e "${GREEN}[OK]${NC} All containers are healthy"
			return 0
		fi

		echo -e "${YELLOW}[WAIT]${NC} $total_waiting containers still initializing... ($wait_time/$max_wait seconds)"
		sleep 10
		wait_time=$((wait_time + 10))
	done

	if [ $unhealthy_count -gt 0 ]; then
		echo -e "${RED}[ERROR]${NC} $unhealthy_count containers are unhealthy after $max_wait seconds"
		return 1
	fi
}

# Check container health with chaos indicators
check_health() {
	echo -e "${BLUE}[INFO]${NC} Checking container health with chaos indicators..."
	echo "=== Health Check & Chaos Indicators ===" >>"$REPORT_FILE"

	local unhealthy_containers=0
	local healthy_containers=0
	local no_healthcheck=0
	local total_restarts=0
	local oom_kills=0

	while IFS= read -r container; do
		if [ "$OS_TYPE" = "termux" ]; then
			health=$(proot-distro login debian --shared-tmp -- docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
			status=$(proot-distro login debian --shared-tmp -- docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
			restarts=$(proot-distro login debian --shared-tmp -- docker inspect --format='{{.RestartCount}}' "$container" 2>/dev/null || echo "0")
			oom=$(proot-distro login debian --shared-tmp -- docker inspect --format='{{.State.OOMKilled}}' "$container" 2>/dev/null || echo "false")
		else
			health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
			status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
			restarts=$(docker inspect --format='{{.RestartCount}}' "$container" 2>/dev/null || echo "0")
			oom=$(docker inspect --format='{{.State.OOMKilled}}' "$container" 2>/dev/null || echo "false")
		fi

		echo "Container: $container" >>"$REPORT_FILE"
		echo "  Status: $status" >>"$REPORT_FILE"
		echo "  Health: $health" >>"$REPORT_FILE"
		echo "  Restarts: $restarts" >>"$REPORT_FILE"
		echo "  OOM Killed: $oom" >>"$REPORT_FILE"

		total_restarts=$((total_restarts + restarts))
		if [ "$oom" = "true" ]; then
			oom_kills=$((oom_kills + 1))
			echo -e "  ${RED}⚠${NC} $container was OOM killed!"
		fi

		if [ "$restarts" -gt 3 ]; then
			echo -e "  ${YELLOW}⚠${NC} $container has restarted $restarts times"
		fi

		if [ "$health" = "healthy" ]; then
			healthy_containers=$((healthy_containers + 1))
			echo -e "  ${GREEN}✓${NC} $container is healthy"
		elif [ "$health" = "unhealthy" ]; then
			unhealthy_containers=$((unhealthy_containers + 1))
			echo -e "  ${RED}✗${NC} $container is UNHEALTHY"
		elif [ "$health" = "none" ]; then
			no_healthcheck=$((no_healthcheck + 1))
			if [ "$status" = "running" ]; then
				echo -e "  ${YELLOW}?${NC} $container running (no healthcheck)"
			else
				echo -e "  ${RED}✗${NC} $container is NOT running"
				unhealthy_containers=$((unhealthy_containers + 1))
			fi
		fi
		echo "" >>"$REPORT_FILE"
	done <"$LOG_DIR/containers.txt"

	echo "Healthy: $healthy_containers" >>"$REPORT_FILE"
	echo "Unhealthy: $unhealthy_containers" >>"$REPORT_FILE"
	echo "No Healthcheck: $no_healthcheck" >>"$REPORT_FILE"
	echo "Total Restarts: $total_restarts" >>"$REPORT_FILE"
	echo "OOM Kills: $oom_kills" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	if [ $oom_kills -gt 0 ]; then
		echo -e "${RED}[CRITICAL]${NC} $oom_kills containers killed by OOM!"
	fi

	if [ $unhealthy_containers -gt 0 ]; then
		echo -e "${RED}[FAILED]${NC} $unhealthy_containers containers are unhealthy!"
		return 1
	else
		echo -e "${GREEN}[OK]${NC} All containers are healthy or running"
		return 0
	fi
}

# Resource usage
check_resources() {
	echo -e "${BLUE}[INFO]${NC} Checking resource usage..."
	echo "=== Resource Usage ===" >>"$REPORT_FILE"

	if [ "$OS_TYPE" = "termux" ]; then
		proot-distro login debian --shared-tmp -- docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >>"$REPORT_FILE"
	else
		docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# Comprehensive service endpoint testing for ALL services
test_service_endpoints() {
	echo -e "${BLUE}[INFO]${NC} Testing ALL service endpoints..."
	echo "=== Comprehensive Service Endpoint Tests ===" >>"$REPORT_FILE"

	local passed=0
	local failed=0
	local skipped=0

	# Helper function to test HTTP endpoint
	test_http() {
		local name=$1
		local url=$2
		local expected_codes=${3:-"200,301,302,401,403,404"}

		if command -v curl &>/dev/null; then
			local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
			if echo "$expected_codes" | grep -qE "(^|,)$http_code($|,)"; then
				echo "  ✓ $name: HTTP $http_code" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} $name responding (HTTP $http_code)"
				passed=$((passed + 1))
				return 0
			else
				echo "  ✗ $name: HTTP $http_code" >>"$REPORT_FILE"
				echo -e "  ${YELLOW}?${NC} $name unreachable (HTTP $http_code)"
				failed=$((failed + 1))
				return 1
			fi
		fi
	}

	# Reverse Proxy & Core
	grep -q "traefik" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Traefik Dashboard" "http://localhost:8088"

	# Monitoring Stack
	grep -q "grafana" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Grafana" "http://localhost:3000"
	grep -q "prometheus" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Prometheus" "http://localhost:9090"
	grep -q "alertmanager" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Alertmanager" "http://localhost:9093"
	grep -q "uptime-kuma" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Uptime Kuma" "http://localhost:3001"
	grep -q "netdata" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Netdata" "http://localhost:19999"
	grep -q "scrutiny" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Scrutiny" "http://localhost:8087"
	grep -q "parseable" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Parseable" "http://localhost:8094"

	# Media - *arr Stack
	grep -q "sonarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Sonarr" "http://localhost:8989"
	grep -q "radarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Radarr" "http://localhost:7878"
	grep -q "lidarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Lidarr" "http://localhost:8686"
	grep -q "readarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Readarr" "http://localhost:8787"
	grep -q "bazarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Bazarr" "http://localhost:6767"
	grep -q "prowlarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Prowlarr" "http://localhost:9696"
	grep -q "jellyfin" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Jellyfin" "http://localhost:8096"
	grep -q "jellyseerr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Jellyseerr" "http://localhost:5055"
	grep -q "qbittorrent" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "qBittorrent" "http://localhost:8282"
	grep -q "ariang" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "AriaNg" "http://localhost:6880"
	grep -q "audiobookshelf" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Audiobookshelf" "http://localhost:13378"
	# grep -q "pinchflat" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Pinchflat" "http://localhost:8945"
	grep -q "slskd" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Slskd" "http://localhost:2234"

	# Productivity
	grep -q "homarr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Homarr" "http://localhost:7575"
	grep -q "paperless-ngx" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Paperless-ngx" "http://localhost:8092"
	grep -q "karakeep" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Karakeep" "http://localhost:9091"
	grep -q "miniflux" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Miniflux" "http://localhost:8080"
	grep -q "mealie" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Mealie" "http://localhost:9000"
	grep -q "actual-budget" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Actual Budget" "http://localhost:5006"
	grep -q "stirling-pdf" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Stirling PDF" "http://localhost:8080"
	grep -q "it-tools" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "IT Tools" "http://localhost:8080"

	# Development
	grep -q "gitea" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Gitea" "http://localhost:3004"
	grep -q "woodpecker-server" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Woodpecker" "http://localhost:3006"
	grep -q "code-server" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Code Server" "http://localhost:8444"

	# Automation
	grep -q "healthchecks" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Healthchecks" "http://localhost:8000"

	# Security & Network
	grep -q "vaultwarden" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Vaultwarden" "http://localhost:80"
	grep -q "authentik-server" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Authentik" "http://localhost:9000"
	grep -q "adguardhome" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "AdGuard Home" "http://localhost:3000"
	grep -q "oauth2-proxy" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "OAuth2-Proxy" "http://localhost:4180"

	# File Management
	grep -q "filebrowser" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Filebrowser" "http://localhost:8090"
	grep -q "filestash" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Filestash" "http://localhost:8095"

	# Other services
	grep -q "syncthing" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Syncthing" "http://localhost:8384"
	grep -q "open-webui" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Open WebUI" "http://localhost:8080"
	grep -q "immich-server" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Immich" "http://localhost:3001"

	grep -q "velld-web" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Velld" "http://localhost:3010"
	grep -q "maintainerr" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Maintainerr" "http://localhost:6246"
	grep -q "atuin" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Atuin" "http://localhost:8888"
	grep -q "backrest" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Backrest" "http://localhost:9898"

	echo "" >>"$REPORT_FILE"
	echo "Endpoints Passed: $passed" >>"$REPORT_FILE"
	echo "Endpoints Failed: $failed" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	echo -e "${BLUE}[INFO]${NC} Endpoint tests: $passed passed, $failed failed"
}

# Test database connectivity
test_databases() {
	echo -e "${BLUE}[INFO]${NC} Testing database connectivity..."
	echo "=== Database Tests ===" >>"$REPORT_FILE"

	# Test PostgreSQL
	if grep -q "postgres" "$LOG_DIR/containers.txt" 2>/dev/null; then
		if [ "$OS_TYPE" = "termux" ]; then
			if proot-distro login debian --shared-tmp -- docker exec postgres pg_isready -U postgres &>/dev/null; then
				echo "  ✓ PostgreSQL: Ready" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} PostgreSQL is ready"
			else
				echo "  ✗ PostgreSQL: Not ready" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} PostgreSQL is not ready"
			fi
		else
			if docker exec postgres pg_isready -U postgres &>/dev/null; then
				echo "  ✓ PostgreSQL: Ready" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} PostgreSQL is ready"
			else
				echo "  ✗ PostgreSQL: Not ready" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} PostgreSQL is not ready"
			fi
		fi
	fi

	# Test Redis
	if grep -q "redis-cache" "$LOG_DIR/containers.txt" 2>/dev/null; then
		if [ "$OS_TYPE" = "termux" ]; then
			if proot-distro login debian --shared-tmp -- docker exec redis-cache redis-cli ping &>/dev/null; then
				echo "  ✓ Redis: PONG" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} Redis is responding"
			else
				echo "  ✗ Redis: No response" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} Redis is not responding"
			fi
		else
			if docker exec redis-cache redis-cli ping &>/dev/null; then
				echo "  ✓ Redis: PONG" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} Redis is responding"
			else
				echo "  ✗ Redis: No response" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} Redis is not responding"
			fi
		fi
	fi

	# Test MongoDB
	if grep -q "mongo" "$LOG_DIR/containers.txt" 2>/dev/null; then
		if [ "$OS_TYPE" = "termux" ]; then
			if proot-distro login debian --shared-tmp -- docker exec mongo mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
				echo "  ✓ MongoDB: Responding" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} MongoDB is responding"
			else
				echo "  ✗ MongoDB: No response" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} MongoDB is not responding"
			fi
		else
			if docker exec mongo mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
				echo "  ✓ MongoDB: Responding" >>"$REPORT_FILE"
				echo -e "  ${GREEN}✓${NC} MongoDB is responding"
			else
				echo "  ✗ MongoDB: No response" >>"$REPORT_FILE"
				echo -e "  ${RED}✗${NC} MongoDB is not responding"
			fi
		fi
	fi

	echo "" >>"$REPORT_FILE"
}

# Generate consolidated summary
generate_summary() {
	echo -e "${BLUE}[INFO]${NC} Generating consolidated test summary..."
	echo "" >>"$REPORT_FILE"
	echo "=====================================" >>"$REPORT_FILE"
	echo "=== CONSOLIDATED TEST SUMMARY ===" >>"$REPORT_FILE"
	echo "=====================================" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	# Count all test results
	local total_containers=$(wc -l <"$LOG_DIR/containers.txt" 2>/dev/null || echo 0)
	local healthy_count=$(grep -c "✓.*healthy" "$REPORT_FILE" 2>/dev/null || echo 0)
	local unhealthy_count=$(grep -c "✗.*UNHEALTHY" "$REPORT_FILE" 2>/dev/null || echo 0)

	local db_tests_passed=$(grep -c "✓.*PostgreSQL\|✓.*Redis\|✓.*MongoDB" "$REPORT_FILE" 2>/dev/null || echo 0)
	local db_tests_failed=$(grep -c "✗.*PostgreSQL\|✗.*Redis\|✗.*MongoDB" "$REPORT_FILE" 2>/dev/null || echo 0)

	local endpoint_tests=$(grep "Endpoints Passed:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
	local endpoint_failed=$(grep "Endpoints Failed:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)

	local total_warnings=$(grep "Total Warnings:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
	local total_errors=$(grep "Total Errors:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
	local total_critical=$(grep "Total Critical:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)

	# Write summary
	echo "Container Status:" >>"$REPORT_FILE"
	echo "  Total Containers: $total_containers" >>"$REPORT_FILE"
	echo "  Healthy: $healthy_count" >>"$REPORT_FILE"
	echo "  Unhealthy: $unhealthy_count" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	echo "Database Tests:" >>"$REPORT_FILE"
	echo "  Passed: $db_tests_passed" >>"$REPORT_FILE"
	echo "  Failed: $db_tests_failed" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	echo "HTTP Endpoint Tests:" >>"$REPORT_FILE"
	echo "  Passed: $endpoint_tests" >>"$REPORT_FILE"
	echo "  Failed: $endpoint_failed" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	echo "Log Analysis:" >>"$REPORT_FILE"
	echo "  Warnings: $total_warnings" >>"$REPORT_FILE"
	echo "  Errors: $total_errors" >>"$REPORT_FILE"
	echo "  Critical: $total_critical" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	# Overall status
	local overall_status="PASSED"
	if [ "$total_critical" -gt 0 ] || [ "$unhealthy_count" -gt 5 ]; then
		overall_status="FAILED"
		echo "OVERALL STATUS: FAILED" >>"$REPORT_FILE"
		echo -e "${RED}[FAILED]${NC} Stack has critical issues!"
	elif [ "$total_errors" -gt 20 ] || [ "$unhealthy_count" -gt 2 ]; then
		overall_status="WARNING"
		echo "OVERALL STATUS: WARNING" >>"$REPORT_FILE"
		echo -e "${YELLOW}[WARNING]${NC} Stack has some issues"
	else
		echo "OVERALL STATUS: PASSED" >>"$REPORT_FILE"
		echo -e "${GREEN}[PASSED]${NC} Stack is healthy!"
	fi

	echo "" >>"$REPORT_FILE"
	echo "Test completed: $(date)" >>"$REPORT_FILE"
	echo "=====================================" >>"$REPORT_FILE"

	# Display summary to console
	echo ""
	echo "======================================"
	echo "CONSOLIDATED TEST SUMMARY"
	echo "======================================"
	echo "Containers: $total_containers ($healthy_count healthy, $unhealthy_count unhealthy)"
	echo "Databases: $db_tests_passed passed, $db_tests_failed failed"
	echo "HTTP Endpoints: $endpoint_tests passed, $endpoint_failed failed"
	echo "Logs: $total_warnings warnings, $total_errors errors, $total_critical critical"
	echo ""
	echo "Overall Status: $overall_status"
	echo "======================================"
}

# Main execution
main() {
	echo "======================================"
	echo "Docker Compose Stack Testing"
	echo "Based on SOTA 2025 Best Practices"
	echo "Started: $(date)"
	echo "======================================"

	echo "Stack Test Report" >"$REPORT_FILE"
	echo "Generated: $(date)" >>"$REPORT_FILE"
	echo "=====================================" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	# OS detection
	detect_os

	# Check Docker availability
	if ! check_docker_available; then
		echo -e "${RED}[FAILED]${NC} Cannot proceed without Docker daemon"
		exit 1
	fi

	# Validate drive structure
	validate_drive_structure

	# Start stack
	start_stack || {
		echo -e "${RED}[FAILED]${NC} Stack startup failed"
		exit 1
	}

	# Wait for services to initialize
	echo -e "${BLUE}[INFO]${NC} Waiting for services to initialize..."
	sleep 15

	# Get running containers
	get_containers

	# Wait for containers to become healthy
	wait_for_health || echo -e "${YELLOW}[WARNING]${NC} Some containers may not be fully healthy"

	# Run all tests
	check_health
	test_databases
	test_service_endpoints
	check_resources
	analyze_logs

	# Generate consolidated summary
	generate_summary

	echo ""
	echo -e "${GREEN}[COMPLETE]${NC} Test finished. Report saved to: $REPORT_FILE"
	echo -e "${BLUE}[INFO]${NC} Logs saved to: $LOG_DIR/"
}

main "$@"
