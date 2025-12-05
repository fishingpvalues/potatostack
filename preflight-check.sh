#!/bin/bash

################################################################################
# PotatoStack Pre-Flight Check Script
# Run this before deploying to verify system requirements
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PotatoStack Pre-Flight Check v1.0             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print check status
check_pass() {
    echo -e "[${GREEN}✓${NC}] $1"
}

check_warn() {
    echo -e "[${YELLOW}⚠${NC}] $1"
    ((WARNINGS++))
}

check_fail() {
    echo -e "[${RED}✗${NC}] $1"
    ((ERRORS++))
}

# Check 1: System Architecture
echo -e "${BLUE}=== System Architecture ===${NC}"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    check_pass "Architecture: $ARCH (ARM64) ✓"
else
    check_warn "Architecture: $ARCH (Expected ARM64, may work but not tested)"
fi

# Check 2: Available RAM
echo -e "\n${BLUE}=== Memory Check ===${NC}"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_RAM -ge 1800 ]; then
    check_pass "RAM: ${TOTAL_RAM}MB available"
else
    check_fail "RAM: ${TOTAL_RAM}MB (Minimum 2GB required, found less)"
fi

# Check available RAM (free)
FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
if [ $FREE_RAM -lt 500 ]; then
    check_warn "Only ${FREE_RAM}MB RAM free (recommend >500MB before starting)"
fi

# Check 3: Swap Space
SWAP=$(free -m | awk '/^Swap:/{print $2}')
if [ $SWAP -ge 1024 ]; then
    check_pass "Swap: ${SWAP}MB configured"
elif [ $SWAP -gt 0 ]; then
    check_warn "Swap: ${SWAP}MB (Recommend ≥1GB for stability)"
else
    check_warn "No swap configured (Strongly recommend adding swap for 2GB RAM system)"
fi

# Check 4: Docker Installation
echo -e "\n${BLUE}=== Docker Check ===${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    check_pass "Docker installed: $DOCKER_VERSION"

    # Check if Docker daemon is running
    if docker ps &> /dev/null; then
        check_pass "Docker daemon running"
    else
        check_fail "Docker daemon not running (try: sudo systemctl start docker)"
    fi
else
    check_fail "Docker not installed (run: curl -fsSL https://get.docker.com | sh)"
fi

# Check 5: Docker Compose
echo -e "\n${BLUE}=== Docker Compose Check ===${NC}"
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
    check_pass "Docker Compose installed: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    check_pass "Docker Compose (plugin) installed: $COMPOSE_VERSION"
else
    check_fail "Docker Compose not installed"
fi

# Check 6: Disk Mounts
echo -e "\n${BLUE}=== Storage Check ===${NC}"

# Check main HDD
if [ -d "/mnt/seconddrive" ]; then
    SECOND_SIZE=$(df -h /mnt/seconddrive | awk 'NR==2{print $2}')
    SECOND_AVAIL=$(df -h /mnt/seconddrive | awk 'NR==2{print $4}')
    SECOND_USED_PCT=$(df -h /mnt/seconddrive | awk 'NR==2{print $5}')
    check_pass "Main HDD mounted: /mnt/seconddrive ($SECOND_SIZE total, $SECOND_AVAIL free, $SECOND_USED_PCT used)"

    # Check if writable
    if touch /mnt/seconddrive/.writetest 2>/dev/null; then
        rm /mnt/seconddrive/.writetest
        check_pass "Main HDD is writable"
    else
        check_fail "Main HDD is not writable (check permissions)"
    fi
else
    check_fail "Main HDD not mounted at /mnt/seconddrive"
fi

# Check cache HDD
if [ -d "/mnt/cachehdd" ]; then
    CACHE_SIZE=$(df -h /mnt/cachehdd | awk 'NR==2{print $2}')
    CACHE_AVAIL=$(df -h /mnt/cachehdd | awk 'NR==2{print $4}')
    CACHE_USED_PCT=$(df -h /mnt/cachehdd | awk 'NR==2{print $5}')
    check_pass "Cache HDD mounted: /mnt/cachehdd ($CACHE_SIZE total, $CACHE_AVAIL free, $CACHE_USED_PCT used)"

    # Check if writable
    if touch /mnt/cachehdd/.writetest 2>/dev/null; then
        rm /mnt/cachehdd/.writetest
        check_pass "Cache HDD is writable"
    else
        check_fail "Cache HDD is not writable (check permissions)"
    fi
else
    check_fail "Cache HDD not mounted at /mnt/cachehdd"
fi

# Check 7: Required Packages
echo -e "\n${BLUE}=== Required Packages ===${NC}"

if command -v smartctl &> /dev/null; then
    check_pass "smartmontools installed"
else
    check_warn "smartmontools not installed (install: sudo apt install smartmontools)"
fi

if command -v curl &> /dev/null; then
    check_pass "curl installed"
else
    check_fail "curl not installed (required for health checks)"
fi

# Check 8: Network Configuration
echo -e "\n${BLUE}=== Network Check ===${NC}"

# Get IP address
IP=$(hostname -I | awk '{print $1}')
check_pass "Local IP: $IP"

# Check if IP is in expected range
if [[ $IP == 192.168.178.* ]]; then
    check_pass "IP in expected Fritzbox range (192.168.178.x)"
else
    check_warn "IP not in Fritzbox range 192.168.178.x (expected for this config)"
fi

# Check internet connectivity
if ping -c 1 8.8.8.8 &> /dev/null; then
    check_pass "Internet connectivity OK"
else
    check_warn "No internet connection (required for pulling Docker images)"
fi

# Check 9: Port Availability
echo -e "\n${BLUE}=== Port Availability Check ===${NC}"

REQUIRED_PORTS=(80 443 81 3000 3001 3002 3003 8080 8082 9000 51515)
for PORT in "${REQUIRED_PORTS[@]}"; do
    if ! netstat -tuln 2>/dev/null | grep -q ":$PORT " && ! ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        check_pass "Port $PORT available"
    else
        check_warn "Port $PORT already in use"
    fi
done

# Check 10: Environment File
echo -e "\n${BLUE}=== Configuration Check ===${NC}"

if [ -f ".env" ]; then
    check_pass ".env file exists"

    # Check for default/example passwords
    if grep -q "change_this" .env || grep -q "your_" .env || grep -q "changeme" .env; then
        check_warn ".env contains default passwords - UPDATE BEFORE DEPLOYING!"
    else
        check_pass ".env appears to be customized"
    fi
else
    check_warn ".env file not found (copy from .env.example)"
fi

if [ -f "docker-compose.yml" ]; then
    check_pass "docker-compose.yml exists"
else
    check_fail "docker-compose.yml not found"
fi

# Check 11: Kernel Parameters
echo -e "\n${BLUE}=== Kernel Parameters ===${NC}"

IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    check_pass "IP forwarding enabled (required for VPN)"
else
    check_warn "IP forwarding disabled (will be enabled by setup.sh)"
fi

INOTIFY_WATCHES=$(cat /proc/sys/fs/inotify/max_user_watches)
if [ "$INOTIFY_WATCHES" -ge 524288 ]; then
    check_pass "inotify watches: $INOTIFY_WATCHES"
else
    check_warn "inotify watches: $INOTIFY_WATCHES (will increase to 524288)"
fi

# Check 12: CPU
echo -e "\n${BLUE}=== CPU Check ===${NC}"

CPU_CORES=$(nproc)
check_pass "CPU cores: $CPU_CORES"

CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
if [ -z "$CPU_MODEL" ]; then
    CPU_MODEL=$(grep "Hardware" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
fi
check_pass "CPU: $CPU_MODEL"

# Summary
echo -e "\n${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    SUMMARY                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! System is ready for PotatoStack deployment.${NC}"
    echo -e "\nNext step: ${BLUE}sudo ./setup.sh${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found. Review warnings above.${NC}"
    echo -e "\nSystem should work, but review warnings for optimal performance."
    echo -e "Continue with: ${BLUE}sudo ./setup.sh${NC}"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    echo -e "\n${RED}Please fix errors before deploying PotatoStack.${NC}"
    exit 1
fi
