# PotatoStack - Missing Tools Recommendations

**Based on**: awesome-selfhosted analysis
**Target**: Le Potato (2GB RAM)
**Date**: December 2025

## Executive Summary

Your PotatoStack is **excellent** with comprehensive coverage of core services. Analysis against awesome-selfhosted reveals strategic gaps in **DNS management**, **knowledge organization**, and **personal productivity** tools.

**Total RAM Impact**: ~270MB for all 8 recommended additions
**Fits 2GB?**: YES (with current stack at ~1.6GB)

---

## ✅ What You Already Have (Excellent!)

| Category | Tool | Status |
|----------|------|--------|
| Media Streaming | Jellyfin | ✓ Deployed |
| Photos | Immich | ✓ Deployed |
| Documents | Paperless-ngx, Stirling-PDF | ✓ Deployed |
| File Sync | Seafile | ✓ Deployed |
| Backups | Kopia | ✓ Deployed |
| Passwords | Vaultwarden | ✓ Deployed |
| Git | Gitea | ✓ Deployed |
| Monitoring | Prometheus, Grafana, Loki | ✓ Deployed |
| Dashboard | Homepage | ✓ Deployed |
| Pastebin | Rustypaste | ✓ Deployed |
| SSO | Authelia | ✓ Deployed |

---

## 🎯 Recommended Additions (Priority Order)

### 1. **Miniflux** ⭐⭐⭐
**Category**: RSS Feed Reader
**RAM**: ~30MB
**Why**: Stay updated with news, blogs, podcasts

**Features**:
- Minimalist, fast Go application
- Feed auto-discovery
- Fever API support (mobile apps)
- Keyboard shortcuts
- Dark mode

**Deploy**:
```bash
# Create database
kubectl exec -it statefulset/postgres -n potatostack -- psql -U postgres
# > CREATE DATABASE miniflux;
# > CREATE USER miniflux WITH PASSWORD 'secure_password';
# > GRANT ALL PRIVILEGES ON DATABASE miniflux TO miniflux;

helm install miniflux oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/miniflux.yaml -n potatostack
```

**Access**: https://rss.lepotato.local
**Mobile Apps**: Fever API compatible (Reeder, NetNewsWire)

---

### 2. **linkding** ⭐⭐
**Category**: Bookmark Manager
**RAM**: ~40MB
**Why**: Organize and search bookmarks across devices

**Features**:
- Fast full-text search
- Tag-based organization
- Browser extensions (Chrome, Firefox)
- Archive snapshots
- REST API

**Deploy**:
```bash
# Create database
kubectl exec -it statefulset/postgres -n potatostack -- psql -U postgres
# > CREATE DATABASE linkding;
# > CREATE USER linkding WITH PASSWORD 'secure_password';
# > GRANT ALL PRIVILEGES ON DATABASE linkding TO linkding;

helm install linkding oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/linkding.yaml -n potatostack
```

**Access**: https://bookmarks.lepotato.local
**Browser Extensions**: Available for Chrome/Firefox

---

### 3. **Radicale** ⭐⭐⭐
**Category**: CalDAV/CardDAV (Calendar & Contacts)
**RAM**: ~20MB
**Why**: Sync calendars/contacts across all devices

**Features**:
- CalDAV (calendars) + CardDAV (contacts)
- Ultra-lightweight Python server
- Compatible with all major clients
- Simple authentication

**Deploy**:
```bash
# Create config
kubectl create configmap radicale-config -n potatostack --from-literal=config="
[server]
hosts = 0.0.0.0:5232

[auth]
type = htpasswd
htpasswd_filename = /data/users
htpasswd_encryption = bcrypt

[storage]
filesystem_folder = /data/collections
"

helm install radicale oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/radicale.yaml -n potatostack
```

**Access**: https://dav.lepotato.local
**Clients**: Apple Calendar/Contacts, Thunderbird, DAVx5 (Android)

---

### 4. **Syncthing** ⭐⭐
**Category**: P2P File Sync
**RAM**: ~40MB
**Why**: Decentralized sync (complements Seafile)

**Features**:
- Peer-to-peer sync (no server needed)
- Continuous file synchronization
- Versioning
- Selective sync
- Encrypted transfers

**Deploy**:
```bash
helm install syncthing oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/syncthing.yaml -n potatostack
```

**Access**: https://sync.lepotato.local
**Use Case**: Sync between desktop, laptop, phone (decentralized)

---

---

## 📊 Resource Impact Summary

| Tool | RAM | CPU | Storage | Priority |
|------|-----|-----|---------|----------|
| Miniflux | 30MB | 0.2 | 500MB | ⭐⭐⭐ |
| linkding | 40MB | 0.2 | 1GB | ⭐⭐ |
| Radicale | 20MB | 0.1 | 2GB | ⭐⭐⭐ |
| Syncthing | 40MB | 0.5 | 50GB | ⭐⭐ |
| **Total** | **130MB** | **1.0** | **~54GB** | - |

**Current Stack**: ~1.6GB RAM
**With All Additions**: ~1.73GB RAM
**Remaining**: ~270MB buffer ✓ FITS EASILY!

---

## 🚀 Deployment Strategy

### Phase 1: Essentials (Week 1)
```bash
# RSS Reader
helm install miniflux oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/miniflux.yaml -n potatostack

# Calendar/Contacts
helm install radicale oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/radicale.yaml -n potatostack
```

### Phase 2: Productivity (Week 2)
```bash
# Bookmarks
helm install linkding oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/linkding.yaml -n potatostack
```

### Phase 3: Optional (Week 3+)
```bash
# P2P Sync
helm install syncthing oci://ghcr.io/bjw-s-labs/charts/app-template \
  -f helm/values/syncthing.yaml -n potatostack
```

---

## 🔍 Additional Considerations

### Tools You DON'T Need (Already Covered)

| Tool | Why Skip |
|------|----------|
| Nextcloud | You have Seafile (lighter) |
| Plex | You have Jellyfin |
| Bitwarden | You have Vaultwarden |
| Prometheus | Already deployed |
| Grafana | Already deployed |
| GitLab | You have Gitea (lighter) |

### Low Priority Tools (Consider Later)

1. **Umami** - Privacy analytics (if you host websites)
2. **n8n** - Workflow automation (~150MB RAM)
3. **Actual Budget** - Personal finance
4. **Changedetection.io** - Monitor website changes
5. **Wiki.js** - Knowledge base (~120MB RAM)
6. **Firefly III** - Advanced budgeting

---

## 🎯 Final Recommendations

### Must-Have (Deploy Now)
1. **Miniflux** - Stay informed with RSS
2. **Radicale** - Calendar/contacts sync

### High Value (Deploy Soon)
3. **linkding** - Bookmark organization

### Optional (Nice to Have)
4. **Syncthing** - Decentralized file sync

### Consider Later (if needed)
- AdGuard Home (DNS/ad-blocking) - Use router-level solution instead
- Memos (note-taking) - Use Paperless-ngx for notes
- Mealie (recipes) - Niche use case
- Wiki.js (documentation) - Only if heavy documentation needs
- n8n (automation) - Power users only
- Umami (analytics) - Only if hosting websites

---

## 📝 Next Steps

1. ✅ Verify current RAM usage: `kubectl top nodes`
2. ✅ Deploy Phase 1 (Miniflux, Radicale)
3. ✅ Set up mobile apps for Miniflux/Radicale
4. ✅ Monitor RAM usage before Phase 2
5. ✅ Deploy Phase 2 (linkding) if needed
6. ✅ Deploy Phase 3 (Syncthing) if P2P sync needed

---

**Your PotatoStack is already excellent! These additions complete the ecosystem.** 🥔🚀
