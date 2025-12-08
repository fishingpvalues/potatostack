# POTATOSTACK Documentation Index

## 🚀 Getting Started (Le Potato 2GB RAM)

**NEW: Optimized for 2GB RAM with database consolidation!**

1. **[QUICK_START.txt](../QUICK_START.txt)** - Start here! Quick reference guide
2. **[LE_POTATO_DEPLOYMENT.md](LE_POTATO_DEPLOYMENT.md)** - Phased deployment strategy for 2GB systems
3. **[LE_POTATO_OPTIMIZATION.md](LE_POTATO_OPTIMIZATION.md)** - Complete optimization summary & changes
4. **[setup-swap.sh](../setup-swap.sh)** - Setup 2GB swap file (run this first!)

## 📚 General Documentation

### Quick References
- **[QUICKSTART.md](QUICKSTART.md)** - General quickstart guide
- **[STACK_OVERVIEW.md](STACK_OVERVIEW.md)** - Overview of all services

### Deployment & Operations
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - SSH deployment script usage
- **[OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md)** - Operations and troubleshooting
- **[UPDATE_STRATEGY.md](UPDATE_STRATEGY.md)** - Update and maintenance procedures

### Security & Authentication
- **[SECURITY.md](SECURITY.md)** - Security best practices
- **[NETWORK_SECURITY.md](NETWORK_SECURITY.md)** - Network security configuration
- **[AUTHELIA_SSO.md](AUTHELIA_SSO.md)** - Single Sign-On setup
- **[SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md)** - Managing secrets and credentials

### Service-Specific Guides
- **[FIREFLY-SETUP.md](FIREFLY-SETUP.md)** - Firefly III finance app setup

### Architecture & Technical Details
- **[ENTERPRISE_ARCHITECTURE.md](ENTERPRISE_ARCHITECTURE.md)** - Architecture overview
- **[TECHNICAL_SPECIFICATIONS.md](TECHNICAL_SPECIFICATIONS.md)** - Technical specifications
- **[SYSTEM_COMPONENT_DIAGRAMS.md](SYSTEM_COMPONENT_DIAGRAMS.md)** - System diagrams
- **[RENOVATE_SETUP.md](RENOVATE_SETUP.md)** - Automated dependency updates

## 🆕 What's New (Le Potato Optimization)

### Database Consolidation
- ✅ **Redis**: 3 instances → 1 shared (saves ~256MB)
- ✅ **MariaDB**: 2 instances → 1 shared (saves ~256MB)
- ✅ **Total savings**: ~512MB RAM

### Resource Optimization
- ✅ Memory limits reduced 40-60% across all services
- ✅ Docker Compose profiles: `apps`, `monitoring-extra`, `heavy`
- ✅ qBittorrent connection tuning for 2GB RAM
- ✅ Prometheus alerts for RAM/CPU thresholds

### New Monitoring
- ✅ Speedtest Exporter dashboard (internet speed monitoring)
- ✅ Fritzbox Exporter dashboard (router & DSL health)
- ✅ RAM/CPU alerts: >80% warning, >90% critical

## 📊 Docker Compose Profiles

Run different service configurations based on available resources:

```bash
# Default (core services ~1.6GB)
docker compose up -d

# With password manager (~1.7GB)
docker compose --profile apps up -d

# With extended monitoring (~2GB)
docker compose --profile apps --profile monitoring-extra up -d

# Everything (~3GB+ - NOT RECOMMENDED for 2GB!)
docker compose --profile heavy up -d
```

## 🔍 Quick Links

- **Grafana**: http://YOUR_IP:3000 (monitoring dashboards)
- **Prometheus**: http://YOUR_IP:9090 (metrics)
- **Nextcloud**: http://YOUR_IP:8082 (cloud storage)
- **Gitea**: http://YOUR_IP:3001 (git server)
- **qBittorrent**: http://YOUR_IP:8080 (torrents)
- **Portainer**: http://YOUR_IP:9000 (docker management)

## 🆘 Troubleshooting

If you encounter issues:

1. Check [LE_POTATO_DEPLOYMENT.md](LE_POTATO_DEPLOYMENT.md) troubleshooting section
2. Review [OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md) for common issues
3. Monitor with: `docker stats` and `free -h`
4. Check logs: `docker compose logs -f <service>`

## 📝 Configuration Files

All configuration files are in the `config/` directory:

- `config/prometheus/` - Prometheus config & alerts
- `config/grafana/` - Grafana dashboards & datasources
- `config/mariadb/init/` - Database initialization scripts
- `config/loki/` - Loki log aggregation
- `config/alertmanager/` - Alert routing
- And more...

---

**Last Updated**: December 2024 (Le Potato 2GB RAM optimization)
