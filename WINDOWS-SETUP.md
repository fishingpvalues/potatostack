# PotatoStack - Windows Setup Guide

Quick setup guide for Windows (detected environment).

## Prerequisites Installation

### 1. Install Helm

```powershell
# Using Chocolatey (recommended)
choco install kubernetes-helm

# OR using Scoop (if you have scoop)
scoop install helm

# OR manual download
# Download from: https://github.com/helm/helm/releases
# Extract to C:\Program Files\helm\
# Add to PATH
```

### 2. Install Minikube (for local testing)

```powershell
# Using Chocolatey
choco install minikube

# OR using Scoop
scoop install minikube

# OR manual download
# Download from: https://minikube.sigs.k8s.io/docs/start/
```

### 3. Install k3d (alternative to Minikube - lighter)

```powershell
# Using Chocolatey
choco install k3d

# OR using Scoop
scoop install k3d

# OR manual download
# Download from: https://k3d.io/#installation
```

## Quick Install (Scoop - Recommended)

```powershell
# Install Scoop if not already installed
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install tools
scoop install helm
scoop install k3d
# kubectl already installed via Docker Desktop
```

## Verify Installation

```bash
kubectl version --client
helm version
k3d version
# OR
minikube version
```

## Deploy Stack

### Option 1: k3d (Recommended for Windows)

```bash
# Create k3d cluster
k3d cluster create potatostack --agents 1

# Deploy stack
make stack-up-local
```

### Option 2: Minikube

```bash
# Start minikube
minikube start --memory=4096 --cpus=2

# Deploy stack
make stack-up-local
```

### Option 3: Docker Desktop Kubernetes

```bash
# Enable Kubernetes in Docker Desktop settings
# Settings > Kubernetes > Enable Kubernetes

# Deploy stack
make stack-up-local
```

## Troubleshooting

### Helm not found
```bash
# Add to PATH manually
$env:Path += ";C:\Program Files\helm"
```

### Cannot create cluster
```bash
# Check Docker is running
docker ps

# For k3d: ensure port 6443 is free
netstat -an | findstr "6443"
```

### Out of memory
```bash
# Increase Docker Desktop memory
# Settings > Resources > Memory: 4GB minimum
```

## Notes

- **Recommended**: Use k3d (lightweight, fast)
- **Alternative**: Minikube (more features, heavier)
- **Windows limitation**: Some features require WSL2
- **Production**: Deploy to real cluster (EKS, GKE, AKS)

## Next Steps

After tools are installed:

```bash
# Create cluster
k3d cluster create potatostack

# Deploy
cd /c/Users/danie/OneDrive/workdir/vllm-windows
make stack-up-local
```
