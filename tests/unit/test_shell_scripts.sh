#!/usr/bin/env bash
# Unit test: Validate shell scripts with shellcheck
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "=========================================="
echo "Shell Script Validation Test"
echo "=========================================="
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck >/dev/null 2>&1; then
  echo -e "${RED}✗${NC} shellcheck not installed. Install: brew install shellcheck"
  exit 1
fi

# Test all shell scripts
find "$PROJECT_ROOT" -type f -name "*.sh" -not -path "*/.git/*" | while read -r file; do
  relpath="${file#$PROJECT_ROOT/}"

  if shellcheck -x "$file"; then
    echo -e "${GREEN}✓${NC} $relpath"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC} $relpath - SHELLCHECK FAILED"
    ((FAILED++))
  fi
done

# Results
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo -e "${RED}TESTS FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}ALL TESTS PASSED${NC}"
  exit 0
fi
