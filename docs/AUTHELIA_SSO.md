# Authelia SSO Implementation Guide

## Overview

Authelia provides Single Sign-On (SSO) with Two-Factor Authentication (2FA) for PotatoStack services. This implementation supports:

- **OAuth2/OIDC** integration with Grafana, Portainer, Nextcloud, and Gitea
- **Two-Factor Authentication** via TOTP (Time-based One-Time Password) and WebAuthn
- **Access Control Lists** with fine-grained permissions per service
- **Session Management** using Redis for high performance
- **Security Features** including brute-force protection and session regulation

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    User Browser                      │
└───────────────┬─────────────────────────────────────┘
                │
                │ 1. Access Service
                ▼
┌─────────────────────────────────────────────────────┐
│          Nginx Proxy Manager (Reverse Proxy)         │
└───────────────┬─────────────────────────────────────┘
                │
                │ 2. Forward Auth Check
                ▼
┌─────────────────────────────────────────────────────┐
│                     Authelia                         │
│  ┌────────────────────────────────────────────┐    │
│  │ Session Store (Redis)                      │    │
│  │ User DB (File-based)                       │    │
│  │ OIDC/OAuth2 Provider                       │    │
│  └────────────────────────────────────────────┘    │
└───────────────┬─────────────────────────────────────┘
                │
                │ 3. Authenticated Request
                ▼
┌─────────────────────────────────────────────────────┐
│     Protected Services (Grafana, Portainer, etc)    │
└─────────────────────────────────────────────────────┘
```

## Installation

### Step 1: Generate Required Secrets

Generate all required secrets and keys:

```bash
# Generate secrets (64+ characters recommended)
openssl rand -base64 64

# You'll need to run this 4 times for:
# - AUTHELIA_JWT_SECRET
# - AUTHELIA_SESSION_SECRET
# - AUTHELIA_STORAGE_ENCRYPTION_KEY
# - AUTHELIA_OIDC_HMAC_SECRET

# Generate OAuth2 client secrets for each service
openssl rand -base64 32  # GRAFANA_OIDC_SECRET
openssl rand -base64 32  # PORTAINER_OIDC_SECRET
openssl rand -base64 32  # NEXTCLOUD_OIDC_SECRET
openssl rand -base64 32  # GITEA_OIDC_SECRET

# Generate RSA key pair for OIDC
docker run --rm authelia/authelia:latest authelia crypto pair rsa generate --bits 4096
```

### Step 2: Update .env File

Copy the generated secrets to your `.env` file:

```bash
# Edit your .env file
nano .env

# Add the following (replace with your generated values):
AUTHELIA_JWT_SECRET=your_generated_jwt_secret
AUTHELIA_SESSION_SECRET=your_generated_session_secret
AUTHELIA_STORAGE_ENCRYPTION_KEY=your_generated_storage_key
AUTHELIA_OIDC_HMAC_SECRET=your_generated_oidc_hmac_secret
AUTHELIA_OIDC_PRIVATE_KEY=|
  -----BEGIN PRIVATE KEY-----
  YOUR_GENERATED_PRIVATE_KEY_HERE
  -----END PRIVATE KEY-----
GRAFANA_OIDC_SECRET=your_generated_grafana_secret
PORTAINER_OIDC_SECRET=your_generated_portainer_secret
NEXTCLOUD_OIDC_SECRET=your_generated_nextcloud_secret
GITEA_OIDC_SECRET=your_generated_gitea_secret
```

### Step 3: Create User Password Hash

Generate an Argon2id password hash for your admin user:

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourSecurePassword123!'
```

Copy the generated hash (starting with `$argon2id$...`) and update `config/authelia/users_database.yml`:

```yaml
users:
  admin:
    displayname: "Administrator"
    password: "$argon2id$v=19$m=65536,t=3,p=4$YOUR_GENERATED_HASH"
    email: admin@lepotato.local
    groups:
      - admins
      - users
```

### Step 4: Configure DNS/Hosts

Add the following entries to your `/etc/hosts` (or configure in your DNS server):

```
192.168.178.40  authelia.lepotato.local
192.168.178.40  grafana.lepotato.local
192.168.178.40  portainer.lepotato.local
192.168.178.40  nextcloud.lepotato.local
192.168.178.40  gitea.lepotato.local
192.168.178.40  qbittorrent.lepotato.local
192.168.178.40  slskd.lepotato.local
192.168.178.40  homepage.lepotato.local
192.168.178.40  prometheus.lepotato.local
192.168.178.40  kopia.lepotato.local
192.168.178.40  uptime.lepotato.local
192.168.178.40  netdata.lepotato.local
```

Replace `192.168.178.40` with your Le Potato's IP address.

### Step 5: Configure Nginx Proxy Manager

1. Access Nginx Proxy Manager at `http://192.168.178.40:81`
2. Log in with default credentials (change immediately!)
3. For each service, create a Proxy Host:

#### Example: Grafana with Authelia Forward Auth

**Proxy Host Settings:**
- Domain: `grafana.lepotato.local`
- Scheme: `http`
- Forward Hostname: `grafana`
- Forward Port: `3000`
- Enable: Cache Assets, Block Common Exploits, Websockets Support

**SSL Tab:**
- SSL Certificate: Request a new Let's Encrypt certificate
- Force SSL: Enabled
- HTTP/2 Support: Enabled

**Advanced Tab:**
```nginx
location /api/oidc/ {
    proxy_pass http://authelia:9091;
    include /etc/nginx/snippets/authelia-location.conf;
}

location / {
    # Forward auth to Authelia
    auth_request /authelia;
    auth_request_set $user $upstream_http_remote_user;
    auth_request_set $groups $upstream_http_remote_groups;
    auth_request_set $name $upstream_http_remote_name;
    auth_request_set $email $upstream_http_remote_email;

    proxy_set_header Remote-User $user;
    proxy_set_header Remote-Groups $groups;
    proxy_set_header Remote-Name $name;
    proxy_set_header Remote-Email $email;

    error_page 401 =302 https://authelia.lepotato.local/?rd=$scheme://$http_host$request_uri;

    proxy_pass http://grafana:3000;
}

location /authelia {
    internal;
    proxy_pass http://authelia:9091/api/verify;

    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-Method $request_method;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Uri $request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;

    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
}
```

Repeat this for all services you want to protect with Authelia.

### Step 6: Start Authelia

```bash
# Start the stack with Authelia
docker-compose up -d authelia

# Check logs
docker logs -f authelia

# Verify it's running
curl http://localhost:9091/api/health
```

### Step 7: Test SSO Login

1. Access Grafana via the proxy: `https://grafana.lepotato.local`
2. You'll be redirected to Authelia login
3. Enter your credentials
4. Complete 2FA setup (scan QR code with authenticator app)
5. You'll be redirected back to Grafana, logged in automatically

## Service Integration

### Grafana

Grafana is configured to use Authelia as an OAuth2 provider. Users in the `admins` group get Admin role, others get Viewer role.

**Access:** `https://grafana.lepotato.local`

### Portainer

Portainer CE has limited OAuth support. For best results, protect it with Nginx forward auth using Authelia.

**Access:** `https://portainer.lepotato.local`

### Nextcloud

Nextcloud requires the OIDC Login app. Install it:

```bash
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:enable user_oidc
```

Configure in Nextcloud admin settings:
- Identifier: `nextcloud`
- Client ID: `nextcloud`
- Client Secret: `${NEXTCLOUD_OIDC_SECRET}`
- Discovery endpoint: `https://authelia.lepotato.local/.well-known/openid-configuration`

**Access:** `https://nextcloud.lepotato.local`

### Gitea

Configure OAuth2 authentication in Gitea admin panel:
1. Go to Site Administration → Authentication Sources
2. Add Authentication Source
3. Type: OAuth2
4. Name: Authelia
5. Client ID: `gitea` (add to Authelia config first)
6. Client Secret: `${GITEA_OIDC_SECRET}`
7. OpenID Connect Auto Discovery URL: `https://authelia.lepotato.local/.well-known/openid-configuration`

**Access:** `https://gitea.lepotato.local`

## Access Control Rules

The default configuration includes three policy levels:

### 1. Two-Factor (Admin Services)
- Grafana
- Prometheus
- Portainer
- Nginx Proxy Manager
- Kopia
- Netdata
- qBittorrent
- slskd (Soulseek)

**Required:** User must be in `admins` group + TOTP/WebAuthn

### 2. One-Factor (User Services)
- Nextcloud
- Gitea
- Homepage
- Uptime Kuma

**Required:** User must be in `users` or `admins` group

### 3. Bypass (Public)
- Public services (if any)

**Required:** None

Edit `config/authelia/configuration.yml` to customize access rules.

## User Management

### Add New User

Edit `config/authelia/users_database.yml`:

```yaml
users:
  newuser:
    displayname: "New User"
    password: "$argon2id$v=19$m=65536,t=3,p=4$GENERATED_HASH"
    email: newuser@lepotato.local
    groups:
      - users
```

Generate password hash:
```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'UserPassword123!'
```

Restart Authelia:
```bash
docker restart authelia
```

### Change User Password

1. Generate new hash:
```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'NewPassword123!'
```

2. Update `config/authelia/users_database.yml`

3. Restart Authelia:
```bash
docker restart authelia
```

### Modify User Groups

Edit `config/authelia/users_database.yml` and change the `groups` array:

```yaml
users:
  username:
    groups:
      - users        # Basic access
      - admins       # Admin services
      - dev          # Development access (if configured)
```

## Two-Factor Authentication

### TOTP (Time-Based One-Time Password)

Supported apps:
- Google Authenticator (iOS/Android)
- Authy (iOS/Android)
- Microsoft Authenticator (iOS/Android)
- 1Password
- Bitwarden

**Setup:**
1. Log in to Authelia
2. Scan the QR code with your authenticator app
3. Enter the 6-digit code to verify

### WebAuthn (Hardware Keys)

Supported devices:
- YubiKey 5 Series
- Google Titan Security Key
- Any FIDO2-compatible device

**Setup:**
1. Log in to Authelia
2. Navigate to Settings → Security
3. Click "Register Device"
4. Follow your browser's prompts

## Monitoring & Troubleshooting

### Check Authelia Health

```bash
# Health endpoint
curl http://localhost:9091/api/health

# Check logs
docker logs -f authelia

# Check Redis connection
docker exec authelia redis-cli -h redis ping
```

### Common Issues

#### 1. "Invalid credentials"
- Verify password hash is correct in `users_database.yml`
- Ensure hash starts with `$argon2id$`
- Check username is lowercase

#### 2. "Session expired"
- Check Redis is running: `docker ps | grep redis`
- Verify Redis connection in logs: `docker logs authelia | grep redis`

#### 3. "OIDC client not found"
- Ensure client ID in service config matches Authelia config
- Verify client secret is set correctly in `.env`
- Check logs: `docker logs authelia | grep oidc`

#### 4. "Redirect URI mismatch"
- Ensure redirect URIs in `configuration.yml` match service configuration
- Check protocol (http vs https)
- Verify domain names

#### 5. "Failed to authenticate"
- Check nginx forward auth configuration
- Verify `/authelia` location block exists
- Check Authelia is accessible from nginx: `docker exec nginx-proxy-manager curl http://authelia:9091/api/health`

### Debug Mode

Enable debug logging temporarily:

```bash
# Edit config/authelia/configuration.yml
log:
  level: debug  # Change from 'info' to 'debug'

# Restart
docker restart authelia

# View detailed logs
docker logs -f authelia
```

## Security Considerations

### 1. Strong Secrets
- All secrets should be 64+ characters
- Use cryptographically secure random generation
- Never reuse secrets across services

### 2. Password Policy
Argon2id parameters (in `configuration.yml`):
- `memory: 65536` (64MB RAM per hash)
- `iterations: 3`
- `parallelism: 4`
- `key_length: 32`

These settings balance security and performance for Le Potato's ARM64 CPU.

### 3. Session Security
- Sessions expire after 1 hour of inactivity
- Remember-me duration: 1 month
- Sessions stored in Redis with encryption

### 4. Brute Force Protection
- Max retries: 5 attempts
- Find time: 2 minutes
- Ban time: 10 minutes

### 5. Network Security
- Authelia only accessible via nginx proxy
- Internal API endpoints not exposed
- Redis connection password-protected

## Backup & Recovery

### Backup Configuration

```bash
# Backup Authelia config
tar -czf authelia-backup-$(date +%Y%m%d).tar.gz \
  config/authelia/

# Include in Kopia backups
# (Already configured via /host mount)
```

### Restore Configuration

```bash
# Extract backup
tar -xzf authelia-backup-YYYYMMDD.tar.gz

# Restart Authelia
docker restart authelia
```

### Backup User Database

The `users_database.yml` contains all users. Back it up regularly:

```bash
cp config/authelia/users_database.yml config/authelia/users_database.yml.bak
```

## Performance Tuning

### Redis Optimization

Authelia uses Redis for session storage. The existing Redis container is optimized for the Le Potato:

```yaml
command:
  - redis-server
  - --maxmemory 64mb
  - --maxmemory-policy allkeys-lru
  - --save ""
  - --appendonly no
```

### Resource Limits

Authelia container limits:
- RAM: 128MB limit, 64MB reservation
- CPU: 0.5 cores
- Logs: 10MB max, 3 files

Adjust in `docker-compose.yml` if needed.

## Advanced Configuration

### Custom Access Rules

Edit `config/authelia/configuration.yml`:

```yaml
access_control:
  rules:
    # Block specific IPs
    - domain: "*"
      policy: deny
      networks:
        - 192.168.100.0/24

    # Allow specific users to specific services
    - domain: "kopia.lepotato.local"
      policy: two_factor
      subject:
        - "user:admin"
        - "user:backup-user"

    # Time-based access
    - domain: "portainer.lepotato.local"
      policy: two_factor
      subject:
        - "group:admins"
      # Add time restrictions if needed (requires cron)
```

### Email Notifications

Authelia sends emails for:
- Password reset requests
- 2FA device registration
- Security alerts

Configure in `configuration.yml` (uses existing SMTP settings from `.env`).

### LDAP Backend (Optional)

For enterprise setups, replace file-based authentication with LDAP:

```yaml
authentication_backend:
  ldap:
    url: ldap://openldap:389
    base_dn: dc=example,dc=com
    username_attribute: uid
    additional_users_dn: ou=users
    users_filter: (&({username_attribute}={input})(objectClass=person))
    additional_groups_dn: ou=groups
    groups_filter: (&(member={dn})(objectClass=groupOfNames))
    group_name_attribute: cn
    mail_attribute: mail
    display_name_attribute: displayName
    user: cn=admin,dc=example,dc=com
    password: admin_password
```

## References

- [Authelia Documentation](https://www.authelia.com/)
- [OAuth2/OIDC Spec](https://oauth.net/2/)
- [Argon2 Password Hashing](https://github.com/P-H-C/phc-winner-argon2)
- [WebAuthn Guide](https://webauthn.guide/)

## Support

For issues:
1. Check logs: `docker logs authelia`
2. Verify configuration: `docker exec authelia authelia validate-config /config/configuration.yml`
3. Test health: `curl http://localhost:9091/api/health`
4. Review this guide's troubleshooting section

---

**Implementation Status:** ✅ Configured and ready for deployment
**Last Updated:** 2025-12-08
**Maintained by:** PotatoStack Project
