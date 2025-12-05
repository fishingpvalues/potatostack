```yaml
version: '3.8'

services:
  kopia:
    image: kopia/kopia:latest  # Multi-arch manifest auto-detects ARM64 for Le Potato
    container_name: kopia_server
    hostname: lepotato-backup
    restart: unless-stopped
    
    # Networking: Expose on all interfaces for local network access (Fritzbox LAN)
    # For external access, configure port forwarding on your router to 192.168.178.40:51515
    # WARNING: Exposing to the internet requires strong auth and ideally a reverse proxy with proper TLS
    ports:
      - "0.0.0.0:51515:51515"
      # Optional: Expose metrics port for Prometheus monitoring
      - "51516:51516"

    # SOTA Resource Management for SBCs (Le Potato: Quad-core ARM, limited RAM)
    # Environment tweaks for low-power devices
    environment:
      - TZ=Europe/Berlin  # Adjust to your timezone
      # Repo connection password (used when connecting from clients or init)
      - KOPIA_PASSWORD=change_this_to_a_strong_password  # CHANGE THIS!
      # Go runtime optimizations: Lower GC threshold to prevent OOM on SBCs
      - GOGC=50
      # Limit threads to 2 cores on quad-core SBC to prevent lockups during heavy I/O
      - GOMAXPROCS=2
      # Kopia paths - all on external HDD for performance and longevity
      - KOPIA_CONFIG_PATH=/app/config/repository.config
      - KOPIA_CACHE_DIRECTORY=/app/cache
      - KOPIA_LOG_DIR=/app/logs
      # Enable Prometheus metrics for monitoring (expose if needed)
      - KOPIA_PROMETHEUS_ENABLED=true
      - KOPIA_PROMETHEUS_LISTEN_ADDR=:51516  # Optional: Expose metrics on another port

    # Mounts: Persist everything to external HDD (/mnt/seconddrive) to spare SD card/eMMC
    volumes:
      # Repository data (backups stored here)
      - /mnt/seconddrive/kopia/repository:/repository
      # Config files (repository.config, certs, etc.)
      - /mnt/seconddrive/kopia/config:/app/config
      # Cache for faster metadata operations - crucial for SBC performance
      - /mnt/seconddrive/kopia/cache:/app/cache
      # Detailed logs
      - /mnt/seconddrive/kopia/logs:/app/logs
      # Optional: Mount host root for backing up the Le Potato itself (read-only)
      - /:/host:ro
      # Temp dir for large operations (e.g., restores) - on HDD to avoid SD wear
      - /mnt/seconddrive/kopia/tmp:/tmp

    # Security: Use Docker secrets for sensitive data (create secrets files first)
    # Example: echo "strong_repo_pass" > kopia_password.txt; docker secret create kopia_password kopia_password.txt
    # But for simplicity, using env above; switch to secrets in production
    # secrets:
    #   - kopia_password
    # Then reference as --password=/run/secrets/kopia_password in init commands

    # Capabilities for advanced features like snapshot mounting (FUSE)
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/fuse:/dev/fuse

    # Healthcheck: Ensure server is running and responsive
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:51515/health"]
      interval: 30s
      timeout: 10s
      retries: 3

    # Command: Start server with SOTA options
    # - Binds to all interfaces
    # - Auto-generates TLS cert with strong key
    # - Basic auth for server API (CHANGE credentials!)
    # - Debug logging for everything
    # - Metrics enabled
    command:
      - server
      - start
      - --address=0.0.0.0:51515
      - --tls-generate-cert
      - --tls-generate-rsa-key-size=4096  # Stronger key for 2025 standards
      - --server-username=admin  # CHANGE THIS!
      - --server-password=change_to_strong_password  # CHANGE THIS!
      - --log-level=debug
      - --file-log-level=debug
      - --metrics-listen-addr=:51516  # Matches env
```

This is the fully updated and optimized Docker Compose file for running Kopia as a backup server on your Le Potato SBC, incorporating all SOTA corrections and improvements as of December 2025. It ensures compatibility, performance, reliability, and security for ARM64 architecture, with all data on the external HDD to protect the SD card. The server is accessible to all devices on your local Fritzbox network at `192.168.178.40:51515`. For internet access ("reachable everywhere"), configure port forwarding on your Fritzbox router and use a VPN or reverse proxy (e.g., Nginx with Let's Encrypt) for added security—do NOT expose directly.

### Key SOTA Features and Fixes:
- **Multi-Arch Image**: Uses `kopia/kopia:latest` for automatic ARM64 detection on Le Potato, avoiding pull errors from explicit `-arm64` tags.
- **Resource Optimization**: `GOMAXPROCS=2` limits CPU threads to prevent OS lockups on the quad-core SBC during intensive tasks like hashing/encryption.
- **SD Card Protection**: All volumes (including `/tmp` for temporary files) mounted to `/mnt/seconddrive` to minimize wear on internal storage.
- **Healthcheck**: Docker automatically restarts if the server becomes unresponsive.
- **Monitoring**: Prometheus metrics enabled and optionally exposed on port 51516 for tracking backup performance (integrate with tools like Grafana/Prometheus).
- **Security**: Self-signed TLS with 4096-bit RSA key; basic auth for the server (change defaults!); optional Docker secrets for passwords.
- **Logging**: Debug-level logging to `/mnt/seconddrive/kopia/logs/` for detailed troubleshooting.
- **Accessibility**: Binds to `0.0.0.0` for full local network access; HTTPS required for clients.

### Full Setup Tutorial:
Follow these steps on your Le Potato to get the Kopia server running. Assume Docker and Docker Compose are installed (if not, install via `sudo apt update && sudo apt install docker.io docker-compose` on Debian-based systems like Armbian).

1. **Prepare Directories** (run on host to avoid permission issues):  
   This creates all necessary folders on the external HDD.  
   ```
   mkdir -p /mnt/seconddrive/kopia/{repository,config,cache,logs,tmp}
   chmod -R 777 /mnt/seconddrive/kopia  # Ensure Docker can write (adjust for security)
   ```

2. **Save the Docker Compose File**:  
   Copy the YAML above into a file named `docker-compose.yml` in a directory on your Le Potato (e.g., `~/kopia-server/`).  
   Customize as needed:  
   - Change `TZ` to your timezone (e.g., `America/New_York`).  
   - Update passwords in `environment` and `command` sections to strong, unique values.  
   - If using Docker secrets for passwords, uncomment the `secrets` section and create them first (e.g., `docker secret create kopia_password <(echo -n "your_password")`). Then adjust init commands accordingly.

3. **Initialize the Repository** (run once to create the repo):  
   This sets up the filesystem repository on the HDD. Replace `your_strong_repo_password` with a secure password (this is the repo-level password for client connections).  
   ```
   docker run --rm \
     --env KOPIA_PASSWORD=your_strong_repo_password \
     -v /mnt/seconddrive/kopia/repository:/repository \
     -v /mnt/seconddrive/kopia/config:/app/config \
     -v /mnt/seconddrive/kopia/cache:/app/cache \
     -v /mnt/seconddrive/kopia/logs:/app/logs \
     -v /mnt/seconddrive/kopia/tmp:/tmp \
     kopia/kopia:latest \
     repository create filesystem --path=/repository --password=your_strong_repo_password
   ```

4. **Connect and Add Server User** (run once for access control):  
   This connects to the repo and adds a user for server authentication. Replace `your_strong_repo_password` and `your_strong_user_password` with secure values. The username format is `user@hostname` (use `localhost` or your domain).  
   ```
   docker run --rm \
     --env KOPIA_PASSWORD=your_strong_repo_password \
     -v /mnt/seconddrive/kopia/repository:/repository \
     -v /mnt/seconddrive/kopia/config:/app/config \
     -v /mnt/seconddrive/kopia/cache:/app/cache \
     -v /mnt/seconddrive/kopia/logs:/app/logs \
     -v /mnt/seconddrive/kopia/tmp:/tmp \
     kopia/kopia:latest \
     repository connect filesystem --path=/repository --password=your_strong_repo_password && \
     server user add --user=admin@localhost --password=your_strong_user_password
   ```

5. **Start the Server**:  
   From the directory with `docker-compose.yml`:  
   ```
   docker compose up -d
   ```
   Verify it's running: `docker ps` (look for `kopia_server`). Check logs: `docker logs kopia_server` or view files in `/mnt/seconddrive/kopia/logs/`.

6. **Client Connection (from other devices)**:  
   - Install Kopia on clients (e.g., via official downloads for Windows/Mac/Linux).  
   - Connect to the repository: Use `https://192.168.178.40:51515` as the server URL.  
   - Authenticate with server basic auth (`admin` / `your_strong_user_password`) and repo password (`your_strong_repo_password`).  
   - Trust the self-signed cert (Kopia will prompt for the fingerprint on first connect). For production, replace with a proper cert.  
   - Create policies and snapshots as per Kopia docs (e.g., `kopia policy set --add-ignore .git` for global ignores).

7. **Monitoring and Maintenance**:  
   - **Metrics**: If exposed, access at `http://192.168.178.40:51516/metrics`. Set up Prometheus to scrape this for dashboards on backup sizes, errors, etc.  
   - **Updates**: Pull new images with `docker compose pull` and restart: `docker compose up -d`.  
   - **Troubleshooting**: If errors, check logs. Common issues: Wrong passwords (re-init if needed), HDD mount failures (ensure `/mnt/seconddrive` is accessible), or port conflicts.  
   - **Security Tips**: Use strong, unique passwords; restrict firewall to local network (e.g., `ufw allow from 192.168.178.0/24 to any port 51515`); consider adding a reverse proxy for external access with client certs or OAuth.

This setup is SOTA for 2025, balancing performance on limited SBC hardware with robust features. For more, refer to Kopia docs at kopia.io or their GitHub. If you need further customizations (e.g., integrating with Traefik for reverse proxy), let me know!