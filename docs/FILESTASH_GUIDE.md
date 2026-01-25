# Filestash Setup

Advanced file manager with multi-protocol support, media previews, and office document viewing.

## Access

- **Port**: 8095 (`https://potatostack.tale-iwato.ts.net:8095`)
- **Traefik**: `https://filestash.${HOST_DOMAIN}`

## Storage Mounts

| Mount | Host | Access |
|-------|------|--------|
| `/mnt/storage` | `/mnt/storage` | RW |
| `/mnt/cachehdd` | `/mnt/cachehdd` | RW |
| `/mnt/docker-data` | `/mnt/ssd/docker-data` | RO |

## Authentik SSO Setup

1. Create OAuth2 Provider in Authentik:
   - Redirect URI: `https://filestash.${HOST_DOMAIN}/login`
   - Scopes: `openid`, `profile`, `email`

2. Add to `.env`:
```bash
FILESTASH_OIDC_CLIENT_ID=<client_id>
FILESTASH_OIDC_CLIENT_SECRET=<client_secret>
```

3. Restart: `docker compose restart filestash`

## Recommended Plugins

Download from https://downloads.filestash.app/upload/plugins, extract to `/mnt/ssd/docker-data/filestash/plugins/`

| Plugin | Purpose |
|--------|---------|
| `plg_authenticate_openid` | Authentik OIDC |
| `plg_application_photographer` | RAW/HEIF photo previews |
| `plg_application_musician` | Music previews |
| `plg_video_transcoder` | Video transcoding |
| `plg_application_office` | Office docs viewer |

## vs Filebrowser

- **Filestash**: Multi-protocol, advanced media previews, office viewer, ~256MB RAM
- **Filebrowser**: Simple, fast, local-only, ~128MB RAM

Use Filebrowser for quick operations, Filestash for advanced file management.
