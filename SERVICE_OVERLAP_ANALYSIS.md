# Service Overlap Analysis - Main Stack

## OVERLAPPING SERVICES TO REMOVE

### 1. MONITORING OVERLAPS ⚠️

#### Keep ONE Dashboard Solution
**Current:**
- ✅ **Homarr** (SOTA 2025) - 30+ integrations, drag-drop, modern
- ❌ **Dockge** - Stack manager (less capable)

**Recommendation:** REMOVE Dockge
- Homarr can show container stats
- Homarr is more comprehensive
- Saves: 256MB RAM, 0.25 CPU

#### Container Monitoring Overlap
**Current:**
- ✅ **cAdvisor** - Exports to Prometheus (SOTA 2025)
- ✅ **Netdata** - Real-time beautiful UI
- ❌ **Beszel** - Redundant with cAdvisor + Grafana

**Recommendation:** REMOVE Beszel
- cAdvisor + Grafana = historical analysis
- Netdata = real-time monitoring
- Beszel adds nothing unique
- Saves: 192MB RAM, 0.35 CPU

### 2. MEDIA SERVER OVERLAPS ⚠️

#### Audio Management
**Current:**
- ✅ **Jellyfin** - Handles music + video + audiobooks
- ❌ **Audiobookshelf** - Audiobooks only (niche)

**Recommendation:** REMOVE Audiobookshelf
- Jellyfin can play audiobooks
- One less service to manage
- Saves: 512MB RAM, 1.0 CPU

### 3. UTILITY OVERLAPS ⚠️

#### Note-Taking
**Current:**
- ✅ **Paperless-ngx** - Documents + OCR (SOTA 2025)
- ❌ **Memos** - Lightweight notes

**Recommendation:** REMOVE Memos
- Paperless handles documents better
- Use Nextcloud Notes for quick notes
- Saves: 256MB RAM, 0.25 CPU

#### Sketching/Whiteboard
**Current:**
- ✅ **Nextcloud Whiteboard** (in AIO)
- ❌ **Excalidraw** - Standalone sketching

**Recommendation:** REMOVE Excalidraw
- Nextcloud has Whiteboard built-in
- Duplicate functionality
- Saves: 128MB RAM, 0.25 CPU

#### PDF Tools
**Current:**
- ✅ **Stirling PDF** - Comprehensive PDF toolkit
- ❌ **IT-Tools** - Has some PDF tools but mainly other utils

**Keep both** - IT-Tools has many other utilities beyond PDF

### 4. SECURITY OVERLAPS ⚠️

#### Secrets Management
**Current:**
- ✅ **Vaultwarden** - Password manager (SOTA, widely used)
- ❌ **HashiCorp Vault** - Enterprise secrets (overkill for homelab)

**Recommendation:** REMOVE HashiCorp Vault
- Vaultwarden is sufficient for homelab
- Vault is enterprise-focused
- Complex to manage
- Saves: 384MB RAM, 0.75 CPU

### 5. DEVELOPMENT OVERLAPS ⚠️

#### Error Tracking
**Current:**
- ❌ **Sentry** - Error tracking (rarely used in homelab)
- Better: Use logs in Loki/Grafana

**Recommendation:** REMOVE Sentry
- Most homelab apps don't integrate with Sentry
- Loki logs are sufficient
- Saves: 1.5GB RAM, 1.5 CPU

### 6. DOWNLOAD CLIENT OVERLAPS ⚠️

#### Download Managers
**Current:**
- ✅ **qBittorrent** - Torrent client (best for *arr)
- ✅ **Aria2** - HTTP/FTP/torrent (multi-protocol)
- ❌ **AriaNg** - Just a UI for Aria2 (built-in web UI exists)

**Recommendation:** REMOVE AriaNg
- Aria2 has its own web UI
- Separate container not needed
- Saves: 64MB RAM, 0.1 CPU

### 7. FILE SHARING OVERLAPS ⚠️

#### Sharing Solutions
**Current:**
- ✅ **Nextcloud** - Full cloud suite with sharing
- ❌ **Pingvin Share** - Temporary file sharing

**Recommendation:** REMOVE Pingvin Share
- Nextcloud can share files publicly
- Saves: 512MB RAM, 1.0 CPU

### 8. CALENDAR/SCHEDULING OVERLAPS ⚠️

#### Calendar Solutions
**Current:**
- ✅ **Nextcloud Calendar** (in AIO)
- ❌ **Cal.com** - Scheduling/booking

**Recommendation:** REMOVE Cal.com (unless you need booking)
- Nextcloud Calendar is sufficient for personal use
- Cal.com is for appointment booking (niche)
- Saves: 512MB RAM, 1.0 CPU

### 9. PASTEBIN OVERLAPS ⚠️

#### Text Sharing
**Current:**
- ❌ **Rustypaste** - Pastebin (rarely used)
- Better: Use Nextcloud Text or Memos

**Recommendation:** REMOVE Rustypaste
- Niche use case
- Nextcloud can share text files
- Saves: 128MB RAM, 0.25 CPU

### 10. BOOKMARK MANAGEMENT

#### Bookmarks
**Current:**
- ✅ **Linkding** - Bookmark manager (SOTA 2025)

**Keep** - No overlap, widely regarded

---

## REMOVAL PRIORITY LIST

### 🔥 HIGH PRIORITY (Remove First)

| Service | Type | RAM Save | CPU Save | Reason |
|---------|------|----------|----------|--------|
| **Sentry** | Error tracking | 1.5GB | 1.5 CPU | Rarely used in homelab, Loki is better |
| **HashiCorp Vault** | Secrets | 384MB | 0.75 CPU | Overkill, Vaultwarden sufficient |
| **Pingvin Share** | File sharing | 512MB | 1.0 CPU | Nextcloud does this |
| **Cal.com** | Calendar | 512MB | 1.0 CPU | Nextcloud Calendar sufficient |
| **Audiobookshelf** | Media | 512MB | 1.0 CPU | Jellyfin handles audiobooks |

**Total Savings:** 3.4GB RAM, 5.25 CPU

### ⚡ MEDIUM PRIORITY

| Service | Type | RAM Save | CPU Save | Reason |
|---------|------|----------|----------|--------|
| **Beszel** | Monitoring | 192MB | 0.35 CPU | cAdvisor + Netdata cover this |
| **Dockge** | Management | 256MB | 0.25 CPU | Homarr is better |
| **Memos** | Notes | 256MB | 0.25 CPU | Paperless/Nextcloud better |
| **Excalidraw** | Sketching | 128MB | 0.25 CPU | Nextcloud Whiteboard exists |
| **Rustypaste** | Pastebin | 128MB | 0.25 CPU | Niche, Nextcloud can share |

**Total Savings:** 960MB RAM, 1.35 CPU

### 💡 LOW PRIORITY (Consider)

| Service | Type | RAM Save | CPU Save | Reason |
|---------|------|----------|----------|--------|
| **AriaNg** | UI | 64MB | 0.1 CPU | Aria2 has built-in UI |

**Total Savings:** 64MB RAM, 0.1 CPU

---

## RECOMMENDED REMOVAL SUMMARY

### Remove These 11 Services:

**High Priority (5):**
1. Sentry
2. HashiCorp Vault
3. Pingvin Share
4. Cal.com
5. Audiobookshelf

**Medium Priority (5):**
6. Beszel
7. Dockge
8. Memos
9. Excalidraw
10. Rustypaste

**Low Priority (1):**
11. AriaNg

### Total Savings:
- **RAM:** 4.4GB saved (down to 8-10GB from 12.5-14GB)
- **CPU:** 6.7 cores saved
- **Services:** 89 (down from 100)
- **Headroom:** 6-8GB RAM available

---

## SOTA 2025 SERVICES TO KEEP

### ✅ Best-in-Class Services

**Databases:**
- PostgreSQL 16 (pgvector) ⭐
- MongoDB 7
- Redis 7

**Security:**
- CrowdSec (modern IPS) ⭐
- Authentik (SSO) ⭐
- Vaultwarden (passwords) ⭐
- Fail2Ban
- Trivy

**Monitoring:**
- Prometheus ⭐
- Thanos (long-term) ⭐
- Grafana ⭐
- Loki ⭐
- Netdata ⭐
- cAdvisor ⭐
- Uptime Kuma

**Media:**
- Jellyfin (HW accel) ⭐
- Sonarr/Radarr/Lidarr/Readarr ⭐
- Prowlarr ⭐
- Bazarr
- qBittorrent ⭐
- slskd (Soulseek) ⭐

**Applications:**
- Nextcloud AIO ⭐
- Immich (AI photos) ⭐
- Paperless-ngx (OCR) ⭐
- Miniflux (RSS) ⭐
- n8n (automation) ⭐
- Gitea ⭐

**Utilities:**
- Homarr (dashboard) ⭐
- Stirling PDF ⭐
- Linkding ⭐
- IT-Tools ⭐
- Open WebUI (LLM) ⭐

**Networking:**
- Traefik ⭐
- Gluetun ⭐
- AdGuard Home ⭐
- Tailscale ⭐

---

## FINAL OPTIMIZED STACK

After removing 11 services:

- **Services:** 89 (best-in-class only)
- **RAM Usage:** 8-10GB peak
- **Available RAM:** 6-8GB
- **CPU Usage:** Lower idle/peak
- **Maintainability:** Easier with fewer services

All remaining services are SOTA 2025 and widely regarded as best in their category.
