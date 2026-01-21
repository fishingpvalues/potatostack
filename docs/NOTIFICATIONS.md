# Notifications Hub (ntfy)

ntfy is the central push hub for all alerts in the stack. It gives one endpoint for phone + desktop notifications.

## Access

- Traefik URL: `https://ntfy.<HOST_DOMAIN>`
- Tailscale HTTPS: `https://HOST_BIND:8060` (after `tailscale-https-setup`)

## Topics

Default topic used by Alertmanager and Diun:
```
potatostack
```

Subscribe in the ntfy app or browser:
```
https://ntfy.<HOST_DOMAIN>/potatostack
```

## Alertmanager → ntfy (already wired)

Alertmanager sends alerts to:
```
http://ntfy:80/potatostack
```

If you want a different topic, edit `config/alertmanager/config.yml`.

## Uptime Kuma → ntfy

In Uptime Kuma:
1. Settings → Notifications → Add
2. Type: **Webhook**
3. URL:
   ```
   https://ntfy.<HOST_DOMAIN>/potatostack
   ```
4. Method: POST

## Healthchecks → ntfy

In Healthchecks:
1. Integrations → Add
2. Webhook
3. URL:
   ```
   https://ntfy.<HOST_DOMAIN>/potatostack
   ```

## Diun → ntfy (already wired)

Diun uses:
```
NTFY_INTERNAL_URL=http://ntfy:80
NTFY_TOPIC=potatostack
```

## n8n → ntfy

Use HTTP Request node:
```
POST https://ntfy.<HOST_DOMAIN>/potatostack
Body: text/plain (message)
```

## Security (optional)

If you want auth:
1. Set `NTFY_ENABLE_LOGIN=true`
2. Set `NTFY_AUTH_DEFAULT_ACCESS=deny-all`
3. Create users inside the container:
   ```
   docker exec ntfy ntfy user add <user>
   docker exec ntfy ntfy access <user> potatostack write
   ```

Then use `Authorization: Bearer <token>` or basic auth in your integrations.
