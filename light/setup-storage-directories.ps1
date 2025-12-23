################################################################################
# PotatoStack Light - Storage Directory Setup (Windows)
# Creates all required /mnt/storage directories with proper permissions
################################################################################

$STORAGE_BASE = "C:\mnt\storage"  # Adjust for your Windows mount point
$PUID = 1000
$PGID = 1000

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "PotatoStack Light - Storage Setup (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Creating directory structure in ${STORAGE_BASE}..." -ForegroundColor Yellow
Write-Host ""

# Function to create directory
function Create-Dir {
    param([string]$dir)
    
    if (-not (Test-Path $dir)) {
        Write-Host "  Creating: $dir" -ForegroundColor Green
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    } else {
        Write-Host "  Exists:   $dir" -ForegroundColor Gray
    }
}

# Check if storage base exists
if (-not (Test-Path $STORAGE_BASE)) {
    Write-Host "ERROR: ${STORAGE_BASE} does not exist!" -ForegroundColor Red
    Write-Host "Creating it now..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $STORAGE_BASE -Force | Out-Null
}

Write-Host "Storage base: ${STORAGE_BASE}" -ForegroundColor Green
Write-Host ""

# Transmission directories
Write-Host "[Transmission - Torrent Client]" -ForegroundColor Cyan
Create-Dir "$STORAGE_BASE\downloads"
Create-Dir "$STORAGE_BASE\transmission-incomplete"
Write-Host ""

# slskd directories
Write-Host "[slskd - Soulseek Client]" -ForegroundColor Cyan
Create-Dir "$STORAGE_BASE\slskd-shared"
Create-Dir "$STORAGE_BASE\slskd-incomplete"
Write-Host ""

# Immich directories
Write-Host "[Immich - Photo Management]" -ForegroundColor Cyan
Create-Dir "$STORAGE_BASE\immich"
Create-Dir "$STORAGE_BASE\immich\upload"
Create-Dir "$STORAGE_BASE\immich\library"
Create-Dir "$STORAGE_BASE\immich\thumbs"
Write-Host ""

# Kopia directories
Write-Host "[Kopia - Backup Server]" -ForegroundColor Cyan
Create-Dir "$STORAGE_BASE\kopia"
Create-Dir "$STORAGE_BASE\kopia\repository"
Create-Dir "$STORAGE_BASE\kopia\cache"
Write-Host ""

# Seafile directories
Write-Host "[Seafile - File Sync & Share]" -ForegroundColor Cyan
Create-Dir "$STORAGE_BASE\seafile"
Write-Host ""

# Fix entrypoint script permissions (Windows - no-op, scripts are executable by default)
Write-Host "[Checking Entrypoint Scripts]" -ForegroundColor Cyan
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "$SCRIPT_DIR\immich-entrypoint.sh") {
    Write-Host "  Found: immich-entrypoint.sh" -ForegroundColor Gray
}
if (Test-Path "$SCRIPT_DIR\seafile-entrypoint.sh") {
    Write-Host "  Found: seafile-entrypoint.sh" -ForegroundColor Gray
}
Write-Host "  (Windows uses WSL/Docker for script execution)" -ForegroundColor Yellow
Write-Host ""

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Directory structure created successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now start the stack:" -ForegroundColor Yellow
Write-Host "  docker compose up -d" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Update docker-compose.yml with your Windows path:" -ForegroundColor Yellow
Write-Host "  Change /mnt/storage to ${STORAGE_BASE}" -ForegroundColor White
Write-Host ""
