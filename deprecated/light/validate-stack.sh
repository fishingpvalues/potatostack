#!/bin/bash

# Comprehensive Stack Validation Script - Light Stack
# SOTA 2025 Best Practices for Docker Compose validation
# Uses: yamllint, shellcheck, shfmt, docker-compose config
# Based on: https://docs.docker.com/compose/compose-file/11-validate/

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="validation-report-light-$(date +%Y%m%d-%H%M%S).txt"

# Temp directory
TMP_DIR="./tmp-validation"
mkdir -p "$TMP_DIR"

# Counters
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_CHECKS=0

echo "======================================"
echo "Light Stack Validation - SOTA 2025"
echo "Started: $(date)"
echo "======================================"
echo ""

echo "Light Stack Validation Report" >"$REPORT_FILE"
echo "Generated: $(date)" >>"$REPORT_FILE"
echo "=====================================" >>"$REPORT_FILE"
echo "" >>"$REPORT_FILE"

# Detect OS
detect_os() {
	if [ -d "/data/data/com.termux" ]; then
		OS_TYPE="termux"
		DOCKER_COMPOSE_CMD="proot-distro login debian --shared-tmp -- docker-compose -f /data/data/com.termux/files/home/workdir/potatostack/light/docker-compose.yml"
	else
		OS_TYPE="linux"
		if command -v docker-compose &>/dev/null; then
			DOCKER_COMPOSE_CMD="docker-compose"
		elif docker compose version &>/dev/null 2>&1; then
			DOCKER_COMPOSE_CMD="docker compose"
		else
			DOCKER_COMPOSE_CMD="docker-compose"
		fi
	fi
	echo "OS Type: $OS_TYPE" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"
}

# 1. YAML Syntax Validation (yamllint)
validate_yaml_syntax() {
	echo -e "${BLUE}[1/7]${NC} Validating YAML syntax with yamllint..."
	echo "=== YAML Syntax (yamllint) ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if command -v yamllint &>/dev/null; then
		if yamllint -f parsable docker-compose.yml >$TMP_DIR/yamllint-light.out 2>&1; then
			echo -e "  ${GREEN}✓${NC} YAML syntax valid"
			echo "Status: PASSED" >>"$REPORT_FILE"
		else
			local warnings=$(grep -c "warning" $TMP_DIR/yamllint-light.out 2>/dev/null || echo 0)
			local errors=$(grep -c "error" $TMP_DIR/yamllint-light.out 2>/dev/null || echo 0)

			if [ "$errors" -gt 0 ]; then
				echo -e "  ${RED}✗${NC} YAML syntax errors: $errors"
				echo "Status: FAILED ($errors errors)" >>"$REPORT_FILE"
				cat $TMP_DIR/yamllint-light.out >>"$REPORT_FILE"
				TOTAL_ERRORS=$((TOTAL_ERRORS + errors))
			else
				echo -e "  ${YELLOW}⚠${NC} YAML warnings: $warnings"
				echo "Status: WARNING ($warnings warnings)" >>"$REPORT_FILE"
				TOTAL_WARNINGS=$((TOTAL_WARNINGS + warnings))
			fi
		fi
	else
		echo -e "  ${YELLOW}⚠${NC} yamllint not installed"
		echo "Status: SKIPPED (yamllint not found)" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 2. Docker Compose Config Validation
validate_compose_config() {
	echo -e "${BLUE}[2/7]${NC} Validating docker-compose config..."
	echo "=== Docker Compose Config Validation ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if $DOCKER_COMPOSE_CMD config >$TMP_DIR/compose-config-light.out 2>&1; then
		echo -e "  ${GREEN}✓${NC} Docker Compose config valid"
		echo "Status: PASSED" >>"$REPORT_FILE"

		# Count services
		local service_count=$(grep -c "^  [a-zA-Z]" $TMP_DIR/compose-config-light.out 2>/dev/null || echo 0)
		echo "  Services configured: $service_count"
		echo "Services: $service_count" >>"$REPORT_FILE"
	else
		echo -e "  ${RED}✗${NC} Docker Compose config validation failed"
		echo "Status: FAILED" >>"$REPORT_FILE"
		grep -i "error\|warn" $TMP_DIR/compose-config-light.out >>"$REPORT_FILE" 2>/dev/null || true
		TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
	fi
	echo "" >>"$REPORT_FILE"
}

# 3. Python YAML Parser Validation
validate_yaml_parser() {
	echo -e "${BLUE}[3/7]${NC} Validating YAML structure with Python..."
	echo "=== Python YAML Parser ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if command -v python3 &>/dev/null; then
		if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>&1 | tee $TMP_DIR/python-yaml-light.out; then
			echo -e "  ${GREEN}✓${NC} YAML structure valid"
			echo "Status: PASSED" >>"$REPORT_FILE"
		else
			echo -e "  ${RED}✗${NC} YAML structure invalid"
			echo "Status: FAILED" >>"$REPORT_FILE"
			cat $TMP_DIR/python-yaml-light.out >>"$REPORT_FILE"
			TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
		fi
	else
		echo -e "  ${YELLOW}⚠${NC} Python3 not installed"
		echo "Status: SKIPPED" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 4. Shell Script Validation (shellcheck)
validate_shell_scripts() {
	echo -e "${BLUE}[4/7]${NC} Validating shell scripts with shellcheck..."
	echo "=== Shell Script Validation (shellcheck) ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if command -v shellcheck &>/dev/null; then
		local total_issues=0
		local scripts_checked=0

		for script in *.sh; do
			[ -f "$script" ] || continue
			scripts_checked=$((scripts_checked + 1))

			if shellcheck "$script" >$TMP_DIR/shellcheck-light-$script.out 2>&1; then
				echo -e "  ${GREEN}✓${NC} $script"
				echo "  $script: PASSED" >>"$REPORT_FILE"
			else
				local issues=$(grep -c "^In $script" $TMP_DIR/shellcheck-light-$script.out 2>/dev/null || echo 0)
				total_issues=$((total_issues + issues))
				echo -e "  ${YELLOW}⚠${NC} $script: $issues issues"
				echo "  $script: $issues issues" >>"$REPORT_FILE"
				cat $TMP_DIR/shellcheck-light-$script.out >>"$REPORT_FILE"
				echo "" >>"$REPORT_FILE"
			fi
		done

		echo "Scripts checked: $scripts_checked, Total issues: $total_issues"
		echo "Summary: $scripts_checked scripts, $total_issues issues" >>"$REPORT_FILE"
		TOTAL_WARNINGS=$((TOTAL_WARNINGS + total_issues))
	else
		echo -e "  ${YELLOW}⚠${NC} shellcheck not installed"
		echo "Status: SKIPPED" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 5. Shell Script Formatting (shfmt)
validate_shell_formatting() {
	echo -e "${BLUE}[5/7]${NC} Checking shell script formatting with shfmt..."
	echo "=== Shell Script Formatting (shfmt) ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if command -v shfmt &>/dev/null; then
		local unformatted=0

		for script in *.sh; do
			[ -f "$script" ] || continue

			if shfmt -d "$script" >$TMP_DIR/shfmt-light-$script.out 2>&1; then
				echo -e "  ${GREEN}✓${NC} $script (formatted)"
			else
				unformatted=$((unformatted + 1))
				echo -e "  ${YELLOW}⚠${NC} $script (needs formatting)"
				echo "  $script: needs formatting" >>"$REPORT_FILE"
			fi
		done

		if [ $unformatted -eq 0 ]; then
			echo "  All scripts properly formatted"
			echo "Status: PASSED" >>"$REPORT_FILE"
		else
			echo "  $unformatted scripts need formatting (run: make format)"
			echo "Status: WARNING ($unformatted unformatted)" >>"$REPORT_FILE"
			TOTAL_WARNINGS=$((TOTAL_WARNINGS + unformatted))
		fi
	else
		echo -e "  ${YELLOW}⚠${NC} shfmt not installed"
		echo "Status: SKIPPED" >>"$REPORT_FILE"
	fi
	echo "" >>"$REPORT_FILE"
}

# 6. Environment Variable Check
validate_env_vars() {
	echo -e "${BLUE}[6/7]${NC} Checking required environment variables..."
	echo "=== Environment Variables ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	if [ -f ".env" ]; then
		echo -e "  ${GREEN}✓${NC} .env file exists"
		echo "Status: .env file found" >>"$REPORT_FILE"

		# Count defined variables
		local var_count=$(grep -c "^[A-Z_]*=" .env 2>/dev/null || echo 0)
		echo "  Defined variables: $var_count"
		echo "Variables defined: $var_count" >>"$REPORT_FILE"
	else
		echo -e "  ${YELLOW}⚠${NC} .env file not found (using .env.example as template)"
		echo "Status: WARNING (.env missing, using defaults)" >>"$REPORT_FILE"
		TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))

		if [ -f ".env.example" ]; then
			echo "  Recommendation: cp .env.example .env"
			echo "Recommendation: Copy .env.example to .env" >>"$REPORT_FILE"
		fi
	fi
	echo "" >>"$REPORT_FILE"
}

# 7. File Structure Validation
validate_file_structure() {
	echo -e "${BLUE}[7/7]${NC} Validating project file structure..."
	echo "=== File Structure ===" >>"$REPORT_FILE"

	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

	local required_files=(
		"docker-compose.yml"
		"Makefile"
	)

	local missing=0
	for file in "${required_files[@]}"; do
		if [ -f "$file" ]; then
			echo -e "  ${GREEN}✓${NC} $file"
			echo "  ✓ $file" >>"$REPORT_FILE"
		else
			echo -e "  ${RED}✗${NC} $file (missing)"
			echo "  ✗ $file (missing)" >>"$REPORT_FILE"
			missing=$((missing + 1))
		fi
	done

	if [ $missing -eq 0 ]; then
		echo "Status: PASSED" >>"$REPORT_FILE"
	else
		echo "Status: FAILED ($missing files missing)" >>"$REPORT_FILE"
		TOTAL_ERRORS=$((TOTAL_ERRORS + missing))
	fi
	echo "" >>"$REPORT_FILE"
}

# Generate summary
generate_summary() {
	echo ""
	echo "======================================"
	echo "VALIDATION SUMMARY"
	echo "======================================"
	echo "Total checks: $TOTAL_CHECKS"
	echo "Errors: $TOTAL_ERRORS"
	echo "Warnings: $TOTAL_WARNINGS"
	echo ""

	echo "=== SUMMARY ===" >>"$REPORT_FILE"
	echo "Total checks: $TOTAL_CHECKS" >>"$REPORT_FILE"
	echo "Errors: $TOTAL_ERRORS" >>"$REPORT_FILE"
	echo "Warnings: $TOTAL_WARNINGS" >>"$REPORT_FILE"
	echo "" >>"$REPORT_FILE"

	if [ $TOTAL_ERRORS -eq 0 ] && [ $TOTAL_WARNINGS -eq 0 ]; then
		echo -e "${GREEN}✓ VALIDATION PASSED${NC}"
		echo "Overall Status: PASSED" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 0
	elif [ $TOTAL_ERRORS -eq 0 ]; then
		echo -e "${YELLOW}⚠ VALIDATION PASSED WITH WARNINGS${NC}"
		echo "Overall Status: PASSED WITH WARNINGS" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 0
	else
		echo -e "${RED}✗ VALIDATION FAILED${NC}"
		echo "Overall Status: FAILED" >>"$REPORT_FILE"
		echo ""
		echo "Report saved to: $REPORT_FILE"
		exit 1
	fi
}

# Main execution
main() {
	detect_os
	validate_yaml_syntax
	validate_compose_config
	validate_yaml_parser
	validate_shell_scripts
	validate_shell_formatting
	validate_env_vars
	validate_file_structure
	generate_summary
}

main
