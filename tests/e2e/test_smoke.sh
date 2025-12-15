#!/usr/bin/env bash
# E2E Smoke test: Quick validation that critical services are running
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "=========================================="
echo "Smoke Test - Critical Services"
echo "=========================================="
echo ""

# Core services that MUST be running
SERVICES=(
  "potatostack:postgres"
  "potatostack:redis"
  "potatostack-monitoring:prometheus-operated"
  "potatostack-monitoring:grafana"
)

for svc in "${SERVICES[@]}"; do
  namespace="${svc%%:*}"
  service="${svc##*:}"

  if kubectl get svc "$service" -n "$namespace" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Service $namespace/$service exists"
    ((PASSED++))

    # Check endpoints
    endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    if [ -n "$endpoints" ]; then
      echo -e "${GREEN}✓${NC} Service $namespace/$service has endpoints"
      ((PASSED++))
    else
      echo -e "${RED}✗${NC} Service $namespace/$service has NO endpoints"
      ((FAILED++))
    fi
  else
    echo -e "${RED}✗${NC} Service $namespace/$service NOT FOUND"
    ((FAILED++))
  fi
done

echo ""
echo "=========================================="
echo "Results: PASSED=$PASSED FAILED=$FAILED"
echo "=========================================="

if [ "$FAILED" -gt 0 ]; then
  echo -e "${RED}SMOKE TEST FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}SMOKE TEST PASSED${NC}"
  exit 0
fi
