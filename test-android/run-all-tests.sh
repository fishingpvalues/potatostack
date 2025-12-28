#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# PotatoStack - Run All Tests (Android/Termux)
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${MAGENTA}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║           PotatoStack Test Suite                      ║"
echo "║           Android/Termux (Unrooted)                   ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Test 1: Main Stack Config
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}[1/3] Main Stack Config Tests (16GB RAM)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

if ./test-main-stack.sh; then
    MAIN_RESULT="${GREEN}PASSED${NC}"
    ((TOTAL_PASSED++))
else
    MAIN_RESULT="${RED}FAILED${NC}"
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""
sleep 2

# Test 2: Light Stack Config
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}[2/3] Light Stack Config Tests (2GB RAM)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

if ./test-light-stack.sh; then
    LIGHT_RESULT="${GREEN}PASSED${NC}"
    ((TOTAL_PASSED++))
else
    LIGHT_RESULT="${RED}FAILED${NC}"
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""
sleep 2

# Test 3: Runtime Tests
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}[3/3] Runtime Tests (Actual Container Healthchecks)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

if ./test-runtime.sh; then
    RUNTIME_RESULT="${GREEN}PASSED${NC}"
    ((TOTAL_PASSED++))
else
    RUNTIME_RESULT="${RED}FAILED${NC}"
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Final Summary
echo -e "${MAGENTA}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║                  FINAL TEST SUMMARY                    ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "Main Stack Config:  $MAIN_RESULT"
echo -e "Light Stack Config: $LIGHT_RESULT"
echo -e "Runtime Tests:      $RUNTIME_RESULT\n"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "Total Test Suites:  ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:             ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed:             ${RED}$TOTAL_FAILED${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║         ✓ ALL TEST SUITES PASSED! ✓                   ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}║         ✗ SOME TEST SUITES FAILED ✗                   ║${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
    exit 1
fi
