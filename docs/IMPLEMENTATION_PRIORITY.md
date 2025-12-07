# Implementation Priority Guide
**PotatoStack - Next Steps for Production Readiness**

## What You Already Have
- VPN stack (Surfshark + qBittorrent + slskd) with killswitch
- Kopia backup with metrics, verification script, and enhanced .kopiaignore
- Nextcloud + MariaDB (with optional Redis)
- Full monitoring: Prometheus, Grafana, Loki, Promtail, Alertmanager, Node/cAdvisor/SMART exporters, Netdata
- Management: Portainer, Diun, Uptime Kuma, Dozzle, Homepage, Autoheal
- Gitea + PostgreSQL
- Nginx Proxy Manager
- **Database backups already running** (nightly mysqldump/pg_dump containers)

---

## Priority 1: CRITICAL (Implement First)

### 1.1 Secrets Management ⭐⭐⭐
**Status:** Not implemented
**Impact:** HIGH - Prevents credential leaks, enables secure git commits
**Effort:** 30 minutes

**Action:**
- Use `sops + age` to encrypt .env file (see docs/SECRETS_MANAGEMENT.md)
- Backup age key to password manager/encrypted USB
- Add `.env.enc` to git, ignore `.env`
- Set up systemd service to decrypt on boot

**Files to create:**
```bash
.sops.yaml
~/.config/sops/age/keys.txt (backup this!)
/etc/systemd/system/decrypt-env.service
```

### 1.2 Offsite Kopia Backups ⭐⭐⭐
**Status:** Local only
**Impact:** HIGH - Disaster recovery for drive failure/fire/theft
**Effort:** 1 hour

**Action:**
Two options:
1. **Cloud backup**: Add S3/Backblaze B2/Wasabi repo
   ```bash
   # From within kopia container:
   kopia repo connect s3 --bucket=your-bucket --access-key=... --secret-access-key=...
   kopia policy set --add-offsite-target=s3 /host
   ```

2. **External USB backup**: Weekly rclone sync
   ```bash
   rclone sync /mnt/seconddrive/kopia/repository /mnt/usb-backup/kopia --progress
   ```

Add to crontab: `0 2 * * 0 /path/to/offsite-sync.sh`

### 1.3 Security Hardening (Container Level) ⭐⭐
**Status:** Partially implemented
**Impact:** MEDIUM - Reduces container escape risk
**Effort:** 20 minutes

**Action:**
Add to non-privileged services in docker-compose.yml:
```yaml
security_opt:
  - no-new-privileges:true
read_only: true  # For stateless services
cap_drop:
  - ALL
cap_add:  # Only add what's needed
  - NET_BIND_SERVICE
```

**Apply to:** homepage, dozzle, prometheus, grafana, alertmanager, nginx-proxy-manager (where feasible)

---

## Priority 2: HIGH (Implement This Week)

### 2.1 HTTP Monitoring (Blackbox Exporter) ⭐⭐
**Status:** Missing
**Impact:** MEDIUM - Detects service outages proactively
**Effort:** 30 minutes

**Action:**
Add to docker-compose.yml:
```yaml
blackbox-exporter:
  image: prom/blackbox-exporter:latest
  container_name: blackbox-exporter
  restart: unless-stopped
  networks:
    - monitoring
  ports:
    - "9115:9115"
  volumes:
    - ./config/blackbox:/config
  command: --config.file=/config/blackbox.yml
```

**Create config/blackbox/blackbox.yml:**
```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      preferred_ip_protocol: "ip4"
```

**Add Prometheus scrape config:**
```yaml
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      - http://192.168.178.40:8080  # qBittorrent
      - http://192.168.178.40:3000  # Grafana
      - http://192.168.178.40:8082  # Nextcloud
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter:9115
```

### 2.2 SSO with Authelia ⭐⭐
**Status:** Not implemented
**Impact:** MEDIUM - Single login for all services
**Effort:** 2 hours

**Action:**
Add Authelia container (see detailed config in AUTHELIA_SETUP.md - to be created)

Benefits:
- One login for Grafana, Nextcloud, Gitea, Portainer
- 2FA support (TOTP)
- Access control rules per service

**Skip if:** Only you access the homelab locally. Implement when exposing to internet.

### 2.3 Tailscale for Remote Access ⭐⭐
**Status:** Not implemented
**Impact:** MEDIUM - Secure access from anywhere
**Effort:** 15 minutes

**Action:**
```bash
# Host install (recommended over container)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --advertise-routes=192.168.178.0/24
```

Then access homelab via `http://lepotato.tailnet-name.ts.net:8080` from anywhere.

**Alternative:** Add to docker-compose.yml if you prefer containerized approach.

---

## Priority 3: MEDIUM (Implement This Month)

### 3.1 UPS Monitoring (NUT) ⭐
**Status:** Not implemented
**Impact:** LOW - Prevents data loss on power outage (if you have a UPS)
**Effort:** 1 hour

**Action:**
Only implement if you have a UPS connected to Le Potato (USB/network).

Add `upsd` container and `nut-exporter` for Prometheus metrics.

### 3.2 Internet Speed Monitoring ⭐
**Status:** Not implemented
**Impact:** LOW - Tracks ISP performance over time
**Effort:** 15 minutes

**Action:**
Add speedtest-exporter:
```yaml
speedtest-exporter:
  image: miguelndecarvalho/speedtest-exporter:latest
  container_name: speedtest-exporter
  restart: unless-stopped
  networks:
    - monitoring
  ports:
    - "9798:9798"
```

Add to Prometheus scrape config.

### 3.3 Gluetun VPN (Optional Alternative to Surfshark) ⭐
**Status:** Using ilteoood/docker-surfshark
**Impact:** LOW - More metrics, multi-VPN support
**Effort:** 30 minutes

**Action:**
Only switch if you need:
- Multiple VPN providers
- Better health metrics
- Port forwarding automation

Your current setup works fine.

### 3.4 Thanos for Long-Term Metrics ⭐
**Status:** Not implemented
**Impact:** LOW - 90+ day metric retention offloaded
**Effort:** 2 hours

**Action:**
Add Thanos sidecar/compactor to docker-compose.yml (enable with profile).

**Skip if:** 14 days retention is enough for your needs.

---

## Priority 4: OPTIONAL (Nice to Have)

### 4.1 Pi-hole/AdGuard Home
Local DNS + ad-blocking for entire network.

### 4.2 Healthchecks for All Services
Already have some; extend to qBittorrent, slskd, Nextcloud, Grafana, NPM.

### 4.3 Renovate Auto-PR for Updates
Already have renovate.json; wire it to Gitea webhook.

### 4.4 Nextcloud FPM + Nginx
Performance boost, but current setup is fine for Le Potato.

---

## Implementation Order (Recommended)

**Week 1:**
1. Secrets management (sops+age) - 30 min
2. Offsite Kopia backup - 1 hour
3. Blackbox exporter - 30 min

**Week 2:**
4. Security hardening (container flags) - 20 min
5. Tailscale - 15 min

**Week 3:**
6. Authelia (if exposing to internet) - 2 hours

**Month 2:**
7. UPS monitoring (if applicable)
8. Internet speed monitoring
9. Thanos (if needed)

---

## Maintenance Checklist

**Daily (automated):**
- Diun checks for image updates (notifications only)
- Database backups (mysqldump/pg_dump)
- Kopia snapshots (configure schedule)

**Weekly:**
- Check Grafana dashboards for anomalies
- Review Alertmanager notifications

**Monthly:**
- Run `verify-kopia-backups.sh`
- Test restore from Kopia backup
- Review container logs in Dozzle for errors
- Offsite backup sync (if using external USB)

**Quarterly:**
- Full disaster recovery test (restore entire stack from Kopia)
- Review and rotate credentials
- Update pinned image tags in .env

---

## Questions?

**Q: What about HOST_BIND=0.0.0.0 vs LAN IP?**
A: Your OPA policy warns about this. Options:
1. Set `HOST_BIND=192.168.178.40` in .env (preferred)
2. Update OPA policy to allow 0.0.0.0 for explicitly LAN-bound services
3. Use Nginx Proxy Manager for all external access, bind containers to 127.0.0.1

**Q: Which to implement first?**
A: **Secrets management + offsite backups** are critical. The rest depends on your use case:
- Exposing to internet? → Authelia + Tailscale
- Want uptime alerts? → Blackbox exporter
- Have a UPS? → NUT monitoring
