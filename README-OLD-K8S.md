# PotatoStack 🥔

**Enterprise-grade self-hosted stack optimized for Le Potato (2GB RAM)**

Production-ready Kubernetes stack with comprehensive monitoring, security, and automation - all running on ARM64 SBC with minimal resources.

## 🎯 Design Goals

- **Low Resource**: Optimized for Le Potato (2GB RAM, ARM64)
- **Production Ready**: Enterprise-grade reliability and security
- **SOTA 2025**: Modern Kubernetes stack (k3s, Gateway API, Kyverno)
- **Fully Tested**: Comprehensive test suite with CI/CD
- **GitOps Ready**: Declarative infrastructure as code

## 📊 Resource Usage

- **Core Stack**: ~1.6GB RAM
- **With Extras**: ~1.73GB RAM
- **Free Buffer**: 270MB
- **Services**: 26 essential services

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Install k3s with optimizations
make k3s-install-optimized

# 2. Verify Le Potato compatibility
make verify-le-potato

# 3. Deploy complete stack
make sota-stack-deploy

# 4. Run tests
make test-all
```

## 📦 What's Included

### Core Infrastructure (SOTA 2025)
- **k3s** - Lightweight Kubernetes
- **cert-manager** - Automatic SSL certificates
- **ingress-nginx** - Traffic routing
- **Kyverno** - Policy engine
- **Gateway API** - Modern traffic management

### Monitoring & Observability
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards
- **Loki** - Log aggregation
- **Blackbox Exporter** - Endpoint monitoring
- **Speedtest Exporter** - Network monitoring
- **SMART CTL Exporter** - Disk health

### Applications
- **Vaultwarden** - Password manager
- **Immich** - Photo management
- **Seafile** - File sync & share
- **Kopia** - Encrypted backups
- **Gitea** - Git hosting
- **Jellyfin** - Media server
- **Paperless-ngx** - Document management
- **Stirling PDF** - PDF tools

### Productivity Tools
- **Miniflux** - RSS reader (30MB)
- **linkding** - Bookmark manager (40MB)
- **Radicale** - CalDAV/CardDAV (20MB)
- **Syncthing** - P2P file sync (40MB)

### Security & Utilities
- **Authelia** - SSO authentication
- **Uptime Kuma** - Uptime monitoring
- **Homepage** - Dashboard
- **Rustypaste** - Pastebin
- **Gluetun** - VPN client (optional)

## 🧪 Testing (Enterprise Grade)

### Test Suite
```bash
make test-unit          # Resource limits, YAML, shellcheck
make test-integration   # K8s deployment validation
make test-e2e           # Smoke tests
make test-all           # Complete suite
make lint               # Code quality
```

### CI/CD Pipeline
- **GitHub Actions** - Automated testing on every push
- **Security Scanning** - Trivy vulnerability detection
- **Pre-commit Hooks** - Local validation

## 📁 Project Structure

```
potatostack/
├── helm/values/         # Helm chart values (26 services)
├── k8s/
│   ├── base/           # Base Kubernetes manifests
│   │   ├── policies/   # ResourceQuota, LimitRange
│   │   ├── monitoring/ # ServiceMonitors
│   │   └── configmaps/ # Configuration
│   └── overlays/       # Environment-specific configs
├── config/
│   ├── k3s-server.yaml      # k3s configuration
│   └── gateway-api.yaml     # Gateway API resources
├── scripts/
│   ├── verify-le-potato-sota.sh  # Validation script
│   └── cluster-setup.sh          # Automated setup
├── tests/
│   ├── unit/           # Unit tests
│   ├── integration/    # Integration tests
│   └── e2e/            # End-to-end tests
└── .github/workflows/  # CI/CD pipelines
```

## 🛠️ Common Tasks

### Deployment
```bash
make helm-repos                    # Add Helm repositories
make helm-install-operators        # Install core operators
make helm-install-monitoring       # Install monitoring stack
make helm-install-datastores       # Install PostgreSQL, Redis
make helm-install-apps             # Install applications
make helm-install-missing-tools    # Install productivity tools
```

### Management
```bash
make k8s-status          # View cluster status
make k8s-logs            # Follow logs
make k8s-backup          # Backup PostgreSQL
make k8s-restore         # Restore from backup
make helm-list           # List installed releases
```

### Monitoring
```bash
make k8s-port-forward-grafana      # Access Grafana (localhost:3000)
make k8s-port-forward-prometheus   # Access Prometheus (localhost:9090)
```

## 🔒 Production Hardening

### Resource Management
- **ResourceQuota**: Namespace-level limits (1.8GB RAM)
- **LimitRange**: Container defaults and limits
- **HPA**: Horizontal Pod Autoscaling (optional)

### Security
- **Network Policies**: Traffic segmentation
- **Kyverno Policies**: Enforcement and validation
- **Authelia SSO**: Centralized authentication
- **TLS**: Automatic SSL via cert-manager

### Monitoring
- **Prometheus Alerts**: Critical service monitoring
- **Grafana Dashboards**: Pre-configured visualizations
- **Loki**: Centralized logging
- **Uptime Kuma**: Endpoint monitoring

## 📖 Documentation

- [Le Potato Quickstart](docs/LE_POTATO_QUICKSTART.md) - Detailed deployment guide
- [Test Suite](tests/README.md) - Testing documentation
- [Missing Tools](docs/MISSING_TOOLS_RECOMMENDATIONS.md) - Optional additions
- [Comparison](docs/AWESOME_SELFHOSTED_COMPARISON.md) - vs awesome-selfhosted

## 🔧 Requirements

### Hardware
- **Le Potato** (AML-S905X-CC) or similar ARM64 SBC
- **RAM**: 2GB minimum
- **Storage**: 64GB+ microSD/eMMC
- **Network**: Ethernet recommended

### Software
- **k3s** (installed via Makefile)
- **Helm** 3.x
- **kubectl**
- **Git**

### Optional
- **yq** - YAML processing (for tests)
- **shellcheck** - Shell linting (for tests)
- **pre-commit** - Git hooks

## 🎓 Architecture Decisions

### Why k3s?
- Lightweight (< 512MB RAM)
- ARM64 optimized
- Production-grade Kubernetes
- Minimal dependencies

### Why Not Include?
**Removed (too heavy for 2GB)**:
- ArgoCD → Use kubectl apply
- Portainer → Use kubectl/k9s
- Netdata → Use Prometheus
- Tempo → Tracing overkill
- Velero → Use Kopia

### Resource Philosophy
- Aggressive memory limits
- CPU throttling over OOM
- Shared datastores (PostgreSQL, Redis)
- Minimal replicas (usually 1)

## 🤝 Contributing

### Development Workflow
1. Fork and clone
2. Install pre-commit: `pre-commit install`
3. Make changes
4. Run tests: `make test-all`
5. Commit and push
6. Open pull request

### Code Quality
- All shell scripts must pass `shellcheck`
- All YAML must be valid
- Resource limits required for new services
- Tests required for new features

## 📊 Monitoring & Alerting

### Access Dashboards
```bash
# Grafana (user: admin, password: from secret)
make k8s-port-forward-grafana

# Prometheus
make k8s-port-forward-prometheus

# Uptime Kuma
kubectl port-forward -n potatostack svc/uptime-kuma 3001:3001
```

### Pre-configured Dashboards
- Node metrics (CPU, RAM, disk)
- Pod resource usage
- Network statistics
- Application-specific metrics

## 🚨 Troubleshooting

### Out of Memory
```bash
# Check memory usage
kubectl top nodes
kubectl top pods -A

# Review resource limits
make test-unit
```

### Pod Crashes
```bash
# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# View logs
kubectl logs -n potatostack <pod-name>

# Describe pod
kubectl describe pod -n potatostack <pod-name>
```

### Tests Failing
```bash
# Run verbose tests
./tests/unit/test_resource_limits.sh
./tests/integration/test_k8s_deploy.sh

# Check CI logs
# Visit: https://github.com/[user]/potatostack/actions
```

## 📝 License

MIT License - See LICENSE file

## 🙏 Credits

Built with:
- [k3s](https://k3s.io/) - Lightweight Kubernetes
- [Helm](https://helm.sh/) - Package manager
- [bjw-s app-template](https://github.com/bjw-s/helm-charts) - Helm charts
- [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) - Inspiration

---

**Made with ❤️ for Le Potato by the PotatoStack community**
