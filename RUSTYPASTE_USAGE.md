# RustyPaste Usage Guide

RustyPaste is a minimal file sharing and pastebin server running on port **8787**.

## Access

- **Web Interface**: http://HOST_BIND:8787
- **CLI Upload**: See examples below
- **Storage**: Files stored in `/mnt/storage/rustypaste/uploads/`

## Configuration

- **Max Upload Size**: 50MB
- **Workers**: 1 (low-resource default)
- **Auto-Cleanup**: Every 4 hours (expired files only)
- **URL Length**: 6 characters (alphanumeric)
- **Memory Limit**: 64MB

## Upload Examples

### Upload a text file:
```bash
curl -F "file=@document.txt" http://HOST_BIND:8787
# Returns: http://HOST_BIND:8787/a3Kf9s.txt
```

### Upload from clipboard/stdin:
```bash
echo "Hello from PotatoStack" | curl -F "file=@-" http://HOST_BIND:8787
# Returns: http://HOST_BIND:8787/b7Jk2p.txt
```

### Upload with custom URL:
```bash
curl -F "file=@report.pdf" -F "url=monthly-report" http://HOST_BIND:8787
# Returns: http://HOST_BIND:8787/monthly-report.pdf
```

### Upload with expiry (1 hour):
```bash
curl -F "file=@secret.txt" -F "expire=1h" http://HOST_BIND:8787
# File will auto-delete after 1 hour
```

### Upload with expiry (1 day):
```bash
curl -F "file=@temp.jpg" -F "expire=1d" http://HOST_BIND:8787
# File will auto-delete after 1 day
```

### Upload with expiry (7 days):
```bash
curl -F "file=@backup.zip" -F "expire=7d" http://HOST_BIND:8787
# File will auto-delete after 7 days
```

## Expiry Options

| Unit | Description |
|------|-------------|
| `s` | Seconds |
| `m` | Minutes |
| `h` | Hours |
| `d` | Days |

Examples: `30s`, `15m`, `2h`, `7d`

## Advanced Usage

### Upload multiple files:
```bash
for file in *.txt; do
    url=$(curl -s -F "file=@$file" http://HOST_BIND:8787)
    echo "$file -> $url"
done
```

### Upload screenshot from clipboard (Linux):
```bash
xclip -selection clipboard -t image/png -o | \
  curl -F "file=@-;filename=screenshot.png" http://HOST_BIND:8787
```

### Download a shared file:
```bash
curl http://HOST_BIND:8787/a3Kf9s.txt
# Or open in browser
```

## Integration with Other Tools

### ShareX (Windows)
Custom uploader configuration:
```json
{
  "Name": "PotatoStack RustyPaste",
  "DestinationType": "ImageUploader, FileUploader",
  "RequestURL": "http://HOST_BIND:8787",
  "FileFormName": "file",
  "URL": "$response$"
}
```

### macOS Shortcut
Create an Automator Quick Action:
```bash
curl -F "file=@$1" http://HOST_BIND:8787 | pbcopy
```

## Monitoring

### Check container status:
```bash
docker ps | grep rustypaste
docker logs rustypaste
```

### Check disk usage:
```bash
du -sh /mnt/storage/rustypaste/
ls -lh /mnt/storage/rustypaste/uploads/
```

### Check memory usage:
```bash
docker stats rustypaste --no-stream
```

## Troubleshooting

### Upload fails with "413 Request Entity Too Large"
Max upload size is 50MB. Increase in `config/rustypaste/config.toml`:
```toml
max_content_length = "100MB"
```
Then restart: `docker compose restart rustypaste`

### Files not cleaning up
Check cleanup configuration in `config/rustypaste/config.toml`:
```toml
[paste]
delete_expired_files.enabled = true
delete_expired_files.interval = "4h"
```

### Container keeps restarting
Check logs: `docker logs rustypaste`
Likely a configuration syntax error in `config/rustypaste/config.toml`

## Security Notes

- **LAN Access Only**: Service binds to `HOST_BIND` IP, not exposed to internet
- **No Authentication**: Anyone on LAN can upload (consider using firewall rules if needed)
- **File Persistence**: Files stored on main HDD at `/mnt/storage/rustypaste/`
- **Auto-Cleanup**: Expired files deleted automatically every 4 hours
- **Backups**: Rustypaste folder included in Kopia backups

## Homepage Integration

RustyPaste appears in the Homepage dashboard under "Media & Storage" section with real-time container status.
