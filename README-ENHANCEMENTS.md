# 🚀 PotatoStack - Production Enhancements

All optional SOTA 2025 production features configured and ready to deploy.

## Quick Install

```bash
# Install all enhancements
make helm-install-enhancements

# Enable autoscaling
make k8s-apply-hpa

# Setup Renovate
make renovate-setup
```

## What's Included

1. **Renovate** - Auto-update dependencies (GitHub App)
2. **Velero** - Kubernetes backup & restore
3. **Sealed Secrets** - Encrypt secrets for Git
4. **external-dns** - Auto DNS management
5. **Metrics Server** - Resource metrics for HPA
6. **Kubernetes Dashboard** - Web UI
7. **Grafana Tempo** - Distributed tracing

## Documentation

See **ENHANCEMENTS-GUIDE.md** for complete setup instructions.

## Resource Impact

**Essential** (recommended for 2GB RAM): ~128-192Mi
**All enhancements**: ~600-1100Mi

Choose what you need!
