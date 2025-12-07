# Renovate Setup Guide

## What is Renovate?

Renovate is an automated dependency update tool that:
- ✅ Scans your `.env.example` for Docker image tags
- ✅ Checks Docker Hub/registries for new versions
- ✅ Creates pull requests with version updates
- ✅ Groups related updates together (e.g., all Grafana stack)
- ✅ Runs on a schedule (weekends only by default)

Combined with **Diun** (notifications), you get a complete update management workflow.

---

## Setup Options

### Option 1: GitHub (Recommended)

If your repository is on GitHub:

1. **Install Renovate GitHub App**
   - Go to: https://github.com/apps/renovate
   - Click "Install"
   - Select your repository
   - Grant permissions

2. **Renovate will automatically:**
   - Detect `renovate.json` in your repo
   - Start scanning `.env.example` for updates
   - Create PRs every weekend (configurable)

3. **Configure (Optional)**
   ```bash
   # Edit schedule in renovate.json
   nano renovate.json

   # Change from:
   "schedule": ["every weekend"]

   # To (examples):
   "schedule": ["every monday"]  # Weekly on Mondays
   "schedule": ["on the first day of the month"]  # Monthly
   "schedule": ["after 10pm every weekday"]  # Nightly
   ```

### Option 2: GitLab

If using GitLab:

1. **Enable Renovate via Pipeline**

   Create `.gitlab-ci.yml`:
   ```yaml
   renovate:
     image: renovate/renovate:latest
     script:
       - renovate
     only:
       - schedules
   ```

2. **Add CI/CD Variables** (Settings → CI/CD → Variables):
   - `RENOVATE_TOKEN`: GitLab Personal Access Token
   - `RENOVATE_PLATFORM`: `gitlab`

3. **Create Pipeline Schedule** (CI/CD → Schedules):
   - Interval: Weekly
   - Target branch: `main`

### Option 3: Self-Hosted (Advanced)

Run Renovate as a cron job on your Le Potato:

1. **Install Renovate CLI**
   ```bash
   npm install -g renovate
   ```

2. **Create config file** (`~/.renovaterc.json`):
   ```json
   {
     "platform": "gitea",
     "endpoint": "http://192.168.178.40:3001/api/v1",
     "token": "YOUR_GITEA_TOKEN",
     "repositories": ["username/potatostack"]
   }
   ```

3. **Add cron job**
   ```bash
   crontab -e

   # Run every Sunday at 2 AM
   0 2 * * 0 cd /path/to/potatostack && renovate
   ```

4. **Test manually**
   ```bash
   cd /path/to/potatostack
   renovate --dry-run
   ```

---

## How Renovate Works with Your Stack

### 1. Image Tag Detection

Renovate scans `.env.example` for patterns like:
```bash
GRAFANA_TAG=10.4.3
PROMETHEUS_TAG=v2.52.0
GLUETUN_TAG=latest
```

### 2. Docker Registry Lookups

For each tag, Renovate:
- Queries the Docker registry (Docker Hub, ghcr.io, etc.)
- Finds the actual image name from the mapping in `renovate.json`
- Checks for new versions

**Mappings configured:**
- `GRAFANA_TAG` → `grafana/grafana`
- `PROMETHEUS_TAG` → `prom/prometheus`
- `GLUETUN_TAG` → `qmcgaw/gluetun`
- `QBITTORRENT_TAG` → `lscr.io/linuxserver/qbittorrent`
- And 22 more...

### 3. Pull Request Creation

When updates are found, Renovate creates PRs:

**Example PR Title:**
> Update monitoring stack (Prometheus v2.52.0 → v2.53.0, Grafana 10.4.3 → 10.5.0)

**PR Description includes:**
- Release notes links
- Breaking changes warnings
- Compatibility information
- Recommended merge strategy

### 4. Grouping Strategy

Updates are grouped by category:

| Group | Images Included |
|-------|----------------|
| **monitoring stack** | Prometheus, Grafana, Loki, Promtail, Alertmanager, exporters |
| **storage and backup** | Nextcloud, MariaDB, PostgreSQL, Kopia, Redis |
| **networking** | Gluetun, qBittorrent, slskd, Nginx Proxy Manager |
| **management tools** | Portainer, Diun, Uptime Kuma, Dozzle, Homepage, Autoheal |
| **git server** | Gitea (separate due to database migrations) |

**Benefits:**
- Fewer PRs to review
- Test related services together
- Easier rollback if grouped update fails

---

## Configuration Reference

### Schedule Control

```json
// renovate.json
{
  "schedule": ["every weekend"],  // Default: Saturday & Sunday
  "prConcurrentLimit": 5,         // Max 5 PRs open at once
  "prHourlyLimit": 2              // Max 2 PRs per hour
}
```

**Common schedules:**
- `["every weekend"]` - Saturday & Sunday
- `["before 5am on Monday"]` - Early Monday morning
- `["after 10pm every weekday"]` - Nightly on weekdays
- `["on the first day of the month"]` - Monthly updates

### Update Types

```json
{
  "matchUpdateTypes": ["major"],      // Breaking changes (1.x → 2.x)
  "matchUpdateTypes": ["minor"],      // Features (1.2.x → 1.3.x)
  "matchUpdateTypes": ["patch"]       // Bug fixes (1.2.3 → 1.2.4)
}
```

**Labels applied:**
- `major-update` - Requires testing, may break things
- `minor-update` - New features, should be safe
- `security` - CVE fixes, high priority

### Disable Updates for Specific Images

If you want to keep a specific version:

```json
{
  "packageRules": [
    {
      "matchPackageNames": ["nextcloud"],
      "enabled": false,
      "description": "Keep Nextcloud at current version"
    }
  ]
}
```

### Pin to Specific Version Range

```json
{
  "packageRules": [
    {
      "matchPackageNames": ["mariadb"],
      "allowedVersions": "10.11.x",
      "description": "Only allow MariaDB 10.11 patches"
    }
  ]
}
```

---

## Workflow Examples

### Weekly Update Cycle

**Sunday Morning:**
1. Renovate runs (scheduled)
2. Creates PRs for available updates
3. Sends notification (if configured)

**Sunday Afternoon:**
1. Review Renovate PRs on GitHub/GitLab
2. Check release notes for breaking changes
3. Decide which updates to apply

**Sunday Evening:**
1. Merge approved PRs
2. Pull changes: `git pull`
3. Update `.env`: `cp .env.example .env`
4. Apply updates: `docker-compose pull && docker-compose up -d`
5. Monitor logs: `docker-compose logs -f`

### Emergency Security Update

**Scenario:** CVE discovered in Grafana

1. **Diun notifies you** (via Telegram/Discord/Email)
2. **Check Renovate dashboard** - PR likely already created
3. **Review PR** - Check it's the CVE fix version
4. **Merge immediately**
5. **Apply update:**
   ```bash
   git pull
   nano .env  # Update GRAFANA_TAG
   docker-compose pull grafana
   docker-compose up -d grafana
   ```

### Staging Updates (Advanced)

Test updates before production:

1. **Create staging branch:**
   ```bash
   git checkout -b staging
   ```

2. **Configure Renovate for staging:**
   ```json
   {
     "baseBranches": ["staging"],
     "schedule": ["after 10pm every weekday"]
   }
   ```

3. **Merge staging PRs** → test for 24-48h
4. **If stable:** merge staging to main
5. **Apply to production**

---

## Monitoring Renovate

### Dependency Dashboard

Renovate creates an issue in your repo: **"Dependency Dashboard"**

Shows:
- ✅ Pending updates
- ✅ Rate-limited PRs
- ✅ Ignored updates
- ✅ Errors

**GitHub:** Issues tab → "Dependency Dashboard"
**GitLab:** Issues tab → "Dependency Dashboard"

### Renovate Logs

**GitHub:**
- Go to Actions tab
- Click latest Renovate workflow run
- View logs

**Self-Hosted:**
```bash
# View last run logs
cat ~/.renovate/renovate.log

# Test configuration
renovate --dry-run --print-config
```

### Common Errors

**"No versions found"**
- Check image name mapping in `renovate.json`
- Verify image exists on Docker Hub/registry

**"Rate limit exceeded"**
- Docker Hub: Create account, add token
- GitHub: Check API rate limits

**"Update ignored"**
- Check packageRules for disabled packages
- Review Dependency Dashboard for ignored list

---

## Integration with Diun

**Diun + Renovate = Complete Update Management**

| Tool | Purpose | Trigger | Output |
|------|---------|---------|--------|
| **Diun** | Notify of new versions | Every 6 hours | Telegram/Discord/Email |
| **Renovate** | Create update PRs | Weekends | GitHub/GitLab PR |

### Workflow:

1. **Diun detects** new Grafana version → sends Telegram notification
2. **You review** notification, decide if urgent
3. **Renovate creates PR** next weekend with Grafana update
4. **You merge PR** after reviewing release notes
5. **Apply update** during maintenance window

### Configure Diun to Skip "Latest" Tags

Since Renovate is disabled for `latest` tags, configure Diun similarly:

```yaml
# config/diun/diun.yml
defaults:
  watchRepo: true
  notifyOn:
    - new
    - update

providers:
  docker:
    watchByDefault: true
    watchStopped: false
```

---

## Best Practices

### 1. Review Before Merging

Never blindly merge Renovate PRs:
- ✅ Read PR description
- ✅ Check release notes links
- ✅ Look for "BREAKING CHANGE" markers
- ✅ Review migration guides

### 2. Test Major Updates

For major version bumps (1.x → 2.x):
1. Create test branch
2. Apply update in dev environment
3. Run for 24-48 hours
4. Check logs for errors
5. Only then apply to production

### 3. Stagger Updates

Don't update everything at once:
- Week 1: Merge monitoring stack PR
- Week 2: Merge storage & backup PR
- Week 3: Merge management tools PR

### 4. Keep .env.example Updated

Always update `.env.example` via PRs:
```bash
# After merging Renovate PR:
git pull
cp .env.example .env  # Copy new versions

# Or selectively update:
grep "GRAFANA_TAG" .env.example >> .env
```

### 5. Security Updates Priority

Label security updates for quick action:
```json
{
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security", "urgent"]
  }
}
```

---

## Troubleshooting

### Renovate Not Creating PRs

1. **Check Renovate is enabled:**
   - GitHub: Renovate app installed?
   - GitLab: Pipeline schedule active?
   - Self-hosted: Cron job running?

2. **Verify configuration:**
   ```bash
   # Validate renovate.json syntax
   renovate-config-validator

   # Or use online validator
   # https://app.renovatebot.com/config-validator
   ```

3. **Check logs** for errors

4. **Test manually:**
   ```bash
   # GitHub
   # Trigger manually via Actions → Renovate → Run workflow

   # Self-hosted
   cd /path/to/potatostack
   renovate --dry-run
   ```

### PRs Have Wrong Image Names

If PR references wrong image:
1. Check `depNameTemplate` in `renovate.json`
2. Verify mapping matches `docker-compose.yml`
3. Example fix:
   ```json
   {
     "matchStrings": ["GRAFANA_TAG=(?<currentValue>[^\\n]+)"],
     "depNameTemplate": "grafana/grafana"  // Must match exact image
   }
   ```

### Too Many PRs Created

Reduce PR rate:
```json
{
  "prConcurrentLimit": 2,  // Max 2 PRs open
  "prHourlyLimit": 1,      // Max 1 PR per hour
  "groupName": "all docker images"  // Group everything into 1 PR
}
```

---

## Migration Guide

### From Manual Updates

**Before:**
```bash
# Every week, manually check for updates
docker images
nano .env.example  # Update tags manually
docker-compose pull
docker-compose up -d
```

**After:**
```bash
# Renovate creates PR automatically
# You just review and merge
git pull
cp .env.example .env
docker-compose pull && docker-compose up -d
```

### From Watchtower

**Before (Watchtower):**
- Auto-updates every 24h (risky)
- No control over updates
- Breaking changes go live immediately

**After (Diun + Renovate):**
- Diun notifies of updates
- Renovate creates PRs
- You control when to update
- Review breaking changes first

---

## Additional Resources

- **Renovate Docs**: https://docs.renovatebot.com/
- **Configuration Options**: https://docs.renovatebot.com/configuration-options/
- **Regex Manager Guide**: https://docs.renovatebot.com/modules/manager/regex/
- **Renovate Dashboard**: https://app.renovatebot.com/dashboard

---

**Last Updated:** 2025-12-07
**Configuration Version:** 2.0
