# Update Strategy - Diun + Renovate

## Overview

PotatoStack uses a **notify-only** update strategy for maximum safety and control:

- **Diun** (Docker Image Update Notifier) - Detects new image versions and sends notifications
- **Renovate** - Creates automated PRs to update image tags in `.env.example`
- **Manual Review** - You decide when to apply updates after testing

This approach prevents automatic updates from breaking your stack and gives you full control over the update process.

---

## Why Not Watchtower?

**Watchtower** automatically pulls and restarts containers with new images. While convenient, this has risks:

❌ **Breaking Changes** - New versions may have incompatible changes
❌ **No Rollback** - Hard to revert if update causes issues
❌ **Downtime** - Services restart without warning
❌ **Database Migrations** - May fail or corrupt data
❌ **No Testing** - Changes go live immediately

**Diun + Renovate** provides a safer workflow:

✅ **Notification Only** - You control when to update
✅ **Review Changes** - Check release notes before applying
✅ **Staged Rollout** - Test updates in dev environment first
✅ **Easy Rollback** - Just revert the PR
✅ **Scheduled Maintenance** - Update during planned downtime

---

## How It Works

### 1. Diun Monitors Images

Diun runs every 6 hours and checks all running containers for new image versions:

```yaml
# config/diun/diun.yml
watch:
  schedule: "0 */6 * * *"  # Every 6 hours
  compareDigest: true      # Compare image digests
```

When a new version is detected, Diun sends a notification via your configured method (Telegram, Discord, Email, etc.).

### 2. Renovate Creates PRs

Renovate scans `.env.example` for image tags and creates pull requests when new versions are available:

```json
// renovate.json
{
  "regexManagers": [
    {
      "fileMatch": ["^\\.env(\\..*)?$", "^\\.env\\.example$"],
      "matchStrings": ["(?<depName>[A-Z_]+)_TAG=(?<currentValue>[^\n]+)"],
      "datasourceTemplate": "docker"
    }
  ]
}
```

Renovate PRs include:
- Version bump details
- Release notes links
- Compatibility information
- Recommended merge strategy

### 3. You Review and Apply

1. Check Diun notifications for critical updates
2. Review Renovate PRs for details
3. Test updates in a dev environment (optional)
4. Merge PR and update `.env` file
5. Apply changes: `docker-compose pull && docker-compose up -d`

---

## Configuration

### Diun Notifications

Edit `config/diun/diun.yml` to configure your notification method:

#### Telegram

```yaml
notif:
  telegram:
    token: YOUR_BOT_TOKEN
    chatIDs:
      - YOUR_CHAT_ID
```

**Setup:**
1. Create bot via [@BotFather](https://t.me/BotFather)
2. Get bot token
3. Send message to bot, then get chat ID: `https://api.telegram.org/bot<TOKEN>/getUpdates`

#### Discord

```yaml
notif:
  discord:
    webhookURL: https://discord.com/api/webhooks/YOUR_WEBHOOK_URL
    mentions:
      - "@everyone"
```

**Setup:**
1. Server Settings → Integrations → Webhooks
2. Create New Webhook
3. Copy webhook URL

#### Email (SMTP)

```yaml
notif:
  mail:
    host: smtp.gmail.com
    port: 587
    ssl: false
    username: ${ALERT_EMAIL_USER}
    password: ${ALERT_EMAIL_PASSWORD}
    from: ${ALERT_EMAIL_USER}
    to: ${ALERT_EMAIL_TO}
```

**For Gmail:**
1. Enable 2FA on your Google account
2. Generate App Password: https://myaccount.google.com/apppasswords
3. Use app password in `ALERT_EMAIL_PASSWORD`

#### Gotify (Self-Hosted)

```yaml
notif:
  gotify:
    endpoint: http://gotify:80
    token: YOUR_APP_TOKEN
    priority: 5
```

**Setup:**
1. Deploy Gotify container (optional)
2. Create application in Gotify UI
3. Copy app token

### Renovate Configuration

Your `renovate.json` is already configured. To customize:

```json
{
  "schedule": ["every weekend"],  // Update check frequency
  "automerge": false,             // Never auto-merge (safer)
  "separateMajorMinor": true,     // Separate PRs for major vs minor
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "groupName": "docker images",
      "separateMajorMinor": true
    }
  ]
}
```

---

## Update Workflow

### Weekly Maintenance Window

1. **Check Diun Logs**
   ```bash
   docker logs diun --tail 50
   ```

2. **Review Available Updates**
   ```bash
   # Check which images have updates
   docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}"
   ```

3. **Review Renovate PRs** (if using GitHub/GitLab)
   - Check PR description for breaking changes
   - Review release notes links
   - Check for security patches

4. **Update .env File**
   ```bash
   # Option 1: Accept Renovate PR (recommended)
   git merge renovate/docker-images

   # Option 2: Manual update
   nano .env.example
   # Update specific tags, e.g., GRAFANA_TAG=10.4.3 → 10.4.4
   ```

5. **Apply Updates**
   ```bash
   # Pull new images
   docker-compose pull

   # Recreate containers with new images
   docker-compose up -d

   # Check logs for errors
   docker-compose logs -f --tail 100
   ```

6. **Verify Services**
   ```bash
   # Check all services are healthy
   docker-compose ps

   # Check Homepage dashboard
   # Check Grafana dashboards
   # Check Uptime Kuma
   ```

7. **Cleanup Old Images**
   ```bash
   docker image prune -a
   ```

### Emergency Security Updates

For critical security patches:

1. **Check CVE Severity**
   - Review security advisory
   - Check if your version is affected

2. **Immediate Update**
   ```bash
   # Update specific service tag in .env
   sed -i 's/GRAFANA_TAG=.*/GRAFANA_TAG=10.4.5/' .env.example

   # Pull and restart only affected service
   docker-compose pull grafana
   docker-compose up -d grafana

   # Monitor logs
   docker logs grafana -f
   ```

3. **Verify Fix**
   - Check service is running
   - Verify vulnerability is patched
   - Monitor for 24 hours

### Rolling Back Updates

If an update causes issues:

1. **Revert to Previous Tag**
   ```bash
   # Edit .env to use old tag
   nano .env.example
   # Change GRAFANA_TAG=10.4.4 back to GRAFANA_TAG=10.4.3

   # Pull old image (if not pruned)
   docker-compose pull grafana
   docker-compose up -d grafana
   ```

2. **Revert Git Commit** (if using version control)
   ```bash
   git revert HEAD
   docker-compose pull
   docker-compose up -d
   ```

---

## Monitoring Updates

### Diun Metrics

Diun doesn't expose Prometheus metrics by default, but you can check update status:

```bash
# View Diun database
sqlite3 ./data/diun/diun.db "SELECT * FROM images;"

# Check notification history
docker logs diun --since 24h | grep "New image"
```

### Homepage Widget

Add Diun to Homepage dashboard:

```yaml
# config/homepage/services.yaml
- Management:
    - Diun:
        icon: mdi-bell-alert
        description: Docker Image Updates
        container: diun
        widget:
          type: customapi
          url: http://diun:8080/api/status  # If using HTTP server
```

---

## Best Practices

### 1. Pin Image Tags

✅ **Good:**
```bash
GRAFANA_TAG=10.4.3
PROMETHEUS_TAG=v2.52.0
```

❌ **Bad:**
```bash
GRAFANA_TAG=latest
PROMETHEUS_TAG=latest
```

**Why:** `latest` tag is unpredictable and can break your stack unexpectedly.

### 2. Test Critical Updates

Before updating production:
1. Backup current state: `docker-compose down && tar -czf backup.tar.gz /mnt/seconddrive`
2. Update in test environment
3. Run for 24-48 hours
4. Apply to production during maintenance window

### 3. Read Release Notes

Always check:
- **Breaking changes** - May require config changes
- **Database migrations** - May need manual steps
- **Deprecations** - Features being removed
- **Security fixes** - Priority updates

### 4. Stagger Updates

Don't update everything at once:
- **Week 1:** Monitoring stack (Prometheus, Grafana, Loki)
- **Week 2:** Storage & Backup (Nextcloud, Kopia)
- **Week 3:** Management tools (Portainer, Homepage)
- **Week 4:** Applications (Gitea, NPM)

This limits blast radius if updates cause issues.

### 5. Backup Before Updates

```bash
# Backup critical data
./scripts/backup-before-update.sh

# Or manual backup
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz \
  ./data \
  ./config \
  /mnt/seconddrive/nextcloud \
  /mnt/seconddrive/gitea

docker-compose up -d
```

---

## Troubleshooting

### Diun Not Sending Notifications

```bash
# Check Diun logs
docker logs diun

# Common issues:
# 1. Wrong notification config
# 2. Firewall blocking outbound connections
# 3. Invalid tokens/credentials

# Test notification manually
docker exec diun diun notif test
```

### Renovate Not Creating PRs

1. Check Renovate is enabled on your repo
2. Verify `renovate.json` syntax: https://docs.renovatebot.com/configuration-options/
3. Check Renovate dashboard: https://app.renovatebot.com/dashboard
4. Review Renovate logs in GitHub Actions

### Update Broke Service

```bash
# Quick rollback
docker-compose down
git revert HEAD
docker-compose up -d

# Or restore from backup
tar -xzf backup-20250107.tar.gz
docker-compose up -d
```

---

## Migration from Watchtower

If you previously used Watchtower:

1. **Remove Watchtower container** ✅ (already done)
   - Replaced with Diun in docker-compose.yml
   - Removed all `watchtower.enable` labels

2. **Configure Diun notifications**
   ```bash
   nano config/diun/diun.yml
   # Add your preferred notification method
   ```

3. **Restart stack**
   ```bash
   docker-compose up -d
   ```

4. **Verify Diun is running**
   ```bash
   docker logs diun
   # Should see: "Diun started"
   ```

5. **Update .env for future updates**
   - Renovate will create PRs for tag updates
   - OR manually update tags in .env.example

---

## Additional Resources

- **Renovate Setup Guide**: See `docs/RENOVATE_SETUP.md` for detailed Renovate configuration
- **Diun Documentation**: https://crazymax.dev/diun/
- **Renovate Documentation**: https://docs.renovatebot.com/
- **Docker Security Best Practices**: https://docs.docker.com/engine/security/
- **Semantic Versioning**: https://semver.org/

---

**Last Updated:** 2025-12-07
**Stack Version:** PotatoStack 2.0
