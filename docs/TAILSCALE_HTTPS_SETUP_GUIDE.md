# Tailscale HTTPS & Secure Access Guide

This guide covers setting up secure HTTPS access for all PotatoStack services using Tailscale, Authentik SSO, Cloudflare, and Infinisical secrets management.

## Overview

PotatoStack provides multiple ways to access your services securely:

| Method | Use Case | When to Use |
|--------|-----------|-------------|
| **Tailscale HTTPS** | Remote access from your devices | Primary method for secure remote access |
| **Traefik HTTPS** | Local network access with SSO | For LAN devices needing Authentik authentication |
| **Cloudflare Tunnel** | Public internet access (optional) | When you need external access from outside your tailnet |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Devices                           │
│  (Windows, Mac, Android, iOS, Linux)                  │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼─────┐          ┌─────▼──────┐
    │Tailscale │          │  Traefik   │
    │  HTTPS   │          │  Reverse   │
    │          │          │   Proxy    │
    └────┬─────┘          └─────┬──────┘
         │                      │
         │                      │
    ┌────▼──────────────────────▼──────┐
    │      PotatoStack Server             │
    │  (100.108.216.90 on tailnet)    │
    │                                  │
    │  ┌──────────────────────────────┐  │
    │  │   Traefik (Reverse Proxy) │  │
    │  │   - SSL termination        │  │
    │  │   - Authentik SSO        │  │
    │  │   - Security headers      │  │
    │  └──────────┬───────────────┘  │
    │             │                   │
    │      ┌──────▼──────────┐       │
    │      │  Authentik (SSO) │       │
    │      │  - OAuth2/OIDC   │       │
    │      │  - MFA support    │       │
    │      └──────┬──────────┘       │
    │             │                   │
    │   ┌─────────▼─────────┐       │
    │   │  All Services     │       │
    │   │  (100 services)   │       │
    │   └───────────────────┘       │
    │                                │
    │  ┌──────────────────────────┐   │
    │  │  Infinisical          │   │
    │  │  - Secrets storage    │   │
    │  │  - Auto-injection     │   │
    │  └───────────────────────┘   │
    └───────────────────────────────┘
```

## Part 1: Tailscale HTTPS Setup

### Prerequisites

1. **Tailscale Account**: Sign up at https://tailscale.com
2. **Tailscale Installed**: Install Tailscale on all your devices
3. **Auth Key**: Generate auth key from Tailscale admin console

### Initial Setup

#### 1. Configure Environment Variables

Add to your `.env` file:

```bash
# Tailscale Configuration
TAILSCALE_AUTHKEY=tskey-auth-<your-auth-key>
TAILSCALE_HOSTNAME=potatostack

# Host binding for Tailscale access
HOST_BIND=0.0.0.0

# Ports to wrap with Tailscale HTTPS
TAILSCALE_SERVE_PORTS=7575,8088,3001,3002,8096,2283,8443,8384,51515,5678,8001,9091,8093,5006,9090,3100,9093,10903,10902,8094,8087,6060,8091,8788,8889,8081,3010,8085,3004,3006,8090,6880,6800,2234,8097,8000,8989,7878,9696,6767,8787,8686,8282,51413,50000,6888,8945,9900,8288,9000,9443,3012,8888
```

#### 2. Enable Tailscale HTTPS (One-Time)

Run this command to enable HTTPS wrapping on all ports:

```bash
docker compose up -d tailscale-https-setup
```

This will:
- Enable HTTPS on all specified ports
- Provide valid Tailscale certificates
- Make services accessible via `https://100.108.216.90:PORT`

#### 3. Enable Automatic HTTPS Re-application (Recommended)

Keep HTTPS wrapping active across reboots:

```bash
docker compose up -d tailscale-https-monitor
```

The monitor will:
- Check every 300 seconds (5 minutes)
- Re-apply HTTPS rules if needed
- Ensure ports stay wrapped on restart

### Accessing Services via Tailscale HTTPS

Once enabled, access services using your tailnet IP:

```bash
# Example URLs (replace 100.108.216.90 with your actual IP)
https://100.108.216.90:7575     # Homarr Dashboard
https://100.108.216.90:8096     # Jellyfin
https://100.108.216.90:2283     # Immich
https://100.108.216.90:3002     # Grafana
```

### Troubleshooting Tailscale HTTPS

#### Error: `PR_END_OF_FILE_ERROR`

This means you're accessing an HTTP port with HTTPS, or HTTPS isn't enabled.

**Fix:**
```bash
docker compose up -d tailscale-https-setup
# Or keep monitor running:
docker compose up -d tailscale-https-monitor
```

#### Services Not Accessible

**Check Tailscale status:**
```bash
docker exec tailscale tailscale status
docker exec tailscale tailscale ping <your-device-name>
```

**Verify ports are wrapped:**
```bash
docker exec tailscale tailscale serve status
```

#### Certificate Warnings

Tailscale certificates are automatically trusted on your tailnet devices. If you see warnings:

1. Ensure Tailscale is running on your client device
2. Check you're using `https://` not `http://`
3. Try IP directly: `https://100.108.216.90:PORT`

## Part 2: Authentik SSO Integration

### Overview

Authentik provides single sign-on (SSO) for all services configured with Traefik.

### Setup Authentik

#### 1. Access Authentik Dashboard

```bash
# Via Tailscale HTTPS
https://100.108.216.90:9000

# Or via Traefik (if DNS configured)
https://auth.danielhomelab.local
```

#### 2. Initial Configuration

1. **First-time setup**: Follow the on-screen wizard
2. **Create admin account**: Set username and password
3. **Configure authentication providers**:
   - Email/password (built-in)
   - OAuth2 (Google, GitHub, etc.)
   - WebAuthn (security keys)

#### 3. Create Application for Each Service

For each service you want to protect with SSO:

**Example: Vaultwarden**

1. **Go to**: Applications → Providers → Create
2. **Type**: OAuth2 Provider
3. **Name**: Vaultwarden
4. **Client ID**: `vaultwarden`
5. **Redirect URIs**: `https://vault.danielhomelab.local/oidc/callback`
6. **Scopes**: `openid`, `email`, `profile`

6. **Create Application**:
   - **Type**: Provider
   - **Provider**: Vaultwarden (created above)
   - **Slug**: `vaultwarden`
   - **Launch URL**: `https://vault.danielhomelab.local`

#### 4. Configure Traefik with Authentik Middleware

Add to docker-compose.yml for each service:

```yaml
vaultwarden:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.vaultwarden.rule=Host(`vault.danielhomelab.local`)"
    - "traefik.http.routers.vaultwarden.entrypoints=websecure"
    - "traefik.http.routers.vaultwarden.tls=true"
    - "traefik.http.routers.vaultwarden.middlewares=sso-chain@docker"

# Global SSO middleware (defined once)
traefik:
  labels:
    - "traefik.http.middlewares.sso.forwardauth.address=http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
    - "traefik.http.middlewares.sso.forwardauth.authResponseHeaders=X-Authentik-User,X-Authentik-Groups,X-Authentik-Email,X-Authentik-Name,X-Authentik-Uid"
```

### Services Protected by Authentik

These services already have Authentik SSO configured:

| Service | Traefik URL | Authentication |
|---------|--------------|----------------|
| Vaultwarden | https://vault.danielhomelab.local | SSO + WebAuthn |
| Gitea | https://git.danielhomelab.local | SSO enabled |
| Actual Budget | https://budget.danielhomelab.local | SSO enabled |
| Grafana | https://grafana.danielhomelab.local | SSO enabled |
| Immich | https://immich.danielhomelab.local | SSO enabled |
| Filebrowser | https://filebrowser.danielhomelab.local | SSO enabled |
| Mealie | https://mealie.danielhomelab.local | SSO enabled |
| Nextcloud | https://nextcloud.danielhomelab.local | SSO enabled |
| Navidrome | https://music.danielhomelab.local | SSO enabled |
| Obsidian | https://obsidian.danielhomelab.local | SSO enabled |

### Using Authentik SSO

1. Access any protected service
2. Redirected to Authentik login
3. Sign in once
4. Access all services without re-authentication

### Configure OAuth Providers (Optional)

Add social login options to Authentik:

**Google OAuth2:**
1. Go to https://console.cloud.google.com
2. Create OAuth 2.0 client ID
3. Redirect URI: `https://auth.danielhomelab.local/application/o/callback/`
4. Add credentials to Authentik: Directory → OAuth2/OIDC → Create

**GitHub OAuth2:**
1. Go to GitHub Settings → Developer settings → OAuth Apps
2. Create new OAuth App
3. Redirect URI: `https://auth.danielhomelab.local/application/o/callback/`
4. Add credentials to Authentik

## Part 3: Cloudflare Integration (Optional Public Access)

### Overview

Use Cloudflare Tunnel for secure public internet access without port forwarding.

### Prerequisites

1. **Cloudflare Account**: Free account at https://cloudflare.com
2. **Domain**: Add your domain to Cloudflare
3. **Cloudflare Tunnel**: Install cloudflared

### Setup Cloudflare Tunnel

#### 1. Install cloudflared

```bash
# On the server
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

#### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser to authenticate with Cloudflare.

#### 3. Create Tunnel

```bash
cloudflared tunnel create potatostack
```

Save the output tunnel ID.

#### 4. Configure Tunnel Services

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-id-from-step-3>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  # Authentik (public access)
  - hostname: auth.yourdomain.com
    service: http://192.168.178.158:9000

  # Vaultwarden (public access)
  - hostname: vault.yourdomain.com
    service: http://192.168.178.158:3012

  # Grafana (public access)
  - hostname: grafana.yourdomain.com
    service: http://192.168.178.158:3002

  # Catch-all: block everything else
  - service: http_status:404
```

#### 5. Run Tunnel

```bash
cloudflared tunnel run potatostack
```

Or run as a systemd service:

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

#### 6. Configure DNS

In Cloudflare dashboard, add CNAME records for each service:

```
auth.yourdomain.com → <tunnel-id>.cfargotunnel.com
vault.yourdomain.com → <tunnel-id>.cfargotunnel.com
grafana.yourdomain.com → <tunnel-id>.cfargotunnel.com
```

### Security with Cloudflare Tunnel

- **No port forwarding needed**: Tunnel outbound from server
- **DDoS protection**: Cloudflare mitigates attacks
- **SSL/TLS**: Automatic HTTPS from Cloudflare to users
- **Access control**: Add Cloudflare Access (Zero Trust) for additional security

### Cloudflare Access (Zero Trust)

Add authentication to public services:

```yaml
ingress:
  - hostname: auth.yourdomain.com
    service: http://192.168.178.158:9000
    originRequest:
      access:
        required: true
        teamName: your-team
```

Then configure access policies in Cloudflare Zero Trust dashboard.

## Part 4: Infinisical Secrets Management

### Overview

Infinisical securely manages secrets for all services, replacing environment variables in .env files.

### Setup Infinisical

#### 1. Access Infinisical Dashboard

```bash
# Via Tailscale HTTPS
https://100.108.216.90:8288

# Or via Traefik (if DNS configured)
https://secrets.danielhomelab.local
```

#### 2. Create Workspace

1. Sign up / Login to Infinisical
2. Create a new workspace: `potatostack`
3. Invite team members if needed

#### 3. Import Secrets

You can import secrets from your existing `.env` file:

```bash
# Create secrets file from .env (sensitive values masked)
grep -E "^[A-Z_]+=.*$" .env | sed 's/=.*/=***SECRET***/' > secrets-import.txt
```

In Infinisical UI:
1. Go to Workspace → Secrets
2. Import secrets file or create manually
3. Set appropriate values for each secret

#### 4. Create Environment Variables

In Infinisical:
1. Go to Workspace → Environments
2. Create environments: `development`, `staging`, `production`
3. Add secrets to appropriate environment

Example secrets structure:
```
potatostack/
├── production/
│   ├── POSTGRES_PASSWORD
│   ├── REDIS_PASSWORD
│   ├── TAILSCALE_AUTHKEY
│   ├── MEALIE_SECRET_KEY
│   └── ...
├── staging/
│   └── ...
└── development/
    └── ...
```

#### 5. Configure Docker Compose with Infinisical

Update docker-compose.yml to use Infinisical CLI for secrets injection:

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      - POSTGRES_PASSWORD=@infisical://potatostack/production/POSTGRES_PASSWORD
```

Or use Infinisical CLI:

```bash
# Install Infinisical CLI
npm install -g @infisical/cli

# Export secrets for Docker Compose
eval $(infisical export --env=production)

# Now run docker compose
docker compose up -d
```

#### 6. Automatic Secret Injection

Create a startup script `scripts/setup/load-secrets.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "Loading secrets from Infinisical..."

# Check if Infinisical CLI is installed
if ! command -v infisical &> /dev/null; then
    echo "Infinisical CLI not found. Please install: npm install -g @infisical/cli"
    exit 1
fi

# Export secrets to environment
eval $(infisical export --env=production --workspace=potatostack)

echo "✓ Secrets loaded from Infinisical"
echo "Starting Docker Compose..."
docker compose up -d
```

Make it executable:
```bash
chmod +x scripts/setup/load-secrets.sh
```

### Using Infinisical with PotatoStack

#### Method 1: Environment Export (Recommended)

```bash
# Load secrets, then start services
infisical export --env=production | tee /tmp/secrets.env
export $(cat /tmp/secrets.env | xargs)
docker compose up -d
rm /tmp/secrets.env
```

#### Method 2: CLI Wrapper

Modify Makefile:

```makefile
.PHONY: up-secrets
up-secrets:
	@echo "Loading secrets from Infinisical..."
	@eval $$(infisical export --env=production) && docker compose up -d
```

Usage:
```bash
make up-secrets
```

#### Method 3: Docker Secrets (Advanced)

Use Docker Swarm secrets with Infinisical:

```bash
# Pull secret and create Docker secret
infisical export --env=production --plain | grep POSTGRES_PASSWORD | cut -d= -f2 | \
  docker secret create postgres_password -
```

### Best Practices

1. **Never commit secrets**: Keep `.env` in `.gitignore`
2. **Rotate secrets regularly**: Use Infinisical rotation features
3. **Access control**: Limit who can view/edit secrets
4. **Audit logs**: Track who accessed which secrets when
5. **Backup secrets**: Infinisical has built-in backup, but export critical secrets periodically

### Example: Storing Sensitive Service Config

**Before (.env file):**
```bash
# ❌ Insecure: secrets in plain text
POSTGRES_PASSWORD=mysecretpassword123
TAILSCALE_AUTHKEY=tskey-auth-secret-key-here
VAULTWARDEN_ADMIN_TOKEN=some-random-token
```

**After (Infinisical):**
```bash
# ✅ Secure: secrets stored encrypted
# .env now only has references
INFISICAL_TOKEN=your-infisical-token
INFISICAL_WORKSPACE=potatostack
INFISICAL_ENVIRONMENT=production
```

Load secrets:
```bash
eval $(infisical export --env=production)
```

## Part 5: Complete Setup Checklist

### Phase 1: Tailscale HTTPS

- [ ] Tailscale account created
- [ ] Tailscale installed on all devices
- [ ] `TAILSCALE_AUTHKEY` added to `.env`
- [ ] `TAILSCALE_SERVE_PORTS` configured in `.env`
- [ ] `docker compose up -d tailscale-https-setup` run
- [ ] `docker compose up -d tailscale-https-monitor` running
- [ ] Verify: `https://100.108.216.90:7575` opens Homarr

### Phase 2: Authentik SSO

- [ ] Access `https://100.108.216.90:9000` or `https://auth.danielhomelab.local`
- [ ] Admin account created
- [ ] OAuth providers configured (Google/GitHub) [optional]
- [ ] Traefik middleware configured for SSO
- [ ] Services added as Authentik applications
- [ ] Test: Access Vaultwarden, redirected to Authentik

### Phase 3: Cloudflare (Optional Public Access)

- [ ] Cloudflare account created
- [ ] Domain added to Cloudflare
- [ ] cloudflared installed on server
- [ ] Tunnel created and authenticated
- [ ] Tunnel services configured in `~/.cloudflared/config.yml`
- [ ] DNS records added for public services
- [ ] Test: `https://auth.yourdomain.com` accessible

### Phase 4: Infinisical Secrets

- [ ] Access `https://100.108.216.90:8288` or `https://secrets.danielhomelab.local`
- [ ] Workspace created
- [ ] Secrets imported from `.env`
- [ ] Environments configured
- [ ] Docker Compose updated to use Infinisical
- [ ] Test: Services start with secrets from Infinisical

## Part 6: Common Issues & Solutions

### Tailscale HTTPS Issues

**Problem**: `PR_END_OF_FILE_ERROR`
**Solution**: Run `docker compose up -d tailscale-https-setup`

**Problem**: Services not accessible via tailnet IP
**Solution**:
1. Check `HOST_BIND=0.0.0.0` in `.env`
2. Verify Tailscale is running on client device
3. Ping server: `ping 100.108.216.90`

### Authentik SSO Issues

**Problem**: Login redirects not working
**Solution**:
1. Check `BASE_URL` in Authentik config
2. Verify Traefik middleware is correct
3. Check Authentik logs: `docker logs authentik-server`

**Problem**: User not authenticated
**Solution**:
1. Clear browser cookies
2. Check Authentik user groups/permissions
3. Verify provider is active

### Cloudflare Tunnel Issues

**Problem**: Tunnel not connecting
**Solution**:
1. Check cloudflared logs: `journalctl -u cloudflared`
2. Verify tunnel ID is correct
3. Check DNS records point to tunnel

**Problem**: DNS propagation delay
**Solution**: Wait 5-15 minutes for DNS to propagate

### Infinisical Issues

**Problem**: Secrets not loaded
**Solution**:
1. Check `INFISICAL_TOKEN` is valid
2. Verify workspace and environment names
3. Test CLI: `infisical export --env=production`

**Problem**: Services can't access secrets
**Solution**:
1. Check permissions in Infinisical
2. Verify secret names match
3. Use `infisical export --plain` to debug

## Part 7: Security Best Practices

### Access Control

1. **Principle of least privilege**: Only expose what's needed
2. **Network segmentation**: Keep VPN traffic separate from LAN
3. **MFA everywhere**: Enable 2FA on Authentik, Cloudflare, Infinisical
4. **Regular audits**: Review access logs monthly

### Secret Management

1. **Never commit secrets**: Keep `.env` in `.gitignore`
2. **Rotate regularly**: Change passwords/tokens every 90 days
3. **Use strong passwords**: 20+ characters, mixed case, numbers, symbols
4. **Unique passwords**: Don't reuse passwords across services

### Monitoring

1. **Enable logging**: Check Authentik, Traefik, Infinisical logs
2. **Set up alerts**: Uptime Kuma for critical services
3. **Review logs**: Weekly review of authentication attempts
4. **Backup configs**: Export Infinisical secrets periodically

## Part 8: Quick Reference

### Essential URLs

| Service | Tailscale HTTPS | Traefik HTTPS | Public (optional) |
|---------|----------------|----------------|------------------|
| Homarr | `https://100.108.216.90:7575` | `https://home.danielhomelab.local` | - |
| Authentik | `https://100.108.216.90:9000` | `https://auth.danielhomelab.local` | `https://auth.yourdomain.com` |
| Vaultwarden | `https://100.108.216.90:8888` | `https://vault.danielhomelab.local` | `https://vault.yourdomain.com` |
| Grafana | `https://100.108.216.90:3002` | `https://grafana.danielhomelab.local` | `https://grafana.yourdomain.com` |
| Jellyfin | `https://100.108.216.90:8096` | `https://jellyfin.danielhomelab.local` | - |

### Essential Commands

```bash
# Tailscale HTTPS (one-time)
docker compose up -d tailscale-https-setup

# Tailscale HTTPS (persistent)
docker compose up -d tailscale-https-monitor

# Check Tailscale status
docker exec tailscale tailscale status

# Restart Traefik
docker restart traefik

# Restart Authentik
docker restart authentik-server authentik-worker

# Load Infinisical secrets
eval $(infisical export --env=production)

# Start all services with secrets
make up-secrets  # (if you added this target to Makefile)
```

### Environment Variables Reference

```bash
# Tailscale
TAILSCALE_AUTHKEY=tskey-auth-...
TAILSCALE_SERVE_PORTS=7575,8088,3001,...

# Host binding
HOST_BIND=0.0.0.0

# Domain for Traefik
HOST_DOMAIN=danielhomelab.local

# Infinisical
INFISICAL_TOKEN=infisical-token-...
INFISICAL_WORKSPACE=potatostack
INFISICAL_ENVIRONMENT=production

# Cloudflare (optional)
CF_API_EMAIL=your@email.com
CF_DNS_API_TOKEN=your-api-token
```

## Support

- **Tailscale Documentation**: https://tailscale.com/kb
- **Authentik Documentation**: https://goauthentik.io/docs/
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Infinisical Documentation**: https://infisical.com/docs

---

**Last Updated**: 2026-01-23
**Version**: 1.0
