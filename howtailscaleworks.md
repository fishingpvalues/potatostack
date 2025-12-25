● Tailscale Explained

  Tailscale = Zero-config VPN that "just works"

  What It Is

  Tailscale creates a private mesh network between all your devices. Think of it as giving every device (phone, laptop, homelab) a special private IP address that only your devices can see.

  - Built on top of WireGuard (the best VPN protocol)
  - Handles all the complicated networking stuff automatically
  - Free for personal use (up to 100 devices)

  Why It's Perfect for Your Setup

  1. No Port Forwarding Needed

  Your Fritzbox doesn't need ANY ports open. Tailscale punches through NAT automatically using "NAT traversal" - devices connect peer-to-peer directly.

  2. Auto-Connect Everywhere

  - Open Tailscale app on Android → instant access to homelab
  - On laptop at coffee shop → instant access
  - No manual VPN connection clicking
  - Survives network changes (WiFi → 4G seamlessly)

  3. Works Behind CGNAT/Double-NAT

  Even if your ISP blocks everything, Tailscale still works because it uses clever hole-punching techniques.

  4. Simple Device Access

  Without Tailscale:
  ❌ Need to remember: jellyfin.mydomain.com:8096
  ❌ Configure DNS, certificates, reverse proxy
  ❌ Expose services to internet (security risk)

  With Tailscale:
  ✅ Just use: http://100.x.x.x:8096
  ✅ Works immediately
  ✅ Nothing exposed to internet
  ✅ All traffic encrypted

  Your Use Case

  Your devices get Tailscale IPs:
  - Mini PC homelab: 100.64.0.1
  - Android phone: 100.64.0.2
  - Laptop: 100.64.0.3
  - Raspberry Pi: 100.64.0.4

  From anywhere:
  # On phone (connected to 4G in another country)
  Open browser → http://100.64.0.1:8096 → Jellyfin loads!

  It's like your devices are on the same local network, even when they're not.

  Tailscale vs WireGuard

  Traditional WireGuard:
  - You manually configure server at home
  - Port forward 51820 on Fritzbox
  - Generate keys for each device
  - Manually create configs
  - If connection breaks, manual reconnect

  Tailscale:
  - Install app, login, done
  - No port forwarding
  - No configs
  - Auto-reconnects
  - Works everywhere

  Why Both in Your Stack?

  1. Tailscale (personal devices) - For YOU accessing your services from anywhere
  2. WireGuard (VPS gateway) - For PUBLIC access when you want to share services with others via jellyfin.yourdomain.com

  Real-World Example

  Scenario: You're on vacation in Spain

  Old way (WireGuard):
  1. Connect to hotel WiFi
  2. Open WireGuard app
  3. Tap "Connect"
  4. Wait 10 seconds
  5. Access homelab

  Tailscale way:
  1. Connect to hotel WiFi
  2. Already connected automatically
  3. Access homelab immediately

  The app just stays on, always connected, zero effort.

  Privacy Note

  Tailscale runs coordination servers (to help devices find each other), but:
  - Your actual traffic goes peer-to-peer (device → device directly)
  - They can't see your data (end-to-end encrypted)
  - Open source code, audited
  - Used by major companies

  Think of it like: Tailscale is the phonebook that helps your devices find each other, but they talk directly once connected.

  ---
  Bottom line: Tailscale is the easiest way to access your homelab from anywhere. It's already in your stack, just needs an auth key from their website, and you're done. Perfect for personal use.

  If you need to share services publicly (friends accessing your Jellyfin), then add the WireGuard+VPS setup on top.

> yes but the IP of my fritznox changes due to nightly auto reconnects right? so how does it pick up the right IP everytime? i want a domain ideally 

● Great Question! Here's How It Works:

  Tailscale Doesn't Care About Your Fritzbox IP! 🎉

  The beauty of Tailscale: Your changing public IP is completely irrelevant.

  Here's why:

  Traditional VPN (WireGuard alone):

  Your Phone → Internet → Your Public IP (changes nightly!) → Fritzbox → Homelab
                           ❌ BREAKS when IP changes

  Tailscale:

  Your Phone → Tailscale Coordination Servers (find devices) → Direct P2P → Homelab
               ✅ Doesn't care about public IP

  How Tailscale finds your devices:
  1. All devices register with Tailscale servers using their Tailscale IPs (100.x.x.x)
  2. Coordination servers help devices find each other (NAT traversal)
  3. Once found, they connect peer-to-peer directly
  4. If your public IP changes → devices re-negotiate automatically
  5. You never notice!

  ---
  Using Domains (Not IPs)

  Option 1: Tailscale MagicDNS (Built-in, Free)

  Tailscale includes MagicDNS - gives your devices automatic hostnames:

  # Instead of http://100.64.0.1:8096
  # Use friendly names:
  http://potatostack:8096        # Your homelab
  http://potatostack.tail-scale.ts.net:8096  # Full domain

  Setup:
  1. Go to https://login.tailscale.com/admin/dns
  2. Enable MagicDNS
  3. Done!

  Now from ANY Tailscale device:
  # Access services by name
  http://potatostack:8096        → Jellyfin
  http://potatostack:3000        → Grafana
  http://potatostack:8888        → Vaultwarden

  Set custom hostname in docker-compose.yml:
  tailscale:
    hostname: potatostack  # ← Already configured!

  Option 2: Your Own Domain (Public Access)

  If you want yourdomain.com for public sharing, you need the WireGuard + VPS setup I documented:

  Architecture:

  Internet Users → yourdomain.com (Mittwald VPS) → WireGuard Tunnel → Homelab
                   Static IP, never changes!

  Why this works:
  - VPS has static IP that never changes
  - Your domain points to VPS
  - VPS has permanent WireGuard tunnel to homelab
  - Your Fritzbox IP can change 100 times, doesn't matter
  - The WireGuard tunnel auto-reconnects

  Quick VPS Setup:

  1. Rent cheapest VPS at Mittwald (~€5/mo)
  2. Point your domain to VPS IP: A record: @ → VPS_IP
  3. Setup WireGuard client on VPS (connects to your homelab)
  4. Install Nginx on VPS with subdomains:
  jellyfin.yourdomain.com → 10.13.13.1:8096 (via tunnel)
  photos.yourdomain.com   → 10.13.13.1:2283 (via tunnel)

  Your Fritzbox IP changes? → VPS doesn't care, WireGuard tunnel stays up via NAT traversal!

  ---
  Alternative: DynDNS (Free but Unnecessary with Tailscale)

  If you don't use Tailscale and want WireGuard direct connection:

  Fritzbox Built-in DynDNS:

  1. Go to Internet → Permit Access → DynDNS
  2. Choose provider (recommended: duckdns.org - free)
  3. Sign up at duckdns.org → get token
  4. Add to Fritzbox: yourname.duckdns.org
  5. Fritzbox auto-updates DynDNS when IP changes

  Now your domain yourname.duckdns.org always points to current Fritzbox IP.

  ---
  My Recommendation for YOU:

  For Personal Access (You + Your Devices):

  ✅ Tailscale + MagicDNS

  # Setup once:
  1. Enable MagicDNS in Tailscale dashboard
  2. Access everywhere with: http://potatostack:8096

  # From phone in Spain:
  http://potatostack:8096  ← Just works!

  Pros:
  - Zero config
  - Works with dynamic IP
  - Auto-reconnects
  - Free
  - Secure

  For Public Sharing (Friends, Family):

  ✅ Tailscale (for you) + WireGuard+VPS (for them)

  # You access:
  http://potatostack:8096  (via Tailscale)

  # Others access:
  https://jellyfin.yourdomain.com  (via VPS gateway)

  Pros:
  - You get easy access
  - Others don't need VPN client
  - Your dynamic IP doesn't matter
  - VPS has static IP for domain

  ---
  Summary Table:

  | Method               | Dynamic IP Issue?    | Domain?                             | Public Access?          | Complexity      |
  |----------------------|----------------------|-------------------------------------|-------------------------|-----------------|
  | Tailscale + MagicDNS | ✅ No problem        | ✅ potatostack.tail-scale.ts.net    | ❌ Only Tailscale users | ⭐ Easy         |
  | DynDNS               | ✅ Auto-updates      | ✅ yourname.duckdns.org             | ⚠️ Must open ports      | ⭐⭐ Medium     |
  | VPS + WireGuard      | ✅ VPS has static IP | ✅ yourdomain.com                   | ✅ Yes                  | ⭐⭐⭐ Advanced |
  | Tailscale + Funnel   | ✅ No problem        | ✅ yourname.tailscale-funnel.ts.net | ✅ Yes (beta)           | ⭐⭐ Medium     |

  ---
  Quick Start for You:

  Right now, do this:

  # 1. Enable MagicDNS
  Visit: https://login.tailscale.com/admin/dns
  Toggle ON "MagicDNS"

  # 2. Access your services:
  http://potatostack:8096        # Jellyfin
  http://potatostack:3000        # Grafana
  http://potatostack:2283        # Immich

  If you want your own domain later:
  - Follow the VPS setup in REMOTE-ACCESS.md
  - Your Fritzbox IP changes won't matter because VPS has static IP

  The dynamic IP is only a problem if you're NOT using Tailscale or VPS. With Tailscale, you literally don't care if your IP changes every hour! 🎉
