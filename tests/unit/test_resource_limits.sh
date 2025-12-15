#!/usr/bin/env bash
# Unit test: Verify all Helm values have proper resource limits for Le Potato (2GB RAM)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
MAX_TOTAL_RAM_MB=1800  # Leave 200MB buffer for system

echo "=========================================="
echo "Resource Limits Unit Test (Le Potato)"
echo "=========================================="
echo ""

# Test 1: All production Helm values must have memory limits
echo "[TEST 1] Checking memory limits exist..."
for file in "$PROJECT_ROOT"/helm/values/*.yaml; do
  filename=$(basename "$file")

  # Skip non-production files
  if [[ "$filename" == "ingress-nginx-minikube.yaml" ]]; then
    continue
  fi

  if grep -q "limits:" "$file" && grep -q "memory:" "$file"; then
    echo -e "${GREEN}✓${NC} $filename has memory limits"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC} $filename missing memory limits"
    ((FAILED++))
  fi
done
echo ""

# Test 2: Calculate total RAM usage
echo "[TEST 2] Calculating total RAM usage..."
TOTAL_RAM_MB=0
for file in "$PROJECT_ROOT"/helm/values/*.yaml; do
  filename=$(basename "$file")

  # Skip non-production files
  if [[ "$filename" == "ingress-nginx-minikube.yaml" ]]; then
    continue
  fi

  # Extract memory limits (handles Mi and Gi)
  while IFS= read -r line; do
    if [[ "$line" =~ memory:.*([0-9]+)(Mi|Gi) ]]; then
      value="${BASH_REMATCH[1]}"
      unit="${BASH_REMATCH[2]}"

      if [[ "$unit" == "Gi" ]]; then
        value=$((value * 1024))
      fi

      TOTAL_RAM_MB=$((TOTAL_RAM_MB + value))
    fi
  done < <(grep -A1 "limits:" "$file" | grep "memory:" || true)
done

echo "Total RAM limits: ${TOTAL_RAM_MB}MB (max: ${MAX_TOTAL_RAM_MB}MB)"

if [ "$TOTAL_RAM_MB" -le "$MAX_TOTAL_RAM_MB" ]; then
  echo -e "${GREEN}✓${NC} RAM usage within Le Potato limits"
  ((PASSED++))
else
  echo -e "${RED}✗${NC} RAM usage exceeds Le Potato limits"
  ((FAILED++))
fi
echo ""

# Test 3: All services must have CPU limits
echo "[TEST 3] Checking CPU limits exist..."
for file in "$PROJECT_ROOT"/helm/values/*.yaml; do
  filename=$(basename "$file")

  # Skip non-production files
  if [[ "$filename" == "ingress-nginx-minikube.yaml" ]]; then
    continue
  fi

  if grep -q "limits:" "$file" && grep -q "cpu:" "$file"; then
    echo -e "${GREEN}✓${NC} $filename has CPU limits"
    ((PASSED++))
  else
    echo -e "${YELLOW}⚠${NC} $filename missing CPU limits (warning only)"
  fi
done
echo ""

# Test 4: Ingress must use cert-manager
echo "[TEST 4] Checking ingress SSL configuration..."
for file in "$PROJECT_ROOT"/helm/values/*.yaml; do
  if grep -q "ingress:" "$file"; then
    if grep -q "cert-manager.io/cluster-issuer" "$file"; then
      echo -e "${GREEN}✓${NC} $(basename "$file") uses cert-manager"
      ((PASSED++))
    else
      echo -e "${YELLOW}⚠${NC} $(basename "$file") missing cert-manager annotation"
    fi
  fi
done
echo ""

# Results
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
