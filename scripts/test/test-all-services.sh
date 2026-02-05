#!/bin/bash

# Comprehensive service test configuration
# Maps service names to their test methods and ports

# Service categories and ports
declare -A SERVICE_PORTS=(
	# Databases
	["postgres"]="5432"
	["pgbouncer"]="5432"
	["mongo"]="27017"
	["redis-cache"]="6379"

	# Reverse Proxy & Network
	["gluetun"]=""
	["tailscale"]=""
	["adguardhome"]="53,3000"

	# Security
	["crowdsec"]="6060"
	["fail2ban"]=""
	["vaultwarden"]="80"
	["authentik-server"]="9000,9443"
	["authentik-worker"]=""

	# Monitoring
	["prometheus"]="9090"
	["grafana"]="3000"
	["alertmanager"]="9093"
	["loki"]="3100"
	["alloy"]=""
	["netdata"]="19999"
	["uptime-kuma"]="3001"
	["scrutiny"]="8087"
	["parseable"]="8094"
	["ntfy"]="8060"
	# ["nextcloud-aio"]="8443"

	# Media - *arr stack
	["sonarr"]="8989"
	["radarr"]="7878"
	["lidarr"]="8686"
	["readarr"]="8787"
	["bazarr"]="6767"
	["prowlarr"]="9696"
	["jellyfin"]="8096"
	["jellyseerr"]="5055"
	["qbittorrent"]="8282"
	["aria2"]="6800"
	["ariang"]="6880"
	["audiobookshelf"]="13378"
	# ["pinchflat"]="8945"
	["slskd"]="2234"
	["rustypaste"]="8788"

	# Productivity
	["nextcloud-aio"]="8080"
	["paperless-ngx"]="8000"
	["stirling-pdf"]="8080"
	["karakeep"]="9091"
	["miniflux"]="8080"
	["actual-budget"]="5006"
	["homarr"]="7575"

	# Automation
	["news-pipeline"]=""
	["diun"]=""
	["autoheal"]=""
	["healthchecks"]="8000"

	# Development
	["gitea"]="3000,22"
	["gitea-runner"]=""
	["woodpecker-server"]="3006"
	["woodpecker-agent"]=""
	["code-server"]="8444"
	["oauth2-proxy"]="4180"

	# Other
	["syncthing"]="8384,22000"
	["it-tools"]="8080"
	["atuin"]="8888"
	["open-webui"]="8080"
	["immich-server"]="3001"
	["immich-machine-learning"]="3003"
	["maintainerr"]="6246"
	["velld-web"]="3010"
	["duckdb"]=""
	["wireguard"]=""
	["snapshot-scheduler"]=""
	["gluetun-monitor"]=""
	["storage-init"]=""
)

declare -A SERVICE_TYPES=(
	# Database services
	["postgres"]="database"
	["pgbouncer"]="database"
	["mongo"]="database"
	["redis-cache"]="database"

	# Web services with HTTP endpoints
	["grafana"]="http"
	["prometheus"]="http"
	["uptime-kuma"]="http"
	["homarr"]="http"
	["jellyfin"]="http"
	["sonarr"]="http"
	["radarr"]="http"
	["lidarr"]="http"
	["readarr"]="http"
	["bazarr"]="http"
	["prowlarr"]="http"
	["qbittorrent"]="http"
	["gitea"]="http"
	["woodpecker-server"]="http"
	["nextcloud-aio"]="http"
	["paperless-ngx"]="http"
	["news-pipeline"]="background"
	["code-server"]="http"
	["karakeep"]="http"
	["miniflux"]="http"
	["actual-budget"]="http"
	["vaultwarden"]="http"
	["jellyseerr"]="http"
	["syncthing"]="http"
	["healthchecks"]="http"
	["it-tools"]="http"
	["atuin"]="http"
	["open-webui"]="http"
	["immich-server"]="http"
	["stirling-pdf"]="http"
	["audiobookshelf"]="http"
	["ariang"]="http"
	# ["pinchflat"]="http"
	["slskd"]="http"
	["rustypaste"]="http"
	["maintainerr"]="http"
	["velld-web"]="http"
	["netdata"]="http"
	["alertmanager"]="http"
	["adguardhome"]="http"
	["authentik-server"]="http"
	["scrutiny"]="http"
	["parseable"]="http"
	["ntfy"]="http"
	["infisical"]="http"

	# Background services (no direct HTTP interface)
	["crowdsec"]="background"
	["fail2ban"]="background"
	["loki"]="background"
	["alloy"]="background"
	["diun"]="background"
	["autoheal"]="background"
	["gluetun"]="background"
	["gluetun-monitor"]="background"
	["tailscale"]="background"
	["gitea-runner"]="background"
	["woodpecker-agent"]="background"
	["authentik-worker"]="background"
	["oauth2-proxy"]="background"
	["immich-machine-learning"]="background"
	["aria2"]="background"
	["duckdb"]="background"
	["wireguard"]="background"
	["snapshot-scheduler"]="background"
	["storage-init"]="init"
)

# Export for use in main script
for service in "${!SERVICE_PORTS[@]}"; do
	echo "$service|${SERVICE_PORTS[$service]}|${SERVICE_TYPES[$service]}"
done
