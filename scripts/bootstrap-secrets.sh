#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-potatostack}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo ".env file not found in repo root" >&2
  exit 1
fi

echo "Loading .env variables..."
set -a
source .env
set +a

echo "Ensuring namespace '$NAMESPACE' exists..."
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

echo "Applying app secrets in namespace $NAMESPACE..."

# Immich
kubectl -n "$NAMESPACE" create secret generic immich-secrets \
  --from-literal=IMMICH_DB_PASSWORD="${IMMICH_DB_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Seafile
kubectl -n "$NAMESPACE" create secret generic seafile-secrets \
  --from-literal=SEAFILE_DB_PASSWORD="${SEAFILE_DB_PASSWORD:-}" \
  --from-literal=SEAFILE_ADMIN_EMAIL="${SEAFILE_ADMIN_EMAIL:-}" \
  --from-literal=SEAFILE_ADMIN_PASSWORD="${SEAFILE_ADMIN_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Vaultwarden
kubectl -n "$NAMESPACE" create secret generic vaultwarden-secrets \
  --from-literal=ADMIN_TOKEN="${VAULTWARDEN_ADMIN_TOKEN:-}" \
  --from-literal=ALERT_EMAIL_USER="${ALERT_EMAIL_USER:-}" \
  --from-literal=ALERT_EMAIL_PASSWORD="${ALERT_EMAIL_PASSWORD:-}" \
  --from-literal=VAULTWARDEN_OIDC_SECRET="${VAULTWARDEN_OIDC_SECRET:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Kopia
kubectl -n "$NAMESPACE" create secret generic kopia-secrets \
  --from-literal=KOPIA_PASSWORD="${KOPIA_PASSWORD:-}" \
  --from-literal=KOPIA_SERVER_USER="${KOPIA_SERVER_USER:-admin}" \
  --from-literal=KOPIA_SERVER_PASSWORD="${KOPIA_SERVER_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Gluetun
kubectl -n "$NAMESPACE" create secret generic gluetun-secrets \
  --from-literal=SURFSHARK_USER="${SURFSHARK_USER:-}" \
  --from-literal=SURFSHARK_PASSWORD="${SURFSHARK_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# slskd
kubectl -n "$NAMESPACE" create secret generic slskd-secrets \
  --from-literal=SLSKD_USER="${SLSKD_USER:-admin}" \
  --from-literal=SLSKD_PASSWORD="${SLSKD_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Homepage
kubectl -n "$NAMESPACE" create secret generic homepage-secrets \
  --from-literal=HOMEPAGE_VAR_QBITTORRENT_PASSWORD="${HOMEPAGE_VAR_QBITTORRENT_PASSWORD:-}" \
  --from-literal=HOMEPAGE_VAR_PORTAINER_KEY="${HOMEPAGE_VAR_PORTAINER_KEY:-}" \
  --from-literal=HOMEPAGE_VAR_GITEA_TOKEN="${HOMEPAGE_VAR_GITEA_TOKEN:-}" \
  --from-literal=HOMEPAGE_VAR_GRAFANA_USER="${HOMEPAGE_VAR_GRAFANA_USER:-}" \
  --from-literal=HOMEPAGE_VAR_GRAFANA_PASSWORD="${HOMEPAGE_VAR_GRAFANA_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Fritz!Box Exporter
kubectl -n "$NAMESPACE" create secret generic fritzbox-secrets \
  --from-literal=FRITZ_USERNAME="${FRITZ_USERNAME:-}" \
  --from-literal=FRITZ_PASSWORD="${FRITZ_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Fileserver (Samba)
kubectl -n "$NAMESPACE" create secret generic fileserver-secrets \
  --from-literal=SAMBA_PASSWORD="${SAMBA_PASSWORD:-changeme}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Optionally create fileserver SSH authorized_keys configmap:" >&2
echo "  kubectl -n $NAMESPACE create configmap fileserver-ssh-config --from-file=config/ssh/authorized_keys --dry-run=client -o yaml | kubectl apply -f -" >&2

echo "All secrets applied to namespace $NAMESPACE."
