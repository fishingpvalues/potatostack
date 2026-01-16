# DroidyPaste Setup Guide

DroidyPaste is an Android client for RustyPaste that allows easy file sharing from your phone.

## Prerequisites

- RustyPaste server running (included in stack on port 8787)
- Android device on same LAN as your PotatoStack host
- DroidyPaste app installed from F-Droid or GitHub

## Installation

### Option 1: F-Droid (Recommended)
1. Install F-Droid from f-droid.org
2. Search for "DroidyPaste"
3. Install

### Option 2: GitHub
1. Go to github.com/orhun/droidypaste/releases
2. Download latest APK
3. Install (enable "Install from unknown sources")

## Configuration

### Step 1: Open DroidyPaste Settings

1. Open DroidyPaste app
2. Tap menu (⋮) → Settings
3. Go to "Server Settings"

### Step 2: Add RustyPaste Server

**Server URL**: `http://HOST_BIND:8787`

Replace `HOST_BIND` with your actual HOST_BIND IP.

**Optional Settings**:
- **Enable authentication**: Leave OFF (RustyPaste doesn't require auth)
- **Default expiry**: 7d (files auto-delete after 7 days)
- **Custom URL**: Leave empty for random URLs

### Step 3: Test Connection

1. Tap "Test Connection"
2. Should show "✓ Server reachable"

If fails:
```bash
# On the PotatoStack host, check if rustypaste is running
docker ps | grep rustypaste
curl http://HOST_BIND:8787
```

## Usage

### Share File from Gallery

1. Open Gallery
2. Select photo/video
3. Tap Share → DroidyPaste
4. URL copied to clipboard automatically
5. Share URL via messaging apps

### Share from File Manager

1. Open file manager
2. Long-press file → Share
3. Select DroidyPaste
4. URL copied to clipboard

### Share Text/Clipboard

1. Copy text to clipboard
2. Open DroidyPaste
3. Tap "Paste from Clipboard"
4. Tap "Upload"
5. URL copied automatically

### Take Photo and Share

1. Open DroidyPaste
2. Tap camera icon
3. Take photo
4. Tap "Upload"
5. Share generated URL

## Advanced Configuration

### Set Default Expiry Time

In DroidyPaste settings:
- **1 hour**: `1h`
- **1 day**: `1d`
- **7 days**: `7d` (recommended)
- **Never**: Leave empty

### Custom URLs (Naming)

Instead of random URLs like `http://HOST_BIND:8787/a3Kf9s.jpg`, use custom names:

1. In DroidyPaste settings, enable "Ask for custom URL"
2. When uploading, app will prompt for name
3. Example: `vacation-photo` → `http://HOST_BIND:8787/vacation-photo.jpg`

### Automatic Upload on Capture

Enable "Auto-upload after capture":
1. Settings → Behavior
2. Enable "Auto-upload after capture"
3. Photos uploaded immediately after taking

## HTTPS Setup (Recommended)

For secure uploads, set up HTTPS (see HTTPS_CERTIFICATE_SOLUTION.md):

1. Add Caddy reverse proxy with Let's Encrypt
2. Get domain (e.g., paste.yourdomain.com)
3. Update DroidyPaste server URL: `https://paste.yourdomain.com`

**Benefits**:
- Encrypted uploads
- Works outside home network (if configured)
- No certificate warnings

## Troubleshooting

### "Connection refused"

**Check server is running**:
```bash
docker ps | grep rustypaste
docker logs rustypaste
```

**Check firewall**:
```bash
# On the PotatoStack host
sudo ufw status
# Should allow port 8787 on LAN
```

**Test manually**:
```bash
# From Android (Termux or browser)
curl http://HOST_BIND:8787
# Should return RustyPaste web interface
```

### "Upload failed"

**Check file size**: Max 50MB (configurable in `config/rustypaste/config.toml`)

**Check storage space**:
```bash
df -h /mnt/storage
```

**Check logs**:
```bash
docker logs rustypaste --tail 50
```

### "Server not found"

**Wrong IP address**: Verify HOST_BIND in `.env` matches your PotatoStack host IP

**Not on same network**: DroidyPaste and the PotatoStack host must be on same LAN

**Check IP**:
```bash
# On the PotatoStack host
ip addr show | grep inet
```

### Uploads work but URLs don't open

**Firewall blocking**: Check router/firewall allows HTTP on port 8787

**Wrong URL format**: DroidyPaste returns full URL like `http://HOST_BIND:8787/abc123.jpg`

## Integration Tips

### Share URLs via Messaging

After upload, DroidyPaste copies URL to clipboard:
1. Open WhatsApp/Telegram/Signal
2. Paste URL (Ctrl+V)
3. Recipient can click to download

### Backup to RustyPaste

Use DroidyPaste as quick backup:
1. Select important documents
2. Share to DroidyPaste with `expire=30d`
3. URLs saved in DroidyPaste history
4. Files also backed up by Kopia

### Quick Screenshots

1. Take screenshot (Power + Volume Down)
2. Share notification → DroidyPaste
3. URL copied automatically
4. Paste in chat/forum/email

## Privacy & Security

### LAN-Only Access

By default, RustyPaste only accessible on LAN:
- ✅ Safe from internet exposure
- ✅ Fast uploads (local network speed)
- ❌ Can't share with people outside LAN

To share outside LAN, see "HTTPS Setup" above.

### No Authentication

RustyPaste has no built-in authentication:
- Anyone on LAN can upload
- Anyone with URL can download
- URLs are random (hard to guess)

**For sensitive files**: Use Vaultwarden secure notes instead.

### File Cleanup

Files with expiry auto-delete:
- Cleanup runs every 4 hours
- Expired files removed automatically
- Check settings in `config/rustypaste/config.toml`

### Storage Location

Files stored at `/mnt/storage/rustypaste/uploads/`:
- Included in Kopia backups
- Accessible via FileBrowser at `http://HOST_BIND:8181`
- Can manually delete via FileBrowser

## Comparison: DroidyPaste vs Alternatives

| Feature | DroidyPaste | Snapdrop | KDE Connect |
|---------|-------------|----------|-------------|
| Self-hosted | ✅ | ✅ | ❌ (P2P) |
| Android app | ✅ | ❌ (browser) | ✅ |
| URL sharing | ✅ | ❌ | ❌ |
| Auto-expire | ✅ | ❌ | N/A |
| RAM usage | ~10MB | ~30MB | ~50MB |
| Setup complexity | Easy | Medium | Hard |

## Resources

- **DroidyPaste GitHub**: github.com/orhun/droidypaste
- **RustyPaste Docs**: github.com/orhun/rustypaste
- **F-Droid Page**: f-droid.org/packages/app.droidypaste
- **Local docs**: See RUSTYPASTE_USAGE.md

## Example Workflow

**Daily use case**:

1. Take photo of receipt
2. Share → DroidyPaste (uploads in 2-3 seconds)
3. URL copied automatically
4. Paste in expense tracking app notes
5. File auto-deletes after 7 days
6. Receipt also in Kopia backups

**No more**:
- ❌ USB cable transfers
- ❌ Email attachments to yourself
- ❌ Cloud upload wait times
- ❌ Privacy concerns with Google Photos
