# Quick Start Guide - Full Monitoring Stack

## 1. Prerequisites Check
```bash
# Verify config files exist
ls -la config/prometheus/prometheus.yml
ls -la config/prometheus/alerts/
ls -la config/grafana/provisioning/datasources/
ls -la config/loki/loki.yml

# If any missing, create them from this repo
```

## 2. Set Environment Variables
```bash
# Edit .env file
nano .env

# Add these (replace with secure passwords):
GRAFANA_ADMIN_PASSWORD=your-secure-password
MINIFLUX_ADMIN_PASSWORD=your-secure-password
```

## 3. Start Monitoring Stack
```bash
# Pull images first (faster startup)
docker compose pull prometheus grafana loki alloy

# Start all monitoring services
docker compose up -d prometheus grafana loki alloy
```

## 4. Verify Services Started
```bash
# Check all monitoring containers are running
docker ps | grep -E "prometheus|grafana|loki|alloy"

# Should see 10+ containers
```

## 5. Access Grafana
```bash
# Wait 30 seconds for startup
sleep 30

# Open in browser: http://192.168.178.158:3002
# Login: admin / <your GRAFANA_ADMIN_PASSWORD>
```

## 6. Import Dashboards (Method 1: Auto)
```bash
# Run auto-import script
./scripts/import/import-grafana-dashboards.sh
```

## 6. Import Dashboards (Method 2: Manual)
In Grafana UI:
1. Click "+" (left sidebar) → "Import"
2. Enter dashboard ID: **893** (Docker Containers)
3. Select datasource: **Prometheus**
4. Click "Import"

Repeat for these IDs:
- **17346** - Traefik
- **13639** - Loki Logs  
- **1860** - Node Exporter
- **3662** - Prometheus Stats

## 7. Verify Metrics Collection
```bash
# Check Prometheus targets (should all be UP)
curl -s http://192.168.178.158:9090/api/v1/targets | grep -o '"health":"[^"]*"' | sort | uniq -c


```

## 8. Test Loki Logs
In Grafana:
1. Go to "Explore" (compass icon)
2. Select datasource: **Loki**
3. Enter query: `{container_name="prometheus"}`
4. Click "Run query"
5. Should see Prometheus logs

## 9. Configure Alerts (Optional)
```bash
# Check alerts loaded
curl -s http://192.168.178.158:9090/api/v1/rules | jq '.data.groups[].name'

# Should show: "PotatoStack Infrastructure" and "Application Health"
```

## 10. Monitor Your Stack!

### Primary Dashboards
1. **Docker Containers Dashboard** - Daily monitoring
   - CPU/RAM per container
   - Network I/O
   - Container restarts

2. **Traefik Dashboard** - HTTP traffic
   - Requests per second
   - Error rates
   - Backend health

3. **Loki Logs Dashboard** - Log analysis
   - Error logs
   - Container logs
   - Log volume
### Real-time Monitoring
  - Live system metrics
  - CPU per core
  - RAM breakdown

## Troubleshooting

### "No data" in Grafana
```bash
# Check Prometheus is scraping
docker logs prometheus | grep "Scrape"

```

### High RAM usage
```bash
# Check which monitoring service uses most RAM
docker stats --no-stream | grep -E "prometheus|grafana|loki"

# If Loki is high, reduce ingestion limits in config/loki/loki.yml
```

## Summary

**Monitoring Stack RAM:** ~3.7GB  
**Total Stack RAM:** ~12.5-14GB / 16GB  
**Services:** 100 total (95 original + 5 monitoring)  
**Dashboards:** 11 pre-configured  
**Metrics Retention:** 30 days (Prometheus)
**Log Retention:** 30 days (Loki)

**Main URL:** http://192.168.178.158:3002 (Grafana)

Done! 🎉
