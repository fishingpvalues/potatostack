# Kopia Advanced Features

This document covers advanced Kopia backup features including policies, verification, and multi-repository support.

## Table of Contents
- [Policy Configuration](#policy-configuration)
- [Backup Verification](#backup-verification)
- [Multi-Repository Setup](#multi-repository-setup)
- [Maintenance & Best Practices](#maintenance--best-practices)

## Policy Configuration

Kopia policies control retention, scheduling, compression, and performance settings for your backups.

### Quick Setup

Run the automated policy setup script:

```bash
./scripts/kopia/setup-policies.sh
```

This configures reasonable defaults:
- **Retention**: GFS (Grandfather-Father-Son) rotation
  - 7 latest snapshots
  - 24 hourly snapshots
  - 14 daily snapshots
  - 8 weekly snapshots
  - 12 monthly snapshots
  - 3 annual snapshots
- **Compression**: zstd for files 1MB-128MB
- **Scheduling**: Daily backups at 3:00 AM
- **Performance**: Parallel uploads for files >16MB
- **Error Handling**: Continue on inaccessible files/directories

### Manual Policy Configuration

Connect to the Kopia container and configure policies manually:

```bash
# View current global policy
docker exec -it kopia_server kopia policy show --global

# Set retention policy
docker exec -it kopia_server kopia policy set --global \
  --keep-latest 7 \
  --keep-hourly 24 \
  --keep-daily 14 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --keep-annual 3

# Set compression
docker exec -it kopia_server kopia policy set --global \
  --compression=zstd \
  --compression-min-size=1048576 \
  --compression-max-size=134217728

# Set snapshot schedule
docker exec -it kopia_server kopia policy set --global \
  --snapshot-time="03:00"

# Set performance options
docker exec -it kopia_server kopia policy set --global \
  --parallel-upload-above-size-mib=16
```

### Per-Path Policies

You can override global policies for specific paths:

```bash
# Set custom retention for critical data
docker exec -it kopia_server kopia policy set /host/critical/data \
  --keep-latest 14 \
  --keep-daily 30 \
  --keep-monthly 24

# Exclude certain directories
docker exec -it kopia_server kopia policy set /host/data \
  --add-ignore=*.tmp \
  --add-ignore=cache/ \
  --add-ignore=.git/

# Show policy for specific path
docker exec -it kopia_server kopia policy show /host/data
```

## Backup Verification

Kopia includes built-in verification tools to ensure backup integrity.

### Quick Verification (10% of files)

```bash
./scripts/kopia/verify-backups.sh
```

### Full Verification (100% of files)

```bash
./scripts/kopia/verify-backups.sh --full
```

### Verify Specific Snapshot

```bash
./scripts/kopia/verify-backups.sh --snapshot k1234567890abcdef
```

### Custom Verification Percentage

```bash
./scripts/kopia/verify-backups.sh --percent 25
```

### Manual Verification

```bash
# List all snapshots
docker exec -it kopia_server kopia snapshot list

# Verify specific snapshot
docker exec -it kopia_server kopia snapshot verify k1234567890abcdef \
  --verify-files-percent=100 \
  --parallel=4 \
  --max-errors=5

# Verify all snapshots
docker exec -it kopia_server kopia snapshot verify --all \
  --verify-files-percent=10

# Validate repository consistency
docker exec -it kopia_server kopia repository validate-provider
```

### Verification Best Practices

1. **Quick Daily Checks**: Run 10% verification daily
   ```bash
   # Add to cron: 0 4 * * * /path/to/verify-backups.sh
   ```

2. **Weekly Deep Checks**: Run 50% verification weekly
   ```bash
   # Add to cron: 0 4 * * 0 /path/to/verify-backups.sh --percent 50
   ```

3. **Monthly Full Verification**: Run 100% verification monthly
   ```bash
   # Add to cron: 0 4 1 * * /path/to/verify-backups.sh --full
   ```

4. **Test Restores**: Periodically restore files to ensure recoverability
   ```bash
   docker exec -it kopia_server kopia mount /snapshots
   docker exec -it kopia_server kopia snapshot restore k1234567890abcdef /restore
   ```

## Multi-Repository Setup

Kopia supports multiple repositories for implementing the 3-2-1 backup rule:
- **3** copies of data (primary + 2 backups)
- **2** different media types (local HDD + cloud/remote)
- **1** off-site copy (cloud storage)

### Example: Three-Tier Backup Strategy

**Repository 1: Primary (Local)**
- Location: `/mnt/seconddrive/kopia/repository` (current setup)
- Purpose: Fast local backups and quick restores
- Retention: 14 daily, 8 weekly, 12 monthly

**Repository 2: Secondary (External USB/NAS)**
- Location: `/mnt/backup-usb/kopia` or NAS
- Purpose: Local redundancy on different physical media
- Retention: 7 daily, 4 weekly, 6 monthly

**Repository 3: Offsite (Cloud)**
- Location: Backblaze B2, AWS S3, Google Cloud, etc.
- Purpose: Offsite disaster recovery
- Retention: 7 daily, 4 weekly, 12 monthly, 3 annual

### Setting Up Multiple Repositories

See the example script for detailed configuration:

```bash
./scripts/kopia/multi-repo-example.sh
```

#### Create Secondary Local Repository

```bash
# Mount external USB drive, then:
docker exec -it kopia_server kopia repository create filesystem \
  --path=/repository-secondary \
  --override-hostname=lepotato-backup \
  --override-username=admin \
  --password="SECURE_PASSWORD"
```

#### Create Cloud Repository (Backblaze B2)

```bash
docker exec -it kopia_server kopia repository create b2 \
  --bucket=my-kopia-backups \
  --key-id="YOUR_B2_KEY_ID" \
  --key="YOUR_B2_APPLICATION_KEY" \
  --password="SECURE_PASSWORD"
```

#### Create Cloud Repository (AWS S3)

```bash
docker exec -it kopia_server kopia repository create s3 \
  --bucket=my-kopia-backups \
  --access-key="YOUR_AWS_ACCESS_KEY" \
  --secret-access-key="YOUR_AWS_SECRET_KEY" \
  --region="us-east-1" \
  --password="SECURE_PASSWORD"
```

#### Create Remote Repository (SFTP)

```bash
docker exec -it kopia_server kopia repository create sftp \
  --path=/backups/kopia \
  --host=backup-server.example.com \
  --username=backup-user \
  --keyfile=/path/to/ssh/key \
  --password="SECURE_PASSWORD"
```

### Multi-Repository Workflow

```bash
# Connect to primary repository
docker exec -it kopia_server kopia repository connect filesystem \
  --path=/repository --password="PRIMARY_PASSWORD"
docker exec -it kopia_server kopia snapshot create /host/important/data

# Switch to secondary repository
docker exec -it kopia_server kopia repository disconnect
docker exec -it kopia_server kopia repository connect filesystem \
  --path=/repository-secondary --password="SECONDARY_PASSWORD"
docker exec -it kopia_server kopia snapshot create /host/important/data

# Switch to offsite repository
docker exec -it kopia_server kopia repository disconnect
docker exec -it kopia_server kopia repository connect b2 \
  --bucket=my-kopia-backups --key-id="B2_KEY" --password="OFFSITE_PASSWORD"
docker exec -it kopia_server kopia snapshot create /host/important/data
```

### Docker Compose Multi-Repository Configuration

Add volume mounts and environment variables to `docker-compose.yml`:

```yaml
kopia:
  volumes:
    - /mnt/seconddrive/kopia/repository:/repository          # Primary
    - /mnt/backup-usb/kopia:/repository-secondary            # Secondary USB
    - /mnt/seconddrive/kopia/config:/app/config
    - /mnt/seconddrive/kopia/cache:/app/cache
    - /:/host:ro
  environment:
    # Cloud credentials (add to .env)
    - B2_KEY_ID=${B2_KEY_ID}
    - B2_APPLICATION_KEY=${B2_APPLICATION_KEY}
    - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
```

Add to `.env`:
```bash
# Backblaze B2
B2_KEY_ID=your_backblaze_key_id
B2_APPLICATION_KEY=your_backblaze_app_key

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
```

## Maintenance & Best Practices

### Regular Maintenance Tasks

1. **Repository Maintenance** (automatic, but can be triggered manually)
   ```bash
   docker exec -it kopia_server kopia maintenance run --full
   ```

2. **Repair Repository** (if corruption detected)
   ```bash
   docker exec -it kopia_server kopia repository repair
   ```

3. **Clean Old Snapshots** (based on retention policy)
   ```bash
   docker exec -it kopia_server kopia snapshot expire
   ```

4. **Monitor Repository Size**
   ```bash
   docker exec -it kopia_server kopia repository status
   ```

### Monitoring & Alerts

Kopia exports Prometheus metrics on port 51516. Key metrics to monitor:

- `kopia_snapshot_count`: Number of snapshots
- `kopia_snapshot_total_size_bytes`: Total backup size
- `kopia_repository_size_bytes`: Repository storage usage
- `kopia_snapshot_last_time`: Time of last snapshot

See Grafana dashboards for visualization (configured in `config/grafana/provisioning/`).

### Security Best Practices

1. **Use Strong Passwords**: Each repository should have a unique, strong password
2. **Encrypt at Rest**: Kopia encrypts all data with AES-256
3. **Secure Credentials**: Store cloud credentials in `.env` (never commit to git)
4. **Regular Verification**: Verify backups weekly to detect corruption early
5. **Test Restores**: Perform test restores monthly to ensure recoverability

### Performance Tuning

For ARM64 SBC with 2GB RAM (Le Potato):

```bash
# Optimize memory usage
docker exec -it kopia_server kopia policy set --global \
  --file-parallelism=2 \
  --parallel-upload-above-size-mib=16

# Reduce cache size if needed
docker exec -it kopia_server kopia cache set --max-size=512MB
```

### Troubleshooting

**High Memory Usage**
```bash
# Reduce parallelism
docker exec -it kopia_server kopia policy set --global --file-parallelism=1

# Clear cache
docker exec -it kopia_server kopia cache clear
```

**Slow Backups**
```bash
# Enable parallel uploads
docker exec -it kopia_server kopia policy set --global \
  --parallel-upload-above-size-mib=8

# Adjust compression
docker exec -it kopia_server kopia policy set --global \
  --compression=s2-default  # Faster than zstd
```

**Verification Errors**
```bash
# Check repository status
docker exec -it kopia_server kopia repository status

# Validate and repair
docker exec -it kopia_server kopia repository validate-provider
docker exec -it kopia_server kopia repository repair
```

## Additional Resources

- [Kopia Documentation](https://kopia.io/docs/)
- [Kopia CLI Reference](https://kopia.io/docs/reference/command-line/)
- [Kopia Server Mode](https://kopia.io/docs/repository-server/)
- [Kopia FAQ](https://kopia.io/docs/faq/)

## Quick Reference Commands

```bash
# View scripts
ls -lh scripts/kopia/

# Setup policies
./scripts/kopia/setup-policies.sh

# Verify backups
./scripts/kopia/verify-backups.sh
./scripts/kopia/verify-backups.sh --full
./scripts/kopia/verify-backups.sh --percent 25

# Multi-repository examples
./scripts/kopia/multi-repo-example.sh

# Manual operations
docker exec -it kopia_server kopia snapshot list
docker exec -it kopia_server kopia policy show --global
docker exec -it kopia_server kopia repository status
docker exec -it kopia_server kopia maintenance run --full
```
