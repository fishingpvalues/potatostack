# Cloudflare Quick Tunnel (Public File Sharing via FileBrowser)

Exposes FileBrowser publicly via a random `trycloudflare.com` subdomain.
No account or domain needed. URL changes on every container restart.

## How It Works

1. **Cloudflared** creates a free quick tunnel → random `*.trycloudflare.com` URL
2. **URL sync cron** (`scripts/monitor/cloudflare-url-sync.sh`) runs every minute, detects the current URL, and updates Homer's config
3. **Homer** dashboard shows a "FileBrowser (Public)" link that always points to the current cloudflare URL
4. **FileBrowser** share links automatically use the cloudflare domain when accessed through it

## Architecture

```
Internet → trycloudflare.com → cloudflared container → filebrowser:80
                                       ↓
                          cloudflare-url-sync.sh (cron)
                                       ↓
                              Homer config.yml (auto-updated)
```

## Get the Public URL

```bash
make share-url
```

Or click "FileBrowser (Public)" on the Homer dashboard.

## Sharing Files

1. Open FileBrowser via the cloudflare URL (Homer → "FileBrowser (Public)")
2. Navigate to the file you want to share
3. Select file → **Share** → set expiration → copy link
4. The share link uses the cloudflare domain — works for anyone on the internet

**Important:** Open FileBrowser via the cloudflare URL (not Tailscale) when
creating share links. FileBrowser share links use the current browser domain.

## Setup

Already configured. The cron job runs automatically:

```
* * * * * /home/daniel/potatostack/scripts/monitor/cloudflare-url-sync.sh
```

Logs: `/tmp/cloudflare-url-sync.log`

## Caveats

- URL changes on every cloudflared restart — existing share links break
- No uptime guarantee (Cloudflare free tier limitation)
- ~1 minute delay for Homer to show new URL after cloudflared restart
- For permanent URLs, use a named tunnel with a custom domain ($1/yr for `.xyz`)
