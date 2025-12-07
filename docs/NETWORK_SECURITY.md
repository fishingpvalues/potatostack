# Network Security Configuration

## HOST_BIND Setting

### What is HOST_BIND?

`HOST_BIND` controls which network interface your Docker services bind to on the host machine.

**Two options:**
1. **0.0.0.0** (all interfaces) - Services accessible from ANY network interface
2. **192.168.178.40** (specific LAN IP) - Services ONLY accessible from your local network

### Why We Use LAN IP (192.168.178.40)

**Security Benefits:**
- ✅ Services only accessible from your local network (192.168.178.0/24)
- ✅ Cannot be reached from other network interfaces (e.g., if you have multiple NICs)
- ✅ Prevents accidental exposure if router is misconfigured
- ✅ Complies with OPA security policy that blocks 0.0.0.0 bindings

**Default Configuration:**
```bash
# In .env file
HOST_BIND=192.168.178.40  # Your Le Potato's LAN IP
HOST_ADDR=192.168.178.40  # Same IP for dashboard links
```

### How It Works

Every service in docker-compose.yml uses:
```yaml
ports:
  - "${HOST_BIND:-0.0.0.0}:8080:8080"
```

This means:
- If `HOST_BIND` is set in .env → uses that IP
- If `HOST_BIND` is NOT set → defaults to 0.0.0.0 (all interfaces)

With `HOST_BIND=192.168.178.40`:
- ✅ `http://192.168.178.40:8080` - Works (LAN access)
- ❌ `http://0.0.0.0:8080` - Doesn't work
- ❌ `http://127.0.0.1:8080` - Doesn't work (not bound to loopback)

### When to Change HOST_BIND

**Change if:**
1. Your Le Potato has a different LAN IP
2. You want to bind to a specific interface (e.g., VPN interface)
3. You're using a different subnet (e.g., 10.0.0.0/8)

**How to find your IP:**
```bash
# On Le Potato
ip addr show | grep "inet " | grep -v 127.0.0.1
# or
hostname -I
```

**Update .env:**
```bash
HOST_BIND=10.0.0.50  # Your actual IP
HOST_ADDR=10.0.0.50
```

Then restart:
```bash
docker compose down
docker compose up -d
```

### Special Case: Localhost-Only Access

If you want services ONLY accessible from the Le Potato itself (not from other devices on LAN):

```bash
HOST_BIND=127.0.0.1  # Localhost only
```

Then access via SSH tunnel from remote machines.

### OPA Policy Compliance

The OPA policy at `policy/docker-compose.rego:139` denies 0.0.0.0 bindings for security.

**Policy rule:**
```rego
deny[msg] {
    binding := input.services[_].ports[_]
    contains(binding, "0.0.0.0:")
    msg := sprintf("Service uses insecure 0.0.0.0 binding: %v", [binding])
}
```

By setting `HOST_BIND=192.168.178.40`, all services pass this policy check.

**Verify compliance:**
```bash
# Run OPA policy check
docker run --rm -v $(pwd):/workspace openpolicyagent/opa:latest \
  eval -i /workspace/docker-compose.yml \
  -d /workspace/policy/docker-compose.rego \
  "data.docker.deny"
```

Should return empty (no policy violations).

## Firewall Recommendations

Even with HOST_BIND set to LAN IP, add firewall rules for defense-in-depth:

### Using UFW (Ubuntu/Debian)

```bash
# Install UFW
sudo apt install ufw

# Default: deny all incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CRITICAL - do this first!)
sudo ufw allow from 192.168.178.0/24 to any port 22

# Allow all services from LAN only
sudo ufw allow from 192.168.178.0/24

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Using iptables (Advanced)

```bash
# Allow LAN access
sudo iptables -A INPUT -s 192.168.178.0/24 -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Drop everything else
sudo iptables -A INPUT -j DROP

# Save rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

## External Access (Optional)

If you need to access services from outside your LAN:

### Option 1: Tailscale (Recommended)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --advertise-routes=192.168.178.0/24

# Access from anywhere via Tailscale IP
```

### Option 2: VPN (WireGuard/OpenVPN)

Set up a VPN server on your router or Le Potato, then access via VPN.

### Option 3: Nginx Proxy Manager + Cloudflare Tunnel

Use Nginx Proxy Manager (already included) with Cloudflare Tunnel for HTTPS access without port forwarding.

**DO NOT:**
- ❌ Change HOST_BIND back to 0.0.0.0
- ❌ Port forward services directly to the internet
- ❌ Expose services without authentication

## Troubleshooting

### Can't access services from other devices on LAN

**Check HOST_BIND:**
```bash
grep HOST_BIND .env
# Should show: HOST_BIND=192.168.178.40
```

**Verify Le Potato IP:**
```bash
ip addr show
# Should include: inet 192.168.178.40/24
```

**If IP changed:**
1. Update .env with new IP
2. Restart: `docker compose restart`

### Can't access from localhost on Le Potato

**Cause:** HOST_BIND is set to LAN IP, not 127.0.0.1

**Solution:** Access via LAN IP instead:
```bash
# Instead of:
curl http://localhost:8080

# Use:
curl http://192.168.178.40:8080
```

**Or bind to both (not recommended for security):**
```yaml
ports:
  - "127.0.0.1:8080:8080"  # Localhost
  - "192.168.178.40:8080:8080"  # LAN
```

### Services not starting after changing HOST_BIND

**Check for port conflicts:**
```bash
# See what's using the port
sudo netstat -tulpn | grep :8080

# Or with ss
sudo ss -tulpn | grep :8080
```

**Check Docker logs:**
```bash
docker compose logs | grep "bind"
```

## Summary

✅ **Default: HOST_BIND=192.168.178.40**
- Secure (LAN-only access)
- Complies with OPA policy
- Prevents accidental exposure

✅ **Firewall: UFW or iptables**
- Defense-in-depth
- Blocks non-LAN access

✅ **External Access: Tailscale**
- Secure remote access
- No port forwarding needed

❌ **Avoid: HOST_BIND=0.0.0.0**
- Insecure (all interfaces)
- Violates OPA policy
- Increases attack surface
