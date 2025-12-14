# PotatoStack - Production Enhancements Guide (SOTA 2025)

All optional production-grade enhancements for PotatoStack Kubernetes cluster.

## Quick Install

```bash
# Install all enhancements at once
make helm-install-enhancements

# Or install individually (see below)
```

---

## 1. Renovate - Automated Dependency Updates

**Status**: ✅ Configured (renovate.json)
**Type**: GitHub App / GitOps Bot
**Purpose**: Automatically create PRs for image and Helm chart updates

### Setup

```bash
# Configuration already exists
make renovate-setup

# Manual setup:
# 1. Install GitHub App: https://github.com/apps/renovate
# 2. Enable for your repository
# 3. Renovate will use renovate.json automatically
```

### Features

- 📅 Runs every weekend
- 🔄 Auto-merges patch updates for stable images
- 📦 Groups monitoring stack updates
- ⏰ Stability period: 3 days before updates
- 🔒 Security vulnerability alerts
- 🎯 ARM64 compatibility checks

### Configuration

Edit `renovate.json` to customize:
- Schedule: `"schedule": ["every weekend"]`
- Auto-merge: `"automerge": true/false`
- Grouping: `"groupName": "monitoring-stack"`

---

## 2. Velero - Kubernetes Backup & Restore

**Chart**: vmware-tanzu/velero
**Namespace**: velero
**Purpose**: Full cluster backups (resources + volumes)

### Prerequisites

1. **Storage backend** (choose one):
   - AWS S3
   - MinIO (self-hosted S3-compatible)
   - Azure Blob Storage
   - Google Cloud Storage
   - Local NFS mount

2. **Create credentials**:

```bash
# For AWS/MinIO/S3-compatible
cat > credentials-velero <<EOF
[default]
aws_access_key_id=<YOUR_ACCESS_KEY>
aws_secret_access_key=<YOUR_SECRET_KEY>
EOF

kubectl create secret generic velero-credentials \
  -n velero --from-file=cloud=credentials-velero
rm credentials-velero
```

### Install

```bash
make helm-install-velero
```

### Usage

```bash
# List backups
velero backup get

# Create manual backup
velero backup create potatostack-manual \
  --include-namespaces potatostack,potatostack-monitoring

# Restore from backup
velero restore create --from-backup potatostack-manual

# Schedule backups (already configured via Helm)
# - Daily: 2 AM, retention 30 days
# - Weekly: 3 AM Sunday, retention 90 days

# Check schedules
velero schedule get
```

### Configuration

Edit `helm/values/velero.yaml`:
- Storage location
- Backup schedules
- Retention policies
- Resource limits

---

## 3. Sealed Secrets - Encrypt Secrets for Git

**Chart**: sealed-secrets/sealed-secrets
**Namespace**: kube-system
**Purpose**: Safely commit encrypted secrets to Git

### Install

```bash
make helm-install-sealed-secrets

# Install kubeseal CLI (one-time)
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-arm64 -O kubeseal
chmod +x kubeseal
sudo mv kubeseal /usr/local/bin/
```

### Usage

```bash
# Create a regular secret (DON'T commit this!)
kubectl create secret generic mysecret \
  --from-literal=password=secretpassword \
  --dry-run=client -o yaml > mysecret.yaml

# Seal the secret (safe to commit)
kubeseal --format=yaml < mysecret.yaml > mysealedsecret.yaml

# Commit the sealed secret to Git
git add mysealedsecret.yaml
git commit -m "Add sealed secret"

# Apply to cluster (controller will decrypt automatically)
kubectl apply -f mysealedsecret.yaml

# The real Secret will be created automatically
kubectl get secret mysecret
```

### Example

```yaml
# mysealedsecret.yaml (SAFE to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mysecret
  namespace: potatostack
spec:
  encryptedData:
    password: AgBx8F7q3... (encrypted)
```

### Backup Keys

```bash
# Backup sealing keys (CRITICAL - store securely!)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Store encrypted in password manager or encrypted storage
# DO NOT commit this to Git!
```

---

## 4. external-dns - Automatic DNS Management

**Chart**: external-dns/external-dns
**Namespace**: external-dns
**Purpose**: Auto-create DNS records for Ingress/Service resources

### Supported Providers

- Cloudflare (recommended)
- AWS Route53
- Google Cloud DNS
- Azure DNS
- CoreDNS (local)

### Prerequisites (Cloudflare example)

```bash
# Create API token at: https://dash.cloudflare.com/profile/api-tokens
# Permissions: Zone - DNS - Edit

kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=<YOUR_CLOUDFLARE_API_TOKEN> \
  -n external-dns
```

### Install

```bash
# Edit helm/values/external-dns.yaml first:
# - Set provider (cloudflare, aws, etc.)
# - Set domainFilters (your domains)

make helm-install-external-dns
```

### Configuration

Edit `helm/values/external-dns.yaml`:

```yaml
provider: cloudflare

domainFilters:
  - example.com
  - example.org

policy: upsert-only  # Don't delete records
```

### Usage

external-dns automatically watches Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.example.com
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

DNS record `myapp.example.com` will be created automatically!

### Verify

```bash
# Check logs
kubectl logs -f -n external-dns deployment/external-dns

# Check created records
kubectl logs -n external-dns deployment/external-dns | grep "CREATE"
```

---

## 5. Metrics Server - Resource Metrics for HPA

**Chart**: metrics-server/metrics-server
**Namespace**: kube-system
**Purpose**: Collect CPU/memory metrics for Horizontal Pod Autoscaler

### Install

```bash
make helm-install-metrics-server

# Verify
kubectl top nodes
kubectl top pods -n potatostack
```

### Apply HPA (Horizontal Pod Autoscaler)

```bash
# Apply pre-configured HPAs
make k8s-apply-hpa

# Check status
kubectl get hpa -n potatostack
```

### Pre-configured HPAs

**Gitea**:
- Min replicas: 1
- Max replicas: 3
- Scale up: CPU > 70%, Memory > 80%

**Vaultwarden**:
- Min replicas: 1
- Max replicas: 2
- Scale up: CPU > 75%, Memory > 85%

### Create Custom HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: potatostack
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Verify Autoscaling

```bash
# Watch HPA
kubectl get hpa -n potatostack -w

# Generate load (for testing)
kubectl run -it --rm load-generator --image=busybox -- /bin/sh
# Inside pod: while true; do wget -q -O- http://myapp; done
```

---

## 6. Kubernetes Dashboard - Web UI

**Chart**: kubernetes-dashboard/kubernetes-dashboard
**Namespace**: kubernetes-dashboard
**Purpose**: Visual cluster management interface

### Install

```bash
make helm-install-dashboard
```

### Create Admin User

```bash
# Create service account
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard

# Grant cluster-admin role
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get access token
kubectl create token dashboard-admin -n kubernetes-dashboard --duration=24h
```

### Access

```bash
# Port forward
make k8s-port-forward-dashboard

# Open browser: https://localhost:8443
# Login with token from above
```

### Features

- 📊 Resource overview (pods, services, deployments)
- 📈 Resource usage graphs
- 📝 Pod logs viewer
- 🔧 Edit resources (YAML)
- ⚙️ Cluster configuration
- 🔍 Search and filter

### Security

Dashboard has read-only role by default. For admin access, use the service account token created above.

---

## 7. Tempo - Distributed Tracing

**Chart**: grafana/tempo
**Namespace**: potatostack-monitoring
**Purpose**: Trace requests across microservices

### Install

```bash
make helm-install-tempo
```

### Configure Grafana Datasource

```bash
# Access Grafana
make k8s-port-forward-grafana

# Add Tempo datasource:
# 1. Settings > Data Sources > Add data source
# 2. Select "Tempo"
# 3. URL: http://tempo.potatostack-monitoring.svc.cluster.local:3100
# 4. Save & Test
```

### Instrument Applications

Add OpenTelemetry SDK to your apps:

**Python example**:
```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Export to Tempo
otlp_exporter = OTLPSpanExporter(
    endpoint="http://tempo.potatostack-monitoring.svc.cluster.local:4317",
    insecure=True
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Create spans
with tracer.start_as_current_span("my-operation"):
    # Your code here
    pass
```

### View Traces in Grafana

1. Explore > Select Tempo datasource
2. Query by Trace ID or search
3. Visualize request flow

### Supported Protocols

- **OpenTelemetry** (OTLP): gRPC (4317), HTTP (4318)
- **Jaeger**: gRPC (14250), HTTP (14268)
- **Zipkin**: HTTP (9411)

---

## Resource Usage Summary (Le Potato 2GB RAM)

| Enhancement | Memory | CPU | Storage |
|-------------|--------|-----|---------|
| Renovate | 0 (GitHub App) | 0 | 0 |
| Velero | 128-256Mi | 100-500m | 5Gi |
| Sealed Secrets | 64-128Mi | 50-200m | 0 |
| external-dns | 64Mi | 50-200m | 0 |
| Metrics Server | 64Mi | 50-200m | 0 |
| Dashboard | 128-256Mi | 100-500m | 0 |
| Tempo | 128-256Mi | 100-500m | 5Gi |
| **Total** | **~600-1100Mi** | **~500m-2000m** | **10Gi** |

**Note**: These enhancements are OPTIONAL. Install only what you need. For Le Potato with 2GB RAM, consider:
- Essential: Renovate, Metrics Server
- Recommended: Sealed Secrets, Dashboard
- Optional: Velero, external-dns, Tempo

---

## Troubleshooting

### Velero backup fails

```bash
# Check logs
kubectl logs -n velero deployment/velero

# Verify credentials
kubectl get secret -n velero velero-credentials

# Test S3 connection
kubectl run -it --rm aws-cli --image=amazon/aws-cli -- s3 ls s3://potatostack-backups
```

### Sealed Secrets not decrypting

```bash
# Check controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Verify controller is running
kubectl get pods -n kube-system | grep sealed-secrets

# Re-create sealed secret
kubeseal --format=yaml < secret.yaml > sealed.yaml
```

### external-dns not creating records

```bash
# Check logs
kubectl logs -f -n external-dns deployment/external-dns

# Verify credentials
kubectl get secret -n external-dns cloudflare-api-token

# Check Ingress annotations
kubectl get ingress -A -o yaml | grep external-dns
```

### HPA not scaling

```bash
# Check metrics-server
kubectl top nodes
kubectl top pods -n potatostack

# Check HPA status
kubectl describe hpa <hpa-name> -n potatostack

# Verify resource requests are set
kubectl get deployment <deployment-name> -n potatostack -o yaml | grep -A5 resources
```

### Dashboard access denied

```bash
# Verify service account
kubectl get sa dashboard-admin -n kubernetes-dashboard

# Verify role binding
kubectl get clusterrolebinding dashboard-admin

# Create new token
kubectl create token dashboard-admin -n kubernetes-dashboard --duration=24h
```

---

## Next Steps

After installing enhancements:

1. ✅ **Set up Renovate** - Enable GitHub App for automated updates
2. ✅ **Configure Velero backups** - Test backup/restore workflow
3. ✅ **Seal sensitive secrets** - Move all secrets to Sealed Secrets
4. ✅ **Configure DNS provider** - Auto-manage DNS records
5. ✅ **Monitor HPA** - Ensure autoscaling works under load
6. ✅ **Access Dashboard** - Bookmark for cluster management
7. ✅ **Instrument apps** - Add tracing to custom applications

---

## Uninstall

```bash
# Uninstall individual enhancements
helm uninstall velero -n velero
helm uninstall sealed-secrets -n kube-system
helm uninstall external-dns -n external-dns
helm uninstall metrics-server -n kube-system
helm uninstall kubernetes-dashboard -n kubernetes-dashboard
helm uninstall tempo -n potatostack-monitoring

# Remove HPAs
kubectl delete -f k8s/base/hpa/

# Clean up namespaces
kubectl delete namespace velero external-dns kubernetes-dashboard
```

---

**Generated**: 2025-12-14
**PotatoStack Version**: SOTA 2025 Kubernetes
