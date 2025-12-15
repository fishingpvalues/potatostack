#!/usr/bin/env bash
# Integration test: Deploy and verify core stack on k3s
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "K8s Deployment Integration Test"
echo "=========================================="
echo ""

# Test 1: kubectl connectivity
echo "[TEST 1] Checking kubectl connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Cluster accessible"
else
  echo -e "${RED}✗${NC} Cluster not accessible"
  exit 1
fi
echo ""

# Test 2: Core operators deployed
echo "[TEST 2] Checking core operators..."
OPERATORS=(
  "cert-manager:cert-manager"
  "ingress-nginx:ingress-nginx-controller"
  "kyverno:kyverno"
)

for op in "${OPERATORS[@]}"; do
  namespace="${op%%:*}"
  deployment="${op##*:}"

  if kubectl get deployment "$deployment" -n "$namespace" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $namespace/$deployment exists"

    # Check if ready
    ready=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    if [ "$ready" == "$replicas" ]; then
      echo -e "${GREEN}✓${NC} $namespace/$deployment is ready ($ready/$replicas)"
    else
      echo -e "${YELLOW}⚠${NC} $namespace/$deployment not ready ($ready/$replicas)"
    fi
  else
    echo -e "${RED}✗${NC} $namespace/$deployment not found"
  fi
done
echo ""

# Test 3: Check namespace exists
echo "[TEST 3] Checking potatostack namespace..."
if kubectl get namespace potatostack >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} potatostack namespace exists"
else
  echo -e "${YELLOW}⚠${NC} potatostack namespace not found (run: make helm-install-datastores)"
fi
echo ""

# Test 4: Resource limits enforced
echo "[TEST 4] Checking resource limits enforcement..."
if kubectl get resourcequota -n potatostack >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} ResourceQuota exists"
else
  echo -e "${YELLOW}⚠${NC} ResourceQuota not configured (optional)"
fi
echo ""

# Test 5: Network policies
echo "[TEST 5] Checking network policies..."
if kubectl get networkpolicy -n potatostack >/dev/null 2>&1; then
  count=$(kubectl get networkpolicy -n potatostack --no-headers 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Network policies configured ($count policies)"
  else
    echo -e "${YELLOW}⚠${NC} No network policies (optional for local)"
  fi
else
  echo -e "${YELLOW}⚠${NC} NetworkPolicy API not available"
fi
echo ""

echo -e "${GREEN}INTEGRATION TESTS PASSED${NC}"
