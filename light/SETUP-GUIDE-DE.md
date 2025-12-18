# PotatoStack Light - Produktions-Setup

Enterprise-Grade Setup mit 100% Uptime Fokus.

## Was wurde eingerichtet

### ✅ Eine Festplatte Architektur
- Alle Daten auf `/mnt/storage` (Haupt-HDD)
- Zweite Festplatte `/mnt/backup` für nächtliche Backups
- Kein Cache-Drive mehr nötig

### ✅ Automatische Backups
- Jede Nacht um 3:00 Uhr Backup auf zweite Festplatte
- Inkrementelle Backups mit rsync
- 7 Tage Aufbewahrung
- Spart Speicherplatz durch Hard Links

### ✅ Homepage Dashboard
- Zentrale Übersicht aller Services
- Live Status aller Container
- Widgets für alle Dienste
- Zugriff: `http://DEINE_IP:3000`

### ✅ Automatische Updates
- **Watchtower** aktualisiert Container täglich um 3 Uhr
- Rollende Updates (minimale Downtime)
- Alte Images werden automatisch gelöscht

### ✅ Self-Healing
- **Autoheal** überwacht Container-Gesundheit
- Automatischer Neustart bei Fehlern
- Checks alle 30 Sekunden

### ✅ 100% Uptime Maßnahmen
- Alle Container mit `restart: always`
- Überlebt Netzwerk-Disconnects
- Überlebt FritzBox-Neustarts
- Docker-Daemon Recovery (alle 10 Minuten)
- Health-Monitoring (alle 5 Minuten)

### ✅ Sicherheit
- Starke Auto-generierte Passwörter (32 Zeichen)
- Nur LAN-Zugriff
- VPN-Killswitch für P2P
- Sichere Backup-Verschlüsselung

## Schnellstart

### 1. Festplatten mounten

```bash
# UUIDs finden
sudo blkid

# /etc/fstab bearbeiten
sudo nano /etc/fstab

# Hinzufügen (UUIDs ersetzen):
UUID=deine-haupt-uuid /mnt/storage ext4 defaults,nofail 0 2
UUID=deine-backup-uuid /mnt/backup ext4 defaults,nofail 0 2

# Mounten
sudo mkdir -p /mnt/storage /mnt/backup
sudo mount -a
```

### 2. Ein-Kommando-Setup

```bash
cd light
chmod +x quick-start-production.sh
sudo ./quick-start-production.sh
```

Das war's! Der Script macht alles:
- ✅ Verzeichnisse erstellen
- ✅ Sichere Passwörter generieren
- ✅ Cron-Jobs einrichten
- ✅ Container starten
- ✅ Homepage konfigurieren

### 3. Zugriff

Nach dem Setup öffne: `http://DEINE_IP:3000`

## Wichtige Funktionen

### Automatische Updates

Watchtower prüft täglich um 3 Uhr morgens auf Updates:
- ✅ Automatischer Download neuer Images
- ✅ Rollender Restart (ein Container nach dem anderen)
- ✅ Bei Fehler: alter Container bleibt
- ✅ Alte Images werden gelöscht

**Manuell updaten:**
```bash
docker compose -f docker-compose.production.yml --env-file .env.production pull
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

### Nightly Backups

Jede Nacht um 3 Uhr:
- ✅ Vollständiges Backup auf zweite Festplatte
- ✅ Nur geänderte Dateien werden kopiert
- ✅ Hard Links sparen bis zu 95% Speicherplatz
- ✅ 7 Tage Historie

**Backup-Logs ansehen:**
```bash
tail -f /var/log/potatostack/backup-$(date +%Y-%m-%d).log
```

**Manuelles Backup:**
```bash
sudo /pfad/zu/backup-to-second-disk.sh
```

### Self-Healing

Autoheal überwacht alle Container:
- ✅ Prüft Gesundheit alle 30 Sekunden
- ✅ Automatischer Restart bei Fehlern
- ✅ 5 Minuten Grace Period beim Start

**Ungesunde Container finden:**
```bash
docker ps --filter "health=unhealthy"
```

### Netzwerk-Resilienz

Alle Container überleben:
- ✅ FritzBox-Neustarts
- ✅ Internet-Reconnects
- ✅ Netzwerk-Disconnects
- ✅ Docker-Daemon-Restarts

**Wie?**
- `restart: always` auf allen Containern
- Custom Bridge Network mit statischer Subnet
- Cron-Job überwacht Docker-Daemon
- Bei Problemen: Automatischer Neustart

## Services

| Service | URL | Beschreibung |
|---------|-----|--------------|
| **Homepage** | http://IP:3000 | Zentrale Übersicht |
| Portainer | https://IP:9443 | Container-Verwaltung |
| Vaultwarden | http://IP:8080 | Passwort-Manager |
| Immich | http://IP:2283 | Foto-Verwaltung |
| Seafile | http://IP:8082 | File Sync & Share |
| Kopia | https://IP:51515 | Backup-Server |
| Transmission | http://IP:9091 | Torrent-Client |
| slskd | http://IP:2234 | Soulseek P2P |
| Rustypaste | http://IP:8001 | Pastebin |

## Wartung

### Status prüfen

```bash
# Alle Container
docker ps

# Logs ansehen
docker compose -f docker-compose.production.yml logs -f

# Einzelner Service
docker logs -f CONTAINER_NAME
```

### Backups prüfen

```bash
# Backups auflisten
ls -lh /mnt/backup/

# Backup-Speicher
df -h /mnt/backup

# Letztes Backup
ls -lh /mnt/backup/latest
```

### Cron-Jobs prüfen

```bash
# Jobs anzeigen
crontab -l

# Logs
tail -f /var/log/potatostack/backup-cron.log
tail -f /var/log/potatostack/docker-prune.log
tail -f /var/log/potatostack/health-check.log
```

## Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker logs CONTAINER_NAME

# Neustart
docker restart CONTAINER_NAME

# Stack neu starten
docker compose -f docker-compose.production.yml restart
```

### Backup fehlgeschlagen

```bash
# Log prüfen
tail -100 /var/log/potatostack/backup-$(date +%Y-%m-%d).log

# Speicher prüfen
df -h /mnt/storage /mnt/backup

# Manuell ausführen
sudo ./backup-to-second-disk.sh
```

### FritzBox neu gestartet

Alle Container sollten automatisch neu starten. Falls nicht:

```bash
# Status prüfen
docker ps -a

# Stack neu starten
docker compose -f docker-compose.production.yml restart
```

### Updates funktionieren nicht

```bash
# Watchtower Logs
docker logs watchtower

# Manuell updaten
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d
```

## Disaster Recovery

### Von Backup wiederherstellen

```bash
# Stack stoppen
docker compose -f docker-compose.production.yml down

# Vom Backup wiederherstellen
sudo rsync -aHAXxv /mnt/backup/latest/ /mnt/storage/

# Stack starten
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

## Zusammenfassung

✅ **Eine Festplatte** - Alle Daten auf /mnt/storage
✅ **Nightly Backups** - Automatisch auf zweite Festplatte
✅ **Homepage Dashboard** - Zentrale Übersicht aller Services
✅ **Auto-Updates** - Täglich um 3 Uhr mit Watchtower
✅ **Self-Healing** - Automatische Container-Recovery
✅ **100% Uptime** - Überlebt Netzwerk-Probleme und Reboots
✅ **Sichere Passwörter** - Auto-generiert, 32 Zeichen
✅ **FritzBox-Resilient** - Kein Problem bei Internet-Reconnects
✅ **Enterprise-Grade** - Monitoring, Logging, Recovery

## Nächste Schritte

1. **Passwörter sichern** - Aus .env.production in Password Manager
2. **Homepage öffnen** - http://DEINE_IP:3000
3. **Portainer einrichten** - Passwort beim ersten Login setzen
4. **Backup testen** - `sudo ./backup-to-second-disk.sh`
5. **API-Keys setzen** - Für Homepage Widgets (Immich, Portainer)

## Hilfe

- 📋 Vollständige Doku: `README.production.md`
- 📊 Logs: `/var/log/potatostack/`
- 🐳 Container Logs: `docker logs CONTAINER_NAME`

**Viel Erfolg mit deinem PotatoStack! 🥔**
