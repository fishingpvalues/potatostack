#!/bin/bash

# Security Scanner for PotatoStack
# Scans Docker Compose configuration and images for vulnerabilities
# Uses: Trivy, docker-compose config, secret detection
# SOTA 2025 Security Best Practices

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="security-scan-report-$(date +%Y%m%d-%H%M%S).txt"

# Counters
TOTAL_VULNS=0
HIGH_VULNS=0
CRITICAL_VULNS=0

echo "======================================"
echo "Security Scan - SOTA 2025"
echo "Started: $(date)"
echo "======================================"
echo ""

echo "Security Scan Report" >"$REPORT_FILE"
echo "Generated: $(date)" >>"$REPORT_FILE"
echo "=====================================" >>"$REPORT_FILE"
echo "" >>"$REPORT_FILE"

# Detect OS
detect_os() {
	if [ -d "/data/data/com.termux" ]; then
		OS_TYPE="termux"
		DOCKER_COMPOSE_CMD="proot-distro login debian --shared-tmp -- docker-compose -f /data/data/com.termux/files/home/workdir/potatostack/docker-compose.yml"
		DOCKER_CMD="proot-distro login debian --shared-tmp -- docker"
	else
		OS_TYPE="linux"
		if command -v docker-compose &>/dev/null; then
			DOCKER_COMPOSE_CMD="docker-compose"
		elif docker compose version &>/dev/null 2>&1; then
			DOCKER_COMPOSE_CMD="docker compose"
		else
			DOCKER_COMPOSE_CMD="docker-compose"
		fi
		DOCKER_CMD="docker"
	fi
	echo "OS Type: $OS_TYPE" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"
}

# 1. Scan for secrets in files
scan_secrets() {
	echo -e "${BLUE}[1/5]${NC} Scanning for exposed secrets..."
	echo "=== Secret Scanning ===" >>"$REPORT_FILE"

	local secrets_found=0

	# Patterns to search for
	local patterns=(
		"password\s*=\s*['\"]?[^'\"[:space:]]+['\"]?"
		"secret\s*=\s*['\"]?[^'\"[:space:]]+['\"]?"
		"api_key\s*=\s*['\"]?[^'\"[:space:]]+['\"]?"
		"token\s*=\s*['\"]?[^'\"[:space:]]+['\"]?"
		"private_key"
		"BEGIN RSA PRIVATE KEY"
		"BEGIN OPENSSH PRIVATE KEY"
	)

	# Scan files
	for pattern in "${patterns[@]}"; do
		# Exclude .env.example and similar files
		if git ls-files | grep -v ".env.example" | grep -v ".git/" | xargs grep -iE "$pattern" 2>/dev/null; then
			secrets_found=$((secrets_found + 1))
		fi
	done

	if [ $secrets_found -eq 0 ]; then
		echo -e "  ${GREEN}✓${NC} No exposed secrets found"
		echo "Status: PASSED - No secrets detected" >>"$REPORT_FILE"
	else
		echo -e "  ${RED}✗${NC} Found $secrets_found potential secrets"
		echo "Status: FAILED - $secrets_found potential secrets found" >>"$REPORT_FILE"
		TOTAL_VULNS=$((TOTAL_VULNS + secrets_found))
		CRITICAL_VULNS=$((CRITICAL_VULNS + secrets_found))
	fi
	echo "" >>"$REPORT_FILE"
}

# 2. Check Docker Compose configuration
check_compose_security() {
	echo -e "${BLUE}[2/5]${NC} Checking Docker Compose security..."
	echo "=== Docker Compose Security ===" >>"$REPORT_FILE"

	local issues=0

	# Check for privileged containers
	if grep -q "privileged: true" docker-compose.yml 2>/dev/null; then
		echo -e "  ${YELLOW}⚠${NC} Privileged containers detected"
		echo "  ⚠ Privileged containers found" >>"$REPORT_FILE"
		issues=$((issues + 1))
	fi

	# Check for host network mode
	if grep -q "network_mode: host" docker-compose.yml 2>/dev/null; then
		echo -e "  ${YELLOW}⚠${NC} Host network mode detected"
		echo "  ⚠ Host network mode found" >>"$REPORT_FILE"
		issues=$((issues + 1))
	fi

	# Check for exposed ports on 0.0.0.0
	if grep -qE '\"0\.0\.0\.0:' docker-compose.yml 2>/dev/null; then
		echo -e "  ${YELLOW}⚠${NC} Ports exposed on 0.0.0.0"
		echo "  ⚠ Ports exposed on all interfaces" >>"$REPORT_FILE"
		issues=$((issues + 1))
	fi

	if [ $issues -eq 0 ]; then
		echo -e "  ${GREEN}✓${NC} Compose configuration secure"
		echo "Status: PASSED" >>"$REPORT_FILE"
	else
		echo -e "  ${YELLOW}⚠${NC} $issues security issues found"
		echo "Status: WARNING - $issues issues" >>"$REPORT_FILE"
		TOTAL_VULNS=$((TOTAL_VULNS + issues))
	fi
	echo "" >>"$REPORT_FILE"
}

# 3. Check for outdated base images
check_image_versions() {
	echo -e "${BLUE}[3/5]${NC} Checking for outdated images..."
	echo "=== Image Version Check ===" >>"$REPORT_FILE"

	# Extract images from docker-compose.yml
	local outdated=0

	# Check for :latest tags (bad practice)
	local latest_count=$(grep -c ":latest" docker-compose.yml 2>/dev/null || echo 0)
	if [ "$latest_count" -gt 0 ]; then
		echo -e "  ${YELLOW}⚠${NC} $latest_count images using :latest tag"
		echo "  ⚠ $latest_count images using :latest tag (not recommended)" >>"$REPORT_FILE"
		outdated=$latest_count
	fi

	if [ "$outdated" -eq 0 ]; then
		echo -e "  ${GREEN}✓${NC} All images use pinned versions"
		echo "Status: PASSED" >>"$REPORT_FILE"
	else
		echo -e "  ${YELLOW}⚠${NC} $outdated images need version pinning"
		echo "Status: WARNING - Pin image versions" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 4. Scan with Trivy (if available)
scan_with_trivy() {
	echo -e "${BLUE}[4/5]${NC} Running Trivy vulnerability scan..."
	echo "=== Trivy Vulnerability Scan ===" >>"$REPORT_FILE"

	if ! command -v trivy &>/dev/null; then
		echo -e "  ${YELLOW}⚠${NC} Trivy not installed"
		echo "  Install: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
		echo "Status: SKIPPED (Trivy not installed)" >>"$REPORT_FILE"
		echo "" >>"$REPORT_FILE"
		return
	fi

	local trivy_issues=0

	# 4a. Scan docker-compose.yml for misconfigurations
	echo -e "  Scanning compose configuration..."
	if trivy config --severity HIGH,CRITICAL docker-compose.yml >"$REPORT_FILE.trivy-config" 2>&1; then
		echo -e "  ${GREEN}✓${NC} Compose config: No issues"
	else
		local config_issues=$(grep -c "HIGH\|CRITICAL" "$REPORT_FILE.trivy-config" 2>/dev/null || echo 0)
		if [ "$config_issues" -gt 0 ]; then
			echo -e "  ${RED}✗${NC} Compose config: $config_issues issues"
			trivy_issues=$((trivy_issues + config_issues))
		fi
	fi

	# 4b. Scan filesystem for secrets and vulnerabilities
	echo -e "  Scanning filesystem for secrets..."
	if trivy fs --scanners secret --severity HIGH,CRITICAL . >"$REPORT_FILE.trivy-secrets" 2>&1; then
		echo -e "  ${GREEN}✓${NC} Secrets scan: No issues"
	else
		local secret_issues=$(grep -c "HIGH\|CRITICAL" "$REPORT_FILE.trivy-secrets" 2>/dev/null || echo 0)
		if [ "$secret_issues" -gt 0 ]; then
			echo -e "  ${RED}✗${NC} Secrets scan: $secret_issues issues"
			trivy_issues=$((trivy_issues + secret_issues))
			CRITICAL_VULNS=$((CRITICAL_VULNS + secret_issues))
		fi
	fi

	# 4c. Scan a sample of critical images (if Docker available)
	if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
		echo -e "  Scanning critical images (postgres, redis)..."
		for img in postgres:16-alpine redis:alpine; do
			if docker image inspect "$img" &>/dev/null 2>&1; then
				local img_vulns=$(trivy image --severity CRITICAL --quiet "$img" 2>/dev/null | grep -c "CRITICAL" || echo 0)
				if [ "$img_vulns" -gt 0 ]; then
					echo -e "    ${RED}✗${NC} $img: $img_vulns critical vulnerabilities"
					trivy_issues=$((trivy_issues + img_vulns))
					CRITICAL_VULNS=$((CRITICAL_VULNS + img_vulns))
				else
					echo -e "    ${GREEN}✓${NC} $img: No critical vulnerabilities"
				fi
			fi
		done
	fi

	if [ "$trivy_issues" -gt 0 ]; then
		echo "Status: FAILED - $trivy_issues total issues" >>"$REPORT_FILE"
		TOTAL_VULNS=$((TOTAL_VULNS + trivy_issues))
	else
		echo -e "  ${GREEN}✓${NC} Trivy scan passed"
		echo "Status: PASSED" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 5. Check file permissions
check_permissions() {
	echo -e "${BLUE}[5/5]${NC} Checking file permissions..."
	echo "=== File Permissions ===" >>"$REPORT_FILE"

	local issues=0

	# Check for world-writable files
	if find . -type f -perm -002 2>/dev/null | grep -v ".git" >/dev/null; then
		echo -e "  ${YELLOW}⚠${NC} World-writable files detected"
		echo "  ⚠ World-writable files found" >>"$REPORT_FILE"
		find . -type f -perm -002 2>/dev/null | grep -v ".git" >>"$REPORT_FILE"
		issues=$((issues + 1))
	fi

	# Check for .sh files without execute permission
	for script in *.sh; do
		[ -f "$script" ] || continue
		if [ ! -x "$script" ]; then
			echo -e "  ${YELLOW}⚠${NC} $script not executable"
			issues=$((issues + 1))
		fi
	done

	if [ $issues -eq 0 ]; then
		echo -e "  ${GREEN}✓${NC} File permissions secure"
		echo "Status: PASSED" >>"$REPORT_FILE"
	else
		echo -e "  ${YELLOW}⚠${NC} $issues permission issues"
		echo "Status: WARNING - $issues issues" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# Generate summary
generate_summary() {
	echo ""
	echo "======================================"
	echo "SECURITY SCAN SUMMARY"
	echo "======================================"
	echo "Total Vulnerabilities: $TOTAL_VULNS"
	echo "Critical: $CRITICAL_VULNS"
	echo "High: $HIGH_VULNS"
	echo ""

	echo "=== SUMMARY ===" >>"$REPORT_FILE"
	echo "Total Vulnerabilities: $TOTAL_VULNS" >>"$REPORT_FILE"
	echo "Critical: $CRITICAL_VULNS" >>"$REPORT_FILE"
	echo "High: $HIGH_VULNS" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	if [ $CRITICAL_VULNS -gt 0 ]; then
		echo -e "${RED}✗ CRITICAL VULNERABILITIES FOUND${NC}"
		echo "Overall Status: CRITICAL - Action required" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 1
	elif [ $TOTAL_VULNS -gt 0 ]; then
		echo -e "${YELLOW}⚠ SECURITY ISSUES FOUND${NC}"
		echo "Overall Status: WARNING - Review recommended" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 0
	else
		echo -e "${GREEN}✓ NO SECURITY ISSUES FOUND${NC}"
		echo "Overall Status: PASSED" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 0
	fi
}

# Main execution
main() {
	detect_os
	scan_secrets
	check_compose_security
	check_image_versions
	scan_with_trivy
	check_permissions
	generate_summary
}

main
