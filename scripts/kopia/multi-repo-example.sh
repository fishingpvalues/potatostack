#!/bin/bash
################################################################################
# Kopia Multi-Repository Example Configuration
# Demonstrates how to set up multiple backup repositories for redundancy
#
# Use Case: 3-2-1 Backup Strategy
#   - 3 copies of data (primary + 2 backups)
#   - 2 different media types (local HDD + cloud/remote)
#   - 1 off-site copy (cloud storage)
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

################################################################################
# MULTI-REPOSITORY STRATEGY
################################################################################

cat << 'EOF'
================================================================================
                    Kopia Multi-Repository Setup
================================================================================

This script demonstrates how to configure multiple Kopia repositories for
a robust backup strategy following the 3-2-1 rule:

Repository Types:
  1. PRIMARY (Local):    /mnt/seconddrive/kopia/repository (current)
  2. SECONDARY (Local):  USB external drive or NAS
  3. OFFSITE (Remote):   Cloud storage (S3, B2, etc.)

Why Multiple Repositories?
  - Protection against single storage failure
  - Geographic redundancy (local + cloud)
  - Different retention policies per repository
  - Faster local restores with cloud backup safety net

================================================================================
EOF

log_warn "This is an EXAMPLE script for educational purposes."
log_warn "Modify the paths and credentials below before running!"
echo ""

# Configuration
KOPIA_CONTAINER="${KOPIA_CONTAINER:-kopia_server}"
DRY_RUN="${DRY_RUN:-true}"  # Set to false to actually execute

################################################################################
# REPOSITORY 1: PRIMARY (Already configured)
################################################################################
log_info "Repository 1: PRIMARY (Local Filesystem)"
echo "  Location: /mnt/seconddrive/kopia/repository"
echo "  Purpose: Fast local backups and quick restores"
echo "  Retention: 14 days daily, 8 weeks weekly, 12 months monthly"
echo "  Status: Already configured in docker-compose.yml"
echo ""

################################################################################
# REPOSITORY 2: SECONDARY (External USB/NAS)
################################################################################
log_info "Repository 2: SECONDARY (External Drive/NAS)"
echo "  Location: /mnt/backup-usb/kopia OR smb://nas.local/backups/kopia"
echo "  Purpose: Local redundancy on different physical media"
echo "  Retention: 7 days daily, 4 weeks weekly, 6 months monthly"
echo ""

cat << 'EOF'
# Example: Create secondary repository on external USB drive
# Mount your USB drive first, then run:

docker exec -it kopia_server kopia repository create filesystem \
  --path=/repository-secondary \
  --override-hostname=lepotato-backup \
  --override-username=admin \
  --password="CHANGE_THIS_PASSWORD"

# Set retention policy for secondary repository
docker exec -it kopia_server kopia policy set --global \
  --keep-latest 5 \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --keep-annual 2

# Create snapshot to secondary repository
docker exec -it kopia_server kopia snapshot create /host
EOF

echo ""

################################################################################
# REPOSITORY 3: OFFSITE (Cloud Storage)
################################################################################
log_info "Repository 3: OFFSITE (Cloud Storage - Backblaze B2 Example)"
echo "  Location: Backblaze B2 bucket (or AWS S3, Google Cloud, etc.)"
echo "  Purpose: Offsite disaster recovery"
echo "  Retention: 3 days daily, 4 weeks weekly, 12 months monthly, 3 years annual"
echo ""

cat << 'EOF'
# Example: Create offsite repository on Backblaze B2
# Required: B2 account, application key, and bucket name

docker exec -it kopia_server kopia repository create b2 \
  --bucket=my-kopia-backups \
  --key-id="YOUR_B2_KEY_ID" \
  --key="YOUR_B2_APPLICATION_KEY" \
  --password="CHANGE_THIS_PASSWORD"

# Set retention policy for offsite repository
docker exec -it kopia_server kopia policy set --global \
  --keep-latest 3 \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --keep-annual 3

# Alternative: AWS S3
docker exec -it kopia_server kopia repository create s3 \
  --bucket=my-kopia-backups \
  --access-key="YOUR_AWS_ACCESS_KEY" \
  --secret-access-key="YOUR_AWS_SECRET_KEY" \
  --region="us-east-1" \
  --password="CHANGE_THIS_PASSWORD"

# Alternative: SFTP (remote server)
docker exec -it kopia_server kopia repository create sftp \
  --path=/backups/kopia \
  --host=backup-server.example.com \
  --username=backup-user \
  --keyfile=/path/to/ssh/key \
  --password="CHANGE_THIS_PASSWORD"
EOF

echo ""

################################################################################
# MULTI-REPOSITORY WORKFLOW
################################################################################
log_info "Multi-Repository Backup Workflow"
echo ""

cat << 'EOF'
WORKFLOW: Backing Up to Multiple Repositories
==============================================

1. Connect to Primary Repository (default)
   docker exec -it kopia_server kopia repository connect filesystem \
     --path=/repository \
     --password="PRIMARY_PASSWORD"

2. Create snapshot to primary
   docker exec -it kopia_server kopia snapshot create /host/important/data

3. Connect to Secondary Repository
   docker exec -it kopia_server kopia repository disconnect
   docker exec -it kopia_server kopia repository connect filesystem \
     --path=/repository-secondary \
     --password="SECONDARY_PASSWORD"

4. Create snapshot to secondary
   docker exec -it kopia_server kopia snapshot create /host/important/data

5. Connect to Offsite Repository
   docker exec -it kopia_server kopia repository disconnect
   docker exec -it kopia_server kopia repository connect b2 \
     --bucket=my-kopia-backups \
     --key-id="B2_KEY_ID" \
     --key="B2_KEY" \
     --password="OFFSITE_PASSWORD"

6. Create snapshot to offsite
   docker exec -it kopia_server kopia snapshot create /host/important/data

AUTOMATION: Use cron or systemd timers to automate this workflow
=================================================================

Example cron job (daily backups to all repositories):
0 3 * * * /home/user/potatostack/scripts/kopia/backup-all-repos.sh
EOF

echo ""

################################################################################
# DOCKER-COMPOSE MULTI-REPOSITORY SETUP
################################################################################
log_info "Docker Compose Multi-Repository Configuration"
echo ""

cat << 'EOF'
To support multiple repositories in docker-compose.yml, add volume mounts:

kopia:
  volumes:
    - /mnt/seconddrive/kopia/repository:/repository          # Primary
    - /mnt/backup-usb/kopia:/repository-secondary            # Secondary USB
    - /mnt/seconddrive/kopia/config:/app/config
    - /mnt/seconddrive/kopia/cache:/app/cache
    - /mnt/seconddrive/kopia/logs:/app/logs
    - /:/host:ro

Environment variables for cloud credentials:
    - B2_KEY_ID=${B2_KEY_ID}
    - B2_APPLICATION_KEY=${B2_APPLICATION_KEY}
    - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

Add to .env:
B2_KEY_ID=your_backblaze_key_id
B2_APPLICATION_KEY=your_backblaze_app_key
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
EOF

echo ""

################################################################################
# VERIFICATION ACROSS REPOSITORIES
################################################################################
log_info "Verifying Backups Across All Repositories"
echo ""

cat << 'EOF'
Verify each repository regularly:

# Verify primary repository
docker exec -it kopia_server kopia repository connect filesystem --path=/repository
docker exec -it kopia_server kopia snapshot verify --all

# Verify secondary repository
docker exec -it kopia_server kopia repository connect filesystem --path=/repository-secondary
docker exec -it kopia_server kopia snapshot verify --all

# Verify offsite repository
docker exec -it kopia_server kopia repository connect b2 --bucket=my-kopia-backups
docker exec -it kopia_server kopia snapshot verify --all
EOF

echo ""

################################################################################
# SUMMARY
################################################################################
log_success "Multi-Repository Strategy Summary"
echo ""
echo "Benefits:"
echo "  ✓ Protection against single point of failure"
echo "  ✓ Geographic redundancy (local + cloud)"
echo "  ✓ Different retention policies per repository"
echo "  ✓ Faster local restores with offsite disaster recovery"
echo ""
log_warn "Remember:"
echo "  - Use different passwords for each repository"
echo "  - Test restores from each repository periodically"
echo "  - Monitor all repositories for errors"
echo "  - Keep cloud credentials secure in .env file"
echo ""
log_info "Next Steps:"
echo "  1. Choose your secondary storage (USB, NAS, or cloud)"
echo "  2. Create repository using examples above"
echo "  3. Set appropriate retention policies"
echo "  4. Automate backups with cron or systemd"
echo "  5. Verify backups regularly: ./scripts/kopia/verify-backups.sh"
