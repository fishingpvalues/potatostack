#!/bin/bash
################################################################################
# PotatoStack Light - Complete Setup & Optimization
# All-in-one: directories, env, optimizations, cron, backup, deployment
################################################################################

set -e

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
MAIN_DISK="/mnt/storage"; BACKUP_DISK="/mnt/backup"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║  ██████╗  ██████╗ ████████╗ █████╗ ████████╗ ██████╗ ███████╗   ║
║  ██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗╚══██╔══╝██╔═══██╗██╔════╝   ║
║  ██████╔╝██║   ██║   ██║   ███████║   ██║   ██║   ██║███████╗   ║
║  ██╔═══╝ ██║   ██║   ██║   ██╔══██║   ██║   ██║   ██║╚════██║   ║
║  ██║     ╚██████╔╝   ██║   ██║  ██║   ██║   ╚██████╔╝███████║   ║
║  ╚═╝      ╚═════╝    ╚═╝   ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝   ║
║          Le Potato Complete Setup - SOTA Optimizations           ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# System checks
[[ "$OSTYPE" != "linux-gnu"* ]] && { echo -e "${RED}ERROR: Linux required${NC}"; exit 1; }
command -v docker &>/dev/null || { echo -e "${RED}ERROR: Docker not installed${NC}"; exit 1; }
docker compose version &>/dev/null || { echo -e "${RED}ERROR: Docker Compose unavailable${NC}"; exit 1; }
echo -e "${GREEN}✓ System checks passed${NC}\n"

################################################################################
# STEP 1: Directories
################################################################################
echo -e "${CYAN}═══ Step 1: Directories ═══${NC}\n"
mountpoint -q "$MAIN_DISK" 2>/dev/null || { echo -e "${RED}ERROR: $MAIN_DISK not mounted${NC}"; exit 1; }
echo -e "${GREEN}✓ Main disk: $MAIN_DISK${NC}"
df -h "$MAIN_DISK"
if mountpoint -q "$BACKUP_DISK" 2>/dev/null; then
    echo -e "${GREEN}✓ Backup disk: $BACKUP_DISK${NC}"; df -h "$BACKUP_DISK"
else
    echo -e "${YELLOW}⚠ Backup disk not mounted${NC}"
fi

for DIR in downloads transmission-incomplete slskd-{shared,incomplete} immich/{upload,library,thumbs} seafile kopia/{repository,cache} rustypaste; do
    sudo mkdir -p "$MAIN_DISK/$DIR"
done
sudo chown -R 1000:1000 "$MAIN_DISK"; sudo chmod -R 755 "$MAIN_DISK"
echo -e "${GREEN}✓ Directories created\n${NC}"

################################################################################
# STEP 2: System Optimization
################################################################################
echo -e "${CYAN}═══ Step 2: System Optimization ═══${NC}\n"

# Kernel params
sudo tee /etc/sysctl.d/99-lepotato.conf >/dev/null <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=200
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.overcommit_memory=0
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
EOF
sudo sysctl -p /etc/sysctl.d/99-lepotato.conf >/dev/null
echo -e "${GREEN}✓ Kernel optimized${NC}"

# ZRAM
sudo tee /etc/default/zramswap >/dev/null <<'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF
sudo systemctl enable zramswap 2>/dev/null || true
sudo systemctl restart zramswap 2>/dev/null || true
echo -e "${GREEN}✓ ZRAM configured${NC}"

# HDD swap
SWAP_FILE="$MAIN_DISK/swapfile"
if [ ! -f "$SWAP_FILE" ]; then
    sudo fallocate -l 4G "$SWAP_FILE" 2>/dev/null || sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=4096 status=none
    sudo chmod 600 "$SWAP_FILE"; sudo mkswap "$SWAP_FILE" >/dev/null; sudo swapon "$SWAP_FILE"
    grep -q "$SWAP_FILE" /etc/fstab || echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    echo -e "${GREEN}✓ 4GB swap created${NC}"
fi

# Docker config
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3","compress":"true"},"storage-driver":"overlay2","max-concurrent-downloads":3,"max-concurrent-uploads":3,"live-restore":true,"userland-proxy":false}
EOF
echo -e "${GREEN}✓ Docker optimized${NC}"

# Journal limits
sudo mkdir -p /etc/systemd/journald.conf.d/
sudo tee /etc/systemd/journald.conf.d/00-lepotato.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
EOF
sudo systemctl restart systemd-journald
echo -e "${GREEN}✓ Journal limited${NC}"

# Memory pressure handler
sudo tee /usr/local/bin/memory-pressure.sh >/dev/null <<'EOF'
#!/bin/bash
while true; do
    MEM=$(free|awk '/Mem:/{printf"%.0f",($3/$2)*100}')
    [ "$MEM" -ge 92 ] && { echo "$(date) EMERGENCY $MEM%" >>/var/log/memory-pressure.log; docker restart immich-microservices kopia 2>/dev/null; sleep 10; }
    [ "$MEM" -ge 85 ] && { sync; echo 3|sudo tee /proc/sys/vm/drop_caches>/dev/null; }
    sleep 30
done
EOF
sudo chmod +x /usr/local/bin/memory-pressure.sh

sudo tee /etc/systemd/system/memory-pressure.service >/dev/null <<'EOF'
[Unit]
Description=Memory Pressure Handler
After=docker.service
[Service]
Type=simple
ExecStart=/usr/local/bin/memory-pressure.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload; sudo systemctl enable memory-pressure.service; sudo systemctl restart memory-pressure.service
echo -e "${GREEN}✓ Memory handler active\n${NC}"

################################################################################
# STEP 3: Environment
################################################################################
echo -e "${CYAN}═══ Step 3: Environment ═══${NC}\n"
if [ -f ".env.production" ]; then
    echo -e "${YELLOW}⚠ .env.production exists${NC}"; read -p "Keep? (Y/n): " -n 1 -r; echo
    [[ $REPLY =~ ^[Nn]$ ]] || { echo -e "${GREEN}✓ Using existing${NC}\n"; skip_env=1; }
fi

if [ -z "$skip_env" ]; then
    read -p "Le Potato IP [192.168.178.40]: " HOST_BIND; HOST_BIND=${HOST_BIND:-192.168.178.40}
    read -p "LAN subnet [192.168.178.0/24]: " LAN; LAN=${LAN:-192.168.178.0/24}
    read -p "Domain [lepotato.local]: " DOM; DOM=${DOM:-lepotato.local}
    read -p "Surfshark Username: " SURF_U; read -sp "Surfshark Password: " SURF_P; echo
    read -p "Seafile Email [admin@$DOM]: " SF_E; SF_E=${SF_E:-admin@$DOM}

    cat >.env.production <<ENVEOF
LAN_NETWORK=$LAN
HOST_BIND=$HOST_BIND
HOST_DOMAIN=$DOM
SURFSHARK_USER=$SURF_U
SURFSHARK_PASSWORD=$SURF_P
SURFSHARK_COUNTRY=Netherlands
SURFSHARK_CITY=Amsterdam
TRANSMISSION_USER=admin
TRANSMISSION_PASSWORD=$(openssl rand -base64 32)
SLSKD_USER=admin
SLSKD_PASSWORD=$(openssl rand -base64 32)
POSTGRES_SUPER_PASSWORD=$(openssl rand -base64 32)
IMMICH_DB_PASSWORD=$(openssl rand -base64 32)
SEAFILE_DB_PASSWORD=$(openssl rand -base64 32)
VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)
KOPIA_PASSWORD=$(openssl rand -base64 32)
KOPIA_SERVER_USER=admin
KOPIA_SERVER_PASSWORD=$(openssl rand -base64 32)
SEAFILE_ADMIN_EMAIL=$SF_E
SEAFILE_ADMIN_PASSWORD=$(openssl rand -base64 32)
FRITZ_USERNAME=
FRITZ_PASSWORD=
FRITZ_HOSTNAME=fritz.box
ENVEOF
    chmod 600 .env.production
    echo -e "${GREEN}✓ .env.production created${NC}"
    echo -e "${YELLOW}SAVE passwords from .env.production!${NC}\n"
fi

################################################################################
# STEP 4: Cron & Backup
################################################################################
echo -e "${CYAN}═══ Step 4: Cron & Backup ═══${NC}\n"
sudo mkdir -p /var/log/potatostack; sudo chown -R $USER:$USER /var/log/potatostack

# Inline backup script
sudo tee "$SCRIPT_DIR/backup-to-second-disk.sh" >/dev/null <<'BACKUP'
#!/bin/bash
set -e
SRC="/mnt/storage"; DST="/mnt/backup"; LOG="/var/log/potatostack/backup-$(date +%Y-%m-%d).log"
mkdir -p /var/log/potatostack
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }
[ ! -d "$SRC" ] && { log "ERROR: $SRC missing"; exit 1; }
[ ! -d "$DST" ] && { log "ERROR: $DST missing"; exit 1; }
BACKUP_DEST="$DST/backup-$(date +%Y-%m-%d_%H-%M-%S)"
LATEST="$DST/latest"
PREV=""; [ -L "$LATEST" ] && PREV=$(readlink -f "$LATEST")
log "Starting backup to $BACKUP_DEST"
OPTS=(-aHAXxv --numeric-ids --delete --partial --info=progress2 --exclude='*.tmp' --exclude='*.swp')
[ -n "$PREV" ] && OPTS+=(--link-dest="$PREV")
rsync "${OPTS[@]}" "$SRC/" "$BACKUP_DEST/" 2>&1 | tee -a "$LOG"
ln -snf "$BACKUP_DEST" "$LATEST"
log "✓ Backup complete"
find "$DST" -maxdepth 1 -type d -name "backup-*" -mtime +7 -exec rm -rf {} \;
BACKUP
chmod +x "$SCRIPT_DIR/backup-to-second-disk.sh"

CRON_FILE="/tmp/potato-cron"
crontab -l >"$CRON_FILE" 2>/dev/null || true
sed -i '/PotatoStack/d; /backup-to-second-disk/d; /docker system prune/d' "$CRON_FILE"
cat >>"$CRON_FILE" <<CRON
# PotatoStack - Backup (3 AM)
0 3 * * * $SCRIPT_DIR/backup-to-second-disk.sh >>/var/log/potatostack/backup.log 2>&1
# PotatoStack - Cleanup (Sun 4 AM)
0 4 * * 0 docker system prune -af >>/var/log/potatostack/cleanup.log 2>&1
CRON
crontab "$CRON_FILE"; rm "$CRON_FILE"
echo -e "${GREEN}✓ Cron configured\n${NC}"

################################################################################
# STEP 5: Deploy
################################################################################
echo -e "${CYAN}═══ Step 5: Deploy ═══${NC}\n"
sudo systemctl daemon-reload; sudo systemctl restart docker; sleep 5
docker compose --env-file .env.production pull
docker compose --env-file .env.production up -d
sleep 10

docker compose ps
[ -d "homepage-config" ] && { docker cp homepage-config/. homepage:/app/config/; docker restart homepage; }

HOST_IP=$(grep "^HOST_BIND=" .env.production | cut -d= -f2)
echo -e "\n${GREEN}✅ COMPLETE!${NC}\n"
echo -e "${CYAN}Access:${NC}"
echo "  Homepage: http://$HOST_IP:3000"
echo "  Immich:   http://$HOST_IP:2283"
echo "  Portainer: https://$HOST_IP:9443"
echo -e "\n${CYAN}Status:${NC}"; free -h; swapon --show
