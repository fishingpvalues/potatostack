# Gokapi - External File Sharing

Share files with people outside your Tailnet via one-time download links with passwords.

## Architecture

- **Gokapi** (port 53842) — lightweight file sharing server with expiring/limited downloads
- **Cloudflared** — creates a public `*.trycloudflare.com` tunnel to Gokapi (no domain needed)

Files are copied to Gokapi's data dir on upload but auto-deleted after download limit or expiry.

## Quick Start

```bash
docker compose up -d gokapi cloudflared

# Get the public URL
docker logs cloudflared 2>&1 | grep trycloudflare.com
```

## Access

| Method | URL |
|--------|-----|
| Local | `http://localhost:53842` |
| Tailscale | `https://potatostack.tale-iwato.ts.net:53842` |
| Public | Check `docker logs cloudflared` for `*.trycloudflare.com` URL |

## Usage

1. Open admin UI (local or Tailscale)
2. Upload a file — set download limit and/or expiry
3. Optionally set a password
4. Share the public cloudflared URL + download link with recipient
5. File auto-deletes after limits are reached

## Upgrading to Named Tunnel

To use your own domain instead of random `*.trycloudflare.com` URLs:

```bash
# Create a named tunnel
cloudflared tunnel create myshares

# Update docker-compose.yml cloudflared command to use token:
# command: tunnel run --token <TOKEN>
```

## Data

- Config/data: `/mnt/ssd/docker-data/gokapi`
- Storage mount: `/mnt/storage` (read-only inside container)
