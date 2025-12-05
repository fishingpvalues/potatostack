#!/bin/bash

################################################################################
# Git Commands for PotatoStack GitHub Upload
# Run these commands to upload your repository safely
################################################################################

echo "PotatoStack Git Upload Commands"
echo "================================"
echo ""
echo "CRITICAL: Before proceeding, ensure you've read:"
echo "  1. SECURITY.md"
echo "  2. GITHUB_UPLOAD_GUIDE.md"
echo ""
read -p "Have you read both files? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Please read SECURITY.md and GITHUB_UPLOAD_GUIDE.md first!"
    exit 1
fi

echo ""
echo "Step 1: Verify no sensitive files will be committed"
echo "---------------------------------------------------"
git status

echo ""
echo "Review the list above. If .env appears, STOP NOW!"
read -p "Is the list safe? (yes/no): " safe

if [ "$safe" != "yes" ]; then
    echo "Please review and fix before continuing"
    exit 1
fi

echo ""
echo "Step 2: Initialize Git repository"
echo "-----------------------------------"
git init

echo ""
echo "Step 3: Add all files"
echo "----------------------"
git add .

echo ""
echo "Step 4: Verify what will be committed"
echo "---------------------------------------"
echo "Files to be committed:"
git diff --cached --name-only

echo ""
read -p "Does this list look correct? (yes/no): " correct

if [ "$correct" != "yes" ]; then
    echo "Aborting. Please review files."
    git reset
    exit 1
fi

echo ""
echo "Step 5: Create initial commit"
echo "-------------------------------"
git commit -m "Initial commit: PotatoStack v2.0 for Le Potato SBC

Complete self-hosted stack including:
- VPN with P2P (Surfshark, qBittorrent, Nicotine+)
- Storage & Backup (Nextcloud, Kopia, Gitea)
- Monitoring (Prometheus, Grafana, Loki, Netdata)
- Management (Portainer, Watchtower, Uptime Kuma, Dozzle)
- Infrastructure (Nginx Proxy Manager, Homepage)

Optimized for Le Potato (2GB RAM, ARM64)
21 services, fully integrated, production-ready"

echo ""
echo "Step 6: Add remote repository"
echo "-------------------------------"
echo "Your repository URL from GitHub: https://github.com/fishingpvalues/potatostack.git"
git remote add origin https://github.com/fishingpvalues/potatostack.git

echo ""
echo "Step 7: Set main branch"
echo "------------------------"
git branch -M main

echo ""
echo "Step 8: Push to GitHub"
echo "-----------------------"
echo "About to push to GitHub. This will upload your code."
read -p "Ready to push? (yes/no): " push

if [ "$push" != "yes" ]; then
    echo "Aborted. You can push later with: git push -u origin main"
    exit 0
fi

git push -u origin main

echo ""
echo "=========================================="
echo "SUCCESS! Repository uploaded to GitHub"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Go to: https://github.com/fishingpvalues/potatostack"
echo "2. Verify repository is PRIVATE"
echo "3. Enable security features (see GITHUB_UPLOAD_GUIDE.md)"
echo "4. Set up branch protection"
echo "5. Enable Dependabot alerts"
echo ""
echo "Your local git is now configured. Future updates:"
echo "  git add ."
echo "  git commit -m 'Description of changes'"
echo "  git push"
echo ""
