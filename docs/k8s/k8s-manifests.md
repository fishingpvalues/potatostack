# PotatoStack - Kubernetes Deployment (2025 SOTA)

Modern Kubernetes deployment for Le Potato SBC with state-of-the-art tooling and best practices.

## Architecture

- **Kustomize**: Configuration management (built into kubectl)
- **Secret Management**: kubernetes-secret-generator + kubernetes-replicator
- **SSL/TLS**: cert-manager with Let's Encrypt
- **Ingress**: NGINX Ingress Controller
- **Monitoring**: Prometheus Operator + Grafana + Loki stack
- **GitOps**: ArgoCD for automated deployments
- **Security**: Network Policies, Pod Security Standards, seccomp profiles
- **Storage**: StatefulSets with PVC for databases

## Prerequisites

1. **Kubernetes cluster** (k3s recommended for ARM64):
```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

2. **kubectl** with kustomize (included in kubectl 1.14+)

3. **Helm** (for operators):
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Quick Start

### 1. Install Core Operators

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace potatostack-monitoring --create-namespace

# Install ArgoCD (optional, for GitOps)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Deploy Infrastructure Operators

```bash
# Deploy secret-generator and replicator
kubectl apply -f k8s/base/operators/secret-generator.yaml
kubectl apply -f k8s/base/operators/replicator.yaml
kubectl apply -f k8s/base/operators/cert-manager.yaml
```

### 3. Create Secrets

Edit and apply secrets (replace REPLACE_ME values):

```bash
kubectl apply -f k8s/base/secrets/generated-secrets.yaml
```

The secret-generator will auto-generate passwords for database credentials, JWT secrets, etc.

### 4. Deploy the Stack

**Option A: Direct kubectl**
```bash
kubectl apply -k k8s/overlays/production
```

**Option B: ArgoCD (GitOps)**
```bash
# Update repo URL in argocd/application.yaml first
kubectl apply -f k8s/argocd/application.yaml
```

### 5. Access Services

Get Ingress IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Add to /etc/hosts:
```
<INGRESS_IP> git.lepotato.local photos.lepotato.local vault.lepotato.local
<INGRESS_IP> grafana.lepotato.local prometheus.lepotato.local
<INGRESS_IP> torrents.lepotato.local soulseek.lepotato.local
```

Access:
- Gitea: https://git.lepotato.local
- Immich: https://photos.lepotato.local
- Vaultwarden: https://vault.lepotato.local
- Grafana: https://grafana.lepotato.local
- qBittorrent: https://torrents.lepotato.local
- slskd: https://soulseek.lepotato.local

## Components

### Storage (StatefulSets)
- PostgreSQL 14 with pgvecto-rs (for Gitea, Immich, Seafile)
- Redis 7 (for caching/sessions)
- Loki (log aggregation)

### Applications
- **Gitea**: Git server with Postgres + Redis
- **Immich**: Self-hosted Google Photos
- **Vaultwarden**: Bitwarden-compatible password manager
- **Seafile**: File sync and share
- **Gluetun**: VPN with qBittorrent + slskd sidecars

### Monitoring
- Prometheus Operator (metrics)
- Grafana (dashboards)
- Loki (logs)
- Promtail (log collector)
- Alertmanager (alerts)

### Security
- Network Policies (default deny + allowlist)
- Pod Security Standards (baseline/restricted)
- seccomp profiles
- Auto-generated secrets
- SSL/TLS with cert-manager

## Management

### View Pods
```bash
kubectl get pods -n potatostack
kubectl get pods -n potatostack-monitoring
kubectl get pods -n potatostack-vpn
```

### Check Logs
```bash
kubectl logs -n potatostack deployment/gitea
kubectl logs -n potatostack-monitoring statefulset/loki
```

### Scale Services
```bash
kubectl scale deployment/gitea -n potatostack --replicas=2
```

### Update Image
```bash
kubectl set image deployment/gitea gitea=gitea/gitea:1.22.0 -n potatostack
```

### View Secrets
```bash
kubectl get secrets -n potatostack
kubectl describe secret postgres-credentials -n potatostack
```

## Monitoring

### Prometheus
```bash
kubectl port-forward -n potatostack-monitoring svc/prometheus-operated 9090:9090
# Access: http://localhost:9090
```

### Grafana
```bash
kubectl port-forward -n potatostack-monitoring svc/grafana 3000:3000
# Access: http://localhost:3000
```

### ArgoCD UI
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Get password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Access: https://localhost:8080 (user: admin)
```

## Backup & Restore

### Backup Postgres
```bash
kubectl exec -n potatostack statefulset/postgres -- pg_dumpall -U postgres > backup.sql
```

### Restore Postgres
```bash
cat backup.sql | kubectl exec -i -n potatostack statefulset/postgres -- psql -U postgres
```

### Backup PVCs
Use Velero or custom backup scripts with snapshots.

## Troubleshooting

### Check Events
```bash
kubectl get events -n potatostack --sort-by='.lastTimestamp'
```

### Describe Pod
```bash
kubectl describe pod <pod-name> -n potatostack
```

### Shell into Pod
```bash
kubectl exec -it -n potatostack deployment/gitea -- sh
```

### Check Network Policies
```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy allow-postgres -n potatostack
```

### View Resource Usage
```bash
kubectl top pods -n potatostack
kubectl top nodes
```

## Customization

### Modify Resources
Edit `k8s/overlays/production/resource-limits.yaml`

### Change Storage Class
Edit `k8s/overlays/production/storage-class.yaml`

### Update Images
Edit `k8s/overlays/production/kustomization.yaml`

### Add Services
1. Create deployment in `k8s/base/deployments/`
2. Add to `k8s/base/kustomization.yaml`
3. Create Ingress in `k8s/base/ingress/`
4. Apply network policies

## Migration from Docker Compose

1. Export data from Docker volumes
2. Deploy Kubernetes stack
3. Create PVCs matching old volume paths
4. Restore data to PVCs
5. Update DNS/hosts to point to Ingress IP
6. Verify all services are healthy
7. Decommission Docker Compose stack

## Advanced Features

### Horizontal Pod Autoscaling (HPA)
```bash
kubectl autoscale deployment gitea -n potatostack --cpu-percent=80 --min=1 --max=3
```

### Pod Disruption Budgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: gitea-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: gitea
```

### Service Mesh (Optional)
Install Linkerd for advanced traffic management:
```bash
curl -sL https://run.linkerd.io/install | sh
linkerd install | kubectl apply -f -
```

## Performance Tuning

For 2GB RAM systems:
- Keep resource limits tight
- Use node affinity for critical services
- Enable swap on host (5GB on cache HDD)
- Monitor with Grafana dashboards
- Use PriorityClasses for critical pods

## Support

- GitHub Issues: https://github.com/YOUR_USERNAME/vllm-windows/issues
- Documentation: See individual service READMEs
- Community: Le Potato SBC forums
