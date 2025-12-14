# PotatoStack Kubernetes - Quick Start

Complete Kubernetes migration with 2025 SOTA tooling. **Cluster-agnostic** - works with Minikube, k3s, and cloud clusters.

## What's Included

✅ **26 Kubernetes manifests** covering entire stack
✅ **Auto-generated secrets** via kubernetes-secret-generator
✅ **Secret replication** across namespaces
✅ **Automatic SSL** with cert-manager + Let's Encrypt
✅ **Prometheus Operator** for monitoring
✅ **Loki** for log aggregation
✅ **ArgoCD** for GitOps
✅ **Network Policies** for security
✅ **Pod Security Standards** enforced
✅ **Kyverno** for policy management
✅ **Kustomize** for environment management

## Quick Deploy Options

### Option 1: Local Development (Minikube/k3s)
```bash
make stack-up-local
```

### Option 2: Manual Setup
```bash
# 1. Setup cluster (auto-detects type)
make k8s-setup

# 2. Install operators
make k8s-operators

# 3. Deploy the stack
make k8s-up

# 4. Get Ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# 5. Access services at https://*.lepotato.local
```

### Option 3: Full Helm Stack
```bash
make stack-up
```

## Key Services

| Service | URL | Port |
|---------|-----|------|
| Gitea | https://git.lepotato.local | 3000 |
| Immich | https://photos.lepotato.local | 3001 |
| Vaultwarden | https://vault.lepotato.local | 80 |
| Grafana | https://grafana.lepotato.local | 3000 |
| qBittorrent | https://torrents.lepotato.local | 8080 |
| Rustypaste | https://paste.lepotato.local | 8000 |

## Supported Cluster Types

PotatoStack is **cluster-agnostic** and works with:

### 🏠 Local Development
- **Minikube**: `make stack-up-local` (uses NodePort, no TLS in some configs)
- **k3s**: `make stack-up-local` (lightweight Kubernetes for edge computing)

### ☁️ Production/Cloud
- **AWS EKS**: `make stack-up` (LoadBalancer service type)
- **Google GKE**: `make stack-up` (LoadBalancer service type)
- **Azure AKS**: `make stack-up` (LoadBalancer service type)
- **Self-hosted k3s**: `make stack-up` (LoadBalancer service type)

### 🔧 Bare Metal/Edge
- **k3s on SBCs**: Perfect for Raspberry Pi, Le Potato, etc.
- **MicroK8s**: Ubuntu's lightweight Kubernetes
- **k0s**: Zero-friction Kubernetes

## Architecture Highlights

### Storage
- **PostgreSQL** StatefulSet with pgvecto-rs for AI embeddings
- **Redis** StatefulSet for caching/sessions
- **Loki** StatefulSet for logs

### Applications
- **Gitea** with Postgres + Redis backend
- **Immich** self-hosted photos (no ML on 2GB RAM)
- **Vaultwarden** password manager
- **Gluetun VPN** with qBittorrent + slskd sidecars

### Monitoring
- **Prometheus Operator** with ServiceMonitors
- **Grafana** with OAuth2 (Authelia)
- **Loki + Promtail** for log aggregation
- **Alertmanager** for notifications

### Security
- **Network Policies**: Default deny + explicit allows
- **Pod Security**: seccomp, drop ALL capabilities
- **Secrets**: Auto-generated + replicated
- **SSL**: Automatic via cert-manager

## Directory Structure

```
k8s/
├── base/
│   ├── namespaces/          # 4 namespaces with PSS
│   ├── operators/           # secret-gen, replicator, cert-manager, kyverno
│   ├── secrets/             # Auto-generated secrets
│   ├── configmaps/          # Postgres init, app configs
│   ├── statefulsets/        # Postgres, Redis, Loki
│   ├── deployments/         # Apps (Gitea, Immich, etc)
│   ├── services/            # K8s Services
│   ├── ingress/             # NGINX Ingress with TLS
│   ├── networkpolicies/     # Security policies
│   └── kustomization.yaml   # Base resources
├── overlays/
│   └── production/
│       ├── kustomization.yaml      # Production config
│       ├── resource-limits.yaml    # Resource constraints
│       └── storage-class.yaml      # Storage tiers
├── argocd/
│   ├── application.yaml     # ArgoCD app definition
│   └── notifications.yaml   # Deployment alerts
├── README.md                # Full documentation
├── MIGRATION.md             # Docker→K8s migration guide
└── FEATURES.md              # SOTA features explained
```

## SOTA Features (2025)

### 1. Operators
- **kubernetes-secret-generator**: Auto-generate passwords
- **kubernetes-replicator**: Sync secrets across namespaces
- **cert-manager**: Automatic SSL certificates
- **Prometheus Operator**: K8s-native monitoring

### 2. GitOps
- **ArgoCD**: Declarative continuous deployment
- **Auto-sync**: Git as source of truth
- **Self-healing**: Auto-correct drift

### 3. Security
- **Kyverno**: K8s-native policy engine
- **Network Policies**: Zero-trust networking
- **Pod Security Standards**: Baseline/Restricted enforcement
- **seccomp**: RuntimeDefault profiles

### 4. Configuration
- **Kustomize**: Built-in, no templating
- **Base + Overlays**: Environment separation
- **Strategic Merge**: Patch configs per environment

### 5. Observability
- **Prometheus**: Metrics with ServiceMonitors
- **Loki**: Log aggregation
- **Grafana**: Unified dashboards
- **Distributed Tracing**: OpenTelemetry-ready

## Common Commands

```bash
# View all resources
kubectl get all -n potatostack

# Check pod logs
kubectl logs -f deployment/gitea -n potatostack

# Port-forward service
kubectl port-forward svc/grafana 3000:3000 -n potatostack-monitoring

# Scale deployment
kubectl scale deployment/gitea --replicas=2 -n potatostack

# Update image
kubectl set image deployment/gitea gitea=gitea/gitea:1.22.0 -n potatostack

# Apply changes
kubectl apply -k k8s/overlays/production

# View secrets
kubectl get secrets -n potatostack

# Check Ingress
kubectl get ingress -A

# View NetworkPolicies
kubectl get networkpolicies -A

# Check resource usage
kubectl top pods -n potatostack
```

## Monitoring

```bash
# Prometheus
kubectl port-forward -n potatostack-monitoring svc/prometheus-operated 9090:9090

# Grafana
kubectl port-forward -n potatostack-monitoring svc/grafana 3000:3000

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Backup

```bash
# Postgres backup
kubectl exec -n potatostack statefulset/postgres -- pg_dumpall -U postgres > backup.sql

# Restore
cat backup.sql | kubectl exec -i -n potatostack statefulset/postgres -- psql -U postgres

# Full cluster backup (requires Velero)
velero backup create potatostack-$(date +%Y%m%d)
```

## Troubleshooting

```bash
# Pod not starting
kubectl describe pod <pod-name> -n potatostack
kubectl logs <pod-name> -n potatostack

# Check events
kubectl get events -n potatostack --sort-by='.lastTimestamp'

# Ingress issues
kubectl describe ingress -n potatostack
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Certificate issues
kubectl get certificates -A
kubectl describe certificate <cert-name> -n potatostack
```

## Next Steps

1. **Customize secrets**: Edit `k8s/base/secrets/generated-secrets.yaml`
2. **Configure storage**: Set up PVs in `k8s/base/pvc/`
3. **Update Ingress domains**: Edit `k8s/base/ingress/main-ingress.yaml`
4. **Deploy**: `kubectl apply -k k8s/overlays/production`
5. **Set up GitOps**: Configure ArgoCD with your Git repo
6. **Enable monitoring**: Import Grafana dashboards
7. **Configure backups**: Set up Velero or CronJobs

## Migration from Docker Compose

See `k8s/MIGRATION.md` for detailed migration guide.

Quick steps:
1. Backup Docker volumes
2. Deploy Kubernetes
3. Restore data to PVCs
4. Update DNS
5. Verify services
6. Decommission Docker

## Documentation

- **Full Guide**: `k8s/README.md`
- **Migration**: `k8s/MIGRATION.md`
- **Features**: `k8s/FEATURES.md`
- **This File**: `KUBERNETES-QUICKSTART.md`

## Support

GitHub: https://github.com/YOUR_USERNAME/vllm-windows
Issues: Report bugs via GitHub Issues
