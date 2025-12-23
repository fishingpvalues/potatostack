# Homepage Dashboard Configuration

## Quick Start

Access the dashboard at:
- **Local**: http://localhost:3000
- **LAN**: http://YOUR_SERVER_IP:3000 (e.g., http://192.168.178.50:3000)

## Configuration Files

All configuration is in `light/homepage-config/`:

```
homepage-config/
├── settings.yaml    # Theme, layout, host validation settings
├── services.yaml    # Service widgets (Gluetun, Transmission, Immich, etc.)
├── widgets.yaml     # Info widgets (resources, search, weather)
├── bookmarks.yaml   # Quick links
├── docker.yaml      # Docker socket integration
└── custom.css       # Custom styling
```

## Making Changes

1. Edit files in `light/homepage-config/`
2. Restart Homepage: `docker compose restart homepage`
3. Changes apply immediately

## LAN Access Fix (Already Configured)

The "Host validation failed" error is fixed in `settings.yaml`:

```yaml
# Disable host validation for LAN access
disableHostCheck: true
```

This allows access from:
- ✅ Localhost
- ✅ LAN devices (phones, tablets, other computers)
- ✅ Multiple network interfaces

## Docker Compose Configuration

Key settings in `docker-compose.yml`:

```yaml
environment:
  # LAN Access Configuration (disableHostCheck: true in settings.yaml)
  - HOMEPAGE_VAR_HOST=${HOST_BIND}
  
volumes:
  # Config files mounted from ./homepage-config/
  - ./homepage-config/settings.yaml:/app/config/settings.yaml:ro
  # ... (all config files mounted as read-only)
```

## Features Configured

### Service Widgets (with live stats)
- **VPN & Downloads**: Gluetun, Transmission, slskd
- **Media & Storage**: Immich, Seafile, Kopia
- **Security & Management**: Vaultwarden, Portainer
- **System & Monitoring**: PostgreSQL, Redis, FritzBox

### Information Widgets
- System resources (CPU, RAM, Disk)
- DuckDuckGo search
- Date & Time
- Berlin weather

### Custom Styling
- Dark slate theme with blur effects
- Space background
- Card hover animations
- VPN status indicator with pulsing green glow
- Orange accent colors

## Troubleshooting

### "Host validation failed" Error
- **Fix**: Already applied in `settings.yaml` (disableHostCheck: true)
- **Verify**: Check line 7 in `homepage-config/settings.yaml`

### Widgets Not Showing Data
- Check Docker socket permission: `ls -l /var/run/docker.sock`
- Verify service is running: `docker compose ps`
- Check logs: `docker compose logs homepage`

### Config Changes Not Applied
- Restart container: `docker compose restart homepage`
- Check file is mounted: `docker compose exec homepage ls -l /app/config/`

## API Keys (Optional)

Some widgets require API keys (not configured):

- **Immich**: Generate in Immich settings → API Keys
- **Portainer**: Generate in Portainer → Account → API Tokens
- **slskd**: Check slskd settings for API key

Add keys as environment variables in `docker-compose.yml`:

```yaml
environment:
  - HOMEPAGE_VAR_IMMICH_KEY=your_key_here
  - HOMEPAGE_VAR_PORTAINER_KEY=your_key_here
  - HOMEPAGE_VAR_SLSKD_KEY=your_key_here
```

## Documentation

- Homepage Docs: https://gethomepage.dev
- Widget Reference: https://gethomepage.dev/widgets/
- Community Examples: https://github.com/gethomepage/homepage/discussions/473
