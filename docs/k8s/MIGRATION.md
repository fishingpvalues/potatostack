# Docker Compose to Kubernetes Migration Guide

## Pre-Migration Checklist

- [ ] Backup all Docker volumes
- [ ] Document current service URLs and ports
- [ ] Export environment variables from `.env`
- [ ] Test Kubernetes cluster (k3s)
- [ ] Install required operators (cert-manager, ingress, prometheus)

## Migration Steps

### 1. Data Backup (Critical)

```bash
# Stop Docker Compose services
docker compose down

# Backup Postgres
docker compose up -d postgres
docker exec postgres pg_dumpall -U postgres > postgres_backup.sql
docker compose down postgres

# Backup volumes
tar -czf volumes_backup.tar.gz /mnt/seconddrive /mnt/cachehdd

# Backup configs
tar -czf config_backup.tar.gz config/
```

### 2. Prepare Kubernetes Cluster

```bash
# Install k3s (if not already)
curl -sfL https://get.k3s.io | sh -

# Verify cluster
kubectl get nodes
kubectl cluster-info

# Install operators
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### 3. Create PersistentVolumes

Map Docker volumes to Kubernetes PVs:

```bash
# Create PV directories
mkdir -p /mnt/k8s-pvs/{postgres,redis,gitea,immich,qbittorrent,slskd}

# Apply PV manifests
kubectl apply -f k8s/base/pvc/
```

### 4. Migrate Secrets

```bash
# Convert .env to Kubernetes secrets
cat > /tmp/secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: surfshark-credentials
  namespace: potatostack-vpn
type: Opaque
stringData:
  SURFSHARK_USER: "$(grep SURFSHARK_USER .env | cut -d'=' -f2)"
  SURFSHARK_PASSWORD: "$(grep SURFSHARK_PASSWORD .env | cut -d'=' -f2)"
EOF

kubectl apply -f /tmp/secrets.yaml
rm /tmp/secrets.yaml

# Apply all secrets
kubectl apply -f k8s/base/secrets/
```

### 5. Restore Database

```bash
# Deploy Postgres StatefulSet
kubectl apply -k k8s/base/statefulsets/

# Wait for Postgres to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n potatostack --timeout=120s

# Restore data
cat postgres_backup.sql | kubectl exec -i -n potatostack statefulset/postgres -- psql -U postgres
```

### 6. Migrate Application Data

```bash
# Copy data to PVCs
kubectl cp /mnt/seconddrive/gitea potatostack/gitea-0:/data/gitea/repositories
kubectl cp /mnt/seconddrive/immich/upload potatostack/immich-server-0:/usr/src/app/upload
kubectl cp /mnt/cachehdd/torrents potatostack-vpn/gluetun-0:/downloads
```

### 7. Deploy Applications

```bash
# Deploy base stack
kubectl apply -k k8s/overlays/production

# Verify deployments
kubectl get deployments -n potatostack
kubectl get pods -n potatostack -w
```

### 8. Configure Ingress

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Update /etc/hosts or DNS
echo "$INGRESS_IP git.lepotato.local" | sudo tee -a /etc/hosts
echo "$INGRESS_IP photos.lepotato.local" | sudo tee -a /etc/hosts
echo "$INGRESS_IP vault.lepotato.local" | sudo tee -a /etc/hosts
```

### 9. Verify Services

Test each service:

```bash
# Gitea
curl -k https://git.lepotato.local

# Immich
curl -k https://photos.lepotato.local/api/server-info/ping

# Vaultwarden
curl -k https://vault.lepotato.local/alive

# Grafana
curl -k https://grafana.lepotato.local/api/health
```

### 10. Monitoring Setup

```bash
# Deploy monitoring stack
kubectl apply -f k8s/base/operators/prometheus-operator.yaml
kubectl apply -f k8s/base/deployments/grafana.yaml
kubectl apply -f k8s/base/statefulsets/loki.yaml

# Import Grafana dashboards
# (See monitoring documentation)
```

### 11. DNS Update

Update your DNS provider to point domains to Ingress IP:
- git.lepotato.local → INGRESS_IP
- photos.lepotato.local → INGRESS_IP
- etc.

### 12. Cleanup Docker

```bash
# Only after verifying Kubernetes is working!
docker compose down -v  # Remove containers and volumes
docker system prune -a  # Clean up images
```

## Service Mapping

| Docker Compose | Kubernetes |
|----------------|------------|
| postgres | StatefulSet in potatostack |
| redis | StatefulSet in potatostack |
| gluetun | Deployment in potatostack-vpn (with sidecars) |
| qbittorrent | Sidecar in gluetun pod |
| slskd | Sidecar in gluetun pod |
| gitea | Deployment in potatostack |
| immich-server | Deployment in potatostack |
| vaultwarden | Deployment in potatostack |
| prometheus | Prometheus CR in potatostack-monitoring |
| grafana | Deployment in potatostack-monitoring |
| loki | StatefulSet in potatostack-monitoring |

## Port Mapping

| Service | Docker Port | Kubernetes Access |
|---------|-------------|-------------------|
| Gitea | 3001 | https://git.lepotato.local |
| Immich | 2283 | https://photos.lepotato.local |
| Vaultwarden | 8084 | https://vault.lepotato.local |
| qBittorrent | 8080 | https://torrents.lepotato.local |
| Grafana | 3000 | https://grafana.lepotato.local |
| Prometheus | 9090 | https://prometheus.lepotato.local |

## Troubleshooting

### Pods Stuck in Pending
```bash
kubectl describe pod <pod-name> -n potatostack
# Check PVC binding, resource limits, node capacity
```

### Database Connection Errors
```bash
# Check Postgres is ready
kubectl get pods -n potatostack -l app=postgres

# Test connection
kubectl exec -it -n potatostack statefulset/postgres -- psql -U postgres -c '\l'
```

### Ingress Not Working
```bash
# Check Ingress controller
kubectl get pods -n ingress-nginx

# Check Ingress resources
kubectl get ingress -A

# Check cert-manager
kubectl get certificates -A
```

### High Memory Usage
```bash
# Check resource usage
kubectl top pods -n potatostack

# Adjust limits in overlays/production/resource-limits.yaml
```

## Rollback Plan

If migration fails:

1. Stop Kubernetes services:
   ```bash
   kubectl delete -k k8s/overlays/production
   ```

2. Restore Docker Compose:
   ```bash
   cd /path/to/vllm-windows
   tar -xzf volumes_backup.tar.gz -C /
   tar -xzf config_backup.tar.gz
   docker compose up -d
   ```

3. Restore database:
   ```bash
   cat postgres_backup.sql | docker exec -i postgres psql -U postgres
   ```

## Post-Migration

- [ ] Monitor resource usage for 24 hours
- [ ] Test all service functionality
- [ ] Update documentation with new URLs
- [ ] Configure automated backups
- [ ] Set up ArgoCD for GitOps
- [ ] Remove Docker Compose files (after 1 week of stable operation)
