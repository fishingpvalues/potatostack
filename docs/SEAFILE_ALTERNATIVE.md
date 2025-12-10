Based on your Docker Compose stack running on a low-power ARM64 SBC like the Le Potato with only 2GB RAM, Nextcloud is generally not ideal due to its high resource demands (typically requiring 4GB+ RAM for smooth operation with multiple users or features enabled, and it's PHP-heavy, which can lead to CPU spikes and slow performance on ARM hardware). Your setup is already optimized with memory limits (e.g., many services capped at 128-256MB), monitoring (Prometheus/Grafana), VPN routing, and lightweight file access via Filebrowser/Samba/SFTP, so a replacement should prioritize minimal CPU/RAM usage while providing core Nextcloud-like features such as file syncing, sharing, web UI access, and mobile/desktop clients.

Recommended Alternative: Seafile

After reviewing various options (including ownCloud Infinite Scale, Pydio, Syncthing, and Cozy Cloud), Seafile stands out as the best low-resource fit for your stack.

Key Advantages for Your Setup

- Low Resource Usage:
  - Minimum: 1 core CPU, 1GB RAM (with 512MB swap if needed).
  - Recommended: 2 cores, 2GB+ RAM—aligned with Le Potato.
  - In practice, Seafile idles at ~100–200MB RAM and low CPU; faster syncing than Nextcloud.
- ARM Compatibility: Official aarch64 images; proven on SBCs.
- Essential Features: File syncing/sharing via web UI, desktop and mobile apps; versioning; links; optional OnlyOffice integration.
- Docker Integration: Works with existing MariaDB/Redis; easy to reverse proxy; can be monitored.
- Security: Encryption, 2FA, audit logs.

Compose Integration (added to docker-compose.yml)

services:
  seafile-db:
    image: mariadb:10.11
    container_name: seafile-db
    restart: unless-stopped
    networks: [default]
    environment:
      - MYSQL_ROOT_PASSWORD=${SEAFILE_DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=seafile
      - MYSQL_USER=seafile
      - MYSQL_PASSWORD=${SEAFILE_DB_PASSWORD}
    volumes:
      - seafile_db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "--password=${SEAFILE_DB_ROOT_PASSWORD}"]
      interval: 30s
      timeout: 10s
      retries: 5
    mem_limit: 128m
    cpus: 0.5

  seafile-memcached:
    image: memcached:alpine
    container_name: seafile-memcached
    restart: unless-stopped
    networks: [default]
    entrypoint: ["memcached", "-m", "128"]
    mem_limit: 128m
    cpus: 0.25

  seafile:
    image: seafileltd/seafile-mc:latest
    container_name: seafile
    restart: unless-stopped
    networks: [default, proxy, monitoring]
    ports:
      - "${HOST_BIND:-0.0.0.0}:8001:80"
    environment:
      - DB_HOST=seafile-db
      - DB_ROOT_PASSWD=${SEAFILE_DB_ROOT_PASSWORD}
      - SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
      - SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
      - SEAFILE_SERVER_LETSENCRYPT=false
      - SEAFILE_SERVER_HOSTNAME=seafile.${HOST_DOMAIN:-lepotato.local}
      - TIME_ZONE=Europe/Berlin
      - MEMCACHED_LOCATION=seafile-memcached:11211
    volumes:
      - /mnt/seconddrive/seafile:/shared
    depends_on:
      seafile-db:
        condition: service_healthy
      seafile-memcached:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget --spider --quiet http://localhost/seafile || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    mem_limit: 384m
    mem_reservation: 256m
    cpus: 1

Volumes:

  seafile_db_data:

Setup Steps

1) Add to .env: `SEAFILE_DB_ROOT_PASSWORD`, `SEAFILE_DB_PASSWORD`, `SEAFILE_ADMIN_EMAIL`, `SEAFILE_ADMIN_PASSWORD`.
2) Start: `docker compose up -d seafile-db seafile-memcached seafile`.
3) Reverse proxy with Nginx Proxy Manager; set SSL; optional Authelia protection.
4) Add Seafile DB to backups (already integrated in db-backups service).
5) Monitor via Prometheus (blackbox targets added for internal/external access).

Alternatives Considered

- ownCloud Infinite Scale: lightweight Go binary, but tends to use more RAM over time; ARM support OK.
- Syncthing: ultra-light P2P sync; no central web portal for sharing—use alongside Filebrowser.
- Pydio Cells: heavier footprint; closer to Nextcloud in resource use.
- Cozy Cloud: lighter but ARM images and stability vary.

