# Quick Start Guide - Full Monitoring Stack

## 1. Prerequisites Check
```bash
# Verify config files exist
ls -la config/prometheus/prometheus.yml
ls -la config/prometheus/alerts/
ls -la config/thanos/bucket.yml
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
THANOS_TAG=latest
CADVISOR_TAG=latest
```

## 3. Start Monitoring Stack
```bash
# Pull images first (faster startup)
docker compose pull prometheus grafana thanos-sidecar thanos-store thanos-query thanos-compactor cadvisor loki

# Start all monitoring services
docker compose up -d prometheus grafana thanos-sidecar thanos-store thanos-query thanos-compactor cadvisor loki promtail netdata
```

## 4. Verify Services Started
```bash
# Check all monitoring containers are running
docker ps | grep -E "prometheus|thanos|grafana|cadvisor|netdata|loki"

# Should see 10+ containers
```

## 5. Access Grafana
```bash
# Wait 30 seconds for startup
sleep 30

# Open in browser: http://192.168.178.40:3002
# Login: admin / <your GRAFANA_ADMIN_PASSWORD>
```

## 6. Import Dashboards (Method 1: Auto)
```bash
# Run auto-import script
./import-grafana-dashboards.sh
```

## 6. Import Dashboards (Method 2: Manual)
In Grafana UI:
1. Click "+" (left sidebar) → "Import"
2. Enter dashboard ID: **893** (Docker Containers)
3. Select datasource: **Thanos**
4. Click "Import"

Repeat for these IDs:
- **17346** - Traefik
- **13639** - Loki Logs  
- **1860** - Node Exporter
- **12937** - Thanos Overview
- **3662** - Prometheus Stats

## 7. Verify Metrics Collection
```bash
# Check Prometheus targets (should all be UP)
curl -s http://192.168.178.40:9090/api/v1/targets | grep -o '"health":"[^"]*"' | sort | uniq -c

# Check Thanos can query data
curl -s http://192.168.178.40:10903/api/v1/query?query=up | jq '.data.result | length'
# Should return number > 0

# Check cAdvisor metrics
curl -s http://192.168.178.40:8089/metrics | grep container_memory_usage_bytes | wc -l
# Should return number > 0 (one per container)
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
curl -s http://192.168.178.40:9090/api/v1/rules | jq '.data.groups[].name'

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
- **Netdata**: http://192.168.178.40:19999
  - Live system metrics
  - CPU per core
  - RAM breakdown

### Long-term Analysis
- **Thanos Query**: http://192.168.178.40:10903
  - Query metrics from last year
  - Downsampled historical data

## Troubleshooting

### "No data" in Grafana
```bash
# Check Prometheus is scraping
docker logs prometheus | grep "Scrape"

# Check Thanos sidecar connected
docker logs thanos-sidecar | grep "prometheus"
```

### High RAM usage
```bash
# Check which monitoring service uses most RAM
docker stats --no-stream | grep -E "prometheus|thanos|grafana|cadvisor|loki"

# If Loki is high, reduce ingestion limits in config/loki/loki.yml
```

### Containers not showing in cAdvisor
```bash
# Restart cAdvisor
docker compose restart cadvisor

# Check it can access Docker socket
docker exec cadvisor ls /var/run/docker.sock
```

## Summary

**Monitoring Stack RAM:** ~3.7GB  
**Total Stack RAM:** ~12.5-14GB / 16GB  
**Services:** 100 total (95 original + 5 monitoring)  
**Dashboards:** 11 pre-configured  
**Metrics Retention:** 7 days (Prometheus) + 365 days (Thanos)  
**Log Retention:** 30 days (Loki)

**Main URL:** http://192.168.178.40:3002 (Grafana)

Done! 🎉
