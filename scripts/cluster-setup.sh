#!/usr/bin/env bash
set -euo pipefail

# Cluster-Agnostic Kubernetes Setup Script
# Supports Minikube, k3s, and other Kubernetes distributions

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|arm64) ARCH=arm64;;
    x86_64|amd64) ARCH=amd64;;
  esac
  curl -Lo /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/${ARCH}/kubectl || true
  if [ -f /tmp/kubectl ]; then
    chmod +x /tmp/kubectl && sudo install /tmp/kubectl /usr/local/bin/kubectl
  else
    echo "Skip download (non-Linux system?), ensure kubectl is installed" >&2
  fi
fi

# Detect cluster type
detect_cluster() {
  if kubectl config current-context | grep -q minikube; then
    echo "minikube"
  elif kubectl config current-context | grep -q k3s; then
    echo "k3s"
  elif kubectl cluster-info | grep -q "k3s"; then
    echo "k3s"
  else
    echo "generic"
  fi
}

CLUSTER_TYPE=$(detect_cluster)
echo "Detected cluster type: $CLUSTER_TYPE"

# Install cluster-specific components
case "$CLUSTER_TYPE" in
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "Installing minikube..."
      ARCH=$(uname -m)
      case "$ARCH" in
        aarch64|arm64) ARCH=arm64;;
        x86_64|amd64) ARCH=amd64;;
      esac
      curl -Lo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH} || true
      if [ -f /tmp/minikube ]; then
        sudo install /tmp/minikube /usr/local/bin/minikube
      else
        echo "Skip download (non-Linux system?), ensure minikube is installed" >&2
      fi
    fi

    DRIVER=${MINIKUBE_DRIVER:-}
    if [ -z "$DRIVER" ]; then
      if command -v docker >/dev/null 2>&1; then
        DRIVER=docker
      else
        DRIVER=none
      fi
    fi

    echo "Starting minikube with driver: $DRIVER"
    if ! minikube status >/dev/null 2>&1; then
      sudo -E minikube start --driver="$DRIVER" --kubernetes-version=stable || minikube start --driver="$DRIVER" --kubernetes-version=stable
    fi

    echo "Enabling addons (ingress, metrics-server)..."
    minikube addons enable ingress || true
    minikube addons enable metrics-server || true

    echo "Minikube IP: $(minikube ip)"
    ;;

  k3s)
    if ! command -v k3s >/dev/null 2>&1; then
      echo "Installing k3s..."
      curl -sfL https://get.k3s.io | sh -
      echo "Waiting for k3s to be ready..."
      sleep 10
      sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s
      mkdir -p ~/.kube
      sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
      sudo chown $(id -u):$(id -g) ~/.kube/config
    fi
    echo "k3s cluster ready"
    ;;

  generic)
    echo "Using existing Kubernetes cluster"
    echo "Ensure you have:"
    echo "  - kubectl configured"
    echo "  - Cluster admin access"
    echo "  - Ingress controller available"
    ;;
esac

echo "Cluster setup complete!"