# PotatoStack Systemd Integration

This directory contains systemd service files to automate PotatoStack deployment and management.

## What's Included

### 1. **Swap Management**
- `potatostack-swap.service` - Systemd service for swap management
- `ensure-potatostack-swap.sh` - Script that creates and activates swap file

### 2. **Auto-Start Service**
- `potatostack.service` - Systemd service to auto-start PotatoStack on boot

### 3. **Installer**
- `install-systemd-services.sh` - Automated installer for all services

## Quick Start

Run the installer as root:

```bash
cd ~/potatostack/systemd
chmod +x install-systemd-services.sh
sudo ./install-systemd-services.sh
```

The installer will:
1. Install swap management script to `/usr/local/bin/`
2. Install systemd services to `/etc/systemd/system/`
3. Configure services with your username and paths
4. Enable services to run on boot
5. Optionally start PotatoStack immediately

## Manual Installation

If you prefer to install manually:

### Step 1: Install Swap Management

```bash
# Copy script
sudo cp ensure-potatostack-swap.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ensure-potatostack-swap.sh

# Install service
sudo cp potatostack-swap.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable potatostack-swap.service
sudo systemctl start potatostack-swap.service

# Verify
sudo systemctl status potatostack-swap.service
free -h
```

### Step 2: Install Auto-Start Service

```bash
# Edit potatostack.service and replace:
# - /home/USER with your actual home directory
# - User=USER with your actual username
# - Group=USER with your actual group

# Install service
sudo cp potatostack.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable potatostack.service
sudo systemctl start potatostack.service

# Verify
sudo systemctl status potatostack.service
docker-compose ps
```

## Usage

### Managing Services

```bash
# Check status
sudo systemctl status potatostack-swap
sudo systemctl status potatostack

# View logs
sudo journalctl -u potatostack-swap -f
sudo journalctl -u potatostack -f

# Restart stack
sudo systemctl restart potatostack

# Stop stack
sudo systemctl stop potatostack

# Disable auto-start
sudo systemctl disable potatostack
```

### Swap Management

```bash
# Check swap status
free -h
swapon --show

# Manually run swap script
sudo /usr/local/bin/ensure-potatostack-swap.sh

# Remove swap (if needed)
sudo swapoff /mnt/seconddrive/potatostack.swap
sudo rm /mnt/seconddrive/potatostack.swap
```

## How It Works

### Boot Sequence

1. **System boots**
2. **potatostack-swap.service** runs first
   - Checks if `/mnt/seconddrive` is mounted
   - Creates swap file if it doesn't exist (3GB by default)
   - Activates swap
   - Adds to `/etc/fstab` for persistence
3. **Docker service** starts
4. **potatostack.service** runs after Docker and swap are ready
   - Changes to PotatoStack directory
   - Optionally pulls latest images
   - Runs `docker-compose up -d`
5. **All containers start** automatically

### Service Dependencies

```
potatostack-swap.service
         ↓
    docker.service
         ↓
  potatostack.service
         ↓
   (All containers)
```

## Customization

### Change Swap Size

Edit `/usr/local/bin/ensure-potatostack-swap.sh`:

```bash
SWAPSIZE_GB=4  # Change from 3 to 4GB
```

Then restart:
```bash
sudo swapoff /mnt/seconddrive/potatostack.swap
sudo rm /mnt/seconddrive/potatostack.swap
sudo systemctl restart potatostack-swap
```

### Change Swap Location

Edit both files to change `SWAPFILE` path:
- `/usr/local/bin/ensure-potatostack-swap.sh`
- `/etc/systemd/system/potatostack-swap.service` (After= line)

### Disable Image Updates on Start

Edit `/etc/systemd/system/potatostack.service`:

Comment out or remove:
```ini
# ExecStartPre=-/usr/bin/docker-compose pull --quiet --ignore-pull-failures
```

## Troubleshooting

### Swap service fails to start

```bash
# Check logs
sudo journalctl -u potatostack-swap -xe

# Common issues:
# - /mnt/seconddrive not mounted yet
# - Insufficient disk space
# - Permissions issue

# Test manually
sudo /usr/local/bin/ensure-potatostack-swap.sh
```

### PotatoStack service fails to start

```bash
# Check logs
sudo journalctl -u potatostack -xe

# Common issues:
# - docker-compose.yml syntax error
# - Missing .env file
# - Insufficient resources

# Test manually
cd ~/potatostack
docker-compose up -d
```

### Services don't start on boot

```bash
# Verify services are enabled
sudo systemctl is-enabled potatostack-swap
sudo systemctl is-enabled potatostack

# Enable if needed
sudo systemctl enable potatostack-swap
sudo systemctl enable potatostack
```

## Uninstallation

To remove systemd services:

```bash
# Stop and disable services
sudo systemctl stop potatostack
sudo systemctl disable potatostack
sudo systemctl stop potatostack-swap
sudo systemctl disable potatostack-swap

# Remove service files
sudo rm /etc/systemd/system/potatostack.service
sudo rm /etc/systemd/system/potatostack-swap.service
sudo rm /usr/local/bin/ensure-potatostack-swap.sh

# Reload systemd
sudo systemctl daemon-reload

# Optionally remove swap
sudo swapoff /mnt/seconddrive/potatostack.swap
sudo rm /mnt/seconddrive/potatostack.swap
# Remove line from /etc/fstab
```

## Benefits

✅ **Automatic startup** - PotatoStack starts on boot, no manual intervention
✅ **Guaranteed swap** - Swap is always available before Docker starts
✅ **Reliability** - Survives reboots and power outages
✅ **Logging** - All output captured in systemd journal
✅ **Service management** - Standard systemctl commands
✅ **Dependency management** - Proper startup order guaranteed

## See Also

- [IMPROVEMENTS_RECOMMENDATIONS.md](../IMPROVEMENTS_RECOMMENDATIONS.md) - Full recommendations document
- [DEPLOYMENT_CHECKLIST.md](../DEPLOYMENT_CHECKLIST.md) - Deployment guide
- [systemd documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
