#!/bin/bash
# Auto-import Grafana dashboards from Grafana.com

GRAFANA_URL="${GRAFANA_URL:-http://192.168.178.158:3002}"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_ADMIN_PASSWORD}"

echo "=== Grafana Dashboard Import Tool ==="
echo "Waiting for Grafana to be ready..."
sleep 10

# Dashboard IDs to import (best for PotatoStack)
declare -A DASHBOARDS=(
	["17346"]="Traefik"
	["13639"]="Loki Logs"
	["1860"]="Node Exporter Full"
	["3662"]="Prometheus Stats"
	["9628"]="PostgreSQL Database"
	["11835"]="Redis"
	["2583"]="MongoDB"
	["14519"]="CrowdSec"
	["14978"]="Netdata"
)

for DASHBOARD_ID in "${!DASHBOARDS[@]}"; do
	NAME="${DASHBOARDS[$DASHBOARD_ID]}"
	echo "Importing: $NAME (ID: $DASHBOARD_ID)"

	curl -s -X POST \
		-H "Content-Type: application/json" \
		-u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
		"$GRAFANA_URL/api/dashboards/import" \
		-d "{
      \"dashboard\": {
        \"id\": null,
        \"uid\": null,
        \"title\": \"$NAME\"
      },
      \"overwrite\": true,
      \"inputs\": [{
        \"name\": \"DS_PROMETHEUS\",
        \"type\": \"datasource\",
        \"pluginId\": \"prometheus\",
        \"value\": \"Prometheus\"
      }],
      \"folderId\": 0,
      \"pluginId\": \"$DASHBOARD_ID\"
    }" >/dev/null 2>&1

	if [ $? -eq 0 ]; then
		echo "✓ Successfully imported: $NAME"
	else
		echo "✗ Failed to import: $NAME"
	fi
done

echo ""
echo "Dashboard import complete!"
echo "Access Grafana at: $GRAFANA_URL"
