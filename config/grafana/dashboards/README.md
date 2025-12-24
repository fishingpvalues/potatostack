# Grafana SOTA 2025 Dashboards

This directory contains pre-configured Grafana dashboards for monitoring the PotatoStack.

## How to Add Dashboards

1. Download dashboards from https://grafana.com/grafana/dashboards/
2. Save the JSON file in this directory
3. Restart Grafana: `docker compose restart grafana`

## Recommended SOTA 2025 Dashboards

### System Monitoring
- **Node Exporter Full** (ID: 1860) - Comprehensive system metrics
- **Docker Container & Host Metrics** (ID: 179) - Container monitoring
- **cAdvisor** (ID: 14282) - Detailed container stats

### Loki & Logs
- **Loki Stack Monitoring** (ID: 14055) - Loki stack health
- **Loki Logs Dashboard** (ID: 15324) - Log visualization
- **Logging Dashboard via Loki** (ID: 12611) - Application logs

### Application Specific
- **Prometheus 2.0 Stats** (ID: 3662) - Prometheus metrics
- **Blackbox Exporter** (ID: 7587) - Endpoint monitoring
- **Speedtest** (ID: 13665) - Network speed tracking
- **Fritzbox** (ID: 13983) - Router metrics

### Docker & Containers
- **Docker Monitoring** (ID: 893) - Docker overview
- **Docker Swarm & Container Overview** (ID: 609)
- **Portainer** (ID: 12831) - Container management stats

## Auto-Import Dashboard IDs

You can also set these in the Grafana environment variable:
```yaml
GF_INSTALL_PLUGINS: grafana-clock-panel,grafana-simple-json-datasource
GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: /var/lib/grafana/dashboards/home.json
```

## Quick Import via CLI

```bash
# Example: Download Node Exporter Full dashboard
curl -o config/grafana/dashboards/node-exporter-full.json \
  https://grafana.com/api/dashboards/1860/revisions/latest/download

# Restart Grafana
docker compose restart grafana
```

## Dashboard Categories

- **system/** - System and hardware metrics
- **containers/** - Docker and container metrics
- **apps/** - Application-specific dashboards
- **network/** - Network and connectivity
- **logs/** - Log aggregation and analysis
