# rdt-client (Debrid Download Client)

Debrid download client with qBittorrent API emulation. Runs behind Gluetun VPN.
Supports Real-Debrid, TorBox, AllDebrid, Premiumize, and DebridLink.

## Setup

1. Get your Real-Debrid API key from https://real-debrid.com/apitoken

2. Add to `.env`:
   ```
   REAL_DEBRID_API_KEY=your_key_here
   ```

3. Start:
   ```bash
   docker compose up -d rdt-client
   ```

4. Open WebUI at `http://localhost:6500` (or via Tailscale)

5. In rdt-client WebUI:
   - **Settings > Provider**: Select Real-Debrid, paste API key
   - **Settings > Download Client**: Set download path to `/downloads`
   - **Settings > Download Client**: Set temp path to `/downloads` (no separate cache, downloads go directly to storage)
   - **Settings > General > Post Download Script**: `/hooks/post-download.sh "{name}"` (optional, for ntfy notifications)

## Using TorBox Instead

rdt-client natively supports TorBox as a provider — no fork or extra image needed.

1. Get your TorBox API key from https://torbox.app/settings

2. In rdt-client WebUI:
   - **Settings > Provider**: Select **TorBox**, paste API key
   - **Settings > General > Timeout**: Set to **30 seconds** or higher (TorBox needs more time)

3. In your TorBox account settings (https://torbox.app/settings):
   - Enable **WebDAV flatten** — required for rdt-client compatibility

Everything else (Sonarr/Radarr setup, paths, notifications) stays the same.

You can switch between Real-Debrid and TorBox at any time in the provider settings.

## Sonarr/Radarr Integration

rdt-client emulates the qBittorrent API. In Sonarr/Radarr:

1. **Settings > Download Clients > Add > qBittorrent**
2. Host: `localhost`, Port: `6500`
3. No username/password needed (unless you set one in rdt-client)
4. Category: `sonarr` or `radarr`
5. Test & Save

Since Sonarr/Radarr also run behind gluetun, they access rdt-client at `127.0.0.1:6500`.

## Storage Layout

| Path (container) | Host path | Purpose |
|---|---|---|
| `/downloads` | `/mnt/storage/downloads/rdt-client` | All downloads (direct to storage) |
| `/mnt/storage/media` | `/mnt/storage/media` | Media library (for hardlinking) |
| `/data/db` | Docker volume `rdt-client-data` | SQLite settings DB |

## Resources

- CPU: 0.5 cores limit
- Memory: 256MB limit
- Port: 6500 (via gluetun)
