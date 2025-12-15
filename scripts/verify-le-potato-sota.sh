#!/usr/bin/env bash
set -euo pipefail

# Le Potato SOTA 2025 Stack Verification Script
# Ensures ARM64 compatibility and optimal configuration

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Le Potato SOTA 2025 Stack Verification"
echo "=========================================="
echo ""

# Check architecture
echo "[1/8] Verifying ARM64 architecture..."
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  echo -e "${GREEN}✓${NC} ARM64 architecture detected: $ARCH"
else
  echo -e "${YELLOW}⚠${NC} Non-ARM architecture detected: $ARCH (development machine?)"
fi
echo ""

# Check memory
echo "[2/8] Checking system memory..."
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -le 2 ]; then
  echo -e "${GREEN}✓${NC} Memory appropriate for Le Potato: ${TOTAL_MEM}GB"
  echo -e "${YELLOW}⚠${NC} Ensure swap is configured (2GB+ recommended)"
else
  echo -e "${GREEN}✓${NC} Memory: ${TOTAL_MEM}GB (more than Le Potato)"
fi
echo ""

# Check k3s installation
echo "[3/8] Checking k3s installation..."
if command -v k3s >/dev/null 2>&1; then
  K3S_VERSION=$(k3s --version | head -1)
  echo -e "${GREEN}✓${NC} k3s installed: $K3S_VERSION"

  # Check k3s server args for optimizations
  if [ -f /etc/systemd/system/k3s.service ]; then
    echo "  Checking k3s optimizations..."

    if grep -q "disable=traefik" /etc/systemd/system/k3s.service 2>/dev/null || \
       grep -q "disable=traefik" /etc/rancher/k3s/config.yaml 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Traefik disabled (using ingress-nginx)"
    else
      echo -e "  ${YELLOW}⚠${NC} Consider disabling Traefik: k3s server --disable traefik"
    fi

    if grep -q "disable=servicelb" /etc/systemd/system/k3s.service 2>/dev/null || \
       grep -q "disable=servicelb" /etc/rancher/k3s/config.yaml 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} ServiceLB disabled (minimal footprint)"
    fi
  fi
else
  echo -e "${YELLOW}⚠${NC} k3s not installed (use: make k8s-setup)"
fi
echo ""

# Check kubectl
echo "[4/8] Checking kubectl..."
if command -v kubectl >/dev/null 2>&1; then
  KUBE_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | cut -d'"' -f4 || echo "unknown")
  echo -e "${GREEN}✓${NC} kubectl installed: $KUBE_VERSION"

  # Check cluster connectivity
  if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Cluster accessible"
    NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' 2>/dev/null || echo "")
    if [[ "$NODES" == *"arm64"* ]]; then
      echo -e "${GREEN}✓${NC} Cluster running on ARM64"
    fi
  else
    echo -e "${YELLOW}⚠${NC} Cluster not accessible (cluster not running?)"
  fi
else
  echo -e "${RED}✗${NC} kubectl not installed"
fi
echo ""

# Check Helm
echo "[5/8] Checking Helm..."
if command -v helm >/dev/null 2>&1; then
  HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓${NC} Helm installed: $HELM_VERSION"
else
  echo -e "${YELLOW}⚠${NC} Helm not installed (install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash)"
fi
echo ""

# Check critical operators
echo "[6/8] Checking SOTA operators..."
if kubectl cluster-info >/dev/null 2>&1; then

  # cert-manager
  if kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} cert-manager installed"
  else
    echo -e "${YELLOW}⚠${NC} cert-manager not installed (run: make helm-install-operators)"
  fi

  # ingress-nginx
  if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ingress-nginx installed"
  else
    echo -e "${YELLOW}⚠${NC} ingress-nginx not installed (run: make helm-install-operators)"
  fi

  # kyverno (policy engine)
  if kubectl get namespace kyverno >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Kyverno (policy engine) installed"
  else
    echo -e "${YELLOW}⚠${NC} Kyverno not installed (run: make helm-install-operators)"
  fi

  # ArgoCD (GitOps)
  if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ArgoCD (GitOps) installed"
  else
    echo -e "${YELLOW}⚠${NC} ArgoCD not installed (run: make helm-install-argocd)"
  fi
fi
echo ""

# Check resource limits in Helm values
echo "[7/8] Checking resource limits optimization..."
TOTAL_LIMITS=0
for file in helm/values/*.yaml; do
  if [ -f "$file" ]; then
    LIMITS=$(grep -A1 "limits:" "$file" | grep "memory:" | awk '{print $2}' | sed 's/Mi$//' | grep -o '[0-9]*' || echo "0")
    for limit in $LIMITS; do
      TOTAL_LIMITS=$((TOTAL_LIMITS + limit))
    done
  fi
done

if [ "$TOTAL_LIMITS" -gt 0 ]; then
  TOTAL_GB=$((TOTAL_LIMITS / 1024))
  if [ "$TOTAL_GB" -le 2 ]; then
    echo -e "${GREEN}✓${NC} Total memory limits: ~${TOTAL_GB}GB (optimized for 2GB)"
  else
    echo -e "${YELLOW}⚠${NC} Total memory limits: ~${TOTAL_GB}GB (may need swap)"
  fi
fi
echo ""

# SOTA 2025 features check
echo "[8/8] Checking SOTA 2025 features..."

# Gateway API
if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Gateway API installed (SOTA)"
else
  echo -e "${YELLOW}⚠${NC} Gateway API not installed (optional SOTA feature)"
fi

# Sealed Secrets
if kubectl get namespace kube-system -o json | grep -q sealed-secrets 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Sealed Secrets installed"
else
  echo -e "${YELLOW}⚠${NC} Sealed Secrets not installed (run: make helm-install-sealed-secrets)"
fi

# Metrics Server (for HPA)
if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Metrics Server installed (enables HPA)"
else
  echo -e "${YELLOW}⚠${NC} Metrics Server not installed (run: make helm-install-metrics-server)"
fi

echo ""
echo "=========================================="
echo "Verification complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy full stack: make stack-up-local"
echo "  2. Access Grafana: make k8s-port-forward-grafana"
echo "  3. Access ArgoCD: make k8s-port-forward-argocd"
echo "  4. Monitor resources: kubectl top nodes"
echo ""
