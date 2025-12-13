# PotatoStack - SOTA 2025 Helm Deployment Guide

Complete migration to production-grade Kubernetes with Helm charts.

## 🚀 Quick Start

```bash
# One-command full stack deployment
make stack-up
```

## 📦 What's Included

### Helm-Managed Services (SOTA 2025)

✅ **cert-manager** v1.19.2 - Automatic SSL certificate management
✅ **ingress-nginx** v4.14.1 - Production-grade ingress controller
✅ **kube-prometheus-stack** - Complete monitoring (Prometheus, Grafana, Alertmanager)
✅ **loki-stack** - Log aggregation with Promtail
✅ **ArgoCD** v9.1.7 - GitOps continuous deployment
✅ **Kyverno** v3.6.1 - Kubernetes-native policy engine
✅ **Gitea** v12.4.0 - Self-hosted Git with PostgreSQL + Valkey
✅ **kubernetes-secret-generator** v3.4.1 - Automatic secret generation
✅ **Blackbox Exporter** - External endpoint probes (Prometheus)
✅ **Netdata** - Realtime node + app monitoring (optional)
✅ **Authelia** - Official chart for SSO portal
✅ **Vaultwarden / Immich / Seafile / Kopia / Gluetun stack / Uptime Kuma / Homepage / Portainer / Dozzle / Fileserver** via app-template

### Kustomize-Managed Workloads

- **Postgres** (pgvecto-rs) - Unified database for Gitea, Immich, Seafile
- **Redis** - Shared cache for all services
- **Vaultwarden** - Password manager with Authelia SSO
- **Immich** - Self-hosted photo management
- **Seafile** - File sync and share
- **Kopia** - Encrypted backups
- **Gluetun** - VPN with qBittorrent + slskd sidecars
- **Authelia** - Single Sign-On with OAuth2/OIDC
- **Homepage** - Unified dashboard
- **Management tools** - Portainer, Dozzle, Uptime Kuma

## 📋 Prerequisites

- Kubernetes 1.19+ (k3s recommended)
- Helm 3.0+
- kubectl configured
- 2GB+ RAM available

## 🔧 Installation Steps

### Option 1: Full Automatic Install

```bash
# Install everything (operators + monitoring + workloads)
make stack-up
```

### Option 2: Step-by-Step Install

```bash
# 1. Add Helm repositories
make helm-repos

# 2. Install infrastructure operators
make helm-install-operators

# 3. Install monitoring stack
make helm-install-monitoring

# 4. Install ArgoCD for GitOps
make helm-install-argocd

# 5. Install shared datastores (Redis + Postgres)
make helm-install-datastores

# 6. Install application workloads via Helm
make helm-install-apps
```

### Option 3: Manual Helm Install

```bash
# Add repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add mittwald https://helm.mittwald.de
helm repo add bjw-s https://bjw-s.github.io/helm-charts
helm repo add gethomepage https://gethomepage.github.io/homepage/
helm repo add portainer https://portainer.github.io/k8s/
helm repo add dozzle https://amir20.github.io/dozzle/
helm repo add netdata https://netdata.github.io/helmchart/
helm repo add authelia https://charts.authelia.com
helm repo update

# Install cert-manager
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  -f helm/values/cert-manager.yaml

# Install ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f helm/values/ingress-nginx.yaml

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace potatostack-monitoring --create-namespace \
  -f helm/values/kube-prometheus-stack.yaml

# Install Loki
helm install loki grafana/loki-stack \
  --namespace potatostack-monitoring \
  -f helm/values/loki-stack.yaml

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f helm/values/argocd.yaml

# Install Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  -f helm/values/kyverno.yaml

# Install Redis (shared cache)
helm install redis bitnami/redis \
  --namespace potatostack --create-namespace \
  -f helm/values/redis.yaml

# Install PostgreSQL (pgvecto-rs image)
helm install postgres bitnami/postgresql \
  --namespace potatostack \
  -f helm/values/postgresql.yaml

# Install Vaultwarden
helm install vaultwarden bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/vaultwarden.yaml

# Install Immich (server + microservices)
helm install immich bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/immich.yaml

# Install Seafile
helm install seafile bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/seafile.yaml

# Install Kopia
helm install kopia bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/kopia.yaml

# Install Gluetun stack (gluetun + qBittorrent + slskd sidecars)
helm install gluetun-stack bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/gluetun-stack.yaml

# Install Uptime Kuma
helm install uptime-kuma bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/uptime-kuma.yaml

# Install Homepage
helm install homepage gethomepage/homepage \
  --namespace potatostack \
  -f helm/values/homepage.yaml

# Install Portainer
helm install portainer portainer/portainer \
  --namespace potatostack \
  -f helm/values/portainer.yaml

# Install Dozzle
helm install dozzle dozzle/dozzle \
  --namespace potatostack \
  -f helm/values/dozzle.yaml

# Install Unified Backups (CronJob)
helm install unified-backups bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/unified-backups.yaml
```

## 🎯 Architecture Highlights

### SOTA 2025 Features

**Helm-Based Deployment**
- Industry-standard package management
- Version-controlled configurations
- Easy rollbacks and upgrades
- Community-maintained charts

**GitOps with ArgoCD**
- Git as single source of truth
- Automated deployments
- Declarative configuration
- Self-healing applications

**Enterprise Security**
- Kyverno policy enforcement
- Pod Security Standards (Baseline/Restricted)
- Network Policies (default deny + explicit allow)
- Automatic secret generation
- Automatic SSL with cert-manager

**Observability**
- Prometheus Operator for metrics
- Grafana with pre-configured dashboards
- Loki for centralized logging
- ServiceMonitors for all services

**High Availability Ready**
- StatefulSets for stateful services
- PVC-backed persistence
- Resource limits optimized for 2GB RAM

## 📊 Accessing Services

### Port Forwarding

```bash
# Grafana (monitoring dashboards)
make k8s-port-forward-grafana
# Access at http://localhost:3000

# Prometheus (metrics)
make k8s-port-forward-prometheus
# Access at http://localhost:9090

# ArgoCD (GitOps UI)
make k8s-port-forward-argocd
# Access at http://localhost:8080
# Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Ingress (when configured)

All services available via ingress at `*.lepotato.local`:
- `https://grafana.lepotato.local` - Monitoring dashboards
- `https://argocd.lepotato.local` - GitOps management
- `https://git.lepotato.local` - Gitea
- `https://vault.lepotato.local` - Vaultwarden
- `https://photos.lepotato.local` - Immich

## 🔄 Common Operations

### Check Status

```bash
# View all Helm releases
make helm-list

# View all K8s resources
make k8s-status

# Complete stack status
make stack-status
```

### Upgrade Services

```bash
# Upgrade all Helm releases
make helm-upgrade-all

# Upgrade specific service
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -f helm/values/kube-prometheus-stack.yaml \
  -n potatostack-monitoring
```

### Backup & Restore

```bash
# Backup Postgres
make k8s-backup

# Restore Postgres
make k8s-restore
```

### Teardown

```bash
# Remove everything
make stack-down

# Or selectively uninstall
make helm-uninstall-all  # Remove Helm releases
make k8s-clean            # Remove K8s resources
```

## 📁 Directory Structure

```
├── helm/
│   └── values/                 # Helm values files
│       ├── kube-prometheus-stack.yaml
│       ├── loki-stack.yaml
│       ├── argocd.yaml
│       ├── cert-manager.yaml
│       ├── ingress-nginx.yaml
│       ├── kyverno.yaml
│       └── gitea.yaml
│       ├── redis.yaml
│       ├── vaultwarden.yaml
│       ├── immich.yaml
│       ├── seafile.yaml
│       ├── kopia.yaml
│       ├── gluetun-stack.yaml
│       ├── uptime-kuma.yaml
│       ├── homepage.yaml
│       ├── portainer.yaml
│       └── dozzle.yaml
├── k8s/
│   ├── base/                   # Base Kustomize manifests
│   ├── overlays/production/    # Production overlays
│   └── apps/                   # ArgoCD app definitions
├── config/                     # ConfigMaps and configs
├── Makefile                    # All commands
└── HELM-DEPLOYMENT.md         # This file
```

## 🔍 Troubleshooting

### Helm Release Issues

```bash
# List all releases
helm list -A

# Get release status
helm status <release-name> -n <namespace>

# View release history
helm history <release-name> -n <namespace>

# Rollback to previous version
helm rollback <release-name> -n <namespace>
```

### Pod Issues

```bash
# View pod logs
kubectl logs -f <pod-name> -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Exec into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### Certificate Issues

```bash
# Check certificates
kubectl get certificates -A

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Describe certificate
kubectl describe certificate <cert-name> -n <namespace>
```

## 🔐 Security Considerations

- All secrets auto-generated via kubernetes-secret-generator
- Pod Security Standards enforced by Kyverno
- Network Policies restrict inter-pod communication
- TLS certificates automated via cert-manager
- OAuth2/OIDC SSO via Authelia

## 📚 Chart Versions (2025)

| Service | Chart Version | App Version |
|---------|--------------|-------------|
| cert-manager | v1.19.2 | v1.19.2 |
| ingress-nginx | 4.14.1 | v1.14.1 |
| kube-prometheus-stack | Latest | v0.77+ |
| loki-stack | Latest | v2.9+ |
| ArgoCD | 9.1.7 | v2.13+ |
| Kyverno | 3.6.1 | v1.16+ |
| Gitea | v12.4.0 | v1.22+ |

## 📖 Additional Resources

- [Kubernetes Quickstart](KUBERNETES-QUICKSTART.md)
- [Migration Guide](MIGRATION_PLAN.md)
- [Main README](README.md)
- [kube-prometheus-stack docs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [ArgoCD docs](https://argo-cd.readthedocs.io/)
- [Kyverno docs](https://kyverno.io/)

## 🎉 What's Next?

1. Configure DNS for `*.lepotato.local`
2. Set up Let's Encrypt for production SSL
3. Configure backup automation with Velero
4. Set up external monitoring with Grafana Cloud
5. Enable horizontal pod autoscaling (HPA)
6. Integrate with external auth provider

## Sources

- [ingress-nginx Helm chart](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx)
- [ArgoCD Helm chart](https://artifacthub.io/packages/helm/argo/argo-cd)
- [Kyverno Helm chart](https://kyverno.io/docs/installation/)
- [Bitnami PostgreSQL](https://artifacthub.io/packages/helm/bitnami/postgresql)
- [kubernetes-secret-generator](https://github.com/mittwald/kubernetes-secret-generator)
# Install Blackbox Exporter
helm install blackbox prometheus-community/prometheus-blackbox-exporter \
  -n potatostack-monitoring -f helm/values/blackbox-exporter.yaml

# Install Netdata (optional)
helm install netdata netdata/netdata \
  -n potatostack-monitoring -f helm/values/netdata.yaml
# Install Fileserver (Samba + SFTP + Filebrowser)
helm install fileserver bjw-s/app-template \
  --namespace potatostack \
  -f helm/values/fileserver.yaml

# Install Speedtest Exporter
helm install speedtest-exporter bjw-s/app-template \
  -n potatostack-monitoring \
  -f helm/values/speedtest-exporter.yaml

# Install Fritz!Box Exporter
helm install fritzbox-exporter bjw-s/app-template \
  -n potatostack-monitoring \
  -f helm/values/fritzbox-exporter.yaml
# Install Authelia (SSO)
helm install authelia authelia/authelia \
  --namespace potatostack --create-namespace \
  -f helm/values/authelia.yaml
