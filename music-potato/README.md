# music-potato

Headless audio endpoint for a home HiFi setup.
Turns a **Libre Computer Le Potato (AML-S905X-CC)** into an always-on audio receiver
that streams losslessly to an AV receiver (Onkyo TX-SR605) via HDMI or SPDIF.

Works with AirPlay, Spotify Connect, UPnP/DLNA, Bluetooth, MPD, and Snapcast multi-room.
No screen needed. Unplug → plug back in → everything comes back automatically (~30 sec).

## Hardware

| Component | Model |
|---|---|
| SBC | Libre Computer AML-S905X-CC (Le Potato) — aarch64 |
| OS | Armbian Trixie Minimal IoT |
| Receiver | Onkyo TX-SR605 (HDMI IN or OPTICAL IN) |
| WiFi | USB dongle required (no built-in) — TP-Link TL-WN822N recommended |
| Bluetooth | USB dongle required (no built-in) — TP-Link UB500 recommended |
| Music | Homelab NFS export — no files stored on Le Potato |

## Quick Start

```bash
# 1. Flash Armbian Trixie Minimal IoT to SD card
# 2. Plug in USB WiFi dongle + USB Bluetooth dongle
# 3. Boot, connect via ethernet or serial, SSH in as root

# 4. Copy this folder to the board
scp -r music-potato/ root@<board-ip>:~/music-potato/
cd ~/music-potato

# 5. Run setup (installs everything, asks a few questions, done)
chmod +x setup.sh
sudo ./setup.sh

# Done. Unplug → plug back in → all services come back in ~30 sec.
```

See `DONGLES.md` for recommended USB WiFi + Bluetooth hardware (MT7921au + TP-Link UB500).

**Setup asks for:**
- WiFi SSID + password
- Homelab LAN IP (e.g. `192.168.1.100`)
- Device name — shown in AirPlay picker and Spotify app (`music-potato`)
- Navidrome username + password
- Tailscale auth key (from tailscale.com/admin)
- ALSA audio device: `hw:0,0` = HDMI (default), `hw:1,0` = USB DAC, `hw:0,1` = SPDIF
- Spotify credentials (optional)

## What runs where

**System-level (bare metal, auto-start via systemd):**
- Docker, NetworkManager, avahi-daemon, PipeWire, BlueZ, NFS client, Tailscale

**Docker (auto-start via `music-potato.service` → `docker compose up -d`):**

| Container | Protocol | Visible as |
|---|---|---|
| `shairport-sync` | AirPlay 2 | "music-potato" in iOS Control Center / Apple Music |
| `spotifyd` | Spotify Connect | "music-potato" in Spotify → Devices |
| `mpd` | MPD protocol (port 6600) | NCMPCPP, M.A.L.P., Symfonium, etc. |
| `upmpdcli` | UPnP/DLNA | BubbleUPnP, Foobar2000, Kazoo |
| `snapcast-client` | Snapcast (multi-room) | Synced to homelab Snapcast server |
| `tailscale` | WireGuard VPN | Le Potato in your tailnet |
| `watchtower` | — | Keeps images updated daily |

**Bluetooth** (A2DP sink): system-level via PipeWire + BlueZ. Pair "music-potato" from any device.

## Connecting from devices

| Device | How |
|---|---|
| iPhone / iPad / Mac | Control Center → AirPlay → **music-potato** |
| Apple Music | AirPlay destination → **music-potato** |
| Spotify (any device) | Devices → **music-potato** (Spotify Connect) |
| Android | BubbleUPnP → auto-discovers via UPnP; or DSub/Symfonium → Navidrome |
| Windows | Foobar2000 → UPnP renderer; or any MPD client |
| Any Bluetooth device | Pair **music-potato** — A2DP audio sink |
| Any device on LAN | `mpc -h music-potato.local status` / SSH `root@music-potato.local` |

## Audio output

| Output | How to enable | AUDIO_DEVICE |
|---|---|---|
| HDMI (default) | Plug HDMI cable | `hw:0,0` |
| SPDIF optical (9J1 header) | `sudo ldto merge spdif && reboot` | `hw:0,1` |
| USB DAC | Plug in DAC | `hw:1,0` (verify with `aplay -l`) |

Change output: edit `.env` → `AUDIO_DEVICE=hw:X,X` → `docker compose restart`.

## Homelab requirements

The homelab (potatostack) needs to be running:
- **Navidrome** (port 4533) — music library
- **NFS server** exporting `/mnt/storage/media/music` — run `sudo ./homelab-nfs-setup.sh`
- **Snapcast server** (port 1704) — for multi-room audio (already in potatostack compose)

## Files

```
setup.sh                ← run this once as root (does everything)
docker-compose.yml      ← Docker services (starts on boot automatically)
.env.example            ← copy to .env (installer does this automatically)
homelab-nfs-setup.sh    ← run on homelab to enable NFS export
config/
  mpd.conf              ← MPD bit-perfect ALSA config
  shairport-sync.conf   ← AirPlay 2 config
  spotifyd.conf         ← Spotify Connect config
  upmpdcli.conf         ← UPnP/DLNA renderer config
etc/
  asound.conf           ← system-wide ALSA device map (deployed to /etc/asound.conf)
  fstab.snippet         ← NFS fstab line reference
SOUND-GUIDE.md          ← full setup guide, lossless paths, karaoke, troubleshooting
ONKYO-GUIDE.md          ← Onkyo TX-SR605 optimal settings
TUNING-ORDER.md         ← manual tuning procedure
TUTORIAL.md             ← step-by-step walkthrough
```

## Re-run to change settings

```bash
sudo ./setup.sh         # safe to re-run — updates WiFi, credentials, audio device
```
