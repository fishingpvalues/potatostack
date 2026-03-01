# Le Potato Audio Stack — Complete Sound Guide

**Hardware:** Libre Computer AML-S905X-CC (Le Potato) + Onkyo TX-SR605 + Yamaha YST-FSW050 + Fluance ES1
**OS:** Armbian Trixie Minimal IoT
**Goal:** Lossless audio hub — AirPlay 2, Spotify Connect, DLNA/UPnP, Bluetooth, Navidrome library

---

## 1. Hardware Connections

### Audio Output: HDMI (Recommended) or Optical SPDIF

#### Option A — HDMI (Easiest, fully lossless, zero config)
```
Le Potato HDMI ──────────────────────── Onkyo TX-SR605 HDMI IN 1/2/3
```
- Carries LPCM 2.0 up to 24-bit/192kHz losslessly
- Onkyo TX-SR605 has HDMI 1.3a — 3 inputs, 1 output
- Zero audio quality difference vs optical for stereo PCM

#### Option B — Optical TOSLINK (Galvanic isolation, no video cable clutter)
```
Le Potato 9J1 header ── TOSLINK adapter ── optical cable ── Onkyo OPTICAL IN 1
```
The 9J1 header is the 3-pin connector between the HDMI port and the 3.5mm jack.

**Pinout (left to right facing the board):**
```
[5V] [SPDIF DATA] [GND]
  ^                  ^
HDMI side         3.5mm side
```

You need a TOSLINK transmitter module (available for ~€3 on AliExpress, search "TOSLINK SPDIF transmitter module 3.3V").
Wire: module VCC → 5V pin, module GND → GND pin, module DIN → DATA pin.

**Enable SPDIF in software:**
```bash
# Test (temporary, reverts on reboot)
sudo ldto enable spdif

# Set ALSA source to I2S (required!)
amixer sset "AIU SPDIF SRC SEL" I2S

# Make permanent after testing
sudo ldto merge spdif
sudo reboot

# Verify
speaker-test -c 2 -D spdif
```

> **Known issue (Oct 2023):** The stock overlay may misorder device tree nodes — if SPDIF doesn't work after enabling, see the workaround thread at https://hub.libre.computer/t/how-to-enable-spdif-on-aml-s905x-cc-le-potato/3005

#### Option C — USB Audio DAC (Most reliable, plug and play)
Any USB DAC with optical out works out of the box on Armbian — no device tree fiddling needed.
Recommended: FiiO K5 Pro, Topping E30 II, or any basic USB-optical adapter (~€15).

---

## 1b. Le Potato Hardware Facts (AML-S905X-CC)

| Spec | Value |
|---|---|
| SoC | Amlogic S905X — 4× Cortex-A53 @ 1.512 GHz |
| Architecture | aarch64 (arm64) |
| RAM | 2 GB LPDDR3 |
| Audio out (built-in) | HDMI (PCM 2.0/5.1/7.1, up to 192kHz), 3.5mm analog, 9J1 SPDIF header |
| Audio card name | `aml-augesound` — ALSA card 0 |
| HDMI audio device | `hw:0,0` |
| SPDIF device | `hw:0,1` after `ldto merge spdif` |
| WiFi | **None built-in** — USB dongle required |
| Bluetooth | **None built-in** — USB dongle required |
| USB | 2× USB-A 2.0 |
| Storage | microSD / eMMC module slot |

**CPU scheduling note:** S905X has no hardware FPU for 32-bit ARM code — use arm64/aarch64 Docker images exclusively. Never pull armhf/arm32 images on Le Potato running 64-bit Armbian.

**ALSA audio device map (Le Potato specific):**
```bash
# Verify on your board:
aplay -l

# Expected output:
# card 0: amlaugesound [aml-augesound], device 0: HDMI HDMI-0 []
# card 0: amlaugesound [aml-augesound], device 1: SPDIF SPDIF-0 []  ← only after ldto merge spdif
```

**Known quirk:** On Armbian Trixie, ALSA mixer defaults may be muted on first boot.
```bash
# Unmute and set volume:
amixer -c 0 sset Master 100% unmute
# For SPDIF path specifically:
amixer sset "AIU SPDIF SRC SEL" I2S
```

---

## 2. Onkyo TX-SR605 — Optimal Settings for Lossless Music

### Speaker Setup (run Audyssey first, then override)

| Setting | Value | Why |
|---|---|---|
| Front speakers | **Large** | Fluance ES1 can handle full range; OR set Small + sub |
| Subwoofer | **Yes** | Connect Yamaha YST-FSW050 via LFE pre-out |
| Crossover freq | **80 Hz** | SOTA reference crossover for bookshelfs |
| Sub level | **+3 to +6 dB** | YST-FSW050 has a passive radiator, needs a bit of boost |
| Center/Surround | **None / Off** | Stereo music setup |

### Listening Mode — The Most Important Setting

For **lossless music playback**:

| Mode | What it does | Use when |
|---|---|---|
| **Pure Audio** | Disables ALL DSP, video circuits, tone controls, Audyssey EQ. Purest 2-channel analog path. | CD, FLAC, ALAC from optical/HDMI |
| **Direct** | Disables tone controls + Audyssey. Video still active. | When you need the display on |
| **Stereo** | Full front stereo, some processing still active | General TV use |
| **Dolby PLII Music** | Expands 2ch to surround. Adds DSP. | If you want surround from stereo (not lossless) |

**Set to Pure Audio for all serious music listening.**

### Digital Input Settings
- **Input: OPTICAL 1** (or whichever you connected)
- **Digital Audio In:** Set to PCM / Auto (not DTS force)
- **Audio Adjust → Re-EQ:** OFF (you want flat response)
- **Late Night:** OFF
- **Dynamic Range:** OFF
- **AccuEQ:** OFF for music (it's a curve filter, colors the sound)

### Subwoofer — Yamaha YST-FSW050
- Connect via LFE/Subwoofer pre-out on Onkyo back panel
- Set the sub's built-in volume knob to ~70% (adjust by ear)
- Set sub's crossover knob to MAX (let Onkyo control the crossover via bass management)
- YST (Yamaha Active Servo Technology) handles its own driver control — do NOT bypass

---

## 3. Who Does What — Le Potato vs Homelab

### Le Potato: dumb audio endpoint

Le Potato sits next to the Onkyo, plugged in via HDMI (or optical). It is a headless
ARM board running Armbian. **It does not serve music. It only plays it.**
Think of it as an open-source smart speaker that accepts audio from multiple protocols
and pipes it out to the Onkyo bit-perfectly.

**What runs on Le Potato (system-level services, no Docker):**

| Service | What it does | Visible as |
|---|---|---|
| `shairport-sync` + `nqptp` | AirPlay / AirPlay 2 receiver | "music-potato" in iOS Control Center / Apple Music |
| `spotifyd` | Spotify Connect endpoint | "music-potato" in Spotify app → Devices |
| `mpd` | Plays FLAC/ALAC directly from NFS music mount | MPD clients (M.A.L.P., NCMPCPP, Symfonium) |
| `upmpdcli` | Exposes MPD as UPnP/DLNA renderer | BubbleUPnP, Foobar2000, any DLNA controller |
| `avahi-daemon` | mDNS/Bonjour discovery | Makes all above auto-appear on LAN |
| `bluez` + `pipewire` | Bluetooth A2DP sink | Any Bluetooth device → pair and play |
| `snapcast-client` | Receives synced multi-room stream from homelab | Plays in sync with any other Snapcast room |

**Le Potato does NOT:**
- Store any music (all files are on homelab, accessed via NFS)
- Run a browser or show anything on a screen (it's headless)
- Handle karaoke (that's the homelab's job)
- Transcode anything (always bit-perfect passthrough to ALSA)

### Homelab (potatostack server): does all the heavy lifting

| Service | What it does |
|---|---|
| `navidrome` | Music library server — Subsonic API for all apps |
| `mpd-snap` + `snapcast` | Multi-room audio feeder for Le Potato (and any other Snapcast rooms) |
| `karaoke-eternal` | Karaoke party server — hosts the web UI and serves CDG+MP3 files |
| `beets` | Tags and imports music, embeds lyrics (LRC) |
| `SpotiFLAC` | Downloads from Spotify as FLAC via NFS to music library |
| NFS server | Exports `/mnt/storage/media/music` → Le Potato mounts it at `/mnt/music` |

### Full Architecture Diagram

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                         HOMELAB (potatostack)                        │
  │                                                                      │
  │  navidrome:4533 ──Subsonic API──► any app (Symfonium, Substreamer…) │
  │  mpd-snap:6601 ──FIFO──► snapcast:1704 ──LAN──────────────────────┐ │
  │  karaoke-eternal:8044 ──browser──► any screen (phone/tablet/TV)   │ │
  │  NFS export /mnt/storage/media/music ────────────────────────────┐ │ │
  └──────────────────────────────────────────────────────────────────┼─┼─┘
                                                                     │ │
  ┌──────────────────────────────────────────────────────────────────┼─┘
  │                      LE POTATO                                   │
  │                                                                  │
  │  /mnt/music (NFS mount) ◄────────────────────────────────────── ┘
  │                 │
  │  [iPhone/iPad]──AirPlay──► shairport-sync ─┐
  │  [Spotify app]──Connect──► spotifyd        ─┤
  │  [BubbleUPnP] ──DLNA────► upmpdcli→mpd    ─┤─► PipeWire → ALSA
  │  [MPD client] ──MPD:6600─► mpd             ─┤       │
  │  [BT device]  ──Bluetooth─► pipewire-bt    ─┤    ┌──┴──────┐
  │  [Homelab]    ──Snapcast──► snapcast-client─┘    │  HDMI   │  ← pick one
  │                                                  │  SPDIF  │
  └──────────────────────────────────────────────────┴──┬──────┘
                                                        │
                                              Onkyo TX-SR605
                                         (Pure Audio mode for lossless)
                                                   │         │
                                           Fluance ES1   Yamaha YST-FSW050
```

**Music flows to Le Potato two ways:**
1. **Streamed in real-time** — iPhone AirPlays, Spotify Connects, phone Bluetooths → Le Potato decodes → ALSA
2. **Played directly** — MPD reads FLAC files from NFS mount → ALSA (bit-perfect, best quality)

---

## 4. Installation — One Script, Fully Automatic

`install.sh` sets everything up in one run. When done, **unplug → plug back in → all services
come back automatically in ~30 seconds.**

### What the script does

| Step | What |
|---|---|
| 1 | Updates Armbian |
| 2 | Configures WiFi via NetworkManager (saved permanently, auto-connects on boot) |
| 3 | Installs Docker |
| 4 | Installs ALSA + PipeWire + Bluetooth (system-level A2DP sink) |
| 5 | Adds NFS music mount to `/etc/fstab` with `x-systemd.automount` |
| 6 | Installs Tailscale, authenticates |
| 7 | Writes `.env` with all your settings |
| 8 | Substitutes placeholders in shairport-sync, spotifyd, mpd configs |
| 9 | Creates `music-potato.service` systemd unit → runs `docker compose up -d` on boot |
| 10 | Pulls Docker images and starts the stack |
| 11 | Verifies all services and prints a summary |

### Auto-start on boot (how it works)

```
Boot
 ├── NetworkManager → WiFi connects
 ├── tailscaled → Tailscale reconnects (persistent state in /var/lib/tailscale)
 ├── docker → starts Docker daemon
 │     └── music-potato.service → docker compose up -d
 │               ├── shairport-sync  (restart: unless-stopped)
 │               ├── mpd             (restart: unless-stopped)
 │               ├── upmpdcli        (restart: unless-stopped)
 │               ├── spotifyd        (restart: unless-stopped)
 │               ├── avahi           (restart: unless-stopped)
 │               ├── snapcast-client (restart: unless-stopped)
 │               └── watchtower      (restart: unless-stopped)
 └── NFS /mnt/music → auto-mounts on first MPD access (x-systemd.automount)
```

If any Docker container crashes, Docker restarts it automatically (`restart: unless-stopped`).

### Run the script

```bash
# 1. Copy the music-potato/ folder to the board (run this on your PC/homelab)
scp -r /path/to/potatostack/music-potato/ root@music-potato.local:~/music-potato/

# 2. SSH into Le Potato
ssh root@music-potato.local

# 3. Run the installer (prompts for everything interactively)
cd ~/music-potato
chmod +x install.sh
sudo ./install.sh
```

The script will ask for:
- WiFi SSID + password
- Homelab LAN IP (e.g. `192.168.1.100`)
- Device name (shown in AirPlay / Spotify)
- Navidrome username + password
- Tailscale auth key (generate at tailscale.com/admin → Settings → Keys)
- ALSA audio device (`hw:0,0` = HDMI, `hw:1,0` = USB DAC, `hw:0,1` = SPDIF optical)
- Spotify username + password (optional — press Enter to skip)

### Non-interactive (CI/scripted)

```bash
sudo \
  WIFI_SSID="MyNetwork" \
  WIFI_PASS="mypassword" \
  HOMELAB_IP="192.168.1.100" \
  DEVICE_NAME="music-potato" \
  NAVIDROME_USER="daniel" \
  NAVIDROME_PASS="secret" \
  TS_AUTHKEY="tskey-auth-XXXX" \
  AUDIO_DEVICE="hw:0,0" \
  ./install.sh
```

### Re-run to update config

The script is idempotent. Re-run it any time to:
- Change WiFi network
- Update Navidrome or Spotify credentials
- Switch audio output device (HDMI ↔ USB DAC ↔ SPDIF)
- Rotate Tailscale key

---

## 4b. Docker Compose Quickstart

### Prerequisites on Le Potato

```bash
# 1. Install Docker (Armbian Trixie)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Add user to audio group (allows ALSA access inside containers)
sudo usermod -aG audio $USER

# 3. Mount NFS music library (run homelab-nfs-setup.sh on homelab first)
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/music
# Add to /etc/fstab (see etc/fstab.snippet), then:
sudo mount -a
ls /mnt/music   # verify library is visible

# 4. Unmute ALSA (Le Potato quirk — muted by default)
amixer -c 0 sset Master 100% unmute
```

### Start the Stack

```bash
cd music-potato/

# Copy and edit environment file
cp .env.example .env
nano .env   # set AUDIO_DEVICE, NAVIDROME_URL, NAVIDROME_PASS

# Pull images and start
docker compose pull
docker compose up -d

# Follow logs
docker compose logs -f
```

### Find the Audio Device

```bash
# On Le Potato, list ALSA devices:
aplay -l

# Typical Le Potato output:
# card 0: amlaugesound, device 0: HDMI         → AUDIO_DEVICE=hw:0,0
# card 0: amlaugesound, device 1: SPDIF        → AUDIO_DEVICE=hw:0,1  (after ldto merge spdif)
# card 1: USB Audio Device, device 0            → AUDIO_DEVICE=hw:1,0  (USB DAC)

# Test audio output:
speaker-test -c 2 -D hw:0,0 -t wav
```

### Verify Services

```bash
docker compose ps

# AirPlay 2 — check it's announcing itself:
avahi-browse -a | grep AirPlay

# MPD — check library loaded:
docker exec mpd mpc stats

# UPnP — check it's discoverable:
avahi-browse -a | grep MediaRenderer

# Spotify Connect — check it's visible (open Spotify app → Connect)

# Logs per service:
docker compose logs shairport-sync -f
docker compose logs mpd -f
docker compose logs upmpdcli -f
docker compose logs spotifyd -f
```

### Switch Audio Output

```bash
# Edit .env, change AUDIO_DEVICE, restart affected containers:
nano .env
docker compose restart shairport-sync mpd spotifyd

# Alternatively override per-run:
AUDIO_DEVICE=hw:0,1 docker compose up -d
```

---

## 5. Service Overview

| Service | Protocol | Port | Visible to |
|---|---|---|---|
| shairport-sync | AirPlay 2 | 5000 (mDNS) | Apple devices, Apple Music |
| spotifyd | Spotify Connect | — (cloud) | Spotify app on any device |
| mpd | MPD protocol | 6600 | NCMPCPP, Cantata, mpc |
| upmpdcli | UPnP/DLNA | 49152 | BubbleUPnP, Foobar, Roon |
| avahi-daemon | mDNS/Bonjour | 5353 | Auto-discovery for all above |
| Bluetooth | A2DP sink | — | Any BT device |

---

## 6. Accessing from Different Devices

### Apple Devices (iPhone, iPad, Mac)
- Open Control Center → AirPlay icon → select **"music-potato"**
- Apple Music → AirPlay destination → **"music-potato"**
- **Quality note:** Apple Music streaming sends **AAC 256kbps** to AirPlay 2 receivers (even though the protocol supports lossless). AirPlay 1 "Realtime" mode gets ALAC CD quality. For truly lossless Apple Music: download tracks to device first, then AirPlay — or use MPD via NFS.
- For maximum lossless: use **Symfonium / Substreamer** app → Navidrome (FLAC direct)

### Android
- **Spotify**: tap Connect → select **"music-potato"** (Spotify Connect)
- **BubbleUPnP** (free/paid): auto-discovers the UPnP renderer, browse Navidrome library
- **DSub / Substreamer**: connects directly to Navidrome at `http://HOMELAB_IP:4533`

### Linux
- `mpc -h music-potato add / && mpc play` — MPD client
- NCMPCPP: set `mpd_host = music-potato` in config
- Cantata, Rhythmbox AirPlay plugin, any UPnP client

### Tailscale (remote)
All services are on LAN. For Tailscale access:
- Ensure Le Potato is in the same tailnet
- Access Navidrome from anywhere: `http://HOMELAB_TS_IP:4533`
- MPD over Tailscale: set `mpd_host = music-potato-tailscale-ip` in client config
- AirPlay 2 does NOT work over Tailscale (mDNS is LAN-only) — use MPD/Subsonic clients instead

---

## 7. Lossless Audio: What's Actually Lossless

| Source | Format | Lossless? | Notes |
|---|---|---|---|
| Navidrome → MPD (NFS direct) | FLAC/ALAC | ✅ Yes | Direct file read, bit-perfect |
| Navidrome → MPD (Subsonic API) | FLAC stream | ✅ Yes | Set `format=raw` in upmpdcli |
| Apple Music → AirPlay 2 (streaming) | AAC 256kbps | ❌ Lossy | Apple sends AAC to AirPlay 2 receivers; streaming content is re-encoded |
| Apple Music → AirPlay 1 (local files) | ALAC 16-bit/44.1kHz | ✅ CD quality | AirPlay 1 "Realtime" mode; shairport-sync without `--with-airplay-2` flag |
| Spotify → Spotify Connect | OGG Vorbis 320kbps | ❌ Lossy | Spotify has no lossless tier yet |
| SpotiFLAC files → MPD | FLAC | ✅ Yes | Files downloaded to homelab, read via NFS |
| Bluetooth A2DP | aptX/SBC | ❌ Lossy | Bluetooth always compresses for wireless |
| Bluetooth LDAC | LDAC 990kbps | ⚠ Near-lossless | Needs LDAC-capable BT device (Le Potato: depends on dongle) |

**For true bit-perfect lossless:** Use MPD with direct NFS mount → SPDIF/HDMI → Onkyo Pure Audio mode. This is the optimal path.

---

## 8. WiFi Setup

Le Potato has no built-in WiFi — you need a USB WiFi adapter.

**Tested/recommended adapters for Armbian:**
- TP-Link TL-WN822N (RTL8192EU, works with Armbian out of box)
- Edimax EW-7811Un (RTL8188CUS)
- Any adapter with `mt76` or `ath9k` driver (most stable on Armbian)

**Avoid:** Realtek RTL8811CU/RTL8821CU adapters — require DKMS module, fragile across kernel updates.

```bash
# Setup WiFi on Armbian
sudo nmtui
# Or:
sudo nmcli dev wifi connect "SSID" password "PASSWORD"
```

---

## 9. Bluetooth Setup

```bash
# Pair and trust a device
bluetoothctl
> power on
> agent on
> discoverable on
> scan on
# Wait for your device, then:
> pair XX:XX:XX:XX:XX:XX
> trust XX:XX:XX:XX:XX:XX
> connect XX:XX:XX:XX:XX:XX
```

Le Potato has no built-in Bluetooth — use a USB BT adapter.
**Recommended:** TP-Link UB500 (Bluetooth 5.0, plug-and-play on Armbian with PipeWire).

---

## 10. What You're Missing / SOTA Additions

| Gap | Solution | Priority |
|---|---|---|
| No built-in WiFi on Le Potato | USB WiFi dongle | Required |
| No built-in Bluetooth | USB BT5 dongle | High |
| Optical SPDIF needs adapter/soldering | Use HDMI or USB DAC instead | Consider |
| Spotify has no lossless tier | SpotiFLAC downloads → NFS → MPD | Workaround in place |
| Apple Music at full lossless | Use Navidrome (FLAC via NFS) + Symfonium/Substreamer — AirPlay 2 streaming is AAC | Use Subsonic apps |
| Karaoke | KaraokeEternal on homelab, player opens in any browser | Done in docker-compose.yml |
| Android Auto-discovery | Avahi + DLNA via upmpdcli | Done |
| Headless volume control from phone | MPD clients (M.A.L.P., MPDroid on Android) | Free |
| EQ/room correction | REW + parametric EQ in MPD / PipeWire | Optional SOTA |
| Multi-room sync | Add Snapcast server on homelab + client on Le Potato | Optional |

### SOTA 2025 Audio Stack Summary
- **PipeWire** replaced PulseAudio as the default audio server in Debian Trixie
- **ShairPort-Sync + NQPTP** is the only open-source AirPlay 2 lossless implementation
- **MPD 0.23+** supports native ALSA output with DSD, resampling, and ReplayGain
- **upmpdcli 1.9+** has native Subsonic/Navidrome plugin for library browsing
- **Spotifyd** is lighter than raspotify but both work; raspotify is easier to install

---

## 11. Homelab NFS Setup (Required for MPD direct-play)

On the **homelab (potatostack server)**:

```bash
# Quick setup
sudo ./music-potato/homelab-nfs-setup.sh 192.168.1.0/24

# Or manually:
sudo apt-get install nfs-kernel-server
echo "/mnt/storage/media/music  192.168.1.0/24(ro,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl enable --now nfs-kernel-server
```

On **Le Potato**, add to `/etc/fstab` (see `etc/fstab.snippet`), then:
```bash
sudo mount -a
ls /mnt/music   # should show your library
```

### Navidrome via Tailscale

Le Potato needs to be in your tailnet to reach Navidrome at `https://potatostack.tale-iwato.ts.net:4533`.

```bash
# On Le Potato — install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key=<YOUR_TSKEY>

# Then Navidrome is reachable at:
# https://potatostack.tale-iwato.ts.net:4533
# Use this URL in upmpdcli.conf as subsonicurl, and in any Subsonic app
```

Subsonic API apps that work on all platforms:
| App | Platform | Best for |
|---|---|---|
| **Symfonium** | Android | Best overall, lossless |
| **Substreamer** | iOS | Best for iPhone/iPad + Navidrome |
| **Ultrasonic** | Android | Free, open source |
| **Sonixd** | Desktop (Linux/Win/Mac) | Electron, full featured |
| **NCMPCPP** | Linux terminal | MPD direct, bit-perfect |

---

## 12. Troubleshooting

| Problem | Fix |
|---|---|
| No sound via HDMI | `aplay -l` to list devices; set ALSA default card |
| SPDIF not working | `amixer sset "AIU SPDIF SRC SEL" I2S` after `ldto enable spdif` |
| AirPlay not discovered | Ensure `avahi-daemon` is running, port 5353 open on firewall |
| Spotify Connect not visible | Check spotifyd is running and connected to WiFi |
| MPD can't read NFS | Check `nfs-music.mount` systemd unit is active |
| Onkyo shows "no signal" on optical | Check ALSA SPDIF source sel; check TOSLINK transmitter power |
| Audio stutters | Increase MPD buffer; check WiFi signal; use wired LAN |

---

## 13. Karaoke Setup

### Does Le Potato need a screen?

**No.** Le Potato is audio-out only. It has no browser, no display server, no GUI.
Karaoke runs on the **homelab** and the lyrics player opens in a **browser on any screen** —
phone, tablet, Chromecast, Android TV, Apple TV browser, or a laptop plugged into Onkyo HDMI IN 2.

### How the system splits

```
HOMELAB:
  KaraokeEternal server (:8044)
         │
         ├──► Phone/tablet browsers: guests browse library + queue songs
         │
         └──► "Player" browser tab (big screen) ─── audio + lyrics here
                        │
               runs on any device with a browser:
               - Chromecast / Android TV → HDMI IN 2 on Onkyo
               - Tablet → Bluetooth to Onkyo
               - Laptop → HDMI IN 2 on Onkyo  ← cleanest

LE POTATO (unchanged):
  Handles all regular music — AirPlay, Spotify Connect, MPD, Bluetooth
  → HDMI IN 1 on Onkyo  (switch input for karaoke vs music)
```

**Onkyo TX-SR605 has 3 HDMI inputs.** Use:
- **HDMI IN 1** → Le Potato (regular music/Snapcast)
- **HDMI IN 2** → karaoke device (laptop/Chromecast running KaraokeEternal player)

Switch with the Onkyo remote. No rewiring needed.

### Microphone for karaoke

The Onkyo's front mic port is for Audyssey calibration only — it does not mix live audio.

**Option A — Easiest:** Small USB audio interface with mic input:
- Focusrite Scarlett Solo (~€100) or Behringer UM2 (~€30)
- Plug mic into it, connect interface audio out to Onkyo analog IN (RCA)
- Set Onkyo to that analog input during karaoke OR use a small passive Y-mixer

**Option B — Budget:** Behringer XENYX 302USB (~€40) mini mixer:
- Mic + karaoke laptop audio → mixed → Onkyo RCA in
- Also works as USB audio interface for Le Potato if needed later

**Option C — Zero cost:** Use Onkyo's A/V IN (front panel) for mic passthrough and switch listening modes.

### KaraokeEternal is already deployed on homelab

```bash
# Start it:
docker compose up -d karaoke-eternal

# First-time setup:
# 1. Go to http://HOMELAB_IP:8044  (or https://potatostack.tale-iwato.ts.net:8044)
# 2. Click "Create Account" — first account becomes admin
# 3. Go to Preferences → Media Folders → add /media
# 4. Scan library

# Open the player on your karaoke screen device:
# http://HOMELAB_IP:8044  → click "Player" button (bottom right)
# This is the full-screen karaoke display with lyrics
```

Media folder on homelab: `/mnt/storage/media/karaoke` (auto-created by storage-init).

### Karaoke file formats

KaraokeEternal uses **CDG+MP3** (industry standard karaoke format), **not** LRC lyrics from Beets.

| Format | Works | Where to get |
|---|---|---|
| `.cdg` + `.mp3` pairs | ✅ Yes | karaoke-version.com, rip from CDG discs |
| `.mp4` karaoke videos | ✅ Yes | download tools (personal use) |
| `.lrc` (from Beets) | ❌ No | see below for singalong alternative |

Name files identically: `Song Title.mp3` + `Song Title.cdg` in the same folder — KaraokeEternal pairs them automatically.

### Using your Beets library for singalong (no CDG needed)

Your beets library has embedded LRC lyrics. For lyrics display during regular MPD playback:

```bash
# On any machine, point ncmpcpp at Le Potato's MPD:
ncmpcpp -h LE_POTATO_IP -p 6600
# Press F5 → lyrics panel (reads embedded LRC)
```

Android apps that show lyrics from Navidrome: **Symfonium** (best), **Ultrasonic** (free)
iOS: **Substreamer**, **play:Sub**

---

## Sources
- [Le Potato SPDIF enable — Libre Computer Hub](https://hub.libre.computer/t/how-to-enable-spdif-on-aml-s905x-cc-le-potato/3005)
- [ShairPort-Sync AirPlay 2 — GitHub](https://github.com/mikebrady/shairport-sync)
- [upmpdcli Docker + Subsonic/Navidrome — GitHub](https://github.com/GioF71/upmpdcli-docker)
- [Onkyo TX-SR605 Listening Modes — AVS Forum](https://www.avsforum.com/threads/onkyo-tx-sr605-705-805-listening-modes-explained-purposes-and-benefits.1008717/)
- [PipeWire + Raspotify + ShairPort multiroom — raspotify Discussion](https://github.com/dtcooper/raspotify/discussions/691)
- [Adventures in Self-Hosting HiFi Audio — jimwillis.org](https://www.jimwillis.org/2024/12/08/adventures-in-self-hosting-hifi-audio-streaming/)
