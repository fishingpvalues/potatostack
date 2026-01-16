# HTTPS Certificate Solution for Vaultwarden Android

## The Problem

Self-signed certificates don't work with Android apps (like Vaultwarden). Even if you accept them in the browser, the app still shows certificate warnings and may refuse to connect.

## Solution: Caddy + Let's Encrypt DNS Challenge

**Caddy** is a lightweight reverse proxy (~20-30MB RAM) that automatically handles Let's Encrypt certificates using DNS challenge, which works for local IPs.

### Requirements

1. **Domain name** (e.g., yourdomain.com from any registrar)
2. **DNS provider with API support** (Cloudflare, DigitalOcean, Route53, etc.)
3. **DNS API token** from your provider

### Why DNS Challenge?

- Works with local IPs (192.168.x.x)
- No port 80/443 exposure to internet needed
- Wildcard certificates possible
- Trusted by all devices (Android, iOS, desktop)

## Implementation

### Step 1: Get DNS API Credentials

**Cloudflare** (recommended, free):
1. Sign up at cloudflare.com
2. Add your domain (change nameservers at registrar)
3. Go to Profile → API Tokens
4. Create token with `Zone:DNS:Edit` permissions
5. Copy token

### Step 2: Add Caddy to docker-compose.yml

```yaml
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    logging: *default-logging
    ports:
      - "${HOST_BIND}:443:443"
      - "${HOST_BIND}:443:443/udp"  # HTTP/3
    environment:
      - TZ=Europe/Berlin
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
      - DOMAIN=${HTTPS_DOMAIN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - potatostack
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.3"
          memory: 64M
        reservations:
          memory: 32M
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:2019/config/"]
      interval: 120s
      timeout: 10s
      retries: 3
      start_period: 30s
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

volumes:
  caddy-data:
  caddy-config:
```

### Step 3: Create Caddyfile

Create `Caddyfile` in the light directory:

```caddy
{
    email your-email@example.com
    # Use Cloudflare DNS for Let's Encrypt challenge
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

# Vaultwarden
vault.{$DOMAIN} {
    reverse_proxy vaultwarden:8443 {
        transport http {
            tls
            tls_insecure_skip_verify
        }
    }

    # WebSocket support
    @websocket {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    handle @websocket {
        reverse_proxy vaultwarden:3012
    }
}

# Kopia (optional)
backup.{$DOMAIN} {
    reverse_proxy kopia:51515 {
        transport http {
            tls
            tls_insecure_skip_verify
        }
    }
}

# RustyPaste (if you want HTTPS)
paste.{$DOMAIN} {
    reverse_proxy rustypaste:8000
}
```

### Step 4: Update .env

Add these variables to `.env`:

```bash
# HTTPS Configuration
HTTPS_DOMAIN=yourdomain.com
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
```

### Step 5: Update Vaultwarden Domain

In docker-compose.yml, change Vaultwarden domain:

```yaml
  vaultwarden:
    environment:
      - DOMAIN=https://vault.${HTTPS_DOMAIN}
```

### Step 6: DNS Configuration

At your DNS provider (Cloudflare), add A record:

```
vault.yourdomain.com → 192.168.178.40 (your HOST_BIND)
backup.yourdomain.com → 192.168.178.40
paste.yourdomain.com → 192.168.178.40
```

Or use wildcard:
```
*.yourdomain.com → 192.168.178.40
```

**Important**: These can be local IPs! DNS challenge doesn't require internet-accessible servers.

### Step 7: Start Caddy

```bash
make down
make up
docker logs -f caddy
```

Watch for "certificate obtained successfully" in logs.

### Step 8: Test

```bash
# From your phone or laptop on same network
curl -I https://vault.yourdomain.com

# Should show valid SSL certificate from Let's Encrypt
```

**Android Vaultwarden app**: Use `https://vault.yourdomain.com`

## Alternative DNS Providers

### DigitalOcean
```yaml
environment:
  - DIGITALOCEAN_API_TOKEN=${DO_API_TOKEN}
```

Caddyfile:
```caddy
acme_dns digitalocean {env.DIGITALOCEAN_API_TOKEN}
```

### AWS Route53
```yaml
environment:
  - AWS_ACCESS_KEY_ID=${AWS_KEY}
  - AWS_SECRET_ACCESS_KEY=${AWS_SECRET}
  - AWS_REGION=us-east-1
```

Caddyfile:
```caddy
acme_dns route53 {
    access_key_id {env.AWS_ACCESS_KEY_ID}
    secret_access_key {env.AWS_SECRET_ACCESS_KEY}
}
```

### Duck DNS (Free)
```yaml
environment:
  - DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
```

Get free subdomain at duckdns.org (e.g., mystack.duckdns.org)

Caddyfile:
```caddy
acme_dns duckdns {env.DUCKDNS_TOKEN}
```

## Memory Impact

- Caddy: ~30-40MB RAM
- Total stack: ~1.2GB → ~1.25GB
- Still within low-RAM budgets

## Troubleshooting

### Certificate not issuing
```bash
docker logs caddy
# Check for DNS API errors
```

### DNS propagation
```bash
# Check if DNS is resolving correctly
nslookup vault.yourdomain.com
dig vault.yourdomain.com
```

### Firewall blocking DNS
Caddy needs outbound port 53 (DNS) and 443 (ACME).

### Rate limits
Let's Encrypt: 50 certs per domain per week. Caddy caches certs, so this rarely matters.

## Benefits

✅ Trusted by all devices (no warnings)
✅ Works with Android/iOS apps
✅ Automatic renewal (every 90 days)
✅ Wildcard support
✅ Low memory (~30MB)
✅ No port forwarding needed
✅ Local IP addresses work fine

## Cost

- Domain: ~$10-15/year (Namecheap, Porkbun, etc.)
- DNS API: Free (Cloudflare, DuckDNS)
- Let's Encrypt: Free
- Caddy: Free (open source)

**Total: ~$10-15/year**

## Alternative: No Domain?

If you don't want to buy a domain:

1. **DuckDNS** (free subdomain): mystack.duckdns.org
2. **No-IP** (free subdomain): mystack.ddns.net
3. **Step-CA** (run your own CA): Still requires installing CA cert on Android (not recommended)

## Security Notes

- Certificates are valid for 90 days, auto-renewed
- Private keys stored in `caddy-data` volume
- DNS API token has minimal permissions (DNS edit only)
- Services still bound to local IP (not exposed to internet)
- Caddy handles TLS 1.3, modern ciphers automatically
