# Infisical Setup Guide

Infisical provides centralized secret management for apps and CI/CD.

## Access

- Traefik URL: `https://secrets.<HOST_DOMAIN>`
- Tailscale HTTPS: `https://HOST_BIND:8288` (after `tailscale-https-setup`)

## Required Secrets

Set these in `.env` before first start:

```
INFISICAL_ENCRYPTION_KEY=<32-char hex>
INFISICAL_AUTH_SECRET=<base64>
```

Generate:
```
openssl rand -hex 16
openssl rand -base64 32
```

## Start

```
docker compose up -d infisical
```

## Notes

- Uses existing Postgres + Redis in the stack.
- Database `infisical` is auto-created by the postgres init script on first init. If Postgres is already initialized, create it manually:
  ```
  docker exec -it postgres createdb -U postgres infisical
  ```
- For API/CLI usage, create a project and service token in the UI.
