# Vaultwarden Setup Guide

Complete step-by-step guide to register and use Vaultwarden across all devices.

## Initial Access

Vaultwarden runs on **HTTPS port 8443** (not 8080) with self-signed certificates.

**Web Vault URL**: `https://HOST_BIND:8443`

When you first visit, your browser will warn about the self-signed certificate. Accept the warning to proceed.

## Step 1: Enable Signups (First Time Only)

By default, signups are disabled. You have two options:

### Option A: Enable Signups Temporarily

1. On the PotatoStack host (or via SSH):
```bash
cd ~/light
nano .env
```

2. Change this line:
```bash
VAULTWARDEN_SIGNUPS_ALLOWED=true
```

3. Restart Vaultwarden:
```bash
docker compose restart vaultwarden
```

4. After creating your account, **disable signups again** and restart:
```bash
VAULTWARDEN_SIGNUPS_ALLOWED=false
docker compose restart vaultwarden
```

### Option B: Use Admin Panel to Invite

1. Access admin panel: `https://HOST_BIND:8443/admin`

2. Enter admin token (get from `.env` file):
```bash
grep VAULTWARDEN_ADMIN_TOKEN .env
```

3. Go to "Users" tab → "Invite User" → Enter email address

4. You'll get an invitation link to copy/paste in browser

## Step 2: Register Your First Account

1. Open web browser: `https://HOST_BIND:8443`

2. Accept certificate warning (click "Advanced" → "Proceed to site")

3. Click **"Create Account"**

4. Fill in:
   - **Email**: Your email (doesn't need to be real, just unique identifier)
   - **Name**: Your name
   - **Master Password**: Strong password (you'll need to remember this)
   - **Re-type Master Password**: Same password
   - **Master Password Hint**: Optional reminder (NOT the password itself)

5. Click **"Submit"**

6. Log in with your email and master password

## Step 3: Setup on Android

### Install Bitwarden App

1. Install **Bitwarden** from Google Play Store (official Bitwarden app works with Vaultwarden)

2. Open app, tap "Settings" (gear icon at top)

3. Tap **"Self-hosted environment"**

4. Enter **Server URL**: `https://HOST_BIND:8443`

5. Leave all other fields EMPTY:
   - Web Vault Server URL: (empty)
   - API Server URL: (empty)
   - Identity Server URL: (empty)
   - Icons Server URL: (empty)

6. Tap **"Save"**

7. Go back, tap **"Log In"**

8. Enter your email and master password

### Certificate Trust (Android)

If connection fails with certificate error:

**Option 1: Trust certificate in Android**
1. In browser on phone, visit `https://HOST_BIND:8443`
2. Accept certificate warning
3. Return to Bitwarden app and try logging in again

**Option 2: Use HTTP instead** (less secure, LAN only)
- Requires changing docker-compose.yml to expose port 80
- Not recommended for production use

## Step 4: Setup on iOS

1. Install **Bitwarden** from App Store

2. Tap Settings → **Server URL**

3. Enter: `https://HOST_BIND:8443`

4. Tap **"Save"**

5. Log in with email and master password

**Certificate trust**: iOS may require installing the self-signed certificate in Settings → General → VPN & Device Management

## Step 5: Setup on Windows

### Option A: Browser Extension

1. Install Bitwarden extension:
   - **Chrome/Edge**: https://chrome.google.com/webstore/detail/bitwarden/nngceckbapebfimnlniiiahkandclblb
   - **Firefox**: https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/

2. Click extension icon → Settings (gear icon)

3. Click **"Self-hosted environment"**

4. Server URL: `https://HOST_BIND:8443`

5. Click **"Save"**

6. Click **"Log In"** → Enter email and master password

7. **Accept certificate**: Browser will prompt about self-signed cert, click "Advanced" → "Proceed"

### Option B: Desktop App

1. Download from: https://bitwarden.com/download/

2. Install and open app

3. Click Settings (gear icon) → **"Self-hosted environment"**

4. Server URL: `https://HOST_BIND:8443`

5. Click **"Save"** → **"Log In"**

## Step 6: Setup on Linux

Same as Windows - use browser extension or desktop app.

```bash
# Flatpak
flatpak install flathub com.bitwarden.desktop

# Snap
snap install bitwarden

# AppImage
wget https://vault.bitwarden.com/download/?app=desktop&platform=linux
chmod +x Bitwarden-*.AppImage
./Bitwarden-*.AppImage
```

Configure with server URL: `https://HOST_BIND:8443`

## Step 7: Test Login Sync

1. Add a test password on one device

2. Wait 10 seconds (or trigger manual sync)

3. Check if it appears on other devices

4. WebSocket port 3012 enables live sync between devices

## Troubleshooting

### "Can't connect to server"

1. **Check Vaultwarden is running**:
```bash
docker ps | grep vaultwarden
docker logs vaultwarden
```

2. **Test from the host itself**:
```bash
curl -k https://127.0.0.1:8443/alive
# Should return: {"status":"ok"}
```

3. **Test from your device**:
```bash
curl -k https://HOST_BIND:8443/alive
```

4. **Check firewall** (host):
```bash
sudo ufw status
sudo ufw allow 8443/tcp
sudo ufw allow 3012/tcp
```

### "Certificate error" / "SEC_ERROR_UNKNOWN_ISSUER"

**Expected behavior** - self-signed certificate triggers warnings.

**Solutions**:
- Click "Advanced" → "Proceed to site" (browser)
- Accept certificate in app settings
- Install root CA certificate on device (advanced)

### Container won't start / keeps restarting

```bash
# Check logs
docker logs vaultwarden

# Check memory
docker stats vaultwarden
free -h

# Restart with more time
docker compose restart vaultwarden
sleep 30  # Wait for startup on low-RAM devices

# Manual healthcheck test
docker exec vaultwarden curl -fk https://127.0.0.1:8443/alive
```

### Forgot admin token

```bash
cd ~/light
grep VAULTWARDEN_ADMIN_TOKEN .env
```

Or regenerate:
```bash
openssl rand -base64 48
# Update .env with new token
docker compose restart vaultwarden
```

## Admin Panel Features

Access: `https://HOST_BIND:8443/admin`

**Functions**:
- View all registered users
- Delete users
- Invite new users (when signups disabled)
- View diagnostics and logs
- Configure settings
- Backup database

## Security Best Practices

1. **Keep signups disabled** after initial setup (`VAULTWARDEN_SIGNUPS_ALLOWED=false`)

2. **Secure admin token** - long random string in `.env`

3. **LAN access only** - services bind to `HOST_BIND` IP, not exposed to internet

4. **Backup data volume**:
```bash
docker run --rm -v vaultwarden-data:/data -v /mnt/storage/backups:/backup alpine tar czf /backup/vaultwarden-$(date +%Y%m%d).tar.gz /data
```

5. **Use strong master passwords** - this is your single point of security

## Service Details

**Web Vault**: HTTPS port 8443
**WebSocket**: Port 3012 (live sync)
**Database**: SQLite at `/data/db.sqlite3` (in volume)
**Certs**: Auto-generated self-signed in `/ssl/` volume
**Memory**: 128MB limit (adequate for low-RAM devices)

## URLs Summary

| Access Point | URL |
|--------------|-----|
| Web Vault | `https://HOST_BIND:8443` |
| Admin Panel | `https://HOST_BIND:8443/admin` |
| Health Check | `https://HOST_BIND:8443/alive` |
| Homepage Link | Click "Vaultwarden" card on dashboard |

**Note**: Replace `HOST_BIND` with your actual host IP from `.env`
