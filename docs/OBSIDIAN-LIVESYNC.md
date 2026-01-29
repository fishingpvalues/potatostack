# Obsidian LiveSync Cheatsheet

## Plugin Settings (Self-hosted LiveSync)

| Field | Value |
|-------|-------|
| **Remote Type** | CouchDB |
| **URI** | `https://potatostack.tale-iwato.ts.net:5984` |
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

1. **No registration** - CouchDB does not support self-registration in Obsidian. Use the existing user (`COUCHDB_USER`) and password from `.env`.
2. **Database doesn't exist** - The init container creates it; plugin can also create it if "Create database if not exists" is enabled.
3. **CORS error** - Ensure `app://obsidian.md` is in `COUCHDB_CORS_ORIGINS` (already configured).
4. **SSL/TLS** - Use `https://potatostack.tale-iwato.ts.net:5984` (Tailscale HTTPS on port 5984).
