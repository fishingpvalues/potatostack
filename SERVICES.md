# Service Access Ports

Default HOST_BIND: `192.168.178.40`

## Dashboard & Management
- **Glance Dashboard**: http://192.168.178.40:3006
- **Portainer**: https://192.168.178.40:9443
- **Traefik Dashboard**: http://192.168.178.40:8080
- **Nginx Proxy Manager**: http://192.168.178.40:81

## Reverse Proxy
- **Traefik HTTP**: 80
- **Traefik HTTPS**: 443
- **NPM HTTP**: 8081
- **NPM HTTPS**: 4443

## Databases
- **Adminer**: http://192.168.178.40:8090
- **Elasticsearch**: http://192.168.178.40:9200
- **Kibana**: http://192.168.178.40:5601

## Authentication
- **Authentik**: http://192.168.178.40:9000 / https://192.168.178.40:9443
- **Vaultwarden**: http://192.168.178.40:8888

## Cloud & Storage
- **Nextcloud**: http://192.168.178.40:8082
- **Syncthing**: http://192.168.178.40:8384

## Finance
- **Firefly III**: http://192.168.178.40:8083
- **Firefly Importer**: http://192.168.178.40:8084

## Media Management (*arr behind VPN - via Gluetun)
- **Gluetun Control**: http://192.168.178.40:8000
- **Sonarr**: http://192.168.178.40:8989
- **Radarr**: http://192.168.178.40:7878
- **Prowlarr**: http://192.168.178.40:9696
- **Lidarr**: http://192.168.178.40:8686
- **Readarr**: http://192.168.178.40:8787
- **Bazarr**: http://192.168.178.40:6767
- **Maintainerr**: http://192.168.178.40:6246

## Media Servers
- **Jellyfin**: http://192.168.178.40:8096
- **Jellyseerr**: http://192.168.178.40:5055
- **Overseerr**: http://192.168.178.40:5056
- **Audiobookshelf**: http://192.168.178.40:13378

## Downloads (behind VPN)
- **qBittorrent**: http://192.168.178.40:8282
- **Aria2 WebUI**: http://192.168.178.40:6880

## Photos
- **Immich**: http://192.168.178.40:2283

## Monitoring
- **Prometheus**: http://192.168.178.40:9090
- **Grafana**: http://192.168.178.40:3000
- **Loki**: http://192.168.178.40:3100
- **Node Exporter**: http://192.168.178.40:9100
- **cAdvisor**: http://192.168.178.40:9200
- **Fritzbox Exporter**: http://192.168.178.40:9787
- **Netdata**: http://192.168.178.40:19999
- **Uptime Kuma**: http://192.168.178.40:3001

## Automation
- **n8n**: http://192.168.178.40:5678
- **Huginn**: http://192.168.178.40:3002
- **Healthchecks**: http://192.168.178.40:8001

## Utilities
- **Rustypaste**: http://192.168.178.40:8085
- **Stirling PDF**: http://192.168.178.40:8086
- **Linkding**: http://192.168.178.40:9091
- **Cal.com**: http://192.168.178.40:3003
- **Code Server**: http://192.168.178.40:8443
- **Draw.io**: http://192.168.178.40:8087
- **Excalidraw**: http://192.168.178.40:8088
- **Atuin**: http://192.168.178.40:8889

## Development
- **Gitea**: http://192.168.178.40:3004
- **Gitea SSH**: port 2222
- **Drone**: http://192.168.178.40:8089
- **Sentry**: http://192.168.178.40:9092

## AI & Special
- **Open WebUI**: http://192.168.178.40:3005
- **OctoBot**: http://192.168.178.40:5001
- **Pinchflat**: http://192.168.178.40:8945

## Network Services
- **Tailscale**: Mesh VPN (host network mode)

## Notes

- Services behind Gluetun VPN: All *arr apps, qBittorrent, Aria2
- Configure Traefik/NPM for domain-based routing
- Use Tailscale for secure remote access
- Default credentials vary by service - check individual docs
