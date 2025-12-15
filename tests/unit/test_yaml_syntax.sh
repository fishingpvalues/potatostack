#!/usr/bin/env bash
# Unit test: Validate YAML syntax for all configuration files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "=========================================="
echo "YAML Syntax Validation Test"
echo "=========================================="
echo ""

# Check if yq is installed
if ! command -v yq >/dev/null 2>&1; then
  echo -e "${RED}✗${NC} yq not installed. Install: brew install yq"
  exit 1
fi

# Test all YAML files
find "$PROJECT_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/node_modules/*" -not -path "*/.git/*" | while read -r file; do
  relpath="${file#$PROJECT_ROOT/}"

  if yq eval '.' "$file" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $relpath"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC} $relpath - INVALID YAML"
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
