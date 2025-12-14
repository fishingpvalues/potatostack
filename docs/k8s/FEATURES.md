# 2025 SOTA Kubernetes Features

This Kubernetes deployment includes cutting-edge tools and best practices for production workloads.

## Core Features

### 🔐 Secret Management
- **kubernetes-secret-generator**: Auto-generates secure passwords and tokens
- **kubernetes-replicator**: Replicates secrets across namespaces
- **Annotations-based**: No manual secret creation needed
```yaml
annotations:
  secret-generator.v1.mittwald.de/autogenerate: password
  replicator.v1.mittwald.de/replicate-to: "namespace1,namespace2"
```

### 🔒 Security

#### Pod Security Standards
- **Baseline** enforcement on main namespace
- **Restricted** warnings for security-sensitive pods
- **Privileged** only for VPN namespace (required for NET_ADMIN)

#### seccomp Profiles
All pods use `RuntimeDefault` seccomp profile:
```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

#### Network Policies
- Default deny all ingress
- Explicit allowlist for service communication
- Namespace isolation
- Prometheus scraping exceptions

#### Capabilities
All containers drop ALL capabilities and only add what's needed:
```yaml
securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_ADMIN]  # Only for VPN
```

### 📦 Storage

#### StatefulSets for Stateful Services
- PostgreSQL with ordered deployment
- Redis with persistent cache (optional)
- Loki for log retention

#### Persistent Volume Claims
- Automatic provisioning
- Storage classes for SSD vs HDD
- Volume expansion enabled

### 🌐 Ingress & SSL

#### NGINX Ingress Controller
- Layer 7 load balancing
- WebSocket support
- Client certificate auth

#### cert-manager
- Automatic SSL certificate provisioning
- Let's Encrypt integration (staging + prod)
- Certificate renewal
- Per-service TLS secrets

Example:
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
tls:
  - hosts: ["git.lepotato.local"]
    secretName: gitea-tls
```

### 📊 Monitoring (Prometheus Operator)

#### Prometheus
- ServiceMonitor CRDs for auto-discovery
- PodMonitor for pod-level metrics
- PrometheusRule for alerts
- Remote write support

#### Grafana
- OAuth2 via Authelia
- Pre-provisioned datasources
- Dashboard as code

#### Loki Stack
- Log aggregation
- LogQL queries
- Retention policies
- Multi-tenancy ready

#### Promtail
- DaemonSet on all nodes
- Automatic pod log discovery
- Kubernetes metadata labels

### 🔄 GitOps (ArgoCD)

#### Features
- Declarative continuous deployment
- Auto-sync with Git repository
- Self-healing
- Rollback capabilities
- Multi-environment support

#### Application of Applications Pattern
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

#### Notifications
- Slack/Discord/Email alerts
- Deployment status
- Health degradation warnings

### 📋 Policy Management (Kyverno)

#### Policy Engine
- Kubernetes-native (no webhooks)
- Validate, mutate, generate resources
- Audit and enforce modes

#### Included Policies
1. **Pod Security**: Require seccomp, drop capabilities
2. **Labels**: Enforce app/version labels
3. **Image Tags**: Disallow :latest
4. **Network Policies**: Auto-generate default-deny

Example policy:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-pod-security-standards
spec:
  validationFailureAction: Enforce
  rules:
  - name: check-seccomp
    validate:
      pattern:
        spec:
          securityContext:
            seccompProfile:
              type: "RuntimeDefault"
```

### 🎯 Configuration Management (Kustomize)

#### Base + Overlays Pattern
```
k8s/
├── base/              # Common configs
└── overlays/
    └── production/    # Environment-specific
```

#### Features
- Built into kubectl
- Strategic merge patches
- ConfigMap/Secret generators
- Image tag management
- Resource limits per environment

Example:
```yaml
# overlays/production/kustomization.yaml
bases: [../../base]
images:
  - name: gitea/gitea
    newTag: 1.21.5  # Pinned version
```

### 🔧 Advanced Kubernetes Features

#### HPA (Horizontal Pod Autoscaling)
Scale based on CPU/memory:
```bash
kubectl autoscale deployment gitea --cpu-percent=80 --min=1 --max=3
```

#### PodDisruptionBudgets
Ensure availability during updates:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: gitea-pdb
spec:
  minAvailable: 1
```

#### ResourceQuotas
Limit namespace resources:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: potatostack-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 2Gi
    persistentvolumeclaims: "10"
```

#### LimitRanges
Default pod limits:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

### 🚀 Deployment Strategies

#### Rolling Updates
Zero-downtime deployments:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

#### Canary Deployments
Using Argo Rollouts (optional):
```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 1h}
    - setWeight: 50
    - pause: {duration: 1h}
```

### 📡 Service Mesh (Optional)

#### Linkerd
Lightweight service mesh for ARM64:
```bash
linkerd install | kubectl apply -f -
linkerd inject deployment.yaml | kubectl apply -f -
```

Features:
- mTLS between services
- Traffic splitting
- Metrics and tracing
- Circuit breaking

### 🔍 Observability

#### Distributed Tracing
OpenTelemetry integration:
```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://jaeger:4317
```

#### Metrics
- Prometheus for metrics collection
- ServiceMonitors for auto-discovery
- Custom metrics via exporters

#### Logs
- Loki for aggregation
- Structured logging (JSON)
- Log retention policies

#### Dashboards
- Grafana for visualization
- Pre-built dashboards
- Custom queries

### 💾 Backup & Disaster Recovery

#### Velero
Kubernetes backup solution:
```bash
velero backup create potatostack-backup --include-namespaces potatostack
velero restore create --from-backup potatostack-backup
```

#### Database Backups
CronJob for automated backups:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:14
            command: ["/bin/sh", "-c"]
            args: ["pg_dumpall > /backup/backup.sql"]
```

### 🔄 Continuous Integration

#### GitHub Actions
```yaml
name: Deploy to Kubernetes
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Deploy
      run: kubectl apply -k k8s/overlays/production
```

#### ArgoCD Image Updater
Auto-update images:
```yaml
annotations:
  argocd-image-updater.argoproj.io/image-list: gitea=gitea/gitea
  argocd-image-updater.argoproj.io/gitea.update-strategy: semver
```

## Why These Tools?

| Tool | Why SOTA (2025) |
|------|-----------------|
| **Kustomize** | Built into kubectl, GitOps-friendly, no templating |
| **cert-manager** | Industry standard for K8s SSL, LetsEncrypt native |
| **Prometheus Operator** | K8s-native monitoring, ServiceMonitors |
| **ArgoCD** | #1 GitOps tool, CNCF graduated |
| **Kyverno** | K8s-native policies, no webhooks, easy to write |
| **Linkerd** | Lightest service mesh, ARM64 support |
| **secret-generator** | Automatic secret generation, no manual work |
| **replicator** | Multi-namespace secret sync, essential for DRY |

## Next Steps

1. **Enable HPA** for auto-scaling
2. **Add Velero** for backups
3. **Deploy Linkerd** for service mesh
4. **Configure OpenTelemetry** for tracing
5. **Set up CI/CD** with GitHub Actions + ArgoCD Image Updater
