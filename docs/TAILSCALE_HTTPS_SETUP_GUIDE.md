# Tailscale HTTPS Setup Guide

This guide covers secure HTTPS access for all PotatoStack services using Tailscale.

## Overview

PotatoStack uses Tailscale for secure HTTPS access:

| Method | Use Case |
|--------|-----------|
| **Tailscale HTTPS** | Primary method - secure access from your devices via tailnet |
| **Traefik** | Local network access with security headers |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Devices                              │
│  (Windows, Mac, Android, iOS, Linux)                        │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │  Tailscale   │
              │    HTTPS     │
              │  Certificates │
              └──────┬───────┘
                     │
    ┌────────────────▼────────────────────┐
    │      PotatoStack Server             │
    │  (100.108.216.90 on tailnet)        │
    │  potatostack.tale-iwato.ts.net      │
    │                                      │
    │  ┌──────────────────────────────┐   │
    │  │   tailscale serve            │   │
    │  │   - Automatic HTTPS certs    │   │
    │  │   - Port wrapping            │   │
    │  └──────────┬───────────────────┘   │
    │             │                       │
    │   ┌─────────▼─────────┐            │
    │   │  All Services     │            │
    │   │  (100 services)   │            │
    │   └───────────────────┘            │
    └─────────────────────────────────────┘
```

## Setup

### Prerequisites

1. **Tailscale Account**: Sign up at https://tailscale.com
2. **Tailscale Installed**: Install Tailscale on all your devices
3. **Auth Key**: Generate auth key from Tailscale admin console

### Environment Variables

In your `.env` file:

```bash
TAILSCALE_AUTHKEY=tskey-auth-<your-auth-key>
HOST_BIND=192.168.178.158
TAILSCALE_SERVE_PORTS=7575,8088,3001,3002,8096,2283,8443,8384,51515,5678,...
```

### Enable Tailscale HTTPS

Run the setup container (one-time):

```bash
docker compose up -d tailscale-https-setup
```

This enables HTTPS on all configured ports using Tailscale certificates.

### Keep HTTPS Active

Enable the monitor to re-apply HTTPS rules on restart:

```bash
docker compose --profile monitor up -d tailscale-https-monitor
```

## Accessing Services

Access services via your Tailscale hostname:

```bash
https://potatostack.tale-iwato.ts.net:7575   # Homarr Dashboard
https://potatostack.tale-iwato.ts.net:8096   # Jellyfin
https://potatostack.tale-iwato.ts.net:2283   # Immich
https://potatostack.tale-iwato.ts.net:3002   # Grafana
```

See `links.md` for the complete service list.

## Troubleshooting

### PR_END_OF_FILE_ERROR

This means HTTPS isn't enabled on the port.

**Fix:**
```bash
docker compose up -d tailscale-https-setup
```

### Services Not Accessible

**Check Tailscale status:**
```bash
docker exec tailscale tailscale status
```

**Verify ports are wrapped:**
```bash
docker exec tailscale tailscale serve status
```

### Certificate Warnings

Tailscale certificates are automatically trusted. If you see warnings:

1. Ensure Tailscale is running on your client device
2. Check you're using `https://` not `http://`
3. Access via hostname: `https://potatostack.tale-iwato.ts.net:PORT`

## Commands

```bash
# Check Tailscale status
docker exec tailscale tailscale status

# List HTTPS endpoints
docker exec tailscale tailscale serve status

# Re-enable HTTPS (if lost after restart)
docker compose up -d tailscale-https-setup

# Run HTTPS monitor continuously
docker compose --profile monitor up -d tailscale-https-monitor
```

---

**Last Updated**: 2026-01-24
