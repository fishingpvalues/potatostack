# Services Cleanup Recommendations

**Generated**: 2025-12-27
**Current Services**: 92
**Recommended After Cleanup**: 72-77 services
**Estimated Memory Savings**: 5-8 GB

---

## 🔴 HIGH PRIORITY - Remove These (Heavy & Redundant)

### 1. Monitoring Stack Duplication
**Problem**: 3 different monitoring solutions running simultaneously

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| netdata | 512M | ❌ REMOVE | Heavy, real-time monitoring - replaced by Beszel |
| prometheus + grafana + node-exporter + cadvisor | ~1.5G | ❌ REMOVE | Enterprise stack - overkill for homelab, use Beszel |
| beszel + beszel-agent | 192M | ✅ KEEP | Modern SOTA 2025, lightweight, sufficient |
| uptime-kuma | 256M | ✅ KEEP | Different purpose - uptime/status pages |

**Savings**: ~1.8 GB

---

### 2. Reverse Proxy Duplication
**Problem**: Running 2 reverse proxies

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| traefik | 256M | ✅ KEEP | Modern, automatic SSL, label-based config |
| npm (Nginx Proxy Manager) | 512M | ❌ REMOVE | Redundant with Traefik |

**Savings**: 512 MB

---

### 3. Logging Stack Duplication
**Problem**: 2 complete logging stacks

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| loki + promtail | ~384M | ✅ KEEP | Lightweight, integrates with Grafana if needed |
| elasticsearch + logstash + kibana | ~2-3G | ❌ REMOVE | Extremely heavy ELK stack, enterprise overkill |

**Savings**: ~2.5 GB

---

### 4. Dashboard Duplication
**Problem**: 2 dashboards

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| homarr | 512M | ✅ KEEP | Modern SOTA 2025, drag-and-drop, 30+ integrations |
| glance | 256M | ❌ REMOVE | Static, limited features |

**Savings**: 256 MB

---

### 5. VPN Server Duplication
**Problem**: 2 inbound VPN solutions

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| tailscale | 128M | ✅ KEEP | Modern mesh VPN, zero-config, SOTA 2025 |
| wireguard-server | 128M | ❌ REMOVE | Redundant with Tailscale, harder to configure |
| gluetun | 256M | ✅ KEEP | Different purpose - outbound VPN for *arr stack |

**Savings**: 128 MB

---

### 6. Automation Duplication
**Problem**: 2 automation platforms

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| n8n | 512M | ✅ KEEP | Modern, visual workflows, popular, active development |
| huginn | 512M | ❌ REMOVE | Older, agent-based, more complex, less maintained |

**Savings**: 512 MB

---

## 🟡 MEDIUM PRIORITY - Consider Removing

### 7. Container Management Overlap

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| dockge | 256M | ✅ KEEP | Modern SOTA 2025, focused on Compose stacks |
| portainer | 256M | ⚠️ CONSIDER | More features but heavier, less modern |

**Decision**: Keep Portainer if you need full container management UI. Remove if you only manage stacks.

---

### 8. Budget/Finance Duplication

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| actual-budget | 256M | ✅ KEEP | Modern SOTA 2025, simple, bank sync |
| firefly-iii + firefly-db + firefly-importer | ~1G | ❌ REMOVE | Complex, heavier, redundant |

**Savings**: ~750 MB

---

### 9. Note-Taking via CouchDB

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| memos | 256M | ✅ KEEP | Modern SOTA 2025, lightweight notes |
| couchdb + couchdb-setup | 512M | ⚠️ CONSIDER | Only if actively using Obsidian LiveSync |

**Decision**: Remove CouchDB if not using Obsidian. Memos is sufficient for quick notes.

---

### 10. Drawing Tool Overlap

| Service | Memory | Status | Reason |
|---------|--------|--------|--------|
| excalidraw | 128M | ✅ KEEP | Modern, hand-drawn style, lightweight |
| drawio | 128M | ❌ REMOVE | Both are diagramming tools |

**Savings**: 128 MB

---

## 🟢 LOW PRIORITY - Optional Cleanup

### 11. Router-Specific Exporter

| Service | Memory | Status | Notes |
|---------|--------|--------|-------|
| fritzbox-exporter | 64M | ⚠️ OPTIONAL | Only useful if you have a FritzBox router |

---

### 12. Pastebin Overlap

| Service | Memory | Status | Notes |
|---------|--------|--------|-------|
| rustypaste | 64M | ⚠️ OPTIONAL | Pingvin Share can handle file/text sharing |

---

## 📊 Summary of Removals

### HIGH PRIORITY Removals:
```
1. netdata (512M)
2. prometheus + grafana + node-exporter + cadvisor (~1.5G)
3. npm (512M)
4. elasticsearch + logstash + kibana (~2.5G)
5. glance (256M)
6. wireguard-server (128M)
7. huginn (512M)
```
**Total High Priority Savings**: ~5.9 GB, 12-15 containers

### MEDIUM PRIORITY Removals:
```
8. firefly-iii stack (~1G)
9. couchdb (~512M if not using Obsidian)
10. drawio (128M)
11. portainer (256M if using Dockge)
```
**Total Medium Priority Savings**: ~1.9 GB, 4-6 containers

### TOTAL POTENTIAL SAVINGS:
- **Memory**: 7-8 GB
- **Containers**: 16-21 removed
- **Final Count**: 71-76 services (down from 92)

---

## ✅ Recommended Final Stack

### Core Infrastructure
- ✅ **Reverse Proxy**: Traefik
- ✅ **Security**: CrowdSec + AdGuard Home
- ✅ **Monitoring**: Beszel + Uptime Kuma
- ✅ **Dashboard**: Homarr
- ✅ **Container Mgmt**: Dockge
- ✅ **Logging**: Loki + Promtail
- ✅ **VPN**: Gluetun (outbound) + Tailscale (mesh)

### Services to Keep
- ✅ All *arr stack (Sonarr, Radarr, etc.)
- ✅ All media (Jellyfin, Audiobookshelf, Navidrome)
- ✅ Nextcloud AIO
- ✅ Vaultwarden
- ✅ Paperless-ngx
- ✅ Actual Budget
- ✅ Memos
- ✅ n8n
- ✅ All other productivity tools

---

## 🚀 How to Clean Up

1. **Backup first**: Export configs from services you're removing
2. **Stop services**: `docker compose stop <service>`
3. **Remove from docker-compose.yml**: Delete service definitions
4. **Clean volumes**: `docker volume rm <volume>` (careful!)
5. **Restart stack**: `docker compose up -d`

---

## ⚠️ Notes

- Keep prometheus+grafana if you need advanced metrics/alerting
- Keep Portainer if you prefer GUI over Dockge
- Keep CouchDB only if using Obsidian LiveSync
- Keep Firefly III if you have complex finances
- ELK stack is only needed for enterprise-level log analysis
