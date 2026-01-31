# Traefik, Authentik & Tailscale: How They Work Together

## TL;DR

| Access Method | Traefik Used? | Authentik Used? | Best For |
|---------------|---------------|-----------------|----------|
| `https://potatostack.ts.net:PORT` | No | No | Quick access, mobile apps |
| `https://service.local.domain` | Yes | Optional | LAN with SSO, public exposure |
| `http://192.168.178.x:PORT` | No | No | Local debugging |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ACCESS PATTERNS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TAILSCALE SERVE (Direct Port Access)                                       │
│  ────────────────────────────────────                                        │
│  Your Device → Tailscale Network → potatostack:PORT → Container             │
│                                                                              │
│  • No Traefik involved                                                       │
│  • No Authentik SSO                                                          │
│  • HTTPS provided by Tailscale (auto-certs)                                  │
│  • Access: https://potatostack.ts.net:8096 (Jellyfin)                       │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TRAEFIK (Domain-Based Routing)                                              │
│  ──────────────────────────────                                              │
│  Browser → Traefik:443 → CrowdSec → Authentik → Container                   │
│                                                                              │
│  • Full security stack (IPS, SSO, rate limiting)                            │
│  • Access: https://jellyfin.local.domain                                    │
│  • Requires DNS setup (local or public)                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## When to Use Each Method

### Tailscale Serve (Direct Port Access)

**Use when:**
- Accessing from mobile apps (Jellyfin, Immich, etc.)
- Quick access without DNS setup
- Apps that don't support custom domains well
- You trust all devices on your Tailnet

**How it works:**
1. `tailscale-https-monitor` runs `tailscale serve` for each port
2. Tailscale wraps HTTP with HTTPS using auto-generated certs
3. Access via `https://potatostack.ts.net:PORT`

**Ports configured** (from `TAILSCALE_SERVE_PORTS`):
```
7575  - Homarr          8096  - Jellyfin        2283  - Immich
8093  - Miniflux        9000  - Authentik       8384  - Syncthing
9090  - Prometheus      3100  - Loki            8076  - pyLoad
2234  - slskd           8000  - Rustypaste
```

### Traefik (Domain Routing + Security)

**Use when:**
- You want SSO across all services
- Exposing services to the internet
- Need CrowdSec IPS protection
- Want consistent domain-based URLs

**How it works:**
1. Request hits Traefik on port 443
2. CrowdSec checks IP reputation
3. Traefik routes based on hostname
4. Authentik middleware validates session (if enabled)
5. Request forwarded to container

**Middleware chains available:**
- `sso-chain@docker` - Full SSO with Authentik
- `public-chain` - CrowdSec + security headers (no auth)
- `api-chain` - Rate-limited for APIs
- `auth-chain` - Rate-limited for auth endpoints

## Effective Usage Guide

### 1. Quick Remote Access (Tailscale)

Just use the Tailscale URLs directly:
```bash
# From any device on your Tailnet
https://potatostack.ts.net:7575    # Homarr dashboard
https://potatostack.ts.net:8096    # Jellyfin
https://potatostack.ts.net:2283    # Immich photos
```

No configuration needed - works immediately if `tailscale-https-monitor` is running.

### 2. SSO-Protected Access (Traefik + Authentik)

**Step 1: Set up DNS**
Add to your local DNS or `/etc/hosts`:
```
192.168.178.158  jellyfin.local.domain
192.168.178.158  immich.local.domain
192.168.178.158  authentik.local.domain
```

**Step 2: Configure Authentik**
1. Access `https://potatostack.ts.net:9000` or `https://authentik.local.domain`
2. Create an Application for each service
3. Create an Outpost with the Traefik provider

**Step 3: Enable SSO on services**
Services with `sso-chain@docker` middleware require Authentik login:
```yaml
labels:
  - "traefik.http.routers.myservice.middlewares=sso-chain@docker"
```

### 3. Hybrid Approach (Recommended)

Use **Tailscale for daily access**, **Traefik+Authentik for sensitive services**:

| Service | Tailscale (quick) | Traefik+Auth (secure) |
|---------|-------------------|----------------------|
| Jellyfin | `ts.net:8096` | Not needed (has own auth) |
| Immich | `ts.net:2283` | Not needed (has own auth) |
| Grafana | `ts.net:3001` | `grafana.local.domain` with SSO |
| Traefik Dashboard | - | `traefik.local.domain` with SSO |

## Configuration Reference

### Tailscale Serve Ports
Edit in `.env`:
```bash
TAILSCALE_SERVE_PORTS=7575,8096,2283,8093,8384,9090,3100,...
```

### Adding SSO to a Service
In `docker-compose.yml`:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.${HOST_DOMAIN}`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.routers.myservice.tls=true"
  - "traefik.http.routers.myservice.middlewares=sso-chain@docker"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

### Authentik Forward Auth Config
Already configured in `config/traefik/dynamic.yml`:
```yaml
middlewares:
  authentik-forwardauth:
    forwardAuth:
      address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
      trustForwardHeader: true
      authResponseHeaders:
        - X-authentik-username
        - X-authentik-groups
        - X-authentik-email
```

## Security Layers

```
Layer 1: Tailscale Network    - Only your devices can reach the server
Layer 2: UFW Firewall         - Host-level port blocking
Layer 3: CrowdSec IPS         - Blocks malicious IPs (Traefik only)
Layer 4: Traefik              - TLS termination, routing
Layer 5: Authentik            - SSO, 2FA (optional per service)
Layer 6: App Auth             - Service's own authentication
```

### With Tailscale Serve:
- Layers 1, 6 active
- Encrypted tunnel, app-level auth only

### With Traefik + Authentik:
- All layers active
- Full defense-in-depth

## Troubleshooting

### Tailscale serve not working
```bash
# Check if monitor is running
docker logs tailscale-https-monitor

# Manually apply serve rules
docker exec tailscale tailscale serve --bg --https=8096 http://127.0.0.1:8096
```

### Authentik redirect loop
1. Check Outpost is running in Authentik admin
2. Verify cookie domain matches your `HOST_DOMAIN`
3. Check browser console for CORS errors

### Service not accessible via Traefik
```bash
# Check Traefik can reach service
docker exec traefik wget -qO- http://service-name:port/health

# Check router is registered
curl http://localhost:8088/api/http/routers | jq
```

## Summary

- **Tailscale Serve**: Simple, quick, good for apps with own auth
- **Traefik**: Domain routing, TLS certs, middleware chains
- **Authentik**: Centralized SSO, 2FA, user management
- **Use together**: Tailscale for network security, Traefik+Authentik for sensitive dashboards
