# Tailscale Access Guide

## Configuration Complete ✅

All services are now configured to accept connections from **all interfaces** (0.0.0.0), making them accessible via:
- ✅ Tailscale network
- ✅ Local LAN
- ✅ Localhost

## How to Access from Your Devices

### From Windows PC (danielfischer - 100.109.19.109)

**Option 1: Use Tailscale IP (Recommended)**
```
http://100.108.216.90:7575    (Homarr)
http://100.108.216.90:2283    (Immich)
http://100.108.216.90:8096    (Jellyfin)
```

**Option 2: Use Hostname (if MagicDNS enabled)**
```
http://potatostack:7575
http://potatostack:2283
http://potatostack:8096
```

### Troubleshooting Connection Issues

#### 1. Can't Connect from Browser

**Check Tailscale Status:**
- Ensure Tailscale is running on your Windows PC
- Look for the green indicator in system tray
- Verify you see `potatostack` in the Tailscale app

**Test Connection:**
```cmd
# Windows Command Prompt
ping 100.108.216.90
telnet 100.108.216.90 7575
```

#### 2. Connection Refused or Timeout

**On Windows PC:**
1. Open Tailscale app
2. Click on "potatostack"
3. Verify status shows "Connected"
4. Try the IP directly: `http://100.108.216.90:7575`

**On Server (via SSH):**
```bash
# Check if services are listening
docker ps | grep homarr
ss -tlnp | grep :7575

# Check Tailscale connectivity
docker exec tailscale tailscale ping danielfischer
```

#### 3. DNS Not Working

If `http://potatostack:7575` doesn't work but `http://100.108.216.90:7575` does:

**Enable MagicDNS on server:**
```bash
docker exec tailscale tailscale up --accept-dns
```

**Enable MagicDNS on Windows:**
- Open Tailscale settings
- Enable "Use Tailscale DNS settings"
- Restart Tailscale

#### 4. Still Not Working?

**Restart Tailscale container:**
```bash
docker restart tailscale
```

**Restart all services:**
```bash
cd ~/potatostack
docker compose restart
```

## Permanent Configuration

### Environment Variables (`.env`)
```bash
# Services bind to all interfaces (required for Tailscale)
HOST_BIND=0.0.0.0

# Your Tailscale auth key
TAILSCALE_AUTHKEY=tskey-auth-...
```

### Services Running on All Interfaces
All 77 services now accept connections from any interface:
- ✅ Tailscale (100.108.216.90)
- ✅ LAN (192.168.178.158)
- ✅ Localhost (127.0.0.1)

## Security Considerations

### Is 0.0.0.0 Safe?

**YES** - Your services are protected by:

1. **Tailscale Encryption**: All Tailscale traffic is end-to-end encrypted
2. **Access Control**: Only devices in your Tailscale network can connect
3. **No Public Exposure**: Services are NOT exposed to the internet
4. **Authentik SSO**: Most services require authentication through Authentik

### What Changed?

**Before:**
```
HOST_BIND=192.168.178.158  # Only LAN access
```

**After:**
```
HOST_BIND=0.0.0.0           # LAN + Tailscale access
```

Services are still **NOT** accessible from the internet - only from:
- Your local network (192.168.178.x)
- Your Tailscale network (100.x.x.x)

## Testing Access

### Quick Connection Test

**From your Windows PC:**

1. Open browser
2. Go to: `http://100.108.216.90:7575`
3. You should see Homarr dashboard

**If you see "Connection refused" or "Can't connect":**
- Check Tailscale is running on Windows
- Verify IP: Run `tailscale ip` in PowerShell
- Ping server: `ping 100.108.216.90`

### All Service URLs

See `links.md` for complete list of all 77 services with their ports.

## Common Issues

### Firefox-Specific Issues

Firefox might block `http://` connections to private IPs by default.

**Fix:**
1. Type `about:config` in Firefox address bar
2. Search for: `network.proxy.allow_hijacking_localhost`
3. Set to `true`

Or use Chrome/Edge which don't have this restriction.

### Windows Firewall

Windows Firewall should allow Tailscale by default, but verify:
1. Windows Security → Firewall & network protection
2. Allow an app through firewall
3. Ensure "Tailscale" is checked for Private networks

### VPN Conflicts

If you're using Surfshark or other VPN on Windows:
- Tailscale traffic goes through the VPN
- This is normal and should work
- If not, try disconnecting VPN temporarily to test

## Next Steps

1. **Save this IP**: `100.108.216.90` (your potatostack)
2. **Bookmark**: `http://100.108.216.90:7575` (Homarr dashboard)
3. **Enable MagicDNS** (optional): For hostname support
4. **Configure Authentik**: Set up SSO for services

## Support

If you still can't connect:

1. Check server status:
   ```bash
   docker ps --filter "name=tailscale"
   docker exec tailscale tailscale status
   ```

2. Check from server:
   ```bash
   nc -zv 100.108.216.90 7575
   ss -tlnp | grep :7575
   ```

3. Collect logs:
   ```bash
   docker logs tailscale --tail 50
   docker logs homarr --tail 50
   ```

---

**Your Tailscale Network:**
- Server: `potatostack` (100.108.216.90)
- Windows PC: `danielfischer` (100.109.19.109)
- Android: `xiaomi-2412dpc0ag-1` (100.102.40.23)
