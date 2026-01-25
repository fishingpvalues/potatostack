# Obsidian LiveSync Cheatsheet

## Plugin Settings (Self-hosted LiveSync)

| Field | Value |
|-------|-------|
| **Remote Type** | CouchDB |
| **URI** | `https://obsidian.YOUR_HOST_DOMAIN` |
| **Username** | `obsidian` (or your `COUCHDB_USER`) |
| **Password** | Your `COUCHDB_PASSWORD` from `.env` |
| **Database name** | `obsidian-vault` (or your `COUCHDB_DATABASE`) |

## Troubleshooting "Connection Refused"

```bash
# 1. Check if container is running
docker ps | grep obsidian-livesync

# 2. Check logs
docker logs obsidian-livesync

# 3. Test CouchDB directly
docker exec obsidian-livesync curl -u obsidian:YOUR_PASSWORD http://127.0.0.1:5984/_up

# 4. Test via Traefik
curl -u obsidian:YOUR_PASSWORD https://obsidian.YOUR_DOMAIN/_up
```

## Common Issues

1. **Database doesn't exist** - Plugin creates it on first sync; check "Create database if not exists" option
2. **CORS error** - Ensure `app://obsidian.md` is in `COUCHDB_CORS_ORIGINS` (already configured)
3. **SSL/TLS** - Use `https://` not `http://` when going through Traefik
4. **Tailscale access** - Use `https://potatostack.tale-iwato.ts.net:PORT` if accessing remotely
