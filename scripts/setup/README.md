# Setup Scripts

This directory contains setup and configuration scripts for PotatoStack.

## Main Setup Script

### `setup-potatostack.sh`

Complete system setup for PotatoStack on Debian 13 (Trixie).

**What it does:**

1. System update and dependencies
2. Docker Engine + Docker Compose installation
3. Docker post-installation (non-root access)
4. Optional Docker rootless mode
5. Development tools (yamllint, shellcheck, shfmt, prettier, trivy)
6. System optimization (sysctl, limits, tmpfs)
7. Host-level tuning (zram, fstrim, journald)
8. Storage directory setup
9. Autostart configuration
10. **UFW firewall setup with Docker integration**
11. Verification and testing
12. Zsh + Oh-My-Zsh + Powerlevel10k shell configuration

**Usage:**

```bash
# Full setup
sudo bash scripts/setup/setup-potatostack.sh

# With options
SETUP_ROOTLESS=true sudo bash scripts/setup/setup-potatostack.sh
SETUP_AUTOSTART=false sudo bash scripts/setup/setup-potatostack.sh
```

**Hardware optimized for:**

- Intel Twin Lake N150 (3.6GHz)
- 16GB RAM
- 512GB SSD

**Features:**

- ✅ UFW firewall with ufw-docker integration
- ✅ Allows: SSH (22), HTTP (80), HTTPS (443), DNS (53)
- ✅ Blocks all other incoming ports
- ✅ BBR congestion control
- ✅ zram swap (25% RAM)
- ✅ SSD optimizations
- ✅ Security hardening

## Firewall Management

### `setup-ufw-rules.sh`

Comprehensive UFW firewall management for Docker containers.

**Commands:**

```bash
# Install and configure UFW
sudo bash scripts/setup/setup-ufw-rules.sh install

# Show firewall status
sudo bash scripts/setup/setup-ufw-rules.sh status

# List Docker container rules
sudo bash scripts/setup/setup-ufw-rules.sh list

# Apply PotatoStack rules
sudo bash scripts/setup/setup-ufw-rules.sh apply

# Allow container port (interactive)
sudo bash scripts/setup/setup-ufw-rules.sh allow

# Deny container port (interactive)
sudo bash scripts/setup/setup-ufw-rules.sh deny

# Reset and reconfigure
sudo bash scripts/setup/setup-ufw-rules.sh reset

# Show help
sudo bash scripts/setup/setup-ufw-rules.sh help
```

**What it does:**

- ✅ Installs UFW and ufw-docker
- ✅ Configures default policies (deny incoming, allow outgoing)
- ✅ Allows essential ports (22, 80, 443, 53)
- ✅ Integrates with Docker networking
- ✅ Manages container-specific firewall rules

**Quick access via Makefile:**

```bash
make firewall-status    # Show status
make firewall-install   # Install and configure
make firewall-list      # List Docker rules
make firewall-allow     # Allow port (interactive)
make firewall-deny      # Deny port (interactive)
make firewall-reset     # Reset and reconfigure
```

## Other Setup Scripts

### `setup-autostart.sh`

Configures systemd service for PotatoStack autostart.

**Usage:**

```bash
sudo bash scripts/setup/setup-autostart.sh
```

**Features:**

- ✅ Creates systemd service unit
- ✅ Enables autostart on boot
- ✅ Graceful shutdown handling
- ✅ Dependency ordering (after docker.service)

### `setup-soulseek-symlinks.sh`

Creates symlinks for Soulseek media sharing.

**Usage:**

```bash
sudo bash scripts/setup/setup-soulseek-symlinks.sh
```

**What it does:**

- Links media directories to Soulseek shared folder
- Organizes by media type (Music, Movies, TV Shows, etc.)

## Directory Structure

```
scripts/setup/
├── README.md                      # This file
├── setup-potatostack.sh           # Main setup script
├── setup-ufw-rules.sh             # UFW firewall management
├── setup-autostart.sh             # Systemd autostart
└── setup-soulseek-symlinks.sh     # Soulseek media links
```

## Common Workflows

### Initial Server Setup

```bash
# 1. Run main setup script
sudo bash scripts/setup/setup-potatostack.sh

# 2. Verify firewall
make firewall-status

# 3. Configure .env file
cp .env.example .env
nano .env

# 4. Start stack
make up

# 5. Verify services
make health
make test
```

### Add New Public Service

```bash
# 1. Add service to docker-compose.yml with Traefik labels
# 2. No firewall changes needed (uses Traefik ports 80/443)
# 3. Restart stack
docker compose up -d
```

### Expose Container Port Directly

```bash
# 1. Allow the container port (interactive)
make firewall-allow
# or
sudo ufw-docker allow mycontainer 8080

# 2. Verify rule
make firewall-list

# 3. Test access
curl http://your-ip:8080
```

### Troubleshoot Firewall Issues

```bash
# 1. Check status
make firewall-status

# 2. Check Docker rules
make firewall-list

# 3. Check UFW logs
sudo tail -f /var/log/ufw.log

# 4. Check Traefik
docker logs traefik

# 5. Check CrowdSec bans
docker exec crowdsec cscli decisions list
```

## Environment Variables

### Setup Script Variables

```bash
# Docker user (default: current user)
DOCKER_USER=myuser

# Enable rootless mode (default: false)
SETUP_ROOTLESS=true

# Enable autostart (default: true)
SETUP_AUTOSTART=true

# Example
DOCKER_USER=myuser SETUP_AUTOSTART=false \
  sudo -E bash scripts/setup/setup-potatostack.sh
```

### Host Binding

Default bind address for LAN-only services:

```bash
HOST_BIND=192.168.178.158  # Set in .env
```

Services bound to HOST_BIND are accessible only from LAN, not internet.

## Security Notes

### Firewall Architecture

```
Internet
  ↓
UFW (ports 22, 80, 443, 53 allowed)
  ↓
ufw-docker (container-specific rules)
  ↓
Traefik (reverse proxy on 80/443)
  ↓
CrowdSec (IPS/threat intelligence)
  ↓
Services
```

### Best Practices

- ✅ Use Traefik for all web services (ports 80/443)
- ✅ Keep admin interfaces on HOST_BIND (LAN-only)
- ✅ Never expose databases directly (5432, 6379, 27017)
- ✅ Regular updates: `docker compose pull`
- ✅ Monitor logs: `docker compose logs -f`
- ✅ Check CrowdSec: `docker exec crowdsec cscli metrics`

### Port Strategy

| Type     | Method              | Examples         | UFW Rule Needed? |
| -------- | ------------------- | ---------------- | ---------------- |
| Public   | Internet → Traefik  | Web services     | No (uses 80/443) |
| LAN      | LAN → HOST_BIND     | Admin panels     | No (LAN-only)    |
| Direct   | Internet → Port     | Special cases    | Yes (use ufw-docker) |
| Internal | Container network   | Databases        | No (internal)    |

## Documentation

- **Complete Guide:** `../../docs/firewall-security.md`
- **Quick Reference:** `../../docs/FIREWALL-QUICKSTART.md`
- **Project Docs:** `../../docs/README.md`
- **Integration Summary:** `../../UFW-INTEGRATION-SUMMARY.md`

## Testing

After running setup scripts:

```bash
# Validate configuration
make validate

# Run tests
make test

# Check health
make health

# Verify firewall
make firewall-status
```

## Troubleshooting

### "Permission denied" errors

```bash
# Scripts need execute permission
chmod +x scripts/setup/*.sh

# Run with sudo
sudo bash scripts/setup/setup-potatostack.sh
```

### "UFW is inactive"

```bash
# Enable UFW
sudo ufw enable

# Or re-run setup
make firewall-install
```

### "Docker containers can't reach internet"

```bash
# Check outgoing policy
sudo ufw status verbose
# Should show: Default: allow (outgoing)

# Fix if needed
sudo ufw default allow outgoing
sudo ufw reload
```

### "Locked out of SSH"

From console/cloud panel:

```bash
sudo ufw allow 22/tcp
sudo ufw reload
```

## Support

- **Issues:** Open issue in repository
- **Documentation:** Check `docs/` directory
- **Community:** PotatoStack forums/Discord

## Contributing

When adding new setup scripts:

1. Follow existing naming convention: `setup-*.sh`
2. Include comprehensive help message
3. Add to this README
4. Test on fresh Debian 13 installation
5. Document in main docs if user-facing

## License

Same as PotatoStack project.
