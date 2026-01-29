# Notification Setup Guide for PotatoStack

This guide covers all notification integrations in PotatoStack using ntfy as primary push notification service.

## Overview

ntfy is a push-based pub/sub notification service (HTTP POST/PUT to topic URLs) that receives real-time alerts from various services and forwards them to subscribed clients (web app, Android/iOS apps, CLI, etc.).

## Core Components

### 1. ntfy Service
- **URL**: `https://ntfy.yourdomain.com` (or `http://ntfy:80` internally)
- **Topics**:
  - `potatostack` - Default notifications
  - `potatostack-critical` - Critical alerts (urgent)
  - `potatostack-warning` - Warning alerts
  - `potatostack-info` - Informational messages
- **Authentication**: Configurable via `NTFY_TOKEN` (optional)
- **Metrics**: Available at `/metrics` endpoint (scraped by Prometheus)

### 2. notify.sh Helper Script
Location: `scripts/monitor/notify.sh`

Shared notification utility for all monitor scripts.

**Functions:**
- `ntfy_send(title, message, priority, tags, topic, click)` - Send notification with headers
- `ntfy_send_json(topic, title, message, priority, tags, click, attach, filename, icon)` - Send JSON payload
- `ntfy_send_critical(title, message)` - Send to critical topic
- `ntfy_send_warning(title, message)` - Send to warning topic
- `ntfy_send_info(title, message)` - Send to info topic

**Environment Variables:**
- `NTFY_INTERNAL_URL` - ntfy internal URL (default: `http://ntfy:80`)
- `NTFY_TOPIC` - Default topic (default: `potatostack`)
- `NTFY_TOPIC_CRITICAL` - Critical topic (default: `potatostack-critical`)
- `NTFY_TOPIC_WARNING` - Warning topic (default: `potatostack-warning`)
- `NTFY_TOPIC_INFO` - Info topic (default: `potatostack-info`)
- `NTFY_TOKEN` - Authorization token (optional)
- `NTFY_DEFAULT_TAGS` - Default tags (default: `potatostack,monitor`)
- `NTFY_DEFAULT_PRIORITY` - Default priority (default: `default`)
- `NTFY_RETRY_COUNT` - Retry attempts (default: 3)
- `NTFY_RETRY_DELAY` - Delay between retries in seconds (default: 5)
- `NTFY_TIMEOUT` - Request timeout in seconds (default: 10)

### 3. Alertmanager Integration
Location: `scripts/alertmanager/alertmanager-ntfy.py`

Converts Prometheus alerts to formatted ntfy notifications.

**Features:**
- Markdown formatting with emojis
- Severity-based topic routing (critical/warning/info)
- Alert aggregation and deduplication
- Runbook support in notifications

**Alert Flow:**
```
Prometheus → Alertmanager → alertmanager-ntfy.py → ntfy → Clients
```

## Service Integrations

### A. Native ntfy Support (Configuration Required)

#### 1. Diun (Docker Image Update Notifier)
**Status:** Already configured ✅

**Environment Variables:**
- `DIUN_NOTIF_NTFY_ENDPOINT` - ntfy endpoint
- `DIUN_NOTIF_NTFY_TOPIC` - Topic for notifications
- `DIUN_NOTIF_NTFY_TOKEN` - Optional auth token

#### 2. pyLoad (Download Manager)
**Status:** Already configured ✅

**Environment Variables:**
- `PYLOAD_ENABLE_NTFY_HOOKS=true`
- `NTFY_INTERNAL_URL`, `NTFY_TOPIC`, `NTFY_TOKEN`

#### 3. Uptime Kuma (Uptime Monitoring)
**Status:** Manual UI configuration required

**Setup:**
1. Access Uptime Kuma at `https://uptime.yourdomain.com`
2. Go to Settings → Notifications
3. Click "Add Notification" → Select "Ntfy"
4. Configure:
   - **Server URL**: `https://ntfy.yourdomain.com`
   - **Topic**: `potatostack-critical` (or custom)
   - **Priority**: `5` (max) for critical monitors
   - **Title**: `{{ $KUMA_MONITOR_NAME }}`
   - **Message**: Custom message template
5. Add notification to specific monitors

**Recommended Monitors:**
- External services (ISP, DNS)
- Critical internal services (Traefik, Authentik)
- External API endpoints

#### 4. Healthchecks (Cron Monitoring)
**Status:** Manual UI configuration required

**Setup:**
1. Access Healthchecks at `https://healthchecks.yourdomain.com`
2. Go to Integrations → Add Integration
3. Select "Ntfy" or configure custom webhook
4. Enter:
   - **Webhook URL**: `https://ntfy.yourdomain.com/potatostack-critical`
   - **Method**: POST
   - **Headers**: Add `Authorization: Bearer YOUR_TOKEN` if configured
   - **Body**: JSON template with alert details
5. Assign to specific checks or as default

#### 5. *arr Stack (Sonarr, Radarr, Prowlarr, Lidarr, Bazarr)
**Status:** Manual UI configuration required (v4+)

**Setup for each service:**
1. Access service UI (e.g., `https://sonarr.yourdomain.com`)
2. Go to Settings → Connect → Add
3. Select "Ntfy" (Sonarr v4/Radarr/Prowlarr)
4. Configure:
   - **Topic**: `potatostack` (or create service-specific topics)
   - **Tags**: e.g., `sonarr,tv`
   - **Priority**: Based on event type
   - **Notification Triggers**:
     - Download started
     - Download completed
     - Import completed
     - Upgrade detected
     - Warning/Critical errors
5. Test notification

**Alternative for v3:** Use webhook or custom script integration.

#### 6. CrowdSec (Security IPS)
**Status:** Metrics available, configure webhook in config

**Setup:**
- Metrics endpoint: `http://crowdsec:6060/metrics` (scraped by Prometheus)
- Alerts via Prometheus rules:
  - `HighAttackRate` - Blocks per second threshold
  - `CrowdSecDown` - Service unavailable
- Custom webhook: Configure in `/etc/crowdsec/notifications/`

### B. Webhook Bridge Scripts (Python)

#### 1. Jellyfin Webhook Bridge
**Service:** `jellyfin-webhook`
**Port:** 8081
**Script:** `scripts/webhooks/jellyfin-webhook.py`

**Setup in Jellyfin:**
1. Access Jellyfin at `https://jellyfin.yourdomain.com`
2. Go to Dashboard → Plugins → Catalog
3. Install "Webhook" plugin
4. Go to Dashboard → Plugins → Webhook → Add
5. Configure:
   - **Name**: ntfy notifications
   - **URL**: `https://jellyfin-webhook.yourdomain.com` (or internal `http://jellyfin-webhook:8081`)
   - **Request Type**: POST
   - **User Agent**: Jellyfin-Webhook
   - **Events to notify**:
     - Playback started/stopped
     - New library content
     - Authentication success/failure
     - Application update available
     - Item added/updated
6. Test notification

**Notifications:**
- Playback: Title, user, TV series or movie details
- Auth: Login attempts with device info
- Updates: Version info
- New content: Title and type

#### 2. Jellyseerr Webhook Bridge
**Service:** `jellyseerr-webhook`
**Port:** 8082
**Script:** `scripts/webhooks/jellyseerr-webhook.py`

**Setup in Jellyseerr:**
1. Access Jellyseerr at `https://jellyseerr.yourdomain.com`
2. Go to Settings → General → Webhooks
3. Click "Add Webhook"
4. Configure:
   - **Name**: ntfy notifications
   - **URL**: `https://jellyseerr-webhook.yourdomain.com`
   - **Events**: Request created, approved, declined, available
   - **User filter**: All users or specific
5. Save and test

**Notifications:**
- New requests: Title, media type (TV/Movie), user
- Approved: By whom, what was approved
- Available: Media ready for download
- Declined: Reason for rejection

#### 3. Miniflux Webhook Bridge
**Service:** `miniflux-webhook`
**Port:** 8083
**Script:** `scripts/webhooks/miniflux-webhook.py`

**Setup in Miniflux:**
1. Access Miniflux at `https://rss.yourdomain.com`
2. Go to Settings → Webhooks
3. Add webhook:
   - **Name**: ntfy
   - **URL**: `https://miniflux-webhook.yourdomain.com`
   - **Events**: New entries, feed changes
4. Test with specific feed or global

**Notifications:**
- New entries: Title, feed name, URL
- Feed created/deleted/modified: Feed details

### C. Prometheus/Alertmanager Alerts

**Alert Rules Location:** `config/prometheus/alerts/potatostack-alerts.yml`

**Current Alert Groups:**
1. **Critical Infrastructure**
   - `CriticalServiceDown` - Services not seen by cAdvisor
   - `ContainerCrashLooping` - Multiple restarts
   - `HighMemoryUsage` - >90% memory limit
   - `HighCPUUsage` - >80% CPU for 10 min
   - `ContainerNotRunning` - Container exited

2. **Database Health**
   - `PostgresDown`, `RedisDown`, `MongoDown`
   - Connection warnings
   - Slow queries

3. **System Health**
   - Disk space critical/low
   - High I/O, load, memory
   - Network issues

4. **Security & Ingress**
   - `TraefikDown`, `TraefikHighErrorRate`
   - `CrowdSecDown`, `HighAttackRate`

5. **VPN & Networking**
   - `GluetunDown`, `VPNTunnelDown`

6. **slskd Health**
   - Metrics down, container not seen

7. **Media Managers Health** (NEW)
   - Sonarr, Radarr, Prowlarr, Lidarr, Bazarr down

8. **Media Server Health** (NEW)
   - Jellyfin down, high CPU
   - Jellyseerr down

9. **RSS Reader Health** (NEW)
   - Miniflux metrics down

10. **Uptime Monitoring** (NEW)
    - Uptime Kuma down
    - Healthchecks down

11. **Backup & Storage Services** (NEW)
    - Kopia down
    - Scrutiny down

12. **CI/CD Health** (NEW)
    - Woodpecker server/agent down
    - Gitea down

**Alert Flow:**
```
Prometheus rules → Alertmanager → alertmanager-ntfy.py → ntfy topics → Clients
```

### D. Grafana Alerts

**Configuration:** `config/grafana/provisioning/notifiers/alerting.yml`

**Contact Points:**
- `ntfy-default` - Default notifications
- `ntfy-critical` - Critical alerts
- `ntfy-warning` - Warning alerts

**Setup Custom Alerts:**
1. Access Grafana at `https://grafana.yourdomain.com`
2. Go to Alerting → New alert rule
3. Define query and conditions
4. Set contact point to ntfy (critical/warning/default)
5. Configure notification template

**Alert Features:**
- Group by alertname, severity, job
- Repeat intervals (15m critical, 6h warning, 12h default)
- Send resolved notifications
- Markdown formatting in messages

### E. Custom Monitor Scripts

Location: `scripts/monitor/`

**Active Monitors:**
1. **disk-space-monitor.sh** - Disk usage warnings (80% warn, 90% crit)
2. **backup-monitor.sh** - Stale backup detection (48h default)
3. **db-health-monitor.sh** - Postgres, Redis, MongoDB health checks
4. **immich-log-monitor.sh** - Immich error log monitoring
5. **tailscale-connectivity-monitor.sh** - VPN connectivity
6. **internet-connectivity-monitor.sh** - Internet reachability
7. **traefik-log-monitor.sh** - Traefik error log monitoring
8. **slskd-queue-monitor.sh** - Download queue monitoring

All monitors use `notify.sh` for ntfy notifications.

## Testing Notifications

### Test from CLI

```bash
# Test default topic
curl -d "Test message" https://ntfy.yourdomain.com/potatostack

# Test with title and priority
curl -d "Test message" "https://ntfy.yourdomain.com/potatostack?title=Test+Alert&priority=high&tags=test"

# Test with JSON payload
curl -H "Title: Test JSON" -H "Tags: test,json" \
  -d '{"message": "JSON test", "value": 123}' \
  https://ntfy.yourdomain.com/potatostack

# Test critical topic
curl -d "Critical test" https://ntfy.yourdomain.com/potatostack-critical
```

### Test from Container

```bash
# Test using notify.sh inside monitor container
docker exec -it disk-space-monitor bash -c "
  . /notify.sh
  ntfy_send 'Test Alert' 'This is a test notification' 'high' 'test'
"
```

### Test Alertmanager

```bash
# Trigger test alert via Alertmanager API
curl -X POST http://alertmanager:9093/api/v1/alerts -H 'Content-Type: application/json' -d'
[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "critical",
      "service": "test"
    },
    "annotations": {
      "summary": "Test alert for ntfy",
      "description": "This is a test alert"
    }
  }
]'
```

## Client Setup

### Web App
- URL: `https://ntfy.yourdomain.com`
- Subscribe to topics
- Receive real-time notifications

### Mobile Apps
- **Android**: Install "ntfy" from F-Droid or Google Play
- **iOS**: Install "ntfy" from App Store
- Subscribe to topics: `potatostack`, `potatostack-critical`, etc.
- Configure push notifications or background polling

### CLI
```bash
# Subscribe and listen
ntfy subscribe potatostack-critical

# One-time poll
ntfy poll potatostack-critical
```

## Best Practices

### Topic Organization
- **potatostack** - General notifications, low priority
- **potatostack-critical** - Urgent alerts requiring immediate action
- **potatostack-warning** - Warnings, attention needed
- **potatostack-info** - Informational updates
- **Service-specific**: e.g., `potatostack-jellyfin`, `potatostack-sonarr`

### Priority Levels
- **1 (min)** - Debug, informational
- **2 (low)** - Normal info updates
- **3 (default)** - Standard notifications
- **4 (high)** - Warnings, attention needed
- **5 (max/urgent)** - Critical alerts, immediate action required

### Tag Usage
- Service category: `media`, `database`, `security`, `monitoring`
- Service name: `jellyfin`, `sonarr`, `postgres`, etc.
- Event type: `new`, `update`, `error`, `warning`, `critical`
- Format: `category,service,event` (e.g., `media,jellyfin,playback`)

### Alert Frequency
- **Critical**: 10s group wait, 15m repeat
- **Warning**: 1m group wait, 6h repeat
- **Info**: 30s group wait, 12h repeat

Avoid notification fatigue by:
- Setting appropriate thresholds
- Using inhibit rules (Alertmanager)
- Silencing alerts during maintenance

## Troubleshooting

### Notifications Not Received
1. Check ntfy service: `docker logs ntfy`
2. Verify topic subscription in client
3. Check network connectivity
4. Review sender logs (service-specific)
5. Test with curl CLI command

### High Notification Volume
1. Review alert rules and adjust thresholds
2. Use Alertmanager inhibit rules
3. Create silences for maintenance windows
4. Filter by priority or tags in client

### Authentication Issues
1. Verify `NTFY_TOKEN` matches ntfy config
2. Check ntfy auth mode (`NTFY_ENABLE_LOGIN`)
3. Test with curl using token header

### Webhook Failures
1. Check webhook container logs
2. Verify internal network connectivity
3. Test endpoint directly: `curl -X POST http://jellyfin-webhook:8081`
4. Review payload format in source service

## Environment Variables Reference

All ntfy-related environment variables in `.env`:

```bash
# ntfy service
NTFY_AUTH_DEFAULT_ACCESS=read-write
NTFY_ENABLE_LOGIN=false
NTFY_ENABLE_METRICS=true

# Topics
NTFY_TOPIC=potatostack
NTFY_TOPIC_CRITICAL=potatostack-critical
NTFY_TOPIC_WARNING=potatostack-warning
NTFY_TOPIC_INFO=potatostack-info

# Connection
NTFY_INTERNAL_URL=http://ntfy:80
NTFY_TOKEN=

# Defaults
NTFY_DEFAULT_TAGS=potatostack,monitor
NTFY_DEFAULT_PRIORITY=default

# Retry/Timeout
NTFY_RETRY_COUNT=3
NTFY_RETRY_DELAY=5
NTFY_TIMEOUT=10

# Webhook bridges
JELLYFIN_NTFY_PORT=8081
JELLYSEERR_NTFY_PORT=8082
MINIFLUX_NTFY_PORT=8083
```

## Additional Resources

- **ntfy Documentation**: https://ntfy.sh
- **Alertmanager**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Grafana Alerting**: https://grafana.com/docs/grafana/latest/alerting/
- **Prometheus Rules**: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/

## Support

For issues or questions:
1. Check service logs: `docker logs <service>`
2. Review ntfy metrics: http://ntfy.yourdomain.com/metrics
3. Test with curl commands above
4. Check Prometheus/Alertmanager UI for alert status
