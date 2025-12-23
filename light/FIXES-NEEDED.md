# PotatoStack Light - Fixes Needed

## 1. TUN Device for Gluetun (CRITICAL)

**Issue:** Gluetun VPN container fails with "TUN device is not available"

**Fix:**
```bash
# Run the fix script
sudo bash fix-tun.sh

# Or manually:
sudo modprobe tun
echo 'tun' | sudo tee -a /etc/modules
docker restart gluetun
```

**Status:** Script created at `fix-tun.sh` - run with sudo

---

## 2. Syncthing API Key for Homepage

**Issue:** Homepage widget needs Syncthing API key

**Fix:**
```bash
# Get the API key from syncthing
docker exec syncthing cat /config/config.xml | grep apikey

# Or get it from Syncthing Web UI:
# Navigate to http://HOST_BIND:8384
# Go to Actions > Settings > General > API Key

# Add to .env file:
SYNCTHING_API_KEY=NMM27tWyktvkdhmSjAuwSJmQTvrTHxj9

# Restart homepage
docker restart homepage
```

**Status:** Config updated, needs .env variable set

---

## 3. Kopia Repository Initialization

**Issue:** Kopia shows "Repository not configured"

**Fix:**
```bash
# Access Kopia web UI at https://HOST_BIND:51515
# Follow the setup wizard to create a new repository
# Use the KOPIA_PASSWORD from .env file
# Select filesystem repository at /repository
```

**Status:** Needs manual setup via web UI

---

## 4. Vaultwarden Admin Token Security

**Issue:** Using plain text ADMIN_TOKEN (insecure)

**Fix:**
```bash
# Generate secure Argon2 hash
docker exec vaultwarden /vaultwarden hash --preset owasp

# Copy the PHC string output and update .env:
VAULTWARDEN_ADMIN_TOKEN='$argon2id$v=...'

# Restart vaultwarden
docker restart vaultwarden
```

**Status:** Warning only, works but should be fixed for production

---

## Summary

### Fixed:
- ✓ Added Syncthing to gethomepage services.yaml
- ✓ Removed all Seafile references from configs
- ✓ Updated postgres init-db to remove Seafile databases
- ✓ Updated .env.example with Syncthing variables

### Needs Action:
- ⚠ Load TUN module (run fix-tun.sh with sudo)
- ⚠ Set SYNCTHING_API_KEY in .env
- ⚠ Initialize Kopia repository via web UI
- ⚠ Hash Vaultwarden admin token (optional, for production)

### Service Status:
- Homepage: ✓ Healthy
- Postgres: ✓ Healthy
- Redis: ✓ Healthy
- Watchtower: ✓ Healthy
- Autoheal: ✓ Healthy
- Gluetun: ✗ Restarting (needs TUN fix)
- Transmission: ⏸ Waiting for Gluetun
- slskd: ⏸ Waiting for Gluetun
- Syncthing: 🔄 Starting
- Immich: 🔄 Starting
- Kopia: 🔄 Starting (needs setup)
- Vaultwarden: 🔄 Starting
- Portainer: 🔄 Starting
