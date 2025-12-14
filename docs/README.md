# PotatoStack Documentation

Complete documentation for PotatoStack SOTA 2025 Kubernetes deployment.

## 📁 Documentation Structure

### Core Documentation (Root)

Located in the root directory for quick access:

- **README.md** - Project overview and quick start
- **KUBERNETES-QUICKSTART.md** - Fast track to deploying the stack
- **MIGRATION-FINAL-REPORT.md** - Complete migration details from Docker to K8s
- **ENHANCEMENTS-GUIDE.md** - Production enhancements setup (Velero, Renovate, etc.)
- **ENHANCEMENTS-COMPLETE.md** - Enhancements summary
- **HELM-DEPLOYMENT.md** - Helm deployment details
- **README-ENHANCEMENTS.md** - Quick enhancements reference

### Kubernetes Documentation (docs/k8s/)

Kubernetes-specific documentation:

- **k8s-manifests.md** - Kubernetes manifests documentation
- **MIGRATION.md** - Docker to Kubernetes migration guide
- **FEATURES.md** - SOTA 2025 Kubernetes features
- **MITTWALD-INTEGRATION.md** - Mittwald operators integration

### Reference Documentation (docs/)

Detailed reference guides:

- **AUTHELIA_SSO.md** - Single Sign-On configuration
- **LE_POTATO_OPTIMIZATION.md** - Le Potato SBC optimizations
- **NETWORK_SECURITY.md** - Network security policies
- **SECURITY.md** - Security best practices

### Archive (docs/archive/)

Legacy documentation from Docker Compose era (kept for reference):

- **OPERATIONAL_RUNBOOK.md** - Docker Compose operations (legacy)
- **LE_POTATO_DEPLOYMENT.md** - Docker deployment guide (legacy)
- **SECRETS_MANAGEMENT.md** - Docker secrets management (legacy)

---

## 🚀 Quick Navigation

### New to PotatoStack?
1. Start with **README.md** (project overview)
2. Read **KUBERNETES-QUICKSTART.md** (deployment)
3. Check **MIGRATION-FINAL-REPORT.md** (architecture)

### Deploying the Stack?
1. **KUBERNETES-QUICKSTART.md** - Quick deployment guide
2. **HELM-DEPLOYMENT.md** - Helm charts details
3. **Makefile** - All available commands (`make help`)

### Adding Enhancements?
1. **ENHANCEMENTS-GUIDE.md** - Complete setup guide
2. **README-ENHANCEMENTS.md** - Quick reference
3. **ENHANCEMENTS-COMPLETE.md** - Summary

### Security & Optimization?
1. **SECURITY.md** - Security best practices
2. **NETWORK_SECURITY.md** - Network policies
3. **AUTHELIA_SSO.md** - SSO configuration
4. **LE_POTATO_OPTIMIZATION.md** - SBC optimizations

### Kubernetes Deep Dive?
1. **docs/k8s/k8s-manifests.md** - Manifests documentation
2. **docs/k8s/FEATURES.md** - SOTA 2025 features
3. **docs/k8s/MIGRATION.md** - Migration details

---

## 📊 Documentation Map

```
vllm-windows/
├── README.md                          # Main entry point
├── KUBERNETES-QUICKSTART.md           # Quick start guide
├── MIGRATION-FINAL-REPORT.md          # Complete migration report
├── ENHANCEMENTS-GUIDE.md              # Production enhancements
├── ENHANCEMENTS-COMPLETE.md           # Enhancements summary
├── HELM-DEPLOYMENT.md                 # Helm deployment
├── README-ENHANCEMENTS.md             # Quick enhancements
├── Makefile                           # All commands
├── renovate.json                      # Renovate config
├── todo.txt                           # Current status
│
├── docs/
│   ├── README.md                      # This file
│   ├── AUTHELIA_SSO.md                # SSO configuration
│   ├── LE_POTATO_OPTIMIZATION.md      # SBC optimizations
│   ├── NETWORK_SECURITY.md            # Network policies
│   ├── SECURITY.md                    # Security practices
│   │
│   ├── k8s/
│   │   ├── k8s-manifests.md           # K8s manifests
│   │   ├── MIGRATION.md               # Migration guide
│   │   ├── FEATURES.md                # SOTA features
│   │   └── MITTWALD-INTEGRATION.md    # Operators
│   │
│   └── archive/
│       ├── OPERATIONAL_RUNBOOK.md     # Docker ops (legacy)
│       ├── LE_POTATO_DEPLOYMENT.md    # Docker deploy (legacy)
│       └── SECRETS_MANAGEMENT.md      # Docker secrets (legacy)
│
├── helm/values/                       # 34 Helm charts
├── k8s/                               # Kubernetes manifests
└── scripts/                           # Setup scripts
```

---

## 📖 Documentation by Topic

### Getting Started
- [Project Overview](../README.md)
- [Quick Start](../KUBERNETES-QUICKSTART.md)
- [Migration Report](../MIGRATION-FINAL-REPORT.md)

### Deployment
- [Helm Deployment](../HELM-DEPLOYMENT.md)
- [Kubernetes Manifests](k8s/k8s-manifests.md)
- [Migration Guide](k8s/MIGRATION.md)

### Enhancements
- [Enhancements Guide](../ENHANCEMENTS-GUIDE.md)
- [Enhancements Summary](../ENHANCEMENTS-COMPLETE.md)
- [Quick Reference](../README-ENHANCEMENTS.md)

### Security
- [Security Best Practices](SECURITY.md)
- [Network Security](NETWORK_SECURITY.md)
- [SSO Configuration](AUTHELIA_SSO.md)

### Optimization
- [Le Potato Optimization](LE_POTATO_OPTIMIZATION.md)
- [SOTA Features](k8s/FEATURES.md)
- [Mittwald Integration](k8s/MITTWALD-INTEGRATION.md)

### Legacy (Docker Compose)
- [Operational Runbook](archive/OPERATIONAL_RUNBOOK.md)
- [Docker Deployment](archive/LE_POTATO_DEPLOYMENT.md)
- [Docker Secrets](archive/SECRETS_MANAGEMENT.md)

---

## 🔍 Finding Information

### How do I...

**Deploy the stack?**
→ [KUBERNETES-QUICKSTART.md](../KUBERNETES-QUICKSTART.md)

**Install enhancements?**
→ [ENHANCEMENTS-GUIDE.md](../ENHANCEMENTS-GUIDE.md)

**Configure security?**
→ [SECURITY.md](SECURITY.md) + [NETWORK_SECURITY.md](NETWORK_SECURITY.md)

**Optimize for Le Potato?**
→ [LE_POTATO_OPTIMIZATION.md](LE_POTATO_OPTIMIZATION.md)

**Set up SSO?**
→ [AUTHELIA_SSO.md](AUTHELIA_SSO.md)

**Understand the migration?**
→ [MIGRATION-FINAL-REPORT.md](../MIGRATION-FINAL-REPORT.md)

**Use Helm charts?**
→ [HELM-DEPLOYMENT.md](../HELM-DEPLOYMENT.md)

**Configure Kubernetes?**
→ [k8s/k8s-manifests.md](k8s/k8s-manifests.md)

---

## 🛠️ Reference

### Commands
```bash
make help                    # Show all available commands
```

### Key Files
- `Makefile` - All automation commands
- `renovate.json` - Dependency updates config
- `helm/values/*.yaml` - Service configurations (34 files)
- `k8s/base/hpa/*.yaml` - Autoscaling configs

---

## 📝 Contributing to Documentation

When adding new documentation:

1. **Core guides** → Root directory (e.g., new feature guides)
2. **Kubernetes-specific** → `docs/k8s/` (e.g., manifest details)
3. **Reference material** → `docs/` (e.g., security, optimization)
4. **Legacy/outdated** → `docs/archive/` (e.g., Docker Compose)

Update this README.md when adding new documentation.

---

**Last Updated**: 2025-12-14
**Stack Version**: SOTA 2025 Kubernetes
**Documentation Version**: 2.0 (Post-Cleanup)
