#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# music-potato — Full Setup Script
# Hardware : Libre Computer AML-S905X-CC (aarch64) + Onkyo TX-SR605
# OS       : Armbian Trixie Minimal IoT
#
# Usage:
#   sudo ./setup.sh
#
# Non-interactive (set env vars first):
#   sudo WIFI_SSID="MyNet" WIFI_PASS="pass" HOMELAB_IP="192.168.1.100" \
#        DEVICE_NAME="music-potato" TS_AUTHKEY="tskey-auth-XXX" ./setup.sh
#
# What this does (in order):
#   1. Installs firmware for all supported driverless USB WiFi/BT dongles
#   2. Detects + loads kernel modules for plugged-in radios
#   3. Prompts for all config (WiFi, homelab, audio, etc.)
#   4. Connects WiFi, verifies Bluetooth
#   5. System: Docker, ALSA, PipeWire+Bluetooth, NFS, Tailscale, avahi (mDNS)
#   6. Docker: shairport-sync, mpd, upmpdcli, spotifyd, snapcast-client,
#              tailscale, watchtower
#   7. systemd music-potato.service — auto-restarts stack on every boot
#
# Safe to re-run. Unplug → plug back in → everything comes back in ~30 sec.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${BLUE}[....] $*${NC}"; }
ok()   { echo -e "${GREEN}[ OK ] $*${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
die()  { echo -e "${RED}[ERR ] $*${NC}"; exit 1; }
ask()  {
  local var="$1" prompt="$2" default="${3:-}" secret="${4:-no}"
  [[ -n "${!var:-}" ]] && return   # already set via env
  if [[ -n "$default" ]]; then
    if [[ "$secret" == "yes" ]]; then
      read -rsp "  ${prompt} [${default}]: " val; echo
    else
      read -rp  "  ${prompt} [${default}]: " val
    fi
    printf -v "$var" '%s' "${val:-$default}"
  else
    while [[ -z "${!var:-}" ]]; do
      if [[ "$secret" == "yes" ]]; then
        read -rsp "  ${prompt}: " val; echo
      else
        read -rp  "  ${prompt}: " val
      fi
      printf -v "$var" '%s' "$val"
      [[ -z "${!var}" ]] && echo "  (cannot be empty)"
    done
  fi
}

[[ $EUID -ne 0 ]] && die "Run as root: sudo ./setup.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  music-potato — Full Setup${NC}"
echo -e "${BOLD}  Armbian Trixie · AML-S905X-CC · aarch64${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

# ─── USB chipset database ──────────────────────────────────────────────────────
# Format: "VID:PID|type|chipset|driver|firmware_pkg|notes"
CHIPSET_DB=(
  # WiFi — MediaTek (recommended: in-kernel since Linux 4.x/5.x)
  "0e8d:7961|wifi|MT7921au|mt7921u|firmware-mediatek|WiFi 6 — 574 Mbps 2.4+5GHz — best choice"
  "0e8d:7925|wifi|MT7925|mt7925u|firmware-mediatek|WiFi 7 — requires kernel 6.7+"
  "0e8d:7612|wifi|MT7612u|mt76x2u|firmware-mediatek|AC1200 5GHz — solid"
  "0e8d:7610|wifi|MT7610u|mt76x0u|firmware-mediatek|AC600 5GHz"
  "0e8d:7601|wifi|MT7601u|mt7601u|firmware-mediatek|N150 2.4GHz — ultra-cheap dongles"
  "0e8d:760a|wifi|MT7601u|mt7601u|firmware-mediatek|N150 variant"
  "0e8d:760b|wifi|MT7601u|mt7601u|firmware-mediatek|N150 variant"
  # WiFi — Ralink (in-kernel, no firmware needed)
  "148f:5370|wifi|RT5370|rt2800usb|none|N150 2.4GHz — no firmware needed"
  "148f:5372|wifi|RT5372|rt2800usb|none|N300 2.4GHz — no firmware needed"
  "148f:7601|wifi|MT7601u|mt7601u|firmware-mediatek|N150 Ralink variant"
  "148f:3070|wifi|RT3070|rt2800usb|none|N150 — classic, no firmware needed"
  "148f:3572|wifi|RT3572|rt2800usb|none|N300 — no firmware needed"
  # WiFi — Realtek RTW88 (in-kernel since Linux 6.14)
  "0bda:8812|wifi|RTL8812AU|rtw8812au|firmware-realtek|AC1200 — kernel 6.14+"
  "0bda:8811|wifi|RTL8811AU|rtw8811au|firmware-realtek|AC600 — kernel 6.14+"
  "0bda:8852|wifi|RTL8852BU|rtw8852bu|firmware-realtek|WiFi 6 — kernel 6.17+"
  "0bda:c852|wifi|RTL8852CU|rtw8852cu|firmware-realtek|WiFi 6 — kernel 6.17+"
  # WiFi — Atheros (in-kernel, needs firmware)
  "0cf3:9271|wifi|AR9271|ath9k_htc|firmware-atheros|N150 — TP-Link TL-WN722N v1 only"
  "0cf3:7015|wifi|AR7015|ath9k_htc|firmware-atheros|N150 variant"
  # Bluetooth — Realtek (in-kernel btrtl)
  "0bda:8761|bt|RTL8761B|btrtl|firmware-realtek|BT 5.0 — TP-Link UB500 recommended"
  "0bda:b009|bt|RTL8822BS|btrtl|firmware-realtek|BT 5.0 combo"
  "0bda:c123|bt|RTL8822CU|btrtl|firmware-realtek|BT 5.0 combo"
  # Bluetooth — MediaTek (in-kernel btmtk)
  "0e8d:c616|bt|MT7921|btmtk|firmware-mediatek|BT 5.2 — MT7921au combo chip"
  "0e8d:c615|bt|MT7663|btmtk|firmware-mediatek|BT 5.0"
  # Bluetooth — Qualcomm/Atheros (in-kernel btusb + ath3k)
  "0cf3:3004|bt|QCA3010|ath3k|firmware-atheros|BT 4.0"
  "0cf3:e005|bt|QCA6174|btusb|firmware-atheros|BT 4.1"
  "0cf3:e009|bt|QCA9377|btusb|firmware-atheros|BT 4.2"
  # Bluetooth — CSR
  "0a12:0001|bt|CSR8510|btusb|none|BT 4.0 — WARNING: many are cheap fakes"
  # Bluetooth — Intel (rare as USB)
  "8087:0026|bt|AX201|btusb|firmware-intel-misc|BT 5.2 — rare USB variant"
  "8087:0032|bt|AX210|btusb|firmware-intel-misc|BT 5.3 — rare USB variant"
)

lookup_id() {
  local id="${1,,}"
  for entry in "${CHIPSET_DB[@]}"; do
    [[ "${entry%%|*}" == "$id" ]] && { echo "$entry"; return 0; }
  done
  return 1
}

# ─── Phase 1: Non-free firmware repo + packages ────────────────────────────────
log "Adding non-free-firmware repo if needed..."
needs_nonfree=true
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
  [[ -f "$f" ]] && grep -q "non-free-firmware" "$f" 2>/dev/null && { needs_nonfree=false; break; }
done
if $needs_nonfree; then
  if [[ -f /etc/apt/sources.list.d/armbian.list ]]; then
    echo "deb http://deb.debian.org/debian trixie non-free-firmware" \
      > /etc/apt/sources.list.d/debian-nonfree-firmware.list
  else
    sed -i 's/^\(deb .*trixie[^#]*\)$/\1 non-free-firmware/' /etc/apt/sources.list 2>/dev/null || true
  fi
  ok "non-free-firmware repo added"
else
  ok "non-free-firmware already configured"
fi

log "Updating system and installing packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  firmware-mediatek firmware-realtek firmware-atheros linux-firmware \
  network-manager curl wget usbutils \
  alsa-utils \
  pipewire pipewire-audio-client-libraries pipewire-pulse pipewire-alsa \
  wireplumber libspa-0.2-bluetooth \
  bluez bluez-tools bluetooth \
  avahi-daemon avahi-utils libnss-mdns \
  nfs-common 2>/dev/null || \
apt-get install -y \
  firmware-mediatek firmware-realtek firmware-atheros linux-firmware \
  network-manager curl wget usbutils \
  alsa-utils \
  pipewire pipewire-audio-client-libraries pipewire-pulse pipewire-alsa \
  wireplumber libspa-0.2-bluetooth \
  bluez bluez-tools bluetooth \
  avahi-daemon avahi-utils libnss-mdns \
  nfs-common
ok "Packages installed"

# ─── Phase 2: Detect USB radios + load modules ────────────────────────────────
log "Scanning USB bus for known WiFi and Bluetooth adapters..."
echo ""
FOUND_WIFI=()
FOUND_BT=()

while IFS= read -r line; do
  id=$(echo "$line" | grep -oP 'ID \K[0-9a-f]{4}:[0-9a-f]{4}' | head -1)
  [[ -z "$id" ]] && continue
  entry=$(lookup_id "$id") || true
  if [[ -n "$entry" ]]; then
    IFS='|' read -r db_id type chipset driver firmware notes <<< "$entry"
    if [[ "$type" == "wifi" ]]; then
      FOUND_WIFI+=("$chipset|$driver|$firmware|$notes|$id")
      echo -e "  ${GREEN}[WiFi]${NC} $chipset ($id) — $notes"
    elif [[ "$type" == "bt" ]]; then
      FOUND_BT+=("$chipset|$driver|$firmware|$notes|$id")
      echo -e "  ${GREEN}[ BT ]${NC} $chipset ($id) — $notes"
    fi
  fi
done < <(lsusb)
echo ""

if [[ ${#FOUND_WIFI[@]} -eq 0 && ${#FOUND_BT[@]} -eq 0 ]]; then
  warn "No known USB WiFi or Bluetooth adapters detected. Is the dongle plugged in?"
  echo "  See DONGLES.md for recommended hardware."
  echo "  lsusb output:"
  lsusb | sed 's/^/    /'
  echo ""
  warn "Continuing — firmware is installed, plug dongle in and re-run if needed."
fi

# Load WiFi modules
if [[ ${#FOUND_WIFI[@]} -gt 0 ]]; then
  log "Loading WiFi kernel modules..."
  for entry in "${FOUND_WIFI[@]}"; do
    IFS='|' read -r chipset driver firmware notes id <<< "$entry"
    [[ "$driver" == "none" ]] && continue
    modprobe "$driver" 2>/dev/null \
      && ok "Module: $driver ($chipset)" \
      || warn "Could not load: $driver — may be built-in or unavailable on this kernel"
  done
fi

# Load BT modules
if [[ ${#FOUND_BT[@]} -gt 0 ]]; then
  log "Loading Bluetooth kernel modules..."
  modprobe btusb 2>/dev/null || true
  for entry in "${FOUND_BT[@]}"; do
    IFS='|' read -r chipset driver firmware notes id <<< "$entry"
    if [[ "$driver" != "btusb" && "$driver" != "none" ]]; then
      modprobe "$driver" 2>/dev/null \
        && ok "Module: $driver ($chipset)" \
        || warn "Could not load: $driver (may be built into btusb)"
    else
      ok "Module: btusb ($chipset)"
    fi
  done
fi

# ─── Phase 3: Find WiFi interface, scan networks ───────────────────────────────
WIFI_IFACE=""
systemctl enable NetworkManager
systemctl start NetworkManager

if [[ ${#FOUND_WIFI[@]} -gt 0 ]]; then
  log "Waiting for WiFi interface..."
  for i in $(seq 1 15); do
    WIFI_IFACE=$(ip link show | grep -oP '(?<=\d: )(wlan\w+|wlx\w+)' | head -1)
    [[ -n "$WIFI_IFACE" ]] && break
    sleep 1
  done
  if [[ -n "$WIFI_IFACE" ]]; then
    ok "WiFi interface: $WIFI_IFACE"
    log "Scanning for networks..."
    nmcli dev wifi rescan ifname "$WIFI_IFACE" 2>/dev/null || true
    sleep 3
    echo ""
    echo "  Available networks:"
    nmcli -f SSID,SIGNAL,SECURITY dev wifi list ifname "$WIFI_IFACE" 2>/dev/null | head -15 | sed 's/^/    /'
    echo ""
  else
    warn "WiFi interface not found after 15s — check: dmesg | tail -20"
  fi
fi

# ─── Phase 4: Interactive configuration ───────────────────────────────────────
echo -e "${BOLD}  Configuration (press Enter to accept [defaults], passwords hidden)${NC}"
echo ""

ask WIFI_SSID       "WiFi network name (SSID)"
ask WIFI_PASS       "WiFi password"                              ""              "yes"
ask HOMELAB_IP      "Homelab LAN IP"                            "192.168.1.100"
ask DEVICE_NAME     "Device name (AirPlay / Spotify label)"     "music-potato"
ask NAVIDROME_USER  "Navidrome username"                        "daniel"
ask NAVIDROME_PASS  "Navidrome password"                        ""              "yes"
ask TS_AUTHKEY      "Tailscale auth key (tskey-auth-...)"       ""
ask AUDIO_DEVICE    "ALSA output (hw:0,0=HDMI | hw:1,0=USB DAC | hw:0,1=SPDIF)" "hw:0,0"
ask SNAPSERVER_HOST "Homelab IP for Snapcast multi-room"        "${HOMELAB_IP}"

SPOTIFY_USER="${SPOTIFY_USER:-}"
SPOTIFY_PASS="${SPOTIFY_PASS:-}"
if [[ -z "$SPOTIFY_USER" ]]; then
  read -rp "  Spotify username (blank to skip): " SPOTIFY_USER || true
fi
if [[ -n "$SPOTIFY_USER" ]] && [[ -z "$SPOTIFY_PASS" ]]; then
  read -rsp "  Spotify password: " SPOTIFY_PASS; echo
fi

MUSIC_NFS_PATH="${MUSIC_NFS_PATH:-/mnt/storage/media/music}"
NAVIDROME_URL="http://${HOMELAB_IP}:4533"

echo ""
log "Starting installation for '${DEVICE_NAME}'..."
echo ""

# ─── Phase 5: Hostname ─────────────────────────────────────────────────────────
log "Setting hostname to '${DEVICE_NAME}'..."
hostnamectl set-hostname "${DEVICE_NAME}"
if grep -q "127.0.1.1" /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${DEVICE_NAME}/" /etc/hosts
else
  echo "127.0.1.1	${DEVICE_NAME}" >> /etc/hosts
fi
ok "Hostname: ${DEVICE_NAME} (reachable as ${DEVICE_NAME}.local on LAN)"

# ─── Phase 6: WiFi connect ────────────────────────────────────────────────────
log "Connecting to WiFi: ${WIFI_SSID}..."
if [[ -n "$WIFI_IFACE" ]]; then
  nmcli dev wifi connect "${WIFI_SSID}" password "${WIFI_PASS}" ifname "$WIFI_IFACE" 2>/dev/null \
    || nmcli connection up "${WIFI_SSID}" 2>/dev/null \
    || true
else
  nmcli dev wifi connect "${WIFI_SSID}" password "${WIFI_PASS}" 2>/dev/null \
    || nmcli connection up "${WIFI_SSID}" 2>/dev/null \
    || true
fi
nmcli connection modify "${WIFI_SSID}" \
  connection.autoconnect yes \
  connection.autoconnect-priority 100 2>/dev/null || true

sleep 2
WIFI_IP=$(ip -4 addr show "${WIFI_IFACE:-}" 2>/dev/null | grep -oP '(?<=inet )\S+' | head -1 || true)
if [[ -n "$WIFI_IP" ]]; then
  ok "WiFi: ${WIFI_SSID} — IP: $WIFI_IP — auto-connects on boot"
else
  ok "WiFi: ${WIFI_SSID} profile saved — auto-connects on boot"
fi

log "Waiting for network..."
for i in $(seq 1 15); do
  ping -c1 -W2 "${HOMELAB_IP}" &>/dev/null && break
  sleep 2
done
ping -c1 -W2 "${HOMELAB_IP}" &>/dev/null \
  && ok "Homelab ${HOMELAB_IP} reachable" \
  || warn "Homelab unreachable — NFS/Navidrome will connect on next boot"

# ─── Phase 7: Bluetooth ───────────────────────────────────────────────────────
log "Checking Bluetooth..."
systemctl enable bluetooth
systemctl start bluetooth

BT_IFACE=""
for i in $(seq 1 10); do
  BT_IFACE=$(hciconfig 2>/dev/null | grep -oP 'hci\d+' | head -1)
  [[ -n "$BT_IFACE" ]] && break
  sleep 1
done

if [[ -n "$BT_IFACE" ]]; then
  hciconfig "$BT_IFACE" up 2>/dev/null || true
  bluetoothctl power on 2>/dev/null || true
  ok "Bluetooth: $BT_IFACE ready"
  hciconfig "$BT_IFACE" 2>/dev/null | grep -E "BD Address|Type" | sed 's/^/    /'
else
  warn "No Bluetooth adapter detected. Plug in dongle and re-run if needed."
fi

# Persist kernel modules across reboots
log "Persisting kernel modules..."
MODULES_FILE="/etc/modules-load.d/music-potato-radios.conf"
{
  echo "# music-potato USB radio modules — auto-loaded on boot"
  echo "btusb"
  for entry in "${FOUND_WIFI[@]}"; do
    IFS='|' read -r chipset driver firmware notes id <<< "$entry"
    [[ "$driver" != "none" ]] && echo "$driver"
  done
  for entry in "${FOUND_BT[@]}"; do
    IFS='|' read -r chipset driver firmware notes id <<< "$entry"
    [[ "$driver" != "btusb" && "$driver" != "none" ]] && echo "$driver"
  done
} | sort -u > "$MODULES_FILE"
ok "Kernel modules saved to $MODULES_FILE"

# ─── Phase 8: Docker ──────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  ok "Docker installed"
else
  ok "Docker already installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
fi
systemctl enable docker
systemctl start docker
usermod -aG docker "${INSTALL_USER}"
ok "Docker enabled, ${INSTALL_USER} added to docker group"

# ─── Phase 9: PipeWire + Bluetooth config + mDNS ─────────────────────────────
log "Configuring PipeWire, Bluetooth, mDNS..."

# mDNS — *.local resolves without Tailscale
if ! grep -q "mdns4_minimal" /etc/nsswitch.conf; then
  sed -i 's/^hosts:.*/hosts:          files mdns4_minimal [NOTFOUND=return] dns/' /etc/nsswitch.conf
fi
systemctl enable --now avahi-daemon
ok "Avahi (mDNS): ${DEVICE_NAME}.local resolvable on LAN"

# Allow headless user session (PipeWire + BT need this)
loginctl enable-linger "${INSTALL_USER}"
ok "User lingering enabled for ${INSTALL_USER}"

# Bluetooth: always on, always discoverable, A2DP sink
cat > /etc/bluetooth/main.conf << EOF
[Policy]
AutoEnable=true

[General]
Name=${DEVICE_NAME}
Class=0x200414
DiscoverableTimeout=0
Discoverable=true
Pairable=true
FastConnectable=true
EOF
systemctl enable bluetooth
systemctl restart bluetooth
ok "Bluetooth: A2DP sink, always discoverable as '${DEVICE_NAME}'"

# ALSA — unmute card 0, configure default device
amixer -c 0 sset Master 100% unmute 2>/dev/null \
  && ok "ALSA: unmuted card 0" \
  || warn "ALSA: no Master control (normal for HDMI-only cards)"
amixer sset "AIU SPDIF SRC SEL" I2S 2>/dev/null || true

cp "${SCRIPT_DIR}/etc/asound.conf" /etc/asound.conf
ALSA_CARD_NUM="${AUDIO_DEVICE#hw:}"; ALSA_CARD_NUM="${ALSA_CARD_NUM%%,*}"
sed -i "s/^defaults.pcm.card .*/defaults.pcm.card ${ALSA_CARD_NUM}/" /etc/asound.conf
sed -i "s/^defaults.ctl.card .*/defaults.ctl.card ${ALSA_CARD_NUM}/" /etc/asound.conf
ok "ALSA: default output = ${AUDIO_DEVICE}"

# ─── Phase 10: NFS music mount ────────────────────────────────────────────────
log "Configuring NFS music mount from ${HOMELAB_IP}:${MUSIC_NFS_PATH}..."
mkdir -p /mnt/music
FSTAB_LINE="${HOMELAB_IP}:${MUSIC_NFS_PATH}  /mnt/music  nfs  ro,nfsvers=4,soft,timeo=30,retrans=2,_netdev,x-systemd.automount,x-systemd.idle-timeout=600 0 0"
if grep -qF "${HOMELAB_IP}:${MUSIC_NFS_PATH}" /etc/fstab 2>/dev/null; then
  sed -i "\|${HOMELAB_IP}:${MUSIC_NFS_PATH}|c\\${FSTAB_LINE}" /etc/fstab
  ok "NFS: updated /etc/fstab"
else
  echo "${FSTAB_LINE}" >> /etc/fstab
  ok "NFS: added to /etc/fstab"
fi
systemctl daemon-reload
mount /mnt/music 2>/dev/null \
  && ok "NFS: /mnt/music mounted ($(ls /mnt/music | wc -l) items)" \
  || warn "NFS: /mnt/music not mounted now — auto-mounts on first MPD access"

# ─── Phase 11: Tailscale ──────────────────────────────────────────────────────
log "Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
  ok "Tailscale installed"
else
  ok "Tailscale already installed"
fi
systemctl enable tailscaled
systemctl start tailscaled
tailscale up \
  --auth-key="${TS_AUTHKEY}" \
  --hostname="${DEVICE_NAME}" \
  --accept-dns=true \
  --ssh 2>/dev/null \
  && ok "Tailscale: connected as ${DEVICE_NAME} ($(tailscale ip 2>/dev/null || echo 'check: tailscale ip'))" \
  || warn "Tailscale auth failed — run: tailscale up --auth-key=<key> --hostname=${DEVICE_NAME}"

# ─── Phase 12: Docker stack config ────────────────────────────────────────────
log "Writing ${SCRIPT_DIR}/.env ..."
cat > "${SCRIPT_DIR}/.env" << EOF
# music-potato docker-compose environment
# Generated by setup.sh — re-run setup.sh or edit + run: docker compose up -d

DEVICE_NAME=${DEVICE_NAME}
AUDIO_DEVICE=${AUDIO_DEVICE}

NAVIDROME_URL=${NAVIDROME_URL}
NAVIDROME_USER=${NAVIDROME_USER}
NAVIDROME_PASS=${NAVIDROME_PASS}
SUBSONIC_ENABLE=yes

SNAPSERVER_HOST=${SNAPSERVER_HOST}

# Tailscale container auth (only used on first start; state persists in Docker volume)
TS_AUTHKEY=${TS_AUTHKEY}

TZ=Europe/Berlin
EOF
chmod 600 "${SCRIPT_DIR}/.env"
ok ".env written (mode 600)"

log "Writing service configs..."
cp "${SCRIPT_DIR}/config/shairport-sync.conf.tpl" "${SCRIPT_DIR}/config/shairport-sync.conf" \
  2>/dev/null || true
sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g"  "${SCRIPT_DIR}/config/shairport-sync.conf"
sed -i "s|__AUDIO_DEVICE__|${AUDIO_DEVICE}|g" "${SCRIPT_DIR}/config/shairport-sync.conf"

sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g"  "${SCRIPT_DIR}/config/spotifyd.conf"
sed -i "s|__AUDIO_DEVICE__|${AUDIO_DEVICE}|g" "${SCRIPT_DIR}/config/spotifyd.conf"
if [[ -n "${SPOTIFY_USER}" ]]; then
  sed -i "s|__SPOTIFY_USER__|${SPOTIFY_USER}|g" "${SCRIPT_DIR}/config/spotifyd.conf"
  sed -i "s|__SPOTIFY_PASS__|${SPOTIFY_PASS}|g" "${SCRIPT_DIR}/config/spotifyd.conf"
  ok "Spotifyd: credentials written"
else
  warn "Spotifyd: no Spotify credentials — edit config/spotifyd.conf later"
fi

sed -i "s|__AUDIO_DEVICE__|${AUDIO_DEVICE}|g" "${SCRIPT_DIR}/config/mpd.conf"
ok "Config files ready"

log "Creating systemd service: music-potato.service ..."
cat > /etc/systemd/system/music-potato.service << EOF
[Unit]
Description=Le Potato Audio Stack (Docker Compose)
Documentation=file://${SCRIPT_DIR}/SOUND-GUIDE.md
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${SCRIPT_DIR}
ExecStartPre=-/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable music-potato.service
ok "music-potato.service enabled — starts on every boot"

log "Pulling Docker images (first run: a few minutes)..."
cd "${SCRIPT_DIR}"
docker compose pull --quiet
ok "Images pulled"

log "Starting Docker Compose stack..."
docker compose up -d
ok "Stack started"

# ─── Phase 13: Verify ─────────────────────────────────────────────────────────
echo ""
sleep 6

echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Service Check${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"

for svc in shairport-sync mpd upmpdcli spotifyd tailscale-music-potato snapcast-client; do
  if docker inspect --format '{{.State.Running}}' "$svc" 2>/dev/null | grep -q true; then
    ok "Docker › $svc"
  else
    warn "Docker › $svc NOT running — check: docker logs $svc"
  fi
done

for svc in docker bluetooth NetworkManager tailscaled avahi-daemon; do
  systemctl is-active --quiet "$svc" 2>/dev/null \
    && ok "System › $svc" \
    || warn "System › $svc NOT running"
done

mountpoint -q /mnt/music \
  && ok "NFS   › /mnt/music ($(ls /mnt/music | wc -l) items)" \
  || warn "NFS   › /mnt/music not mounted yet (auto-mounts on first MPD access)"

# ─── Summary ──────────────────────────────────────────────────────────────────
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
TS_IP="$(tailscale ip 2>/dev/null | head -1 || echo 'not connected')"

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  music-potato is ready!${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  AirPlay 2        → '${DEVICE_NAME}' in iOS Control Center / Apple Music"
echo "  Spotify Connect  → '${DEVICE_NAME}' in Spotify app → Devices"
echo "  UPnP/DLNA        → '${DEVICE_NAME}' in BubbleUPnP / Foobar2000"
echo "  Bluetooth        → pair '${DEVICE_NAME}' from any device"
echo "  MPD (LAN)        → ${LAN_IP}:6600"
echo "  Navidrome        → ${NAVIDROME_URL}"
echo "  Tailscale IP     → ${TS_IP}"
echo "  Music library    → /mnt/music (NFS from ${HOMELAB_IP})"
echo ""
echo "  Auto-restart on boot:"
echo "    WiFi           → YES (NetworkManager auto-connect '${WIFI_SSID}')"
echo "    Audio stack    → YES (music-potato.service → docker compose up -d)"
echo "    NFS music      → YES (x-systemd.automount on first MPD access)"
echo "    Tailscale      → YES (tailscaled system service)"
echo ""
echo "  Unplug → plug back in → all services come back in ~30 seconds."
echo ""
echo "  Useful commands:"
echo "    docker compose -f ${SCRIPT_DIR}/docker-compose.yml logs -f"
echo "    docker compose -f ${SCRIPT_DIR}/docker-compose.yml restart <service>"
echo "    mpc -h ${LAN_IP} status"
echo "    aplay -l                              # list audio devices"
echo "    tailscale status"
echo ""
echo "  Re-run to update config:  sudo ${SCRIPT_DIR}/setup.sh"
echo ""
