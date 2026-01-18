# FRITZ!Box Domain Forwarding Setup for PotatoStack

This guide covers setting up external access to PotatoStack via a FRITZ!Box router with a free domain.

## Quick Summary

| Component | Purpose |
|-----------|---------|
| DuckDNS | Free dynamic DNS (maps domain to your public IP) |
| FRITZ!Box Port Forwarding | Routes ports 80/443 to your server |
| Traefik | Handles HTTPS/TLS certificates via Let's Encrypt |
| DNS Rebind Protection | Allows internal resolution of your domain |

## Step 1: Get a Free Domain with DuckDNS

DuckDNS is recommended (free, no account limits, simple API).

1. Go to [https://www.duckdns.org](https://www.duckdns.org)
2. Sign in with Google/GitHub/Twitter
3. Create a subdomain (e.g., `yourname.duckdns.org`)
4. Note your **token** (shown on the dashboard)

### Configure DuckDNS in FRITZ!Box

1. **FRITZ!Box Web UI**: `http://fritz.box` or `192.168.178.1`
2. Navigate to: **Internet > Permit Access > DynDNS**
3. Enable **Use DynDNS**
4. Configure:
   - **Provider**: User-defined
   - **Update URL**:
     ```
     https://www.duckdns.org/update?domains=<domain>&token=<pass>&ip=<ipaddr>
     ```
   - **Domain name**: `yourname.duckdns.org`
   - **Username**: `yourname` (your subdomain)
   - **Password**: Your DuckDNS token

5. Click **Apply**

### Alternative: MyFRITZ! (Built-in)

If you prefer the built-in option:
1. Navigate to: **Internet > MyFRITZ! Account**
2. Create/login to MyFRITZ! account
3. You get: `yourbox.myfritz.net`

## Step 2: Port Forwarding Configuration

### Required Ports for PotatoStack

| Port | Service | Description |
|------|---------|-------------|
| 80 | HTTP | Traefik (redirects to HTTPS) |
| 443 | HTTPS | Traefik (main entry point) |

### FRITZ!Box Port Forwarding Setup

1. Navigate to: **Internet > Permit Access > Port Sharing**
2. Click **Add Device for Sharing**
3. Select your PotatoStack server (by IP or name)
4. Click **New Sharing**
5. Configure for **Port 80**:
   - Application: HTTP server
   - Port to device: 80
   - External port: 80 (or different if ISP blocks 80)
   - Protocol: TCP
6. Repeat for **Port 443**:
   - Application: HTTPS server
   - Port to device: 443
   - External port: 443
   - Protocol: TCP
7. Click **Apply**

### If Your ISP Blocks Port 80/443

Some ISPs block common ports. Solutions:

1. **Use alternate ports** (e.g., 8080/8443):
   - Update FRITZ!Box external ports
   - Update Traefik entrypoints in `docker-compose.yml`
   - Access via: `https://yourname.duckdns.org:8443`

2. **Use Cloudflare Tunnel** (bypasses port issues entirely):
   - Free, no port forwarding needed
   - Add `cloudflared` service to docker-compose

## Step 3: DNS Rebind Protection (Local Access)

Without this, accessing `yourname.duckdns.org` from inside your network fails.

1. Navigate to: **Home Network > Network > Network Settings**
2. Scroll to **DNS Rebind Protection**
3. Add your domain: `yourname.duckdns.org`
4. Also add wildcard: `*.yourname.duckdns.org` (if supported)
5. Click **Apply**

## Step 4: Update PotatoStack Configuration

### Update `.env` file

```bash
# Your domain configuration
HOST_DOMAIN=yourname.duckdns.org

# Your server's local IP (for internal binding)
HOST_BIND=192.168.178.XXX  # Replace with your server IP
```

### Verify Traefik Configuration

Traefik handles Let's Encrypt certificates automatically. Ensure in `docker-compose.yml`:

```yaml
traefik:
  command:
    - "--certificatesresolvers.letsencrypt.acme.email=your@email.com"
    - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
```

### Restart Stack

```bash
docker compose up -d traefik
```

## Step 5: Verify Setup

### Test External Access

From outside your network (e.g., mobile data):

```bash
curl -I https://yourname.duckdns.org
```

Expected: HTTP 200 or redirect to login page.

### Test Services

| Service | URL |
|---------|-----|
| Homarr Dashboard | `https://home.yourname.duckdns.org` |
| Grafana | `https://grafana.yourname.duckdns.org` |
| Jellyfin | `https://jellyfin.yourname.duckdns.org` |

### Check Certificate

```bash
echo | openssl s_client -connect yourname.duckdns.org:443 2>/dev/null | openssl x509 -noout -dates
```

## Troubleshooting

### "This site can't be reached"

1. Check port forwarding is active in FRITZ!Box
2. Verify your public IP matches DuckDNS: `curl ifconfig.me`
3. Check Traefik logs: `docker logs traefik`

### Certificate Errors

1. Ensure port 80 is accessible (Let's Encrypt HTTP challenge)
2. Check rate limits: [https://letsencrypt.org/docs/rate-limits/](https://letsencrypt.org/docs/rate-limits/)
3. View ACME logs: `docker exec traefik cat /letsencrypt/acme.json | jq`

### Internal Access Issues

1. Verify DNS rebind protection includes your domain
2. Try: `nslookup yourname.duckdns.org` from inside network
3. Consider running Pi-hole/AdGuard for local DNS override

### FRITZ!Box Specific Issues

- **IPv6**: If using IPv6, add the device's Interface ID manually
- **Guest Network**: Port forwarding doesn't work for guest network devices
- **Dual-Stack Lite (DS-Lite)**: Some ISPs use this - you may need IPv6 or a tunnel

## Security Recommendations

1. **Use Authentik SSO**: All services behind authentication
2. **Fail2ban**: Already configured in PotatoStack
3. **CrowdSec**: IPS protection enabled
4. **Regular Updates**: `docker compose pull && docker compose up -d`

## Alternative: Tailscale (No Port Forwarding)

For simpler private access without exposing ports:

```yaml
# Already in PotatoStack docker-compose.yml
tailscale:
  image: tailscale/tailscale
  # Provides: yourhost.tailnet-name.ts.net
```

Access services via Tailscale network without any router configuration.

## Summary Checklist

- [ ] DuckDNS domain created and configured in FRITZ!Box
- [ ] Port 80 forwarded to server
- [ ] Port 443 forwarded to server
- [ ] DNS rebind protection configured for domain
- [ ] `.env` updated with `HOST_DOMAIN`
- [ ] Traefik restarted
- [ ] External access tested
- [ ] HTTPS certificate verified
