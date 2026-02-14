# Connecting Windows PC to PotatoStack

## Prerequisites

- PotatoStack server running with Tailscale
- Tailscale installed on your Windows PC ([download](https://tailscale.com/download/windows))
- Both devices on the same Tailnet

## Credentials

- **Username:** `daniel`
- **Password:** Value of `SAMBA_PASSWORD` in your `.env` file

---

## Method 1: Samba (SMB) via Tailscale — Recommended

SMB gives you a native Windows network drive. It works over the Tailscale IP directly (not via HTTPS serve).

### Step 1: Find the server's Tailscale IP

On the PotatoStack server:

```bash
docker exec tailscale tailscale ip -4
```

Current IP: `100.90.148.77` (may change if Tailscale is re-authenticated).

### Step 2: Connect from Windows

1. Open **File Explorer**
2. In the address bar, type:
   ```
   \\100.x.y.z\storage
   ```
   (Replace `100.x.y.z` with your actual Tailscale IP)
3. When prompted:
   - **Username:** `daniel`
   - **Password:** your `SAMBA_PASSWORD` from `.env`
   - Check **Remember my credentials**

### Step 3: Map as a network drive (optional)

1. Right-click **This PC** → **Map network drive**
2. Pick a drive letter (e.g., `S:`)
3. Folder: `\\100.x.y.z\storage`
4. Check **Reconnect at sign-in**
5. Check **Connect using different credentials**
6. Enter `daniel` / your password

### Available shares

| Share       | Path on server     | Contents                    |
|-------------|--------------------|-----------------------------|
| `storage`   | `/mnt/storage`     | Media, photos, documents    |
| `cachehdd`  | `/mnt/cachehdd`    | Caches, metrics             |
| `media`     | `/mnt/storage/media`| TV, movies, music, audiobooks|

### Troubleshooting SMB

**"Windows cannot access \\..."**

1. Make sure Tailscale is connected on both devices (green icon in system tray)
2. Test connectivity: open PowerShell and run:
   ```powershell
   ping 100.x.y.z
   Test-NetConnection 100.x.y.z -Port 445
   ```
3. If port 445 is blocked, check that the samba container is running:
   ```bash
   docker ps --filter name=samba
   docker logs samba
   ```

**"The specified network password is not correct"**

- The password is `SAMBA_PASSWORD` from `.env`, NOT your Linux user password
- Try prefixing: `.\daniel` as the username (no domain)

**SMB1 vs SMB2/3**

Windows 10+ disables SMB1 by default. The servercontainers/samba image supports SMB2/3, so this should work. If not, check:
```powershell
# Verify SMB2 is enabled (should be True)
Get-SmbServerConfiguration | Select EnableSMB2Protocol
```

**Firewall**

If using Windows Defender Firewall, SMB client is usually allowed. If blocked:
```powershell
# Run as Administrator
Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled True
```

---

## Method 2: Filebrowser (Web UI)

No setup needed — just a browser. Good for quick file access and uploads.

1. Open your browser
2. Go to: `https://potatostack.tale-iwato.ts.net:8086`
3. Log in (default credentials in Filebrowser, check your setup)
4. Browse, upload, download, edit files

Filebrowser shows everything in `/mnt/storage`.

---

## Method 3: Filestash (Web UI + Multi-Protocol)

Filestash supports SFTP, S3, FTP, and more from a browser UI.

1. Open: `https://potatostack.tale-iwato.ts.net:3006`
2. Configure a connection to localhost SFTP or browse local files
3. Use the web interface to manage files

---

## Method 4: SFTP via Tailscale

If SSH is enabled on the PotatoStack server, SFTP works over Tailscale with no extra setup.

### Using WinSCP (recommended SFTP client)

1. Download [WinSCP](https://winscp.net/eng/download.php)
2. New Site:
   - **Protocol:** SFTP
   - **Host:** `100.x.y.z` (Tailscale IP)
   - **Port:** 22
   - **Username:** `daniel`
   - **Password:** your Linux user password (NOT Samba password)
3. Click **Login**

### Using Windows built-in SFTP

```powershell
sftp daniel@100.x.y.z
```

### Using Windows Explorer with SFTP (via SSHFS-Win)

To mount SFTP as a drive letter:

1. Install [WinFsp](https://github.com/winfsp/winfsp/releases) and [SSHFS-Win](https://github.com/winfsp/sshfs-win/releases)
2. Open File Explorer → Map network drive
3. Folder: `\\sshfs\daniel@100.x.y.z\mnt\storage`
4. It mounts as a native Windows drive

---

## Quick Reference

| Method      | URL / Path                           | Protocol | Best For           |
|-------------|--------------------------------------|----------|--------------------|
| Samba       | `\\100.x.y.z\storage`               | SMB      | Native drive mount |
| Filebrowser | `https://potatostack...:8086`        | HTTPS    | Quick web access   |
| Filestash   | `https://potatostack...:3006`        | HTTPS    | Multi-protocol     |
| SFTP        | `sftp://100.x.y.z/mnt/storage`      | SSH      | Secure transfers   |
