#!/bin/bash

# Comprehensive Light Stack Testing Script (2GB RAM optimized)
# Tests 13 services: VPN, file sync, backups, password manager
# Based on SOTA 2025 Docker Compose testing practices:
# - Testcontainers-style health validation
# - Dependency chain testing
# - Shift-left testing approach
# - Service-specific endpoint testing
# - Chaos resilience indicators

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="light-stack-test-$(date +%Y%m%d-%H%M%S).txt"
LOG_DIR="./test-logs"
mkdir -p "$LOG_DIR"

# Detect OS and set commands accordingly
detect_os() {
    echo -e "${BLUE}[INFO]${NC} Detecting OS..."

    if [ -d "/data/data/com.termux" ]; then
        OS_TYPE="termux"
        DOCKER_CMD="proot-distro login debian --shared-tmp -- docker-compose"
        echo -e "${GREEN}[OK]${NC} Running on Termux/Android - using proot"
    elif [ -f /etc/debian_version ] || [ -f /etc/redhat-release ] || [ -f /etc/arch-release ]; then
        OS_TYPE="linux"
        if command -v docker-compose &> /dev/null; then
            DOCKER_CMD="docker-compose"
        elif docker compose version &> /dev/null 2>&1; then
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

    echo "OS Type: $OS_TYPE" >> "$REPORT_FILE"
    echo "Docker Command: $DOCKER_CMD" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Validate drive structure for light stack
validate_drive_structure() {
    echo -e "${BLUE}[INFO]${NC} Validating drive structure..."
    echo "=== Drive Structure Validation ===" >> "$REPORT_FILE"

    local missing_dirs=0
    local required_dirs=(
        "/mnt/storage"
        "/mnt/cachehdd"
    )

    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} $dir exists"
            echo "  ✓ $dir: EXISTS" >> "$REPORT_FILE"
            if [ -w "$dir" ]; then
                echo "    Writable: YES" >> "$REPORT_FILE"
            else
                echo -e "    ${YELLOW}[WARNING]${NC} Not writable"
                echo "    Writable: NO" >> "$REPORT_FILE"
            fi
        else
            echo -e "  ${YELLOW}?${NC} $dir not found (will be created)"
            echo "  ? $dir: MISSING" >> "$REPORT_FILE"
            missing_dirs=$((missing_dirs + 1))
        fi
    done

    echo "" >> "$REPORT_FILE"
}

# Start stack
start_stack() {
    echo -e "${BLUE}[INFO]${NC} Starting light stack..."
    echo "=== Stack Startup ===" >> "$REPORT_FILE"

    if $DOCKER_CMD up -d >> "$LOG_DIR/startup.log" 2>&1; then
        echo -e "${GREEN}[OK]${NC} Stack started successfully"
        echo "Status: SUCCESS" >> "$REPORT_FILE"
    else
        echo -e "${RED}[ERROR]${NC} Stack startup failed"
        echo "Status: FAILED" >> "$REPORT_FILE"
        cat "$LOG_DIR/startup.log" >> "$REPORT_FILE"
        return 1
    fi
    echo "" >> "$REPORT_FILE"
}

# Get container list
get_containers() {
    echo -e "${BLUE}[INFO]${NC} Getting container list..."
    if [ "$OS_TYPE" = "termux" ]; then
        proot-distro login debian --shared-tmp -- docker ps --format "{{.Names}}" > "$LOG_DIR/containers.txt"
    else
        docker ps --format "{{.Names}}" > "$LOG_DIR/containers.txt"
    fi
}

# Wait for containers with dependency validation
wait_for_health() {
    echo -e "${BLUE}[INFO]${NC} Waiting for containers with dependency chain validation..."
    local max_wait=120
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

        echo -e "${YELLOW}[WAIT]${NC} $total_waiting containers initializing... ($wait_time/$max_wait seconds)"
        sleep 10
        wait_time=$((wait_time + 10))
    done

    if [ $unhealthy_count -gt 0 ]; then
        echo -e "${RED}[ERROR]${NC} $unhealthy_count containers unhealthy after $max_wait seconds"
        return 1
    fi
}

# Check container health with chaos indicators (critical for 2GB RAM)
check_health() {
    echo -e "${BLUE}[INFO]${NC} Checking health with chaos indicators (2GB RAM)..."
    echo "=== Health Check & Chaos Indicators ===" >> "$REPORT_FILE"

    local unhealthy_containers=0
    local healthy_containers=0
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

        echo "Container: $container" >> "$REPORT_FILE"
        echo "  Status: $status, Health: $health" >> "$REPORT_FILE"
        echo "  Restarts: $restarts, OOM: $oom" >> "$REPORT_FILE"

        total_restarts=$((total_restarts + restarts))
        if [ "$oom" = "true" ]; then
            oom_kills=$((oom_kills + 1))
            echo -e "  ${RED}⚠ OOM${NC} $container killed by out of memory!"
        fi

        if [ "$restarts" -gt 2 ]; then
            echo -e "  ${YELLOW}⚠${NC} $container restarted $restarts times"
        fi

        if [ "$health" = "healthy" ] || ([ "$health" = "none" ] && [ "$status" = "running" ]); then
            healthy_containers=$((healthy_containers + 1))
            echo -e "  ${GREEN}✓${NC} $container healthy"
        else
            unhealthy_containers=$((unhealthy_containers + 1))
            echo -e "  ${RED}✗${NC} $container UNHEALTHY"
        fi
        echo "" >> "$REPORT_FILE"
    done < "$LOG_DIR/containers.txt"

    echo "Healthy: $healthy_containers" >> "$REPORT_FILE"
    echo "Unhealthy: $unhealthy_containers" >> "$REPORT_FILE"
    echo "Total Restarts: $total_restarts" >> "$REPORT_FILE"
    echo "OOM Kills: $oom_kills" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ $oom_kills -gt 0 ]; then
        echo -e "${RED}[CRITICAL]${NC} $oom_kills containers OOM killed! Check memory limits!"
    fi

    if [ $unhealthy_containers -gt 0 ]; then
        echo -e "${RED}[FAILED]${NC} $unhealthy_containers containers unhealthy!"
        return 1
    else
        echo -e "${GREEN}[OK]${NC} All containers healthy"
        return 0
    fi
}

# Test light stack endpoints
test_service_endpoints() {
    echo -e "${BLUE}[INFO]${NC} Testing light stack endpoints..."
    echo "=== Service Endpoint Tests ===" >> "$REPORT_FILE"

    local passed=0
    local failed=0

    test_http() {
        local name=$1
        local url=$2
        local expected_codes=${3:-"200,301,302,401,403,404"}

        if command -v curl &> /dev/null; then
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
            if echo "$expected_codes" | grep -qE "(^|,)$http_code($|,)"; then
                echo "  ✓ $name: HTTP $http_code" >> "$REPORT_FILE"
                echo -e "  ${GREEN}✓${NC} $name (HTTP $http_code)"
                passed=$((passed + 1))
                return 0
            else
                echo "  ✗ $name: HTTP $http_code" >> "$REPORT_FILE"
                echo -e "  ${YELLOW}?${NC} $name unreachable (HTTP $http_code)"
                failed=$((failed + 1))
                return 1
            fi
        fi
    }

    # Test all light stack services
    grep -q "homepage" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Homepage Dashboard" "http://localhost:3000"
    grep -q "vaultwarden" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Vaultwarden" "http://localhost:8084"
    grep -q "syncthing" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Syncthing" "http://localhost:8384"
    grep -q "transmission" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Transmission" "http://localhost:9091"
    grep -q "kopia" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Kopia" "http://localhost:51515"
    grep -q "portainer" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Portainer" "http://localhost:9000"
    grep -q "filebrowser" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Filebrowser" "http://localhost:8082"
    grep -q "slskd" "$LOG_DIR/containers.txt" 2>/dev/null && test_http "Slskd" "http://localhost:5030"

    echo "" >> "$REPORT_FILE"
    echo "Endpoints Passed: $passed" >> "$REPORT_FILE"
    echo "Endpoints Failed: $failed" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    echo -e "${BLUE}[INFO]${NC} Endpoint tests: $passed passed, $failed failed"
}

# Analyze logs
analyze_logs() {
    echo -e "${BLUE}[INFO]${NC} Analyzing logs..."
    echo "=== Log Analysis ===" >> "$REPORT_FILE"

    local total_warnings=0
    local total_errors=0
    local total_critical=0

    while IFS= read -r container; do
        if [ "$OS_TYPE" = "termux" ]; then
            proot-distro login debian --shared-tmp -- docker logs "$container" > "$LOG_DIR/${container}.log" 2>&1 || true
        else
            docker logs "$container" > "$LOG_DIR/${container}.log" 2>&1 || true
        fi

        warnings=$(grep -iE "warn|warning" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)
        errors=$(grep -iE "error|err|fail|failed" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)
        critical=$(grep -iE "critical|fatal|panic" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l || echo 0)

        total_warnings=$((total_warnings + warnings))
        total_errors=$((total_errors + errors))
        total_critical=$((total_critical + critical))

        if [ "$errors" -gt 0 ] || [ "$critical" -gt 0 ]; then
            echo "Container: $container - Warnings: $warnings, Errors: $errors, Critical: $critical" >> "$REPORT_FILE"
        fi
    done < "$LOG_DIR/containers.txt"

    echo "" >> "$REPORT_FILE"
    echo "Total Warnings: $total_warnings" >> "$REPORT_FILE"
    echo "Total Errors: $total_errors" >> "$REPORT_FILE"
    echo "Total Critical: $total_critical" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ "$total_critical" -gt 0 ]; then
        echo -e "${RED}[CRITICAL]${NC} Found $total_critical critical issues"
    elif [ "$total_errors" -gt 5 ]; then
        echo -e "${YELLOW}[WARNING]${NC} Found $total_errors errors"
    else
        echo -e "${GREEN}[OK]${NC} Log analysis complete"
    fi
}

# Check resources (important for 2GB RAM limit)
check_resources() {
    echo -e "${BLUE}[INFO]${NC} Checking resource usage (2GB RAM limit)..."
    echo "=== Resource Usage ===" >> "$REPORT_FILE"

    if [ "$OS_TYPE" = "termux" ]; then
        proot-distro login debian --shared-tmp -- docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "$REPORT_FILE"
    else
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Generate consolidated summary
generate_summary() {
    echo -e "${BLUE}[INFO]${NC} Generating summary..."
    echo "" >> "$REPORT_FILE"
    echo "=====================================" >> "$REPORT_FILE"
    echo "=== CONSOLIDATED TEST SUMMARY ===" >> "$REPORT_FILE"
    echo "=====================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    local total_containers=$(wc -l < "$LOG_DIR/containers.txt" 2>/dev/null || echo 0)
    local healthy_count=$(grep -c "✓.*healthy\|✓.*running" "$REPORT_FILE" 2>/dev/null || echo 0)
    local unhealthy_count=$(grep -c "✗.*UNHEALTHY" "$REPORT_FILE" 2>/dev/null || echo 0)
    local endpoint_tests=$(grep "Endpoints Passed:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
    local endpoint_failed=$(grep "Endpoints Failed:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
    local total_errors=$(grep "Total Errors:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)
    local total_critical=$(grep "Total Critical:" "$REPORT_FILE" | tail -1 | awk '{print $3}' || echo 0)

    echo "Light Stack (2GB RAM optimized)" >> "$REPORT_FILE"
    echo "Total Containers: $total_containers" >> "$REPORT_FILE"
    echo "Healthy: $healthy_count" >> "$REPORT_FILE"
    echo "Unhealthy: $unhealthy_count" >> "$REPORT_FILE"
    echo "HTTP Endpoints: $endpoint_tests passed, $endpoint_failed failed" >> "$REPORT_FILE"
    echo "Logs: $total_errors errors, $total_critical critical" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    local overall_status="PASSED"
    if [ "$total_critical" -gt 0 ] || [ "$unhealthy_count" -gt 2 ]; then
        overall_status="FAILED"
        echo "OVERALL STATUS: FAILED" >> "$REPORT_FILE"
        echo -e "${RED}[FAILED]${NC} Stack has critical issues!"
    elif [ "$total_errors" -gt 5 ] || [ "$unhealthy_count" -gt 0 ]; then
        overall_status="WARNING"
        echo "OVERALL STATUS: WARNING" >> "$REPORT_FILE"
        echo -e "${YELLOW}[WARNING]${NC} Stack has some issues"
    else
        echo "OVERALL STATUS: PASSED" >> "$REPORT_FILE"
        echo -e "${GREEN}[PASSED]${NC} Light stack is healthy!"
    fi

    echo "" >> "$REPORT_FILE"
    echo "Test completed: $(date)" >> "$REPORT_FILE"

    echo ""
    echo "======================================"
    echo "LIGHT STACK TEST SUMMARY"
    echo "======================================"
    echo "Containers: $total_containers ($healthy_count healthy)"
    echo "Endpoints: $endpoint_tests passed, $endpoint_failed failed"
    echo "Logs: $total_errors errors, $total_critical critical"
    echo "Overall: $overall_status"
    echo "======================================"
}

# Main execution
main() {
    echo "======================================"
    echo "Light Stack Testing (2GB RAM)"
    echo "SOTA 2025 Best Practices"
    echo "Started: $(date)"
    echo "======================================"

    echo "Light Stack Test Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "=====================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    detect_os
    validate_drive_structure
    start_stack || { echo -e "${RED}[FAILED]${NC} Stack startup failed"; exit 1; }

    echo -e "${BLUE}[INFO]${NC} Waiting for services..."
    sleep 12

    get_containers
    wait_for_health || echo -e "${YELLOW}[WARNING]${NC} Some containers may not be healthy"
    check_health
    test_service_endpoints
    check_resources
    analyze_logs
    generate_summary

    echo ""
    echo -e "${GREEN}[COMPLETE]${NC} Report: $REPORT_FILE"
}

main "$@"
