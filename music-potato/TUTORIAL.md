# Le Potato Audio Hub — Complete Setup Tutorial

**Hardware:** Libre Computer AML-S905X-CC + Onkyo TX-SR605 + Yamaha YST-FSW050 + Fluance ES1
**Stack:** Armbian Trixie Minimal IoT + Docker + AirPlay 2 + Spotify Connect + UPnP/DLNA + Snapcast
**Result:** Lossless audio hub discoverable by every Apple, Android, Linux device on your network and tailnet

---

## Shopping List — Buy Before You Start

| Item | What to buy | Why |
|---|---|---|
| WiFi dongle | **TP-Link TL-WN822N** (RTL8192EU) | Works on Armbian out of box. Avoid RTL8811CU — needs fragile DKMS |
| Bluetooth dongle | **TP-Link UB500** (BT 5.0) | Plug and play with PipeWire on Armbian |
| MicroSD card | **32 GB A1 class or better** (e.g. SanDisk Endurance) | Armbian fits in 8 GB but 32 GB gives room. A1 = fast random IO |
| Power supply | **5V/3A USB-C** (or 5V/2A microUSB depending on your Le Potato revision) | Underpowering causes audio glitches |
| HDMI cable | Any HDMI ≥ 1.3 | Le Potato → Onkyo HDMI IN |
| **OR** TOSLINK cable + TOSLINK transmitter module | Any TOSLINK cable + ~€3 module from AliExpress ("TOSLINK SPDIF transmitter 3.3V") | For optical connection instead of HDMI |

**USB ports:** Le Potato has only 2× USB-A 2.0. WiFi dongle + BT dongle uses both.
If you need keyboard during setup → use a USB hub, remove it after.

---

## Part 1 — Flash Armbian on Le Potato

### Step 1.1 — Download Armbian

Download **Armbian Trixie Minimal IoT** for AML-S905X-CC:
```
https://www.armbian.com/lepotato/
```
Pick: **Armbian_XX.XX_Lepotato_trixie_current_X.X.X.img.xz** (CLI / minimal / IoT)
Do NOT pick the desktop build — you don't need it and it wastes RAM.

### Step 1.2 — Flash the SD card

```bash
# On your main machine (Linux/Mac):
# Install balenaEtcher or use dd

# With dd (replace /dev/sdX with your SD card):
xz -dc Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync

# Or use balenaEtcher (GUI, available on all platforms)
```

### Step 1.3 — First boot

1. Insert SD card into Le Potato
2. Connect HDMI to a monitor (only needed for first boot)
3. Connect Ethernet cable (easier than WiFi for initial setup)
4. Power on

First boot takes ~2 minutes. Armbian will auto-resize the partition.

### Step 1.4 — Initial Armbian setup

Connect via serial or HDMI+keyboard. Default login:
```
username: root
password: 1234
```

Armbian will force you to change the root password and create a user:
```bash
# Follow the prompts:
# 1. Set new root password
# 2. Create user: daniel
# 3. Set user password
# 4. Choose shell: bash
```

### Step 1.5 — Update system

```bash
apt-get update && apt-get upgrade -y
apt-get install -y curl wget git htop nano
```

### Step 1.6 — Set hostname

```bash
hostnamectl set-hostname music-potato
# Verify:
hostname
```

---

## Part 2 — WiFi Setup

### Step 2.1 — Plug in WiFi dongle

Plug in the TP-Link TL-WN822N. Verify Armbian sees it:
```bash
ip link show
# You should see: wlan0 or wlx... interface
```

If no WiFi interface appears: `lsusb` — if the dongle shows up but no interface, the driver isn't loaded:
```bash
# For RTL8192EU:
apt-get install -y rtl8192eu-dkms
reboot
```

### Step 2.2 — Connect to WiFi

```bash
# Interactive TUI (easiest):
nmtui
# → Edit a connection → Add → WiFi → enter SSID + password → OK → Activate

# Or command line:
nmcli dev wifi connect "YOUR_SSID" password "YOUR_PASSWORD"

# Verify:
ip addr show wlan0
ping -c 3 8.8.8.8
```

### Step 2.3 — Disconnect Ethernet (optional)

Once WiFi works, you can unplug Ethernet. SSH in via WiFi IP:
```bash
# Find IP:
ip addr show wlan0 | grep "inet "

# From your main machine:
ssh daniel@<LE_POTATO_WIFI_IP>
```

Give the router a DHCP reservation for Le Potato's MAC address so the IP never changes.

---

## Part 3 — Homelab NFS Export

Run these commands **on the homelab (potatostack server)**, not on Le Potato.

### Step 3.1 — Run the NFS setup script

```bash
# On homelab:
cd /home/daniel/potatostack
sudo bash music-potato/homelab-nfs-setup.sh 192.168.1.0/24
# Replace 192.168.1.0/24 with your actual LAN subnet
```

What this does:
- Installs `nfs-kernel-server`
- Exports `/mnt/storage/media/music` read-only to your LAN
- Runs `exportfs -ra`

### Step 3.2 — Verify the export from homelab

```bash
# On homelab:
exportfs -v
# Should show: /mnt/storage/media/music  192.168.1.0/24(ro,sync,...)

showmount -e localhost
# Should show: /mnt/storage/media/music  192.168.1.0/24
```

### Step 3.3 — Test mount from Le Potato

```bash
# On Le Potato:
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/music
sudo mount -t nfs HOMELAB_IP:/mnt/storage/media/music /mnt/music

ls /mnt/music
# Should show your music library folders
```

### Step 3.4 — Make NFS mount permanent

```bash
# On Le Potato — add to /etc/fstab:
echo "HOMELAB_IP:/mnt/storage/media/music  /mnt/music  nfs  ro,nfsvers=4,hard,intr,timeo=150,retrans=3,_netdev  0  0" | sudo tee -a /etc/fstab

# Test fstab entry:
sudo umount /mnt/music
sudo mount -a
ls /mnt/music   # should still work
```

---

## Part 4 — Docker Installation on Le Potato

### Step 4.1 — Install Docker

```bash
# On Le Potato:
curl -fsSL https://get.docker.com | sh

# Add your user to docker group:
sudo usermod -aG docker daniel
sudo usermod -aG audio daniel

# Apply group changes (or log out/in):
newgrp docker
newgrp audio
```

### Step 4.2 — Verify Docker

```bash
docker run --rm hello-world
# Should print "Hello from Docker!"

# Check architecture — MUST show aarch64:
uname -m
# Expected: aarch64
```

### Step 4.3 — Enable Docker on boot

```bash
sudo systemctl enable docker
sudo systemctl enable containerd
```

---

## Part 5 — Audio Device Setup

### Option A — HDMI (Recommended, zero config)

Connect Le Potato HDMI out → Onkyo TX-SR605 HDMI IN 1, 2, or 3.

```bash
# Verify HDMI audio device exists:
aplay -l
# Look for: card 0: amlaugesound [aml-augesound], device 0: HDMI HDMI-0

# Unmute (muted by default on Armbian!):
amixer -c 0 sset Master 100% unmute

# Test — should produce white noise through Onkyo:
speaker-test -c 2 -D hw:0,0 -t wav -l 1
```

Set `AUDIO_DEVICE=hw:0,0` in `.env` (done in Step 6).

---

### Option B — Optical SPDIF

**Hardware:** Solder or connect a TOSLINK transmitter module to the 9J1 header on Le Potato.

```
9J1 header pinout (between HDMI port and 3.5mm jack):
[5V] [SPDIF DATA] [GND]
  ↑                  ↑
HDMI side          3.5mm side

Wire: module VCC → 5V pin
      module GND → GND pin
      module DIN → DATA (middle) pin
```

Connect TOSLINK cable: Le Potato 9J1 module → Onkyo OPTICAL IN 1.

```bash
# Enable SPDIF overlay (temporary test first):
sudo ldto enable spdif

# REQUIRED: route audio to SPDIF:
amixer sset "AIU SPDIF SRC SEL" I2S

# Test:
speaker-test -c 2 -D hw:0,1 -t wav -l 1
# If Onkyo shows signal → working

# Make permanent:
sudo ldto merge spdif
sudo reboot

# After reboot, set source again:
amixer sset "AIU SPDIF SRC SEL" I2S
```

Set `AUDIO_DEVICE=hw:0,1` in `.env`.

> If SPDIF doesn't work after `ldto merge spdif`, see the device tree ordering workaround:
> https://hub.libre.computer/t/how-to-enable-spdif-on-aml-s905x-cc-le-potato/3005

---

### Option C — USB DAC

Plug in any USB DAC. Armbian loads it automatically.

```bash
aplay -l
# New card appears: card 1: ...
# Note the card number and use hw:1,0 (or hw:2,0 etc)
```

Set `AUDIO_DEVICE=hw:1,0` in `.env`.

---

## Part 6 — Deploy Le Potato Docker Stack

### Step 6.1 — Copy stack files to Le Potato

```bash
# On homelab:
scp -r /home/daniel/potatostack/music-potato/ daniel@LE_POTATO_IP:~/music-potato/
```

### Step 6.2 — Create and fill .env

```bash
# On Le Potato:
cd ~/music-potato
cp .env.example .env
nano .env
```

Fill in every value:

```env
DEVICE_NAME=music-potato           # name shown in AirPlay picker, Spotify, DLNA

AUDIO_DEVICE=hw:0,0             # hw:0,0=HDMI | hw:0,1=SPDIF | hw:1,0=USB DAC

NAVIDROME_URL=http://192.168.1.100:4533   # homelab LAN IP (not Tailscale yet)
NAVIDROME_USER=daniel
NAVIDROME_PASS=YOUR_NAVIDROME_PASSWORD    # find in homelab .env

SNAPSERVER_HOST=192.168.1.100   # homelab LAN IP

TS_AUTHKEY=tskey-auth-XXXXXXXXX # generate in step 7, leave blank for now

TZ=Europe/Berlin
```

> Find `NAVIDROME_PASS`: on homelab run `grep NAVIDROME /home/daniel/potatostack/.env`

### Step 6.3 — Copy ALSA config to system

```bash
# On Le Potato:
sudo cp ~/music-potato/etc/asound.conf /etc/asound.conf
```

### Step 6.4 — Pull and start

```bash
cd ~/music-potato
docker compose pull
docker compose up -d

# Watch startup:
docker compose logs -f
# Wait until all services show "started" or "ready"
# Ctrl+C to stop following logs
```

### Step 6.5 — Verify all containers running

```bash
docker compose ps
```

Expected output (all should show `Up` or `running`):

```
NAME               STATUS
avahi              Up
mpd                Up (healthy)
shairport-sync     Up (healthy)
snapcast-client    Up (healthy)
spotifyd           Up (healthy)
tailscale-music-potato Up (healthy)
upmpdcli           Up (healthy)
watchtower-music-potato Up
```

### Step 6.6 — Verify audio services are announcing

```bash
# AirPlay 2 on network:
avahi-browse -a -t | grep -i airplay
# Should show: music-potato [type=_airplay._tcp]

# UPnP/DLNA renderer:
avahi-browse -a -t | grep -i MediaRenderer
# Should show: music-potato [type=_mediarenderer._tcp]
```

### Step 6.7 — Verify MPD loaded your library

```bash
docker exec mpd mpc stats
# Shows: Artists, Albums, Songs counts
# If songs = 0: NFS not mounted or MPD hasn't scanned yet

# Force rescan:
docker exec mpd mpc update
# Wait ~30s, then:
docker exec mpd mpc stats
```

---

## Part 7 — Tailscale Setup

### Step 7.1 — Generate auth key

On your main machine, go to:
```
https://login.tailscale.com/admin/settings/keys
```
Click **Generate auth key** → one-time key (not reusable) → Copy it.

### Step 7.2 — Add key to .env

```bash
# On Le Potato:
nano ~/music-potato/.env
# Set: TS_AUTHKEY=tskey-auth-XXXXXXXXXXXXXXXX
```

### Step 7.3 — Restart Tailscale container

```bash
cd ~/music-potato
docker compose restart tailscale-music-potato

# Check it joined:
docker exec tailscale-music-potato tailscale status
# Should show: music-potato  100.x.x.x  ...  active
```

### Step 7.4 — Update Navidrome URL to Tailscale

Now that Le Potato is in your tailnet, switch to the Tailscale HTTPS URL for Navidrome:

```bash
nano ~/music-potato/.env
# Change:
# NAVIDROME_URL=http://192.168.1.100:4533
# To:
NAVIDROME_URL=https://potatostack.tale-iwato.ts.net:4533

docker compose restart upmpdcli
```

### Step 7.5 — Verify Tailscale

```bash
# From homelab, ping Le Potato by name:
ping music-potato

# From Le Potato, reach Navidrome via Tailscale:
curl -s https://potatostack.tale-iwato.ts.net:4533/ping
# Should return: {"ok":true}
```

---

## Part 8 — Homelab Snapcast + MPD (Multi-room)

Run these on **homelab**.

### Step 8.1 — Start snapcast and mpd-snap

```bash
# On homelab:
cd /home/daniel/potatostack
docker compose up -d mpd-snap snapcast
docker compose ps mpd-snap snapcast
```

### Step 8.2 — Verify snapcast server is up

```bash
# Web UI should be accessible:
curl -s http://localhost:1780 | head -5
# → HTML response

# Via Tailscale from anywhere:
# https://potatostack.tale-iwato.ts.net:1780
```

### Step 8.3 — Test multi-room playback

```bash
# On homelab — add music to mpd-snap queue and play:
mpc -h localhost -p 6601 clear
mpc -h localhost -p 6601 add /
mpc -h localhost -p 6601 shuffle
mpc -h localhost -p 6601 play

# On Le Potato — verify snapcast client is receiving:
docker logs snapcast-client --tail 20
# Should show: "Connected to..." and audio stream info
```

Audio should now play through Onkyo on Le Potato.

### Step 8.4 — Control multi-room volume per room

Open Snapweb in browser: `https://potatostack.tale-iwato.ts.net:1780`

- Each connected room appears as a client
- Set per-room volume independently
- Set latency per client if rooms are out of sync (usually 0ms is fine on LAN)

---

## Part 9 — Bluetooth Setup

### Step 9.1 — Plug in BT dongle

Plug in the TP-Link UB500. Verify:
```bash
hciconfig
# Should show: hci0   Type: Primary  Bus: USB  UP RUNNING

bluetoothctl show
# Should show: Controller XX:XX:XX:XX:XX:XX  music-potato [default]
```

If not detected: `lsusb` to confirm USB recognition, then `dmesg | tail -20` for errors.

### Step 9.2 — Make Le Potato discoverable as BT audio sink

```bash
bluetoothctl
```

Inside bluetoothctl:
```
power on
agent on
default-agent
discoverable on
pairable on
```

Leave this open. On your phone/device, scan for Bluetooth and connect to **music-potato**.

Once paired:
```
# In bluetoothctl:
trust XX:XX:XX:XX:XX:XX    ← your device MAC
quit
```

### Step 9.3 — Install PipeWire Bluetooth (enables A2DP audio sink)

```bash
sudo apt-get install -y pipewire pipewire-audio-client-libraries \
  pipewire-pulse wireplumber libspa-0.2-bluetooth

# Enable PipeWire as system service:
systemctl --user enable --now pipewire pipewire-pulse wireplumber

# Verify:
pactl info | grep "Server Name"
# Should show: PulseAudio (on PipeWire X.X)
```

### Step 9.4 — Make Bluetooth auto-connect on boot

```bash
sudo nano /etc/bluetooth/main.conf
```

Ensure these lines are set:
```ini
[Policy]
AutoEnable=true

[General]
DiscoverableTimeout=0
Discoverable=true
FastConnectable=true
```

```bash
sudo systemctl restart bluetooth
```

Now when your phone pairs with Le Potato over BT, audio goes through Onkyo automatically.

---

## Part 10 — Onkyo TX-SR605 Configuration

### Step 10.1 — Physical connections

```
Le Potato HDMI    →  Onkyo HDMI IN 1
(or 9J1 optical)  →  Onkyo OPTICAL IN 1

Yamaha YST-FSW050 →  Onkyo SUBWOOFER PRE-OUT (RCA cable)
Fluance ES1 Left  →  Onkyo FRONT L (speaker wire)
Fluance ES1 Right →  Onkyo FRONT R (speaker wire)
```

### Step 10.2 — Run Audyssey room correction first

Press **SETUP** on Onkyo remote → Auto Setup → place the Audyssey mic at listening position → run measurement. This sets speaker distances and levels.

Then **override** the Audyssey settings below — Audyssey EQ is for movies, not music.

### Step 10.3 — Speaker configuration

Remote: **SETUP** → Speaker → Configuration

| Setting | Value |
|---|---|
| Front | Large (Fluance ES1 handles full range 40-20kHz) |
| Center | None |
| Surround | None |
| Subwoofer | Yes |
| Crossover | 80 Hz |

### Step 10.4 — Subwoofer settings

On the **Yamaha YST-FSW050** itself:
- Volume knob: 70% (adjust by ear later)
- Crossover knob: MAX → let Onkyo handle crossover via bass management

On Onkyo: SETUP → Audio → Subwoofer Level → adjust until bass blends with Fluance ES1.

### Step 10.5 — Set Pure Audio mode for music

Press the **LISTENING MODE** button on the remote or front panel until it shows:

```
PURE AUDIO
```

**What Pure Audio does:**
- Disables ALL digital signal processing
- Disables Audyssey EQ, tone controls, Dynamic EQ, Late Night
- Disables video circuits (screen goes dark — normal)
- Routes audio through a pure 2-channel analog path
- Eliminates switching noise from unused circuits

This is the highest quality mode for music. Use **DIRECT** instead if you need the display on.

### Step 10.6 — Input and digital settings

Press **SETUP** → Audio Adjust:
- Re-EQ: **OFF**
- Late Night: **OFF**
- Dynamic Range: **OFF**
- AccuEQ: **OFF** for music

Select your input:
- If using HDMI: press **HDMI** input selector → choose HDMI 1 (or whichever Le Potato is on)
- If using optical: press **DVD** or **CD** input selector (whichever OPTICAL IN 1 is assigned to)

### Step 10.7 — Verify signal

Play a FLAC file via MPD:
```bash
docker exec mpd mpc clear
docker exec mpd mpc add /
docker exec mpd mpc play
```

Onkyo front panel should show:
```
PCM 48kHz  (or 44.1kHz depending on track)
PURE AUDIO
```

If it shows `DD` or `DTS` → your HDMI audio format is wrong. Set ALSA format to stereo PCM:
```bash
# In shairport-sync.conf and asound.conf, format is already set to stereo PCM
# Restart containers:
docker compose restart shairport-sync mpd
```

---

## Part 11 — Testing Every Protocol

### 11.1 — AirPlay 2 (Apple Music / iPhone / iPad / Mac)

**iPhone/iPad:**
1. Open Control Center (swipe down from top right)
2. Long-press the audio widget (top right of Control Center)
3. Tap the AirPlay icon (triangle with rings)
4. Select **music-potato**
5. Open Apple Music → play any song
6. In Apple Music settings: **Lossless** and **Dolby Atmos** should be ON

**Mac:**
1. Click the Control Center icon (menu bar) → AirPlay
2. Select **music-potato**
3. Play music in Apple Music

What to expect: Onkyo shows `PCM 48kHz` in Pure Audio mode. Apple Music streams ALAC 24-bit/48kHz losslessly.

### 11.2 — Spotify Connect (any device)

1. Open Spotify on phone/desktop
2. Tap the **Connect** icon (cast icon at bottom of player screen)
3. Select **music-potato**
4. Play any song

What to expect: Audio through Onkyo. Note: Spotify is always OGG 320kbps — not lossless. For lossless Spotify tracks, use your SpotiFLAC downloads via MPD.

### 11.3 — MPD direct (your music library, lossless)

**From terminal on any machine in tailnet:**
```bash
# Single command to play whole library shuffled:
mpc -h LE_POTATO_IP -p 6600 clear && \
mpc -h LE_POTATO_IP -p 6600 add / && \
mpc -h LE_POTATO_IP -p 6600 shuffle && \
mpc -h LE_POTATO_IP -p 6600 play
```

**Android app:** Install **M.A.L.P.** (free, F-Droid/Play Store)
- Settings → Server → Host: `LE_POTATO_IP`, Port: `6600`
- Browse library, create playlists, control playback

**iOS app:** Install **Rigelian** (paid) or **MPDRemote** (free)
- Connect to `LE_POTATO_IP:6600`

What to expect: FLAC files play bit-perfect. Onkyo shows the exact sample rate of the file (44.1kHz for CD rips, 96kHz for hi-res, etc.).

### 11.4 — UPnP/DLNA with Navidrome library

**Android:** Install **BubbleUPnP** (free tier works)
1. Open BubbleUPnP → Renderers → select **music-potato**
2. Library → Servers → your Navidrome should auto-appear
3. Browse → play

**iOS:** Install **mconnect** or **Kazoo**

What to expect: You can browse Navidrome's library from BubbleUPnP and play through Le Potato / Onkyo.

### 11.5 — HTTP stream (any browser or VLC)

```
http://LE_POTATO_IP:8000/stream
```

Open in VLC, a browser, or any media player. Plays whatever MPD is currently playing as a FLAC stream.

Useful for: casting to devices that don't support MPD, quick testing, playing in browser.

### 11.6 — Navidrome Subsonic app (remote/tailnet)

Install **Symfonium** (Android) or **Substreamer** (iOS):
- Server URL: `https://potatostack.tale-iwato.ts.net:4533`
- Username: `daniel`
- Password: your Navidrome password

These apps connect directly to the homelab Navidrome and stream to your phone — they do NOT play through Le Potato/Onkyo. Use for listening on headphones away from home.

### 11.7 — Multi-room Snapcast

```bash
# On homelab — play via mpd-snap:
mpc -h localhost -p 6601 clear
mpc -h localhost -p 6601 add /
mpc -h localhost -p 6601 play

# Open Snapweb to see all rooms and adjust volume:
# https://potatostack.tale-iwato.ts.net:1780
```

---

## Part 12 — Which Mode to Use When

| Situation | What to use | Control |
|---|---|---|
| Your music library, best quality | **MPD** port 6600 | M.A.L.P. / NCMPCPP / mpc |
| Apple Music streaming | **AirPlay 2** (shairport-sync) | iPhone/iPad/Mac natively |
| Spotify | **Spotify Connect** (spotifyd) | Spotify app Connect button |
| Browse Navidrome from DLNA app | **UPnP/DLNA** (upmpdcli) | BubbleUPnP / mconnect |
| Multi-room sync | **Snapcast** (mpd-snap port 6601) | M.A.L.P. at port 6601 / Snapweb |
| Bluetooth headphones on Le Potato | **BT A2DP** (native) | pair from device settings |
| Remote listening (out of house) | **Navidrome** Subsonic API | Symfonium / Substreamer |

---

## Part 13 — Maintenance

### Update all Le Potato containers

Watchtower does this automatically every 24 hours. To force update now:
```bash
cd ~/music-potato
docker compose pull
docker compose up -d
```

### Update homelab snapcast/mpd-snap

```bash
cd /home/daniel/potatostack
docker compose pull mpd-snap snapcast
docker compose up -d mpd-snap snapcast
```

### If NFS mount drops (homelab reboot)

```bash
# On Le Potato:
sudo mount -a
docker compose restart mpd
```

### Check Le Potato container health

```bash
cd ~/music-potato
docker compose ps
docker compose logs --tail 50
```

### Check homelab snapcast

```bash
cd /home/daniel/potatostack
docker compose logs mpd-snap --tail 30
docker compose logs snapcast --tail 30
```

---

## Part 14 — Troubleshooting

### No sound at all

```bash
# Step 1 — check ALSA isn't muted:
amixer -c 0 contents | grep -A1 "Master"
amixer -c 0 sset Master 100% unmute

# Step 2 — verify correct device:
aplay -l
speaker-test -c 2 -D hw:0,0 -t wav -l 1

# Step 3 — check container audio permissions:
docker exec shairport-sync ls /dev/snd/
# Should list: controlC0, pcmC0D0p, etc.
```

### AirPlay device not showing up on iPhone

```bash
# Avahi must be running:
docker compose ps avahi
# If not: docker compose restart avahi

# Check shairport-sync announced itself:
avahi-browse _airplay._tcp --terminate
# Should show: music-potato

# iPhone and Le Potato must be on same WiFi — check:
ip addr show wlan0    # Le Potato IP
# Ping it from iPhone using a network scanner app
```

### Spotify Connect not visible in app

```bash
# Check spotifyd running:
docker compose ps spotifyd
docker compose logs spotifyd --tail 30

# Most common cause: wrong Spotify credentials in config/spotifyd.conf
nano ~/music-potato/config/spotifyd.conf
# Fix username/password
docker compose restart spotifyd
```

### MPD shows 0 songs

```bash
# Check NFS is mounted:
ls /mnt/music
# If empty: sudo mount -a

# Force MPD rescan:
docker exec mpd mpc update
sleep 30
docker exec mpd mpc stats
```

### Snapcast client not connecting

```bash
# Check server is reachable from Le Potato:
nc -zv HOMELAB_IP 1704
# Should say: Connection to HOMELAB_IP 1704 port [tcp/*] succeeded

# If not: homelab firewall or docker port binding issue
# On homelab:
docker compose ps snapcast
# Port 1704 must NOT be bound to 127.0.0.1 — check docker-compose.yml
```

### SPDIF no signal on Onkyo

```bash
# Ensure overlay is merged (persists across reboots):
sudo ldto list | grep spdif
# Should show: spdif (merged)

# If not:
sudo ldto merge spdif
sudo reboot

# After reboot — always set this:
amixer sset "AIU SPDIF SRC SEL" I2S

# Add to /etc/rc.local for persistence:
echo 'amixer sset "AIU SPDIF SRC SEL" I2S' | sudo tee -a /etc/rc.local
```

### Audio stutters or drops

```bash
# 1. Check WiFi signal strength:
iwconfig wlan0 | grep "Signal level"
# Should be: -70 dBm or better (-50 is excellent, -80 is poor)

# 2. Check NFS latency:
time ls /mnt/music > /dev/null
# Should complete in < 0.5 seconds

# 3. Increase MPD buffer in .env (change BUFFER_SIZE):
nano ~/music-potato/.env
# Set BUFFER_SIZE=16384   (double it)
docker compose restart mpd

# 4. Switch to wired Ethernet if WiFi is the problem
```

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                    HOMELAB                          │
│                                                     │
│  Navidrome ──Subsonic API──────────────────────┐   │
│  mpd-snap ──FIFO──► snapcast server ──LAN──┐   │   │
│  NFS export (/mnt/storage/media/music)     │   │   │
└────────────────────────────────────────────┼───┼───┘
                                             │   │
              ┌──────────────────────────────┘   │ Tailscale
              │                                  │
┌─────────────▼────────────────────────────────────────┐
│                   LE POTATO                          │
│                                                      │
│  snapcast-client ◄──────────────────────────────────┤
│  /mnt/music (NFS) ──► mpd ──ALSA──────────────────┐ │
│  [iPhone]  ──AirPlay 2──► shairport-sync ──ALSA──┐ │ │
│  [Spotify] ──Connect──► spotifyd ──────────ALSA──┤ │ │
│  [BubbleUPnP]──DLNA──► upmpdcli ──MPD──────ALSA──┤ │ │
│  [BT device] ──────────────────────────────BT──┐ │ │ │
│                                                 ▼ ▼ ▼ │
│                              ALSA hw:0,0 (HDMI) OR    │
│                              ALSA hw:0,1 (SPDIF)      │
└───────────────────────────────────────────────────────┘
                         │
            ┌────────────▼──────────┐
            │  Onkyo TX-SR605       │
            │  Mode: Pure Audio     │
            │  Crossover: 80 Hz     │
            └──┬────────────────────┘
               ├── Fluance ES1 Left
               ├── Fluance ES1 Right
               └── Yamaha YST-FSW050
```

---

## Quick Reference Card

```
# Play music (single room, your library):
mpc -h LE_POTATO_IP play

# Play music (multi-room):
mpc -h HOMELAB_IP -p 6601 play

# Status check:
cd ~/music-potato && docker compose ps

# Restart everything:
cd ~/music-potato && docker compose restart

# Update everything:
cd ~/music-potato && docker compose pull && docker compose up -d

# Volume control (software):
docker exec mpd mpc volume 80

# What's playing:
docker exec mpd mpc current

# Snapweb (per-room volume):
https://potatostack.tale-iwato.ts.net:1780

# Navidrome (library management):
https://potatostack.tale-iwato.ts.net:4533
```
