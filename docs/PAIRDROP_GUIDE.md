# PairDrop Android App Guide

## Overview

PairDrop is a local-first, peer-to-peer file sharing solution that allows seamless file transfer between devices without uploading to any cloud server.

### Key Features

- ✅ **P2P Transfer**: Direct device-to-device via WebRTC (no server storage)
- ✅ **No File Size Limits**: Transfer files of any size
- ✅ **End-to-End Encrypted**: Secure WebRTC connections
- ✅ **Offline Support**: Works on same LAN without internet
- ✅ **Cross-Platform**: Web browser + Android app + iOS
- ✅ **Remote Access**: Works via Tailscale VPN
- ✅ **Zero Config**: No signup, no account required

### How It Works

```
┌─────────────┐              ┌─────────────┐
│   Device A  │ ──WebRTC───▶ │   Device B  │
│ (Android)   │   Direct     │  (Desktop)  │
└─────────────┘   P2P Link   └─────────────┘
       │                            │
       └────────────────────────────┘
              │
              ▼
        ┌──────────────┐
        │  PairDrop    │
        │  (Signaling) │
        │   PotatoStack │
        └──────────────┘
```

PairDrop acts as a signaling server that establishes the initial connection, then files transfer directly between devices using WebRTC. **No files are stored on the server.**

## Access

### Primary Access (Tailscale HTTPS - Recommended)

```
https://potatostack.tale-iwato.ts.net:3013
```

- ✅ Secure TLS certificates via Tailscale
- ✅ Works from anywhere (home, office, mobile data)
- ✅ End-to-end encryption
- ✅ Works with all devices on your Tailscale network

### Secondary Access (Local LAN)

```
http://192.168.178.158:3013
```

- ✅ Works on same WiFi network
- ✅ Faster for large files (no VPN overhead)
- ⚠️ Not encrypted (use HTTPS for sensitive files)

### Container Status Check

```bash
# Check if PairDrop is running
docker ps | grep pairdrop

# View logs
docker logs pairdrop -f

# Restart if needed
docker compose restart pairdrop
```

## Android App Setup

### Installation

#### Option 1: Google Play Store

1. Open Play Store
2. Search for "PairDrop"
3. Install the official PairDrop app

#### Option 2: F-Droid

1. Open F-Droid app
2. Search for "PairDrop"
3. Install (fully open-source version)

### Configure PairDrop Instance

#### Method 1: Use Public PairDrop (Default)

The app works out-of-the-box with the public PairDrop server:
- No configuration needed
- Files transfer P2P (not stored on server)
- Works with anyone on public server

#### Method 2: Connect to Your PotatoStack Instance

For privacy and security, configure your own PairDrop server:

1. **Open PairDrop App**

2. **Go to Settings**
   - Tap the menu icon (three dots)
   - Select "Settings"

3. **Configure Server URL**
   - Find "Custom Server" or "Server URL" option
   - Enter your Tailscale URL:
     ```
     https://potatostack.tale-iwato.ts.net:3013
     ```
   - Save settings

4. **Test Connection**
   - App should connect to your PairDrop instance
   - You'll see a clean interface with your device name

### Verify Connection

After connecting to your PotatoStack instance:

1. Open PairDrop app on Android
2. On desktop browser, open: `https://potatostack.tale-iwato.ts.net:3013`
3. Both devices should appear on each other's screens
4. Device names show as: "Android (Device Name)" and "Desktop (Browser)"

## Using PairDrop

### Web Interface (Desktop Browser)

1. **Open PairDrop**
   ```
   https://potatostack.tale-iwato.ts.net:3013
   ```

2. **Devices Appear Automatically**
   - All devices on same network or Tailscale network show up
   - Your device appears as "This Device"

3. **Send Files**
   - Click on the target device
   - Select files to transfer
   - Files transfer directly (P2P)

4. **Send Text**
   - Click target device
   - Type message and send
   - Useful for sharing links, passwords, codes

5. **Send Folder** (Chrome only)
   - Drag and drop folder onto target device
   - Entire folder transfers in one go

### Android App

#### Sending Files from Android

1. **Open PairDrop App**
   - Ensure connected to your server instance

2. **Select Files**
   - Tap the "+" or "Send" button
   - Choose files from Gallery, Downloads, or file manager
   - Select multiple files if needed

3. **Choose Recipient**
   - List of available devices appears
   - Tap destination device
   - Files start transferring immediately

4. **Send Photos/Videos**
   - From Gallery app:
     - Open Gallery
     - Select photos/videos
     - Tap Share → PairDrop
   - Direct integration with Android share menu

#### Receiving Files on Android

1. **Accept Incoming Transfer**
   - Notification appears when someone sends files
   - Tap notification or open PairDrop app
   - See incoming transfer request

2. **Choose Save Location**
   - Files save to: `/Internal Storage/Download/PairDrop/`
   - Change location in app settings if needed

3. **Automatic Accept**
   - Enable "Auto-accept files" in settings
   - Useful for trusted devices (your desktop)

#### Sharing from Other Apps

PairDrop integrates with Android's share menu:

1. **In Any App** (Gallery, File Manager, Chrome)
2. **Tap Share Button**
3. **Select PairDrop** from share menu
4. **Choose Destination Device**

Works seamlessly with:
- Photos from Gallery
- Files from Downloads
- Documents from Office apps
- Links from Chrome

### Multi-Device Scenarios

#### Scenario 1: Android ↔ Desktop

**Send photos from Android to Desktop:**
1. Open PairDrop app on Android
2. Select photos from Gallery → Share → PairDrop
3. Choose "Desktop (Browser)" as recipient
4. Files appear in Desktop browser download folder

**Send documents from Desktop to Android:**
1. Open PairDrop in desktop browser
2. Click on Android device name
3. Select files from desktop
4. Accept transfer on Android

#### Scenario 2: Android ↔ Android

**Between two Android phones:**
1. Install PairDrop on both phones
2. Connect both to your server (or public server)
3. Both devices appear on each other's screens
4. Send files directly P2P

**Use Cases:**
- Transfer photos between family phones
- Share APK files without Google Play
- Large videos (no MMS limit)

#### Scenario 3: Desktop ↔ Desktop

**Between two laptops:**
1. Open PairDrop in browser on both
2. Devices auto-discover on same LAN
3. Click device to send files
4. Direct P2P transfer (no cloud)

**Remote Access via Tailscale:**
- Both laptops connect to Tailscale
- Both open: `https://potatostack.tale-iwato.ts.net:3013`
- Devices discover each other via Tailscale network
- Transfer files even when on different WiFi networks

### File Types Supported

- ✅ **Photos**: JPG, PNG, HEIC, RAW
- ✅ **Videos**: MP4, MOV, MKV, AVI
- ✅ **Documents**: PDF, DOCX, XLSX, PPTX
- ✅ **Archives**: ZIP, RAR, 7Z, TAR
- ✅ **Audio**: MP3, FLAC, AAC, WAV
- ✅ **Code**: Any source code files
- ✅ **Folders**: Chrome/Edge only (drag & drop)

### Transfer Speeds

| Connection Type | Expected Speed | Use Case |
|---------------|----------------|----------|
| Same WiFi (LAN) | 50-200 MB/s | Large files locally |
| Tailscale (LAN) | 30-100 MB/s | Secure local transfers |
| Tailscale (Remote) | 5-20 MB/s | Away from home |
| Public Server | 1-10 MB/s | With strangers |

**Factors affecting speed:**
- Network bandwidth (WiFi vs mobile data)
- WiFi signal strength
- VPN overhead (Tailscale)
- Device processing power
- File size (larger files = better sustained throughput)

## Features

### Core Features

- **P2P Transfer**: Files transfer directly between devices
- **No Server Storage**: PairDrop never stores your files
- **WebRTC**: Modern, secure P2P protocol
- **Auto-Discovery**: Devices appear automatically on network
- **No Size Limits**: Transfer multi-GB files
- **No Account Required**: Privacy-first design
- **End-to-End Encrypted**: Secure WebRTC connections
- **Works Offline**: No internet needed if devices are on same LAN

### Advanced Features

#### Text Sharing

Send text snippets, links, codes:

1. Click target device
2. Type message
3. Send
4. Appears as text message on recipient

**Use Cases:**
- Share WiFi passwords
- Send login codes
- Share URLs (no bit.ly needed)
- Quick notes between devices

#### QR Code

PairDrop can generate QR codes:

1. Click "Send"
2. Select "QR Code" option
3. Scan with other device's camera
4. Opens PairDrop on recipient device

**Use Cases:**
- Onboard new users quickly
- No need to type server URL
- Great for temporary access

#### Room Mode

Create private rooms for specific transfers:

1. Click room name (e.g., "blue-antelope")
2. Change to custom room name
3. Share room name with recipient
4. Only devices in same room see each other

**Use Cases:**
- Private transfers in public spaces
- Multiple users in same building
- Avoid mixing up devices

## Troubleshooting

### Device Not Showing

**Problem: Target device doesn't appear in PairDrop**

**Solution:**

1. **Check Network Connection**
   - Ensure both devices have internet (for public server)
   - Or both on same WiFi (for LAN discovery)
   - Or both connected to Tailscale (for remote access)

2. **Verify Same Server**
   - Android app: Check Settings → Server URL
   - Desktop browser: Check address bar
   - Both must connect to same PairDrop instance

3. **Refresh PairDrop**
   - On Android: Pull down to refresh
   - On Desktop: Refresh browser (F5)

4. **Check Firewall** (Desktop only)
   - Windows: Allow PairDrop in Windows Firewall
   - Linux: Ensure WebRTC ports aren't blocked
   - Disable VPN temporarily to test

5. **Test Tailscale Connection**
   ```bash
   # On server
   docker exec tailscale tailscale status

   # On Android
   Open Tailscale app → Check connection status
   ```

### Connection Refused

**Problem: Can't connect to PairDrop server**

**Solution:**

1. **Check Server URL**
   - Android: Verify `https://potatostack.tale-iwato.ts.net:3013`
   - Ensure HTTPS not HTTP

2. **Restart PairDrop Container**
   ```bash
   docker compose restart pairdrop
   ```

3. **Check Container Status**
   ```bash
   docker ps | grep pairdrop
   # Should show "Up" status
   ```

4. **View Logs**
   ```bash
   docker logs pairdrop --tail 50
   # Look for errors in startup
   ```

5. **Test Direct Access**
   - Open URL in browser: `https://potatostack.tale-iwato.ts.net:3013`
   - Should see PairDrop interface

### File Transfer Fails

**Problem: Transfer starts but fails or stalls**

**Solution:**

1. **Check Network Stability**
   - Ensure stable WiFi connection
   - Avoid switching WiFi networks mid-transfer
   - If mobile data, ensure strong signal

2. **Reduce File Count**
   - Transfer files one at a time
   - Large folders may timeout
   - Zip large folders before sending

3. **Disable VPN Temporarily**
   - Turn off Tailscale on one device
   - Use LAN access instead
   - Faster for large files

4. **Check Available Storage**
   - Android: Settings → Storage
   - Desktop: Check disk space
   - Ensure enough space for incoming files

5. **Restart PairDrop App**
   - Force close Android app
   - Reopen and retry transfer

### Tailscale Connectivity Issues

**Problem: Can't access PairDrop via Tailscale**

**Solution:**

1. **Verify Tailscale Connection**
   ```bash
   # On server
   docker exec tailscale tailscale status
   # Should show your devices listed
   ```

2. **Check HTTPS Wrapping**
   ```bash
   # Verify port 3013 is wrapped with HTTPS
   docker exec tailscale tailscale serve status

   # If not listed, run:
   docker compose restart tailscale-https-monitor
   ```

3. **Test Direct Tailscale IP**
   - Get server IP: `docker exec tailscale tailscale ip -4`
   - Try: `https://<IP>:3013`
   - If works, issue is DNS not HTTPS

4. **Restart Tailscale Container**
   ```bash
   docker compose restart tailscale
   docker compose restart tailscale-https-monitor
   ```

5. **Use MagicDNS (Optional)**
   ```bash
   # Enable on server
   docker exec tailscale tailscale up --accept-dns

   # Then access via hostname:
   https://potatostack:3013
   ```

### Android App Crashes

**Problem: PairDrop app crashes or freezes**

**Solution:**

1. **Clear App Cache**
   - Settings → Apps → PairDrop → Storage
   - Clear Cache
   - Clear Data (if persistent issues)

2. **Reinstall App**
   - Uninstall PairDrop
   - Reinstall from Play Store / F-Droid
   - Reconfigure server URL

3. **Check Android Version**
   - PairDrop requires Android 8.0+ (API 26)
   - Update Android if needed

4. **Report Issue**
   - Check PairDrop GitHub: https://github.com/schlagmichdoch/pairdrop
   - Check for known issues with your device

### Slow Transfer Speeds

**Problem: Files transferring very slowly**

**Solution:**

1. **Use LAN Instead of VPN**
   - Both devices on same WiFi
   - Disable Tailscale temporarily
   - Access via: `http://192.168.178.158:3013`

2. **Check WiFi Signal**
   - Move closer to router
   - Use 5GHz WiFi if available
   - Avoid interference (microwaves, other networks)

3. **Close Other Apps**
   - Background downloads
   - Video streaming
   - Cloud sync (Dropbox, Google Photos)

4. **Restart Router**
   - Fixes routing issues
   - Clears congestion

5. **Use Ethernet** (Desktop)
   - Wired connection = faster speeds
   - More stable than WiFi

## Security Notes

### End-to-End Encryption

PairDrop uses WebRTC for direct P2P transfers:

- ✅ **WebRTC Encryption**: DTLS-SRTP protocol (AES-256)
- ✅ **No Server Storage**: Files never touch PairDrop server
- ✅ **Signaling Only**: Server only establishes initial connection
- ✅ **Peer Verification**: Verify device names before accepting

### Network Isolation

**Your PotatoStack Instance:**
- ✅ **Tailscale Network**: Only your devices can connect
- ✅ **No Public Exposure**: Not accessible from internet
- ✅ **LAN Access**: Devices on same WiFi can connect
- ⚠️ **Public Server**: Anyone can use public PairDrop (but P2P still)

**Best Practices:**
1. Use your PotatoStack instance (not public server) for sensitive files
2. Verify device names before accepting transfers
3. Use HTTPS (Tailscale) for security
4. Enable "Ask before accepting" in Android app settings

### File Privacy

**What PairDrop Does:**
- ✅ Transfers files directly between devices
- ✅ Never stores files on server
- ✅ Encrypts all P2P connections
- ✅ No logging of transfer content

**What PairDrop Doesn't Do:**
- ❌ No cloud storage
- ❌ No file scanning or indexing
- ❌ No user accounts or tracking
- ❌ No access to files after transfer

### Access Control

**Tailscale Access:**
- Only devices in your Tailscale network can connect
- Tailscale provides additional encryption layer
- Manage access via Tailscale admin console

**LAN Access:**
- Anyone on same WiFi network can discover devices
- Verify device names before accepting transfers
- Consider using separate WiFi for sensitive transfers

## Commands

### Container Management

```bash
# Check PairDrop status
docker ps | grep pairdrop

# View logs
docker logs pairdrop -f

# Restart PairDrop
docker compose restart pairdrop

# Stop PairDrop
docker compose stop pairdrop

# Start PairDrop
docker compose start pairdrop

# Update PairDrop to latest
docker compose pull pairdrop
docker compose up -d pairdrop
```

### Tailscale Integration

```bash
# Check Tailscale status
docker exec tailscale tailscale status

# Verify HTTPS wrapping
docker exec tailscale tailscale serve status

# Restart Tailscale HTTPS monitor
docker compose restart tailscale-https-monitor

# Test PairDrop connectivity
curl -I https://potatostack.tale-iwato.ts.net:3013
```

### Storage Management

**Important**: PairDrop is a P2P file transfer tool - files transfer directly between devices via WebRTC. The server does NOT store files. The `/mnt/storage/pairdrop/` directory is mounted but primarily used for temporary WebSocket fallback data if P2P fails.

```bash
# Check PairDrop storage folder (mostly empty)
ls -lh /mnt/storage/pairdrop/

# Check storage usage
du -sh /mnt/storage/pairdrop/

# Files are NOT stored here - they transfer P2P
# This directory is only used for WebSocket fallback if enabled
```

## Comparison with Other File Sharing Tools

| Tool | Storage Method | Size Limit | Remote Access | Encryption | Speed |
|------|---------------|------------|---------------|------------|-------|
| **PairDrop** | P2P (none) | None | ✅ Tailscale | ✅ WebRTC E2EE | Fast |
| **Syncthing** | Local sync | Disk space | ✅ Tailscale | ✅ TLS | Fast |
| **Filebrowser** | Server RW | Disk space | ✅ Tailscale | ✅ Basic | Medium |
| **Telegram** | Cloud | 2GB | ✅ Internet | ❌ Server | Medium |
| **WeTransfer** | Cloud | 2GB | ✅ Internet | ❌ Server | Slow |
| **Bluetooth** | P2P | None | ❌ Local only | ✅ E2EE | Very Slow |

### When to Use PairDrop

- ✅ Quick one-off transfers
- ✅ Sharing with new devices
- ✅ No cloud storage wanted
- ✅ Large files (GBs)
- ✅ Privacy-critical transfers
- ✅ Offline transfers (same LAN)

### When to Use Syncthing

- ✅ Continuous sync between devices
- ✅ Version history needed
- ✅ Automated backup
- ✅ Multiple folders synced

### When to Use Filebrowser

- ✅ Browse files from browser
- ✅ Download specific files
- ✅ Upload files to server
- ✅ File management (rename, move, delete)

## Best Practices

### For Large Files

1. **Use LAN Connection** (not VPN)
2. **Close Other Apps** (bandwidth)
3. **Connect Devices Near Router** (5GHz WiFi)
4. **Transfer One File at a Time**
5. **Zip Multiple Files** (fewer connections)

### For Security

1. **Use Your PotatoStack Instance** (not public server)
2. **Verify Device Names** before accepting
3. **Enable HTTPS** (Tailscale)
4. **Don't Accept Unknown Devices**
5. **Check File Extensions** before opening

### For Privacy

1. **P2P = No Server Storage**
2. **Use Tailscale for Remote Access**
3. **Avoid Public Server for Sensitive Files**
4. **Clear App Cache** periodically
5. **Review Sent Files** in history

## FAQ

### Is PairDrop free?

Yes, PairDrop is 100% free and open-source. The PotatoStack instance runs locally with no subscription fees.

### Does PairDrop work offline?

Yes, if devices are on same WiFi network. PairDrop uses WebRTC which works on LAN without internet.

### Can I transfer folders?

- **Desktop**: Yes (Chrome/Edge drag & drop)
- **Android**: No (must zip folder first)

### Is there a file size limit?

No, file size is unlimited. Only limited by your device storage and network speed.

### Can strangers access my PairDrop?

**Your PotatoStack instance:**
- No, only your Tailscale network or LAN
- Tailscale provides access control

**Public PairDrop server:**
- Yes, but files transfer P2P (not stored)
- Verify device names before accepting
- Use custom room names for privacy

### Can I transfer files between Android and iPhone?

Yes, PairDrop works across all platforms:
- Android app
- iOS web browser (Safari)
- Desktop browsers (Chrome, Firefox, Edge)
- Linux, Windows, Mac

### How fast is PairDrop?

Typical speeds:
- Same WiFi: 50-200 MB/s
- Tailscale (local): 30-100 MB/s
- Tailscale (remote): 5-20 MB/s

Depends on your network and device hardware.

### Does PairDrop keep logs?

No, PairDrop does not log file transfers. It only acts as a signaling server for WebRTC connections.

### Can I use PairDrop with multiple people?

Yes, PairDrop supports multiple devices simultaneously. Great for:
- Family photo sharing
- Office document sharing
- Group projects

### What happens if transfer is interrupted?

PairDrop uses resumable transfers in some cases:
- Pause and resume (desktop)
- Restart transfer from beginning (Android)
- Files never corrupt mid-transfer

---

## Support

### Documentation

- **Official PairDrop**: https://pairdrop.net
- **PairDrop GitHub**: https://github.com/schlagmichdoch/pairdrop
- **PairDrop FAQ**: https://github.com/schlagmichdoch/pairdrop/blob/master/docs/faq.md

### Troubleshooting

1. Check logs: `docker logs pairdrop`
2. Restart container: `docker compose restart pairdrop`
3. Check Tailscale: `docker exec tailscale tailscale status`
4. Review this guide's troubleshooting section

### Report Issues

If you encounter persistent issues:

1. Check PairDrop GitHub for known issues
2. Search existing issues: https://github.com/schlagmichdoch/pairdrop/issues
3. Create new issue with details:
   - Device types (Android version, browser)
   - Network setup (LAN vs Tailscale)
   - Error messages or logs
   - Steps to reproduce

---

**Last Updated**: 2026-02-08

**Your PairDrop Instance**: https://potatostack.tale-iwato.ts.net:3013

**Related Guides**:
- [TAILSCALE_ACCESS.md](TAILSCALE_ACCESS.md) - Tailscale network setup
- [SYNCTHING_PERSISTENCE.md](SYNCTHING_PERSISTENCE.md) - Continuous file sync
- [FILESTASH_GUIDE.md](FILESTASH_GUIDE.md) - Advanced file manager
