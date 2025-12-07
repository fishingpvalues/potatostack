# Secrets Management Guide

## Overview
This guide covers managing sensitive environment variables using sops+age for encrypted .env files on the host system.

## Option 1: sops + age (Recommended for Host-Level)

### Setup
1. **Install age and sops:**
   ```bash
   # On Debian/Ubuntu
   sudo apt install age
   wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.arm64 -O /usr/local/bin/sops
   sudo chmod +x /usr/local/bin/sops
   ```

2. **Generate age key:**
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

   **CRITICAL:** Backup this key to a secure location (encrypted USB, password manager)!

3. **Create .sops.yaml config:**
   ```yaml
   creation_rules:
     - path_regex: \.env$
       age: >-
         age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   Replace with your public key from `~/.config/sops/age/keys.txt` (starts with `age1`)

4. **Encrypt your .env file:**
   ```bash
   # First time: encrypt existing .env
   sops --encrypt .env > .env.enc

   # To edit encrypted file:
   sops .env.enc

   # To decrypt (for docker-compose):
   sops --decrypt .env.enc > .env
   ```

5. **Automate decryption with systemd:**
   Create `/etc/systemd/system/decrypt-env.service`:
   ```ini
   [Unit]
   Description=Decrypt environment file for PotatoStack
   Before=docker.service

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/sops --decrypt /home/user/potatostack/.env.enc --output /home/user/potatostack/.env
   RemainAfterExit=yes

   [Install]
   WantedBy=multi-user.target
   ```

   Enable: `sudo systemctl enable decrypt-env.service`

### Security Best Practices
- Never commit .env (only commit .env.enc)
- Store age key backup in password manager or encrypted external drive
- Use `sops updatekeys .env.enc` when rotating keys
- Consider using multiple age keys for redundancy

## Option 2: Bitwarden CLI (Alternative)

### Setup
1. **Install bw CLI:**
   ```bash
   npm install -g @bitwarden/cli
   ```

2. **Login and unlock:**
   ```bash
   export BW_SESSION=$(bw login --raw)
   # Or if already logged in:
   export BW_SESSION=$(bw unlock --raw)
   ```

3. **Fetch secrets in scripts:**
   ```bash
   #!/bin/bash
   export KOPIA_PASSWORD=$(bw get password kopia-repo)
   export GRAFANA_PASSWORD=$(bw get password grafana-admin)
   docker compose up -d
   ```

4. **Store BW_SESSION securely:**
   Add to `~/.bashrc` or use systemd environment file

## Option 3: Vaultwarden Container (Self-Hosted Bitwarden)

Add to docker-compose.yml:
```yaml
vaultwarden:
  image: vaultwarden/server:latest
  container_name: vaultwarden
  restart: unless-stopped
  networks:
    - proxy
  ports:
    - "${HOST_BIND:-0.0.0.0}:8084:80"
  environment:
    - DOMAIN=https://vault.yourdomain.com
    - SIGNUPS_ALLOWED=false  # Disable after creating your account
  volumes:
    - /mnt/seconddrive/vaultwarden:/data
  mem_limit: 128m
  mem_reservation: 64m
  labels:
    - "homepage.group=Security"
    - "homepage.name=Vaultwarden"
    - "homepage.icon=bitwarden.png"
    - "homepage.href=http://${HOST_ADDR}:8084"
```

Then use Bitwarden browser extension or CLI to manage all passwords.

## Recommendation
For your Le Potato setup, use **sops+age** because:
- Lightweight (no container overhead)
- Works at boot before Docker starts
- Simple backup/recovery (just one key file)
- Integrates with git workflow (commit .env.enc, never .env)

For teams or multiple devices, use **Vaultwarden**.
