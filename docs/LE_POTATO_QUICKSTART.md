# Le Potato SOTA 2025 Kubernetes Stack - Quickstart Guide

**Last Updated**: December 2025
**Stack Version**: 2.1 (SOTA 2025)
**Target Hardware**: Le Potato (AML-S905X-CC) - 2GB RAM, ARM64

## What You Get

A production-ready Kubernetes stack optimized for Le Potato with:

- ✅ **k3s** - Lightweight Kubernetes (certified, ARM64 optimized)
- ✅ **ArgoCD** - GitOps continuous deployment
- ✅ **Prometheus + Grafana + Loki** - Complete observability
- ✅ **cert-manager** - Automatic SSL certificates
- ✅ **Kyverno** - Policy engine & security
- ✅ **Gateway API** - Modern traffic routing (SOTA 2025)
- ✅ **Sealed Secrets** - GitOps-friendly secrets
- ✅ **Metrics Server** - Horizontal Pod Autoscaling
- ✅ **Cilium Hubble** (optional) - eBPF network observability
- ✅ All apps: Gitea, Vaultwarden, Immich, Seafile, Kopia, etc.

**Total RAM usage**: ~1.4-1.6GB under normal load (requires 2GB swap)

---

## Prerequisites

### Hardware
- Le Potato (AML-S905X-CC) or compatible ARM64 SBC
- 2GB RAM minimum
- microSD card (16GB+) for OS
- 2x HDDs:
  - Main storage (14TB in reference setup)
  - Cache storage (500GB in reference setup)
- Power supply (5V 2A minimum)

### Software
- **OS**: Armbian (Debian/Ubuntu based) or Ubuntu Server 22.04+ ARM64
- **Kernel**: 5.10+ (for eBPF support)
- **Internet connection** during setup

---

## One-Command Install

```bash
# 1. Clone repository
git clone <your-repo-url> ~/potatostack
cd ~/potatostack

# 2. Verify compatibility
make verify-le-potato

# 3. Install k3s with optimizations
make k3s-install-optimized

# 4. Deploy complete SOTA 2025 stack
make sota-stack-deploy

# 5. Check status
make k8s-status
```

Done! 🎉

---

## Step-by-Step Installation

### 1. Prepare the System

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl git make

# Mount HDDs (adjust device names)
sudo mkdir -p /mnt/seconddrive /mnt/cachehdd

# Find UUIDs
sudo blkid

# Add to /etc/fstab (replace UUIDs)
# UUID=xxx-xxx /mnt/seconddrive ext4 defaults 0 2
# UUID=yyy-yyy /mnt/cachehdd ext4 defaults 0 2

sudo mount -a
```

### 2. Configure Swap (Critical for 2GB RAM!)

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make persistent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Set swappiness (prefer RAM, use swap as last resort)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 3. Install k3s (Optimized)

```bash
cd ~/potatostack

# Install k3s with Le Potato optimizations
make k3s-install-optimized

# Verify installation
kubectl get nodes
# Should show: Ready
```

**What this does**:
- Installs k3s v1.31+ (latest stable)
- Disables Traefik (using ingress-nginx instead)
- Configures aggressive memory limits
- Enables secrets encryption at rest
- Sets max 50 pods per node
- Optimizes for ARM64

### 4. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### 5. Add Helm Repositories

```bash
make helm-repos

# This adds:
# - prometheus-community
# - grafana
# - argo (ArgoCD)
# - ingress-nginx
# - kyverno
# - bitnami
# - And more...
```

### 6. Deploy the Stack

```bash
# Full SOTA 2025 deployment
make sota-stack-deploy

# This installs:
# 1. cert-manager, ingress-nginx, kyverno (operators)
# 2. Prometheus, Grafana, Loki (monitoring)
# 3. ArgoCD (GitOps)
# 4. Redis, PostgreSQL (datastores)
# 5. All applications (Gitea, Vaultwarden, etc.)
# 6. Gateway API CRDs
```

**Wait ~5-10 minutes** for all pods to start.

### 7. Verify Deployment

```bash
# Check all resources
make k8s-status

# Watch pods come up
watch kubectl get pods -A

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

---

## Accessing Services

### Port Forwarding (Quick Access)

```bash
# Grafana (monitoring)
make k8s-port-forward-grafana
# Open: http://localhost:3000
# Default: admin / (from .env GRAFANA_PASSWORD)

# ArgoCD (GitOps)
make k8s-port-forward-argocd
# Open: http://localhost:8080
# User: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Prometheus
make k8s-port-forward-prometheus
# Open: http://localhost:9090
```

### Ingress (Production Access)

Configure `/etc/hosts` on your client machine:

```bash
# Get ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Add to /etc/hosts (replace <INGRESS_IP>)
<INGRESS_IP> grafana.lepotato.local
<INGRESS_IP> argocd.lepotato.local
<INGRESS_IP> gitea.lepotato.local
<INGRESS_IP> vault.lepotato.local
<INGRESS_IP> photos.lepotato.local
```

Or configure DNS (if using external-dns).

---

## Optional Enhancements (SOTA 2025)

### Gateway API (Modern Ingress)

```bash
# Install Gateway API CRDs
make install-gateway-api

# Deploy gateways
kubectl apply -f config/gateway-api.yaml

# Migrate from Ingress to HTTPRoutes over time
```

**Benefits**:
- Type-safe routing
- Better multi-tenancy
- More expressive rules
- Vendor-neutral

### eBPF Network Observability (Cilium Hubble)

```bash
# Install Cilium Hubble (observability mode)
make helm-install-cilium-hubble

# Access Hubble UI
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Open: http://localhost:12000

# View network flows
hubble observe
```

**Requirements**:
- Kernel 5.10+ with eBPF support
- ~128MB additional RAM

### Sealed Secrets (GitOps-Friendly)

```bash
# Install Sealed Secrets controller
make helm-install-sealed-secrets

# Download kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-arm64 -O kubeseal
chmod +x kubeseal
sudo mv kubeseal /usr/local/bin/

# Encrypt a secret
kubectl create secret generic my-secret --dry-run=client \
  --from-literal=password=supersecret -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to Git safely!
kubectl apply -f sealed-secret.yaml
```

### Metrics Server + HPA

```bash
# Install Metrics Server
make helm-install-metrics-server

# Verify
kubectl top nodes
kubectl top pods -A

# Apply HPAs
make k8s-apply-hpa

# Check autoscaling
kubectl get hpa -n potatostack
```

### Kubernetes Dashboard

```bash
# Install dashboard
make helm-install-dashboard

# Create admin user
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get token
kubectl create token dashboard-admin -n kubernetes-dashboard --duration=24h

# Access dashboard
make k8s-port-forward-dashboard
# Open: https://localhost:8443
```

---

## Resource Management

### Current Usage (Typical)

| Component | Memory | CPU | Notes |
|-----------|--------|-----|-------|
| k3s system | 200MB | 0.2 | Core Kubernetes |
| PostgreSQL | 192MB | 0.5 | Shared DB |
| Redis | 64MB | 0.1 | Shared cache |
| Prometheus | 192MB | 0.5 | Monitoring |
| Grafana | 128MB | 0.3 | Dashboards |
| ArgoCD | 512MB | 1.0 | GitOps |
| Applications | 400MB | 1.0 | Varies by load |
| **Total** | **~1.6GB** | **~3.6** | +swap |

### Monitoring Resources

```bash
# Real-time stats
watch kubectl top nodes
watch kubectl top pods -A

# Check OOM kills
dmesg | grep -i oom

# Check swap usage
free -h
```

### Scaling Down (If Needed)

```bash
# Disable optional services
kubectl scale deployment netdata -n potatostack-monitoring --replicas=0
kubectl scale deployment uptime-kuma -n potatostack --replicas=0

# Lower Prometheus retention
kubectl edit prometheus prometheus-kube-prometheus-prometheus -n potatostack-monitoring
# Change: retention: 3d → 1d
```

---

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient memory → scale down or add swap
# - PVC not bound → check storage class
# - Image pull errors → check ARM64 compatibility
```

### High Memory Usage

```bash
# Identify memory hogs
kubectl top pods -A --sort-by=memory

# Check node pressure
kubectl describe node

# Restart resource-heavy pods
kubectl rollout restart deployment <name> -n <namespace>
```

### Services Not Accessible

```bash
# Check ingress controller
kubectl get svc -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress resources
kubectl get ingress -A

# Test service directly
kubectl port-forward -n <namespace> svc/<service> 8080:80
```

### k3s Not Starting

```bash
# Check service status
sudo systemctl status k3s

# View logs
sudo journalctl -u k3s -f

# Check config
sudo cat /etc/rancher/k3s/config.yaml

# Restart k3s
sudo systemctl restart k3s
```

---

## Maintenance

### Weekly

```bash
# Check cluster health
make k8s-status

# View resource usage
kubectl top nodes
kubectl top pods -A

# Check for updates (via Renovate PRs)
```

### Monthly

```bash
# Update Helm charts
make helm-upgrade-all

# Backup Postgres
make k8s-backup

# Check disk usage
df -h /mnt/seconddrive
df -h /mnt/cachehdd

# Prune old images
kubectl exec -n kube-system <k3s-pod> -- crictl images prune
```

### Quarterly

```bash
# Update k3s
curl -sfL https://get.k3s.io | sh -

# Update OS
sudo apt update && sudo apt upgrade -y
sudo reboot
```

---

## Backup & Restore

### Backup

```bash
# Backup Postgres databases
make k8s-backup
# Creates: backup.sql

# Backup Helm releases
helm list -A > helm-releases.txt

# Backup configs
tar -czf potatostack-config-$(date +%F).tar.gz \
  helm/values/ k8s/ config/ .env
```

### Restore

```bash
# Restore Postgres
make k8s-restore

# Restore entire stack
make sota-stack-deploy
```

---

## Performance Tips

1. **Swap is mandatory** - Configure 2GB swap
2. **Limit concurrent operations** - Don't update all apps at once
3. **Schedule heavy tasks** - Run backups/updates during off-hours
4. **Use local storage** - Mount HDDs directly, avoid network storage
5. **Monitor swap usage** - If >1GB sustained, scale down services
6. **Disable unused exporters** - Reduce monitoring overhead
7. **Use node selectors** - Pin heavy workloads to specific nodes (multi-node)

---

## Next Steps

1. ✅ Configure Grafana dashboards
2. ✅ Set up Alertmanager notifications
3. ✅ Configure Gitea repositories
4. ✅ Import photos to Immich
5. ✅ Set up Kopia backups
6. ✅ Configure Authelia SSO
7. ✅ Enable ArgoCD apps

---

## References

- [k3s Documentation](https://docs.k3s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kyverno Policies](https://kyverno.io/policies/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Cilium Hubble](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

---

**Built for Le Potato 🥔 | Kubernetes SOTA 2025 🚀**
