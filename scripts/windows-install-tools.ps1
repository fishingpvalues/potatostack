# PotatoStack Windows Tools Installer
# Installs Helm, k3d, and other required tools

Write-Host "PotatoStack - Windows Tools Installer" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "WARNING: Not running as administrator. Some installations may fail." -ForegroundColor Yellow
    Write-Host ""
}

# Check for package managers
$hasChoco = Get-Command choco -ErrorAction SilentlyContinue
$hasScoop = Get-Command scoop -ErrorAction SilentlyContinue

if (-not $hasChoco -and -not $hasScoop) {
    Write-Host "No package manager found. Installing Scoop..." -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    $hasScoop = $true
}

# Install tools
Write-Host "Installing required tools..." -ForegroundColor Green

if ($hasScoop) {
    Write-Host "Using Scoop for installation..." -ForegroundColor Cyan

    # Install Helm
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Helm..." -ForegroundColor Yellow
        scoop install helm
    } else {
        Write-Host "Helm already installed" -ForegroundColor Green
    }

    # Install k3d
    if (-not (Get-Command k3d -ErrorAction SilentlyContinue)) {
        Write-Host "Installing k3d..." -ForegroundColor Yellow
        scoop install k3d
    } else {
        Write-Host "k3d already installed" -ForegroundColor Green
    }

} elseif ($hasChoco) {
    Write-Host "Using Chocolatey for installation..." -ForegroundColor Cyan

    # Install Helm
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Helm..." -ForegroundColor Yellow
        choco install kubernetes-helm -y
    } else {
        Write-Host "Helm already installed" -ForegroundColor Green
    }

    # Install k3d
    if (-not (Get-Command k3d -ErrorAction SilentlyContinue)) {
        Write-Host "Installing k3d..." -ForegroundColor Yellow
        choco install k3d -y
    } else {
        Write-Host "k3d already installed" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan

# Verify installations
Write-Host "kubectl: " -NoNewline
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    $kubectlVersion = kubectl version --client --short 2>$null
    Write-Host "OK - $kubectlVersion" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND" -ForegroundColor Red
}

Write-Host "helm: " -NoNewline
if (Get-Command helm -ErrorAction SilentlyContinue) {
    $helmVersion = helm version --short 2>$null
    Write-Host "OK - $helmVersion" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND - Please install manually" -ForegroundColor Red
}

Write-Host "k3d: " -NoNewline
if (Get-Command k3d -ErrorAction SilentlyContinue) {
    $k3dVersion = k3d version 2>$null
    Write-Host "OK - $k3dVersion" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND - Please install manually" -ForegroundColor Red
}

Write-Host "docker: " -NoNewline
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerVersion = docker version --format '{{.Client.Version}}' 2>$null
    Write-Host "OK - v$dockerVersion" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND - Docker Desktop required!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan
Write-Host "1. Restart your terminal to load new PATH" -ForegroundColor Yellow
Write-Host "2. Create k3d cluster: k3d cluster create potatostack" -ForegroundColor Yellow
Write-Host "3. Deploy stack: make stack-up-local" -ForegroundColor Yellow
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
