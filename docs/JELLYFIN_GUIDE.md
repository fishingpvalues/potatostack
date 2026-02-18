# Jellyfin Guide

## 1. Initial Web Setup

Go to `http://192.168.178.158:8096` from any browser on your LAN.

1. Create your admin account (username + password)
2. **Skip** adding media libraries for now (do it properly in step 2)
3. Finish the wizard

---

## 2. Add Media Libraries

**Dashboard → Libraries → + Add Media Library** for each:

| Library Type | Name | Folder(s) |
|---|---|---|
| Shows | TV Shows | `/data/tvshows` + `/data/tvshows2` |
| Movies | Movies | `/data/movies` + `/data/movies2` |
| Music | Music | `/data/music` |
| Books | Audiobooks | `/data/audiobooks` |

For TV/Movies, add **both folders to one library** — click `+` next to the folder field to add a second path.

- **Metadata language:** English
- **Enable real-time monitoring:** ON

---

## 3. Hardware Acceleration (Intel N150 QSV)

Verified via `vainfo` — supported profiles confirmed before setting these.

**Dashboard → Playback → Transcoding:**

| Setting | Value |
|---|---|
| Hardware acceleration | Intel QuickSync (QSV) |
| QSV device | `/dev/dri/renderD128` |
| Hardware decoding: H264 | ON |
| Hardware decoding: HEVC | ON |
| Hardware decoding: HEVC 10bit | ON |
| Hardware decoding: MPEG2 | ON |
| Hardware decoding: VC1 | ON |
| Hardware decoding: VP8 | ON |
| Hardware decoding: VP9 | ON |
| Hardware decoding: AV1 | ON (decode only — N150 has no AV1 encoder) |
| Enable hardware encoding | ON |
| Intel Low-Power encoder H264 | ON (EncSliceLP confirmed) |
| Intel Low-Power encoder HEVC | ON (EncSliceLP confirmed) |
| Allow HEVC encoding | ON |
| Allow AV1 encoding | OFF (not supported on N150) |
| VPP Tone-Mapping | ON (iHD driver Gen 12 supports it, HDR10 → SDR) |
| Tone-Mapping | ON (fallback for unsupported cases) |
| Transcoding temp path | `/transcode` (tmpfs, 2GB, already configured) |
| Throttle transcoding | ON |
| Delete segments | ON |

Save — Jellyfin validates the device. Check logs if playback fails (`docker logs jellyfin`).

---

## 4. Android TV App

Install **Jellyfin for Android TV** from the Play Store.

**LAN (fast, recommended for home):**

1. Open app → **Add Server**
2. Address: `http://192.168.178.158:8096`
3. Log in with your admin account

The TV may auto-discover Jellyfin via SSDP on boot — same server.

**Away from home (Tailscale):**

1. Install Tailscale on the TV, join the tailnet
2. Address: `https://potatostack.tale-iwato.ts.net:8096`

---

## 5. Recommended Settings

**Dashboard → Networking:**
- LAN networks: `192.168.178.0/24` — prevents bitrate throttling on local streams

**Dashboard → Users → your user → Preferences:**
- Max streaming bitrate: **Auto**
- Home sections: Latest Movies, Next Up, Continue Watching

**Dashboard → Playback:**
- Audio: pass through DTS/AC3/EAC3 if your TV/receiver supports it, otherwise transcode to AAC

---

## 6. First Scan

After adding libraries: **Dashboard → Libraries → Scan All Libraries**

Takes minutes to hours depending on library size. Progress shown at the bell icon.

---

## Quick Reference

| | Address |
|---|---|
| Web UI (LAN) | `http://192.168.178.158:8096` |
| Web UI (Tailscale) | `https://potatostack.tale-iwato.ts.net:8096` |
| Android TV | `http://192.168.178.158:8096` |
| Media folders | `/data/tvshows`, `/data/tvshows2`, `/data/movies`, `/data/movies2` |
