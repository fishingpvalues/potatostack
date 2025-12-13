#!/usr/bin/env bash
set -euo pipefail

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
