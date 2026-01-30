# Gluetun VPN Configuration Guide

This guide explains how to configure Gluetun VPN using a Surfshark WireGuard configuration file.

## Quick Start

1. **Download Surfshark WireGuard Configuration**
   - Log in to your Surfshark account
   - Go to Setup → Manual Setup → WireGuard
   - Select your location (e.g., Germany - Frankfurt)
   - Generate a key pair first (if required)
   - Download the `.conf` file

2. **Run the Configuration Script**
   ```bash
   ./scripts/setup/configure-gluetun-from-conf.sh ~/Downloads/surfshark-frankfurt.conf
   ```

3. **Restart Gluetun**
   ```bash
   docker compose restart gluetun
   ```

4. **Verify VPN Status**
   ```bash
   docker logs -f gluetun
   curl http://192.168.178.158:8008/v1/vpn/status
   ```

## Script Details

The `configure-gluetun-from-conf.sh` script:

- Parses a Surfshark WireGuard `.conf` file
- Extracts: PrivateKey, Address, PublicKey, Endpoint, DNS
- Updates `.env` file with correct Gluetun parameters
- Creates a timestamped backup of `.env` before modifying

### What Gets Updated in `.env`

| Variable | Value |
|----------|-------|
| `VPN_PROVIDER` | surfshark |
| `VPN_TYPE` | wireguard |
| `WIREGUARD_PRIVATE_KEY` | From conf file |
| `WIREGUARD_ADDRESSES` | From conf file |
| `SERVER_COUNTRIES` | Auto-detected from endpoint |
| `VPN_DNS` | First DNS server from conf |

## Manual Configuration

If you prefer to configure manually, update these variables in `.env`:

```bash
VPN_PROVIDER=surfshark
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_ADDRESSES=10.14.0.2/16
SERVER_COUNTRIES=Germany
VPN_DNS=1.1.1.1
```

## Troubleshooting

### VPN Fails to Connect

Check logs for errors:
```bash
docker logs --tail 100 gluetun
```

Common issues:
- Wrong private key (regenerate key pair in Surfshark)
- Incorrect address format (should be CIDR notation, e.g., `10.14.0.2/16`)
- DNS resolution issues (try `VPN_DNS=1.1.1.1`)

### Healthcheck Failing

The healthcheck verifies connectivity by attempting to reach external services:
- github.com
- cloudflare.com

If DNS is slow or blocked, the initial healthcheck may fail. Gluetun will retry automatically.

### Verify Public IP

Check if VPN is working:
```bash
curl http://192.168.178.158:8008/v1/vpn/publicip
```

Expected output should show a Surfshark IP address in the configured country.

## Services Using VPN

These services use the VPN automatically via `network_mode: "service:gluetun"`:

- Prowlarr (indexer manager)
- Sonarr (TV shows)
- Radarr (movies)
- Lidarr (music)
- Bookshelf (ebooks)
- Bazarr (subtitles)
- qBittorrent (downloads)
- Slskd (Soulseek)
- SpotiFLAC
- pyLoad
- Stash

## Security Notes

- Never commit `.env` file to git
- The script creates backups before modifying `.env`
- VPN credentials are stored in `.env` as plain text
- Rotate your Surfshark keys periodically via their dashboard
