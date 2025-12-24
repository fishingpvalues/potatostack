# Remote Access Guide for PotatoStack

## Overview

This guide covers **SOTA 2025** remote access solutions for your homelab:

1. **Tailscale** (Recommended) - Zero-config mesh VPN for personal devices
2. **WireGuard + VPS Gateway** - Public domain access with Mittwald/VPS
3. **Fritzbox Configuration** - Port forwarding and security

---

## Option 1: Tailscale (EASIEST - Recommended for Personal Use)

### Why Tailscale?

- ✅ **Zero configuration** - Install and go
- ✅ **Automatic NAT traversal** - Works behind any router
- ✅ **Auto-reconnect** - Devices stay connected
- ✅ **Cross-platform** - Android, iOS, Windows, Mac, Linux
- ✅ **Free** - Up to 100 devices on personal plan
- ✅ **Already in your stack!**

**Sources:**
- [Tailscale vs WireGuard](https://tailscale.com/compare/wireguard)
- [Homelab Networking with Tailscale](https://tailscale.com/use-cases/homelab)
- [6 reasons to prefer Tailscale](https://www.xda-developers.com/reasons-use-tailscale-instead-wireguard/)

### Setup Steps

#### 1. Get Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate an **Auth Key** (check "Reusable" and "Ephemeral: No")
3. Copy the key

#### 2. Configure PotatoStack

```bash
# In your .env file
TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxx
```

#### 3. Start Tailscale

```bash
docker compose up -d tailscale
```

#### 4. Check Status

```bash
docker logs tailscale
# You should see "Logged in" message
```

#### 5. Connect Devices

**Android:**
1. Install [Tailscale from Play Store](https://play.google.com/store/apps/details?id=com.tailscale.ipn)
2. Open app, sign in with your account
3. Done! Auto-connects

**Laptop/Desktop:**
1. Download from https://tailscale.com/download
2. Install and sign in
3. Done! Auto-connects

**Access Services:**
- Find your homelab IP in Tailscale: `100.x.x.x`
- Access any service: `http://100.x.x.x:port`
- E.g., Jellyfin: `http://100.x.x.x:8096`

---

## Option 2: WireGuard + VPS Gateway (For Public Domain Access)

### Architecture

```
Internet → Mittwald VPS (yourdomain.com) → WireGuard Tunnel → Fritzbox → Mini PC
```

This setup lets you:
- Access services via public domain (`jellyfin.yourdomain.com`)
- Share access with others (without VPN client)
- Keep home network secure
- Works with CGNAT/Double-NAT

**Sources:**
- [WireGuard VPS Gateway](https://adminarchives.com/posts/vps-wireguard-gateway/)
- [VPS Reverse Proxy Tunnel](https://blog.fuzzymistborn.com/vps-reverse-proxy-tunnel/)
- [WireGuard HAProxy Gateway](https://theorangeone.net/posts/wireguard-haproxy-gateway/)

### Step 1: Configure WireGuard Server at Home

#### 1.1 Update .env

```bash
# WireGuard Server Configuration
WIREGUARD_SERVERURL=your-fritzbox-dyndns-or-static-ip.com
WIREGUARD_SERVERPORT=51820
WIREGUARD_PEERS=vps,android,laptop,tablet
WIREGUARD_INTERNAL_SUBNET=10.13.13.0/24
```

#### 1.2 Start WireGuard Server

```bash
docker compose up -d wireguard-server
```

#### 1.3 Get VPS Peer Config

```bash
docker exec wireguard-server cat /config/peer_vps/peer_vps.conf
```

Save this config - you'll need it for the VPS!

### Step 2: Configure Fritzbox Port Forwarding

**Sources:**
- [WireGuard Fritzbox Setup](https://support.surfshark.com/hc/en-us/articles/12672238950290-How-to-set-up-WireGuard-on-FRITZ-Box)
- [Port Forwarding for WireGuard](https://portforward.com/wireguard/)

#### 2.1 Login to Fritzbox

1. Go to `http://fritz.box` (or `192.168.178.1`)
2. Login with admin password

#### 2.2 Enable Port Forwarding

1. Go to **Internet** → **Permit Access** → **Port Sharing**
2. Click **New Port Sharing**
3. Configure:
   - Device: Your Mini PC (192.168.178.40)
   - Application: Other Applications
   - Designation: WireGuard
   - Protocol: UDP
   - Port to device: 51820
   - to Port: 51820
4. Click **OK**

#### 2.3 Setup DynDNS (if no static IP)

1. Go to **Internet** → **Permit Access** → **DynDNS**
2. Choose provider (e.g., duckdns.org, dynu.com)
3. Create account and configure
4. Use this domain as WIREGUARD_SERVERURL

### Step 3: Setup Mittwald VPS Gateway

#### 3.1 Rent Mittwald VPS

- Smallest VPS is enough (1GB RAM)
- Ubuntu 24.04 LTS
- Get public IPv4
- Point your domain to this IP

#### 3.2 Install WireGuard on VPS

```bash
# SSH into VPS
ssh root@your-vps-ip

# Install WireGuard
apt update
apt install wireguard -y
```

#### 3.3 Configure WireGuard Client

```bash
# Copy the peer_vps.conf content from home server
nano /etc/wireguard/wg0.conf

# Paste the config, then add these lines at the end:
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Start WireGuard
wg-quick up wg0
systemctl enable wg-quick@wg0

# Test connection
ping 10.13.13.1  # Your home server's WireGuard IP
```

#### 3.4 Install Nginx Reverse Proxy

```bash
apt install nginx -y

# Configure for your services
nano /etc/nginx/sites-available/potatostack
```

**Example Nginx Config:**

```nginx
# Jellyfin
server {
    listen 80;
    server_name jellyfin.yourdomain.com;

    location / {
        proxy_pass http://10.13.13.1:8096;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Grafana
server {
    listen 80;
    server_name grafana.yourdomain.com;

    location / {
        proxy_pass http://10.13.13.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Add more services as needed
```

```bash
# Enable site
ln -s /etc/nginx/sites-available/potatostack /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

#### 3.5 Add SSL with Let's Encrypt

```bash
apt install certbot python3-certbot-nginx -y

# Get certificates for all domains
certbot --nginx -d jellyfin.yourdomain.com -d grafana.yourdomain.com

# Auto-renewal is enabled by default
```

### Step 4: Connect Personal Devices (Android/Laptop)

#### Option A: Via Tailscale (Recommended)
- Follow Option 1 above
- Access services via internal IPs

#### Option B: Via WireGuard Direct
1. Get peer config: `docker exec wireguard-server cat /config/peer_android/peer_android.conf`
2. **Android**: Install [WireGuard app](https://play.google.com/store/apps/details?id=com.wireguard.android)
3. **Laptop**: Install [WireGuard](https://www.wireguard.com/install/)
4. Import config (scan QR code or copy/paste)
5. Enable VPN

---

## Comparison: Tailscale vs WireGuard

| Feature | Tailscale | WireGuard+VPS |
|---------|-----------|---------------|
| **Ease of Setup** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Personal Access** | ✅ Perfect | ✅ Good |
| **Public Domain** | ❌ No | ✅ Yes |
| **Sharing with Others** | ❌ Requires account | ✅ Yes |
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ (VPS adds latency) |
| **Auto-Connect** | ✅ Yes | ⚠️ Manual |
| **NAT Traversal** | ✅ Automatic | ⚠️ Manual port forward |
| **Cost** | Free (100 devices) | VPS cost (~€5/mo) |
| **Privacy** | 3rd party (trusted) | 100% self-hosted |

---

## Recommended Setup

### For Personal Use Only:
→ **Use Tailscale** (already configured)

### For Personal + Public Sharing:
→ **Tailscale** for your devices + **WireGuard+VPS** for public access

### For Maximum Control:
→ **WireGuard** for everything (more complex)

---

## Security Best Practices

1. **Firewall Rules**
   - Only expose WireGuard port (51820/udp)
   - Block all other ports from internet
   - Use Authentik SSO for web services

2. **Fail2ban** (Optional - add to stack)
   ```bash
   # Protects against brute force
   docker run -d --name fail2ban \
     --network host \
     --cap-add NET_ADMIN \
     --cap-add NET_RAW \
     -v /var/log:/var/log:ro \
     crazymax/fail2ban:latest
   ```

3. **Regular Updates**
   - Check Diun notifications
   - Update containers monthly: `docker compose pull && docker compose up -d`

4. **Monitor Access**
   - Use Grafana dashboards
   - Check WireGuard logs: `docker logs wireguard-server`
   - Monitor with Uptime Kuma

---

## Troubleshooting

### Tailscale Not Connecting
```bash
docker logs tailscale
docker restart tailscale
```

### WireGuard Peer Can't Connect
```bash
# Check server is running
docker logs wireguard-server

# Check Fritzbox port forward
# Test from outside: nmap -sU -p 51820 your-domain.com

# Check firewall on home server
sudo ufw status
```

### VPS Can't Reach Home Services
```bash
# On VPS, test WireGuard tunnel
wg show
ping 10.13.13.1

# Check WireGuard is running at home
docker logs wireguard-server
```

---

## Device-Specific Guides

### Android Auto-Connect

**Tailscale (Recommended):**
1. Enable "Use Tailscale" toggle - stays on automatically
2. Enable "Run on boot" in app settings

**WireGuard:**
1. Open WireGuard app → tap tunnel
2. Enable "Allow remote control"
3. Use Tasker/MacroDroid to auto-enable on specific WiFi disconnect

### Raspberry Pi Client

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Or WireGuard
sudo apt install wireguard
# Copy peer config to /etc/wireguard/wg0.conf
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

---

## Services Access Summary

Once connected (via Tailscale or WireGuard):

| Service | Internal URL | Public URL (if VPS setup) |
|---------|--------------|---------------------------|
| Traefik | http://192.168.178.40:8080 | https://traefik.yourdomain.com |
| Jellyfin | http://192.168.178.40:8096 | https://jellyfin.yourdomain.com |
| Grafana | http://192.168.178.40:3000 | https://grafana.yourdomain.com |
| Immich | http://192.168.178.40:2283 | https://photos.yourdomain.com |
| Nextcloud | http://192.168.178.40:8443 | https://cloud.yourdomain.com |
| Vaultwarden | http://192.168.178.40:8888 | https://vault.yourdomain.com |

---

## Quick Start Commands

```bash
# Check all VPN services
docker logs tailscale
docker logs wireguard-server

# Restart VPN services
docker compose restart tailscale wireguard-server

# View WireGuard peer configs
docker exec wireguard-server ls /config

# Show specific peer QR code
docker exec wireguard-server cat /config/peer_android/peer_android.png
```

---

**Sources & Further Reading:**
- [Tailscale Documentation](https://tailscale.com/kb/)
- [WireGuard Official Docs](https://www.wireguard.com/)
- [Secure Homelab Remote Access 2025](https://homelabdad.com/secure-your-homelab-top-4-remote-access-methods-for-2025/)
- [WireGuard VPS Guide](https://contabo.com/blog/wireguard-vps-the-definitive-guide-for-self-hosted-approach/)
