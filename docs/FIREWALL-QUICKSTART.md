# UFW Firewall Quick Start Guide

## TL;DR - Essential Commands

```bash
# Check firewall status
make firewall-status

# Install/configure UFW (first time only)
make firewall-install

# Apply PotatoStack rules
make firewall-apply

# List Docker container rules
make firewall-list
```

## Initial Setup (One-Time)

During PotatoStack installation, UFW is automatically configured by `setup-potatostack.sh`. If you need to set it up manually:

```bash
# Install and configure UFW
sudo bash scripts/setup/setup-potatostack.sh

# Or just the firewall part
make firewall-install
```

**What this does:**

- ✅ Installs UFW
- ✅ Installs ufw-docker
- ✅ Allows SSH (22), HTTP (80), HTTPS (443), DNS (53)
- ✅ Blocks all other incoming ports
- ✅ Enables UFW

## Quick Status Check

```bash
# Using Makefile (recommended)
make firewall-status

# Direct UFW command
sudo ufw status verbose

# Check Docker-specific rules
sudo ufw-docker list
```

## Common Operations

### 1. Allow a Docker Container Port

```bash
# Interactive (recommended for beginners)
make firewall-allow
# Follow the prompts

# Direct command
sudo ufw-docker allow <container-name> <port> <protocol>

# Examples
sudo ufw-docker allow traefik 80
sudo ufw-docker allow traefik 443
sudo ufw-docker allow adguardhome 53
```

### 2. Remove a Docker Container Port

```bash
# Interactive
make firewall-deny

# Direct command
sudo ufw-docker deny <container-name> <port>
```

### 3. Check Current Rules

```bash
# Show all UFW rules
sudo ufw status numbered

# Show Docker-specific rules
sudo ufw-docker list
make firewall-list

# Show raw iptables rules
sudo iptables -L -n -v
```

### 4. Emergency Access

If you get locked out:

```bash
# From console/physical access
sudo ufw disable
sudo ufw allow 22/tcp
sudo ufw enable
```

## Service Access Patterns

### Public Services (via Traefik)

**Access:** Internet → UFW (443) → Traefik → Service

**Configuration:** Already handled by Traefik labels in docker-compose.yml

**Examples:**

- `https://nextcloud.yourdomain.com`
- `https://jellyfin.yourdomain.com`
- `https://vault.yourdomain.com`

**Firewall:** No additional UFW rules needed (uses ports 80/443)

### LAN-Only Services

**Access:** `http://192.168.178.40:PORT`

**Configuration:** Already bound to HOST_BIND in docker-compose.yml

**Examples:**

- `http://192.168.178.40:9090` (Prometheus)
- `http://192.168.178.40:3002` (Grafana)
- `http://192.168.178.40:19999` (Netdata)

**Firewall:** No UFW rules needed (LAN-only, not exposed to internet)

### Exposing New Public Services

If you want to expose a service directly to the internet (not recommended, use Traefik instead):

```bash
# Allow the container port
sudo ufw-docker allow <container-name> <port>

# Example: Expose SSH on a container
sudo ufw-docker allow my-vps 2222
```

**⚠️ Warning:** Only do this if you can't use Traefik. Direct exposure bypasses CrowdSec protection!

## Troubleshooting

### "Connection refused" from internet

1. Check UFW allows the port:

```bash
sudo ufw status | grep <port>
```

2. Check Docker rule exists:

```bash
sudo ufw-docker list
```

3. Add rule if missing:

```bash
sudo ufw-docker allow <container> <port>
```

### "Can't access any services"

UFW might be blocking everything:

```bash
# Check status
sudo ufw status

# Temporarily disable for testing
sudo ufw disable

# If that fixes it, check your rules
sudo ufw status numbered

# Re-enable
sudo ufw enable
```

### "Locked out of SSH"

From cloud console or physical access:

```bash
sudo ufw allow 22/tcp
sudo ufw reload
```

### "Docker containers can't reach internet"

Check outgoing policy:

```bash
sudo ufw status verbose
# Should show: Default: allow (outgoing)
```

If blocked:

```bash
sudo ufw default allow outgoing
sudo ufw reload
```

## Security Best Practices

### ✅ DO

- ✅ Use Traefik for all web services
- ✅ Keep most services on LAN-only (HOST_BIND)
- ✅ Regularly check `make firewall-status`
- ✅ Review CrowdSec bans: `docker exec crowdsec cscli decisions list`
- ✅ Monitor logs: `docker logs traefik`

### ❌ DON'T

- ❌ Expose database ports (PostgreSQL, MongoDB, Redis)
- ❌ Disable UFW permanently
- ❌ Open port ranges (`ufw allow 1000:2000/tcp`)
- ❌ Bypass Traefik for web services
- ❌ Forget to backup your rules

## Common Ports Reference

### Allowed by Default

| Port | Service      | Purpose              |
| ---- | ------------ | -------------------- |
| 22   | SSH          | Remote administration |
| 80   | Traefik      | HTTP (→ HTTPS)       |
| 443  | Traefik      | HTTPS (main entry)   |
| 53   | AdGuard Home | DNS server           |

### LAN-Only Services (HOST_BIND)

| Port  | Service           | URL                               |
| ----- | ----------------- | --------------------------------- |
| 8088  | Traefik Dashboard | `http://192.168.178.40:8088`      |
| 9090  | Prometheus        | `http://192.168.178.40:9090`      |
| 3002  | Grafana           | `http://192.168.178.40:3002`      |
| 19999 | Netdata           | `http://192.168.178.40:19999`     |
| 3100  | Loki              | `http://192.168.178.40:3100`      |
| 8089  | cAdvisor          | `http://192.168.178.40:8089`      |

### Never Expose Publicly

| Port  | Service    | Reason               |
| ----- | ---------- | -------------------- |
| 5432  | PostgreSQL | Security risk        |
| 6379  | Redis      | Security risk        |
| 27017 | MongoDB    | Security risk        |
| 2375  | Docker API | Remote code execution |

## Advanced: Manual Configuration

### Add Custom Rule

```bash
# Allow from specific IP
sudo ufw allow from 1.2.3.4 to any port 22

# Allow port range
sudo ufw allow 6000:6010/tcp

# Allow specific network
sudo ufw allow from 192.168.1.0/24

# Delete rule by number
sudo ufw status numbered
sudo ufw delete [number]
```

### Backup/Restore Rules

```bash
# Backup
sudo cp /etc/ufw/user.rules ~/ufw-backup-$(date +%F).rules
sudo cp /etc/ufw/user6.rules ~/ufw6-backup-$(date +%F).rules

# Restore
sudo cp ~/ufw-backup.rules /etc/ufw/user.rules
sudo ufw reload
```

### Reset Everything

```bash
# Reset UFW completely (WARNING: removes all rules!)
make firewall-reset

# Or manually
sudo ufw disable
sudo ufw reset
sudo ./scripts/setup/setup-ufw-rules.sh install
```

## Monitoring & Logs

```bash
# UFW logs
sudo tail -f /var/log/ufw.log

# See blocked connections
sudo grep -i block /var/log/ufw.log | tail -20

# CrowdSec decisions (IP bans)
docker exec crowdsec cscli decisions list

# Traefik access logs
docker logs traefik | tail -50
```

## Getting Help

1. Check the full documentation: `docs/firewall-security.md`
2. Run stack tests: `make test`
3. Check container logs: `docker logs <service>`
4. View Traefik dashboard: `http://192.168.178.40:8088`

## Emergency Recovery

If you completely break your firewall:

```bash
# 1. Disable UFW
sudo ufw disable

# 2. Reset to defaults
sudo ufw reset

# 3. Re-run setup
make firewall-install

# 4. Verify SSH still works BEFORE enabling
sudo ufw allow 22/tcp

# 5. Enable UFW
sudo ufw enable

# 6. Check status
make firewall-status
```

---

**Remember:** The goal is to have:

- **Public access:** Only through Traefik (ports 80/443)
- **LAN access:** Direct via HOST_BIND for monitoring/admin tools
- **No access:** Databases and internal services (Docker network only)

For detailed security architecture, see: `docs/firewall-security.md`
