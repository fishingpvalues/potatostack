# AGENTS.md - Development Guidelines for PotatoStack

## Overview
This repository contains PotatoStack, a comprehensive Docker Compose-based self-hosted infrastructure stack. It includes two variants:
- **Main Stack**: Full-featured stack for Mini PC (16GB RAM) with 60+ services
- **Light Stack**: Lean stack for resource-constrained devices (2GB RAM)

## Build/Development Commands

### Docker Compose Commands
```bash
# Start main stack
docker compose up -d

# Start light stack
cd light && docker compose up -d

# Start with optional services (light stack)
cd light && docker compose --profile optional up -d

# Start specific services only
docker compose up -d postgres mongo redis

# Stop all services
docker compose down

# Stop and remove volumes (DANGER - destroys data)
docker compose down -v

# Check service status
docker compose ps

# View logs for specific service
docker compose logs -f jellyfin

# View logs for all services
docker compose logs

# Restart specific service
docker compose restart sonarr

# Update all containers via Watchtower
# (runs automatically at 3 AM daily)
```

### Single Test Commands
```bash
# Test VPN connectivity (Gluetun)
curl http://localhost:8000/v1/publicip/ip

# Test database connectivity
docker compose exec postgres pg_isready -U postgres
docker compose exec mongo mongosh --eval "db.adminCommand('ping')"

# Test service healthchecks
docker compose ps --format "table {{.Name}}\t{{.Status}}"

# Test resource usage
docker stats --no-stream

# Test VPN status
curl http://localhost:8000/v1/openvpn/status
```

### Build/Lint/Typecheck Commands
```bash
# Validate docker-compose.yml syntax
docker compose config

# Lint docker-compose.yml (requires docker-compose-lint)
docker-compose-lint docker-compose.yml

# Check for security issues in Docker images
docker compose pull && docker scan $(docker compose images -q)

# Validate environment variables
docker compose config --quiet
```

## Code Style Guidelines

### Docker Compose Conventions

#### Service Naming
- Use lowercase with hyphens: `nextcloud-aio`, `firefly-importer`
- Database services: `{service}-db` or `{service}-postgres`
- Worker services: `{service}-worker`
- UI services: Keep simple names like `grafana`, `portainer`

#### Environment Variables
- Prefix with service name: `POSTGRES_SUPER_PASSWORD`, `GRAFANA_USER`
- Use uppercase with underscores
- Document required variables in comments
- Use `.env` file for secrets (never commit)

#### Port Mapping
- Bind to `HOST_BIND` variable (default: 192.168.178.40)
- Standard ports: web=80, ssl=443, admin ports=8xxx
- Document ports in comments: `# Admin UI`

#### Volume Naming
- Database volumes: `{service}-data`
- Config volumes: `{service}-config`
- Logs volumes: `{service}-logs`
- Use named volumes over bind mounts where possible

#### Labels
- Security headers middleware: `traefik.http.routers.{service}.middlewares=security-headers@docker`
- Enable Traefik: `traefik.enable=true`
- Watchtower updates: `com.centurylinklabs.watchtower.enable=true`
- Autoheal: `autoheal=true`

#### Healthchecks
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 30s
```

### YAML Formatting
- Use 2-space indentation
- Group related services with comments
- Document complex configurations inline
- Use anchors for repeated configurations: `x-common-env: &common-env`

### Networking
- Use dedicated network: `potatostack`
- Subnet: `172.21.0.0/16`
- Bridge driver with custom name: `br-potato`

### Resource Management
- Set memory limits for all services
- Use reservations for guaranteed minimums
- CPU limits where needed (0.1-1.0 cores)
- Logging: max 10m size, 3 files, compressed

### Security Best Practices
- Non-root users: `PUID=1000`, `PGID=1000`
- No privileged containers unless required
- VPN killswitch for download services
- TLS everywhere with Traefik/Let's Encrypt
- Secrets in environment variables, never in code

### Error Handling
- Use `restart: unless-stopped` for production services
- Implement healthchecks for critical services
- Graceful shutdown with `stop_grace_period`
- Autoheal for automatic recovery

### Logging
```yaml
logging: *default-logging
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
    compress: "true"
```

### Dependencies
- Use `depends_on` with health checks where possible
- Start databases first, then applications
- Use `condition: service_healthy` for proper startup order

### Environment Variables Structure
```bash
# Network
HOST_BIND=192.168.178.40
HOST_DOMAIN=local.domain

# Databases
POSTGRES_SUPER_PASSWORD=...
MONGO_ROOT_PASSWORD=...

# VPN
VPN_PROVIDER=surfshark
VPN_USER=...
VPN_PASSWORD=...

# Services (one per service)
SERVICE_API_KEY=...
SERVICE_SECRET_KEY=...
```

### File Organization
```
/
├── docker-compose.yml          # Main stack
├── light/
│   ├── docker-compose.yml      # Light stack
│   └── README.md              # Light stack docs
├── config/                     # Service configurations
│   ├── grafana/
│   ├── prometheus/
│   └── ...
├── scripts/                    # Utility scripts
├── CLAUDE.md                   # Agent instructions
└── README.md                   # Main documentation
```

### Naming Conventions
- Services: lowercase, descriptive (`jellyfin`, `nextcloud-aio`)
- Volumes: `{service}-{purpose}` (`postgres-data`, `grafana-config`)
- Networks: `potatostack`
- Environment files: `.env` (gitignored)

### Documentation
- Document ports and access URLs in README
- Include resource requirements
- Provide troubleshooting commands
- Update service list when adding/removing services

### Version Pinning
- Use specific tags, not `latest`: `postgres:16-alpine`
- Document version variables: `POSTGRES_TAG=16`
- Test upgrades before updating tags

### Backup Strategy
- Database backups via respective services
- Volume backups via Kopia (light) or external tools
- Config backup: repository + `.env` file (encrypted)
- Test restore procedures regularly

### Monitoring
- Prometheus for metrics collection
- Grafana for dashboards
- Loki/Promtail for centralized logging
- Node Exporter for system metrics
- Uptime Kuma for external monitoring

## Development Workflow

1. **Local Development**
   ```bash
   # Clone repository
   git clone <repo>
   cd potatostack

   # Copy environment template
   cp .env.example .env

   # Edit configuration
   nano .env

   # Start development stack
   docker compose up -d

   # Monitor logs
   docker compose logs -f
   ```

2. **Testing Changes**
   ```bash
   # Validate configuration
   docker compose config

   # Test startup
   docker compose up -d --scale <service>=0  # Start without specific service
   docker compose up -d <service>            # Start only specific service

   # Check health
   docker compose ps
   docker stats
   ```

3. **Adding New Services**
   ```bash
   # Add service to docker-compose.yml
   # Update README.md with new ports/services
   # Test startup order with depends_on
   # Add healthcheck
   # Set resource limits
   # Add to monitoring if needed
   ```

4. **Security Review**
   ```bash
   # Check for exposed ports
   docker compose config | grep -A5 ports

   # Validate no secrets in compose file
   grep -r "password\|secret\|key" docker-compose.yml | grep -v "PASSWORD\|SECRET\|KEY"

   # Test network isolation
   docker network ls
   ```

## Performance Optimization

- **Memory**: Total ~13.5GB for main stack, ~1.2GB for light
- **CPU**: 4+ cores recommended for main stack
- **Storage**: SSD + HDD recommended, separate cache disk
- **Network**: 1GB Ethernet minimum

## Troubleshooting Commands

```bash
# Check service health
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# View resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check VPN status
curl http://localhost:8000/v1/openvpn/status

# Database connectivity
docker compose exec postgres pg_isready -U postgres

# View recent logs
docker compose logs --tail=100 -f <service>

# Restart unhealthy services
docker compose restart $(docker compose ps --filter "status=unhealthy" --format "{{.Name}}")
```</content>
<filePath>AGENTS.md