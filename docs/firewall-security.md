# PotatoStack Firewall & Security Architecture

## Overview

PotatoStack uses a **defense-in-depth** security architecture with UFW firewall, Docker networking, Traefik reverse proxy, CrowdSec IPS, and Authentik SSO working together to protect your services.

## Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: UFW Host Firewall                                      │
│ ├─ SSH (22) ✓                                                   │
│ ├─ HTTP (80) ✓ → Traefik only                                   │
│ ├─ HTTPS (443) ✓ → Traefik only                                 │
│ ├─ DNS (53) ✓ → AdGuard Home only                               │
│ └─ All other ports ✗ DENIED                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: ufw-docker Container Rules                             │
│ ├─ Traefik container: 80, 443 allowed                           │
│ ├─ AdGuard Home: 53 allowed                                     │
│ └─ All other containers: Blocked at firewall                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Traefik Reverse Proxy                                  │
│ ├─ SSL/TLS termination (Let's Encrypt)                          │
│ ├─ HTTP → HTTPS redirect                                        │
│ ├─ Routing to internal services                                 │
│ ├─ Security headers (HSTS, CSP, etc.)                           │
│ └─ Rate limiting                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: CrowdSec IPS                                            │
│ ├─ Community threat intelligence                                │
│ ├─ Automatic IP blocking                                        │
│ ├─ Bot detection                                                 │
│ └─ CVE protection                                                │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 5: Authentik SSO                                           │
│ ├─ Single sign-on                                               │
│ ├─ Multi-factor authentication (2FA/TOTP)                       │
│ ├─ User/group management                                        │
│ └─ OIDC/SAML/LDAP provider                                      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 6: OAuth2 Proxy                                            │
│ ├─ Authorization layer                                          │
│ ├─ Session management                                           │
│ └─ User authentication enforcement                              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Application Layer                                                │
│ └─ Your services (Nextcloud, Jellyfin, etc.)                    │
└─────────────────────────────────────────────────────────────────┘
```

## UFW Configuration

### Default Policy

```bash
# Deny all incoming by default
ufw default deny incoming

# Allow all outgoing
ufw default allow outgoing
```

### Essential Rules

| Port       | Protocol | Service         | Access    | Purpose                    |
| ---------- | -------- | --------------- | --------- | -------------------------- |
| 22         | TCP      | SSH             | Public    | Remote administration      |
| 80         | TCP      | Traefik         | Public    | HTTP (redirects to HTTPS)  |
| 443        | TCP      | Traefik         | Public    | HTTPS (main entry point)   |
| 53         | TCP/UDP  | AdGuard Home    | Public    | DNS server                 |
| HOST_BIND  | Various  | Internal Servs  | LAN-only  | Direct LAN access          |

### Check UFW Status

```bash
# Show UFW status
sudo ufw status verbose

# Show numbered rules
sudo ufw status numbered

# Show raw iptables rules
sudo iptables -L -n -v
```

## Docker Integration (ufw-docker)

### Why ufw-docker?

Docker manipulates iptables directly, which **bypasses UFW rules**. The `ufw-docker` tool ensures UFW rules are properly applied to Docker containers.

### Installation

```bash
# Installed automatically by setup-potatostack.sh
sudo wget -O /usr/local/bin/ufw-docker \
  https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
sudo chmod +x /usr/local/bin/ufw-docker
sudo ufw-docker install
```

### Usage

```bash
# Allow a container port
sudo ufw-docker allow <container-name> <port> [protocol]

# Examples
sudo ufw-docker allow traefik 80
sudo ufw-docker allow traefik 443
sudo ufw-docker allow adguardhome 53

# Deny/remove a rule
sudo ufw-docker deny <container-name> <port>

# List Docker-specific rules
sudo ufw-docker list

# Check rules
sudo ufw-docker check
```

## Traefik Configuration

### Entry Points

```yaml
# HTTP (port 80) - Redirects to HTTPS
entrypoints.web.address: :80
entrypoints.web.http.redirections.entrypoint.to: websecure
entrypoints.web.http.redirections.entrypoint.scheme: https

# HTTPS (port 443) - Main entry point
entrypoints.websecure.address: :443
entrypoints.websecure.http.tls: true
entrypoints.websecure.http.tls.certresolver: letsencrypt
```

### Security Middlewares

#### 1. CrowdSec Bouncer

```yaml
crowdsec-bouncer:
  forwardAuth:
    address: http://crowdsec-traefik-bouncer:8080/api/v1/forwardAuth
```

#### 2. Security Headers

```yaml
security-headers:
  headers:
    sslRedirect: true
    stsSeconds: 31536000  # 1 year HSTS
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: "strict-origin-when-cross-origin"
```

#### 3. Rate Limiting

```yaml
rate-limit-public:
  rateLimit:
    average: 100    # requests per second
    burst: 200      # burst allowance
```

### Middleware Chains

```yaml
# Public services (no auth required)
public-chain:
  - crowdsec-bouncer
  - security-headers
  - rate-limit-public
  - compress

# Authenticated services (SSO required)
auth-chain:
  - crowdsec-bouncer
  - security-headers
  - oauth2-proxy
  - compress
```

## Service Access Patterns

### 1. Public Services (via Traefik)

```
Internet → UFW (443) → Traefik → CrowdSec → Service
```

**Examples:**

- `https://nextcloud.yourdomain.com` → Nextcloud
- `https://jellyfin.yourdomain.com` → Jellyfin
- `https://vault.yourdomain.com` → Vaultwarden

**Configuration:**

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service.rule=Host(`service.${HOST_DOMAIN}`)"
  - "traefik.http.routers.service.entrypoints=websecure"
  - "traefik.http.routers.service.tls=true"
  - "traefik.http.routers.service.middlewares=public-chain@docker"
```

### 2. LAN-Only Services (Direct Access)

```
LAN Client → HOST_BIND:PORT → Service
```

**Examples:**

- `http://192.168.178.158:9090` → Prometheus
- `http://192.168.178.158:3002` → Grafana
- `http://192.168.178.158:8089` → cAdvisor

**Configuration:**

```yaml
ports:
  - "${HOST_BIND:-192.168.178.158}:9090:9090"
```

### 3. Internal Services (Container Network Only)

```
Container → potatostack network → Service
```

**Examples:**

- PostgreSQL (5432)
- Redis (6379)
- MongoDB (27017)

**Configuration:**

```yaml
networks:
  - potatostack
# No ports exposed
```

## CrowdSec Integration

### Collections Enabled

```bash
crowdsecurity/traefik              # Traefik-specific parsers
crowdsecurity/http-cve             # HTTP CVE detection
crowdsecurity/whitelist-good-actors # Allow known good bots
crowdsecurity/linux                # Linux-specific scenarios
```

### Bouncer Configuration

The CrowdSec bouncer runs as a ForwardAuth middleware in Traefik:

```yaml
crowdsec-traefik-bouncer:
  image: fbonalair/traefik-crowdsec-bouncer
  environment:
    CROWDSEC_BOUNCER_API_KEY: ${CROWDSEC_BOUNCER_KEY}
    CROWDSEC_AGENT_HOST: crowdsec:8080
```

### Checking Banned IPs

```bash
# List decisions (bans)
docker exec crowdsec cscli decisions list

# Add IP to whitelist
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 24h --type ban

# Remove ban
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
```

## Management Scripts

### 1. UFW Management Script

```bash
# Install/configure UFW
sudo bash scripts/setup/setup-ufw-rules.sh install

# Show status
sudo bash scripts/setup/setup-ufw-rules.sh status

# List Docker rules
sudo bash scripts/setup/setup-ufw-rules.sh list

# Allow container port (interactive)
sudo bash scripts/setup/setup-ufw-rules.sh allow

# Reset and reapply rules
sudo bash scripts/setup/setup-ufw-rules.sh reset
```

### 2. Direct UFW Commands

```bash
# Allow SSH (if locked out)
sudo ufw allow 22/tcp

# Allow specific IP
sudo ufw allow from 192.168.1.100

# Deny specific IP
sudo ufw deny from 1.2.3.4

# Delete rule by number
sudo ufw status numbered
sudo ufw delete [number]

# Reload rules
sudo ufw reload

# Reset UFW completely
sudo ufw reset
```

## Security Best Practices

### 1. Principle of Least Privilege

- ✅ Only expose ports that need to be public
- ✅ Use HOST_BIND for internal services
- ✅ Keep most containers on internal network
- ✅ Use Traefik for all public-facing services

### 2. Regular Maintenance

```bash
# Weekly: Check for malicious activity
docker exec crowdsec cscli metrics
docker exec crowdsec cscli decisions list

# Monthly: Review firewall rules
sudo ufw status verbose
sudo ufw-docker list

# Quarterly: Update CrowdSec collections
docker exec crowdsec cscli collections upgrade --all
docker exec crowdsec cscli hub update
```

### 3. Monitoring & Alerts

- **Grafana Dashboard:** UFW metrics, CrowdSec stats
- **Uptime Kuma:** Service availability monitoring
- **Netdata:** Real-time firewall connection tracking
- **Loki/Parseable:** Centralized log analysis

### 4. Backup Critical Configs

```bash
# Backup UFW rules
sudo cp /etc/ufw/user.rules ~/backup/ufw-rules-$(date +%F).backup

# Backup Traefik config
cp -r config/traefik ~/backup/traefik-$(date +%F)

# Backup CrowdSec config
docker exec crowdsec tar czf - /etc/crowdsec > ~/backup/crowdsec-$(date +%F).tar.gz
```

## Troubleshooting

### Service Not Accessible from Internet

1. **Check UFW:**

```bash
sudo ufw status verbose
# Ensure port 80/443 are allowed
```

2. **Check ufw-docker:**

```bash
sudo ufw-docker list
# Ensure Traefik container is allowed
```

3. **Check Traefik:**

```bash
docker logs traefik
# Look for routing errors
```

4. **Check CrowdSec:**

```bash
docker exec crowdsec cscli decisions list
# Check if your IP is banned
```

### Container Can't Access Internet

1. **Check Docker network:**

```bash
docker network inspect potatostack
```

2. **Check UFW outgoing:**

```bash
sudo ufw status verbose
# Should be: Default: allow (outgoing)
```

3. **Check DNS:**

```bash
docker exec <container> ping 8.8.8.8
docker exec <container> ping google.com
```

### Locked Out of Server

If you accidentally block SSH:

1. **Physical/Console Access:**

```bash
sudo ufw allow 22/tcp
sudo ufw reload
```

2. **Cloud Provider Console:**
   - Access via web console
   - Run same commands

3. **Prevention:**

```bash
# Always test firewall changes with SSH
sudo ufw allow 22/tcp comment 'SSH - DO NOT REMOVE'
```

## Port Reference

### Public Ports (Allowed through UFW)

| Port | Service       | Purpose             |
| ---- | ------------- | ------------------- |
| 22   | SSH           | Remote admin        |
| 80   | Traefik       | HTTP → HTTPS        |
| 443  | Traefik       | HTTPS (main entry)  |
| 53   | AdGuard Home  | DNS                 |

### LAN-Only Ports (HOST_BIND)

See `docker-compose.yml` for full list. Key services:

| Port  | Service           |
| ----- | ----------------- |
| 8088  | Traefik Dashboard |
| 9090  | Prometheus        |
| 3002  | Grafana           |
| 19999 | Netdata           |
| 3100  | Loki              |
| 8089  | cAdvisor          |

### Internal Ports (No External Access)

| Port  | Service    |
| ----- | ---------- |
| 5432  | PostgreSQL |
| 6379  | Redis      |
| 27017 | MongoDB    |

## Additional Resources

- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [ufw-docker GitHub](https://github.com/chaifeng/ufw-docker)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [Docker Network Security](https://docs.docker.com/network/security/)

## Support

For issues or questions:

1. Check logs: `docker compose logs <service>`
2. Review this documentation
3. Open an issue in the repository
4. Check PotatoStack community forums
