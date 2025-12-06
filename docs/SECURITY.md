# Security Guidelines for PotatoStack

## ⚠️ CRITICAL: GitHub Data Breach Notice

**Before uploading this repository to GitHub, be aware:**

GitHub.com experienced a data breach affecting approximately 265,160 accounts. Exposed data includes:
- Email addresses
- Usernames
- Names
- Locations
- Company names
- Bio information

**Source:** [Have I Been Pwned](https://haveibeenpwned.com/)

### Immediate Actions Required

1. **Never commit the `.env` file** - It contains all your passwords and secrets
2. **Use strong, unique passwords** for your GitHub account
3. **Enable 2FA on GitHub** immediately if not already enabled
4. **Review repository visibility** - Keep private unless intentionally sharing
5. **Use GitHub secrets** for any CI/CD workflows

---

## 🔒 Security Checklist Before GitHub Upload

### Files That MUST NOT Be Committed

- [ ] `.env` - Contains all passwords (already in .gitignore)
- [ ] `*.log` - May contain sensitive information
- [ ] `backup-*.tar.gz` - May contain credentials
- [ ] Any files with actual passwords or API keys

### Verify .gitignore

```bash
# Check what would be committed
git status

# Ensure .env is not listed
# If it is, DO NOT COMMIT!
```

### Recommended GitHub Repository Settings

1. **Repository Visibility:**
   - **Private**: Recommended if this is your personal config
   - **Public**: Only if intentionally sharing (sanitize first!)

2. **Branch Protection:**
   - Require pull request reviews
   - Require status checks to pass
   - Require signed commits (optional but recommended)

3. **Security Features to Enable:**
   - Dependabot alerts
   - Secret scanning
   - Dependency graph
   - Code scanning (GitHub Advanced Security)

---

## 🛡️ PotatoStack Security Best Practices

### 1. Password Management

**NEVER use default passwords!** Change these immediately:

```bash
# Generate strong passwords
openssl rand -base64 32

# Or use a password manager like:
# - Bitwarden (self-hosted option available)
# - KeePassXC
# - 1Password
```

**Required password changes:**
- [ ] All passwords in `.env` file
- [ ] Nginx Proxy Manager (default: admin@example.com / changeme)
- [ ] qBittorrent (default: admin / adminadmin)
- [ ] Grafana admin password
- [ ] Nextcloud admin password
- [ ] Portainer admin password
- [ ] slskd (Soulseek) password

### 2. Two-Factor Authentication (2FA)

Enable 2FA on ALL services that support it:

- [ ] **GitHub account** (CRITICAL!)
- [ ] **Nextcloud** (Settings → Security → Two-Factor Authentication)
- [ ] **Nginx Proxy Manager** (Settings → Users → Edit → Enable 2FA)
- [ ] **Portainer** (Settings → Authentication → Enable 2FA)
- [ ] **Grafana** (Configuration → Users → Edit → 2FA)
- [ ] **Gitea** (User Settings → Security → Two-Factor Authentication)

### 3. Network Security

#### Firewall Configuration

```bash
# On Le Potato, restrict access to local network only
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.178.0/24
sudo ufw enable

# Check status
sudo ufw status verbose
```

#### VPN Access (WireGuard on Fritzbox)

**NEVER expose services directly to the internet!**

1. Configure WireGuard VPN on Fritzbox
2. Connect devices via VPN
3. Access services through VPN tunnel only

**Test VPN protection:**
```bash
# From device connected via WireGuard
curl http://192.168.178.40:3003

# From device NOT on VPN - should timeout/fail
```

### 4. SSL/TLS Configuration

**Use Nginx Proxy Manager for all external access:**

1. Configure Let's Encrypt certificates
2. Force HTTPS redirects
3. Use strong cipher suites
4. Enable HSTS (HTTP Strict Transport Security)

**Recommended NPM settings:**
```
# Force SSL
Force SSL: ✓

# HSTS
HSTS Enabled: ✓
HSTS Subdomains: ✓

# HTTP/2
HTTP/2 Support: ✓
```

### 5. VPN Killswitch Verification

**Ensure P2P traffic ONLY goes through Surfshark:**

```bash
# Check Surfshark IP
docker exec surfshark curl -s https://ipinfo.io/ip
# Should show Surfshark IP, NOT your real IP

# Check qBittorrent IP
docker exec qbittorrent curl -s https://ipinfo.io/ip
# Should show SAME Surfshark IP

# Check slskd IP (via Surfshark namespace)
docker exec surfshark curl -s --max-time 10 http://localhost:2234 || true
# Should show SAME Surfshark IP

# If ANY show your real IP, DO NOT USE - fix configuration first!
```

### 6. Container Security

**Security best practices:**

- [ ] All containers run as non-root where possible (PUID=1000, PGID=1000)
- [ ] Read-only volumes where appropriate (`:ro` flag)
- [ ] Limited capabilities (only necessary `cap_add`)
- [ ] Resource limits prevent DoS (memory/CPU limits set)
- [ ] Health checks restart failed containers automatically

**Review container privileges:**
```bash
# Check which containers run privileged
docker ps --format "{{.Names}}" | xargs -I {} docker inspect {} --format '{{.Name}}: {{.HostConfig.Privileged}}'

# Only these should be privileged:
# - smartctl-exporter (needs direct disk access)
# - netdata (needs system access)
# - surfshark (needs network admin)
```

### 7. Backup Security

**Kopia provides encrypted backups:**

- Backups are encrypted at rest
- Uses strong AES-256 encryption
- Repository password required for access
- Store repository password securely (password manager)

**Backup the backup:**
```bash
# Periodically backup Kopia repository to external location
# Example: Offsite NAS, cloud storage, external HDD

rclone sync /mnt/seconddrive/kopia/repository \
  remote:backups/kopia --progress
```

### 8. Log Security

**Logs may contain sensitive information:**

```bash
# Regularly review and rotate logs
docker system prune --volumes --filter "until=720h"

# Check for accidentally logged secrets
grep -r "password\|secret\|token" /mnt/seconddrive/*/logs/ || echo "No secrets found"
```

**Loki retention** is set to 30 days in configuration.

### 9. Update Strategy

**Watchtower handles automatic updates, but verify:**

```bash
# Check Watchtower logs
docker logs watchtower

# Manually update all images
docker-compose pull
docker-compose up -d

# Remove old images
docker image prune -a
```

**Before updates:**
- [ ] Backup configuration files
- [ ] Note current versions
- [ ] Review changelog for breaking changes

### 10. Monitoring & Alerting

**Security alerts configured in Alertmanager:**

- VPN connection drops (P2P exposure risk)
- Container crashes (potential breach attempts)
- High disk usage (log spam/DoS)
- SMART failures (data loss risk)
- Unauthorized access attempts (via logs)

**Review security logs regularly:**
```bash
# Check auth logs
docker logs nginx-proxy-manager | grep "401\|403"

# Check Nextcloud logs
docker exec nextcloud tail -f /var/www/html/data/nextcloud.log

# Check failed login attempts
docker exec nextcloud grep "Login failed" /var/www/html/data/nextcloud.log
```

---

## 🚨 Incident Response

### If You Suspect a Breach

1. **Immediately disconnect from network:**
   ```bash
   docker-compose down
   sudo ifconfig eth0 down
   ```

2. **Preserve evidence:**
   ```bash
   # Backup all logs
   tar -czf incident-$(date +%Y%m%d-%H%M%S).tar.gz \
     /var/log/ \
     /mnt/seconddrive/*/logs/
   ```

3. **Review access logs:**
   - Check Nginx Proxy Manager logs
   - Check Nextcloud audit log
   - Check Grafana admin actions
   - Check Portainer events

4. **Change ALL passwords:**
   ```bash
   # Generate new passwords for ALL services
   for i in {1..10}; do openssl rand -base64 32; done
   ```

5. **Review Docker container changes:**
   ```bash
   docker diff [container_name]
   # Look for unexpected file modifications
   ```

6. **Check for rootkits/malware:**
   ```bash
   sudo apt install rkhunter chkrootkit
   sudo rkhunter --check
   sudo chkrootkit
   ```

### After Incident

- [ ] Document what happened
- [ ] Update security measures
- [ ] Review and improve monitoring
- [ ] Consider professional security audit

---

## 📋 Security Audit Checklist

Perform monthly:

- [ ] Review all passwords (rotate if >90 days)
- [ ] Check 2FA is enabled on all accounts
- [ ] Review user accounts (remove unused)
- [ ] Check VPN killswitch is working
- [ ] Verify SSL certificates are valid
- [ ] Review Alertmanager logs for security alerts
- [ ] Check for container updates
- [ ] Review disk usage (detect log spam)
- [ ] Test backup restoration
- [ ] Review firewall rules
- [ ] Check for exposed ports: `sudo netstat -tlnp`
- [ ] Review Docker privileged containers
- [ ] Check GitHub security advisories for dependencies

---

## 📚 Additional Resources

### Security Tools

- [Lynis](https://cisofy.com/lynis/) - Security auditing tool
- [Docker Bench Security](https://github.com/docker/docker-bench-security) - Docker security checker
- [OWASP ZAP](https://www.zaproxy.org/) - Web application security scanner
- [Have I Been Pwned](https://haveibeenpwned.com/) - Check if your accounts were breached

### Documentation

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Nextcloud Security Hardening](https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html)

### GitHub Security

- [GitHub Security Best Practices](https://docs.github.com/en/code-security/getting-started/securing-your-organization)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [GitHub Dependabot](https://docs.github.com/en/code-security/dependabot)

---

## ⚖️ Legal & Compliance

### Data Privacy

This stack processes personal data. Depending on your jurisdiction:

- **GDPR (EU):** Ensure proper data handling, user consent, and right to deletion
- **CCPA (California):** Similar requirements for California residents
- **Local laws:** Check your local data protection regulations

### P2P File Sharing

- Only share content you have rights to distribute
- Be aware of copyright laws in your jurisdiction
- Use VPN to protect privacy (already configured)
- Monitor bandwidth usage to avoid ISP throttling

### Logging & Retention

- Logs may contain personal information
- Implement retention policies (30 days configured)
- Secure log storage and access
- Comply with local data retention laws

---

**Remember: Security is not a one-time setup, it's an ongoing process!**

Last updated: December 2025
