# GitHub Upload Guide for PotatoStack

## ⚠️ CRITICAL SECURITY NOTICE

Before uploading to GitHub, you MUST read `SECURITY.md` completely.

**GitHub has experienced a data breach affecting 265,160 accounts.**

---

## Pre-Upload Security Checklist

### 1. Verify .gitignore is Working

```bash
cd ~/potatostack

# Check what files will be committed
git status

# CRITICAL: These files must NOT appear in the list:
# - .env
# - *.log files
# - backup-*.tar.gz files
# - Any file with actual passwords

# If .env appears, STOP and verify .gitignore!
```

### 2. Remove Sensitive Data from Git History

If you've already committed sensitive files:

```bash
# Install BFG Repo-Cleaner
# https://rtyley.github.io/bfg-repo-cleaner/

# Remove .env from history (if accidentally committed)
java -jar bfg.jar --delete-files .env

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### 3. Scan for Accidentally Committed Secrets

```bash
# Check for potential secrets in files
grep -r "password\|secret\|token\|api_key" . \
  --exclude-dir=.git \
  --exclude=SECURITY.md \
  --exclude=GITHUB_UPLOAD_GUIDE.md \
  --exclude=README.md

# Should only find references in:
# - .env.example (which has placeholder text)
# - Documentation files
# - NOT in any committed config files!
```

### 4. Verify No Private Data in Configs

```bash
# Check config files for hardcoded values
grep -r "192.168.178.40" config/ || echo "OK"
# This is fine - it's just a local IP

# Check for emails
grep -r "@" config/ --exclude="*.md"
# Should only find placeholder emails in alertmanager config

# Check for actual passwords
grep -ri "changeme\|admin\|password123" config/
# Should return nothing or only .env.example
```

---

## Upload Steps

### Option 1: Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Authenticate
gh auth login

# Create private repository
gh repo create potatostack --private --source=. --remote=origin

# Push code
git add .
git commit -m "Initial commit: PotatoStack for Le Potato SBC"
git push -u origin main
```

### Option 2: Using Git (Traditional)

As shown in your GitHub screenshot:

```bash
# Initialize repository
git init
git add .
git commit -m "Initial commit: PotatoStack for Le Potato SBC"

# Add remote (use YOUR repository URL)
git remote add origin https://github.com/fishingpvalues/potatostack.git
git branch -M main

# Push to GitHub
git push -u origin main
```

### Option 3: Using SSH (More Secure)

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy output and add to GitHub: Settings → SSH and GPG keys → New SSH key

# Test connection
ssh -T git@github.com

# Push using SSH
git remote add origin git@github.com:fishingpvalues/potatostack.git
git push -u origin main
```

---

## Post-Upload Security

### 1. Verify Repository Settings

Go to: `https://github.com/fishingpvalues/potatostack/settings`

**General:**
- [ ] Visibility: Private (unless intentionally public)
- [ ] Disable Wiki (not needed)
- [ ] Disable Issues (if not accepting contributions)
- [ ] Disable Projects (not needed)

**Branches:**
- [ ] Enable branch protection for `main`
- [ ] Require pull request reviews
- [ ] Require status checks to pass
- [ ] Require conversation resolution before merging

**Security:**
- [ ] Enable Dependabot alerts
- [ ] Enable Dependabot security updates
- [ ] Enable Secret scanning (if available)
- [ ] Enable Dependency graph

### 2. Add Repository Secrets (if using GitHub Actions)

Settings → Secrets and variables → Actions → New repository secret

Example secrets for CI/CD:
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`
- `NOTIFICATION_WEBHOOK`

**NEVER commit these as environment variables!**

### 3. Create Branch Protection Rules

Settings → Branches → Add branch protection rule

For `main` branch:
- [x] Require a pull request before merging
- [x] Require approvals: 1
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require conversation resolution before merging
- [x] Require signed commits (optional)
- [x] Include administrators

### 4. Enable Security Scanning

**For Public Repositories:**
- Go to Security tab
- Enable Dependabot alerts
- Enable Code scanning with CodeQL

**For Private Repositories:**
- Requires GitHub Advanced Security
- Consider if you're sharing the repo with team members

---

## Maintaining the Repository

### Regular Updates

```bash
# Pull latest changes
cd ~/potatostack
git pull

# Make changes
nano docker-compose.yml

# Commit and push
git add docker-compose.yml
git commit -m "Update: Added new service"
git push
```

### Branching Strategy

```bash
# Create feature branch
git checkout -b feature/add-new-service

# Make changes and test
docker-compose up -d

# Commit
git add .
git commit -m "Add new monitoring service"

# Push feature branch
git push -u origin feature/add-new-service

# Create pull request on GitHub
gh pr create --title "Add new monitoring service" --body "Description"

# After review, merge
gh pr merge

# Switch back to main
git checkout main
git pull
```

### Handling Secrets in Development

**Use git-secret or git-crypt for sensitive files:**

```bash
# Install git-secret
sudo apt install git-secret

# Initialize
cd ~/potatostack
git secret init

# Add GPG key
git secret tell your_email@example.com

# Hide .env
git secret add .env
git secret hide

# Now .env.secret can be committed safely
# Team members with GPG key can decrypt:
# git secret reveal
```

---

## Collaboration Best Practices

### If Sharing Repository with Team

1. **Never share `.env` file directly**
   - Each team member creates their own from `.env.example`
   - Share passwords via secure channels (KeePass, Bitwarden, etc.)

2. **Document all changes**
   - Write clear commit messages
   - Update documentation when changing configs
   - Use pull requests for review

3. **Code Review Checklist**
   - [ ] No hardcoded passwords or secrets
   - [ ] Resource limits appropriate
   - [ ] Health checks configured
   - [ ] Logging properly configured
   - [ ] Documentation updated
   - [ ] `.gitignore` not modified to expose secrets

4. **Communication**
   - Use GitHub Issues for tracking
   - Use GitHub Discussions for questions
   - Use GitHub Projects for roadmap

---

## Backup Strategy

### Before Major Changes

```bash
# Create backup branch
git checkout -b backup/before-major-change
git push -u origin backup/before-major-change

# Return to main
git checkout main

# Make changes...

# If something breaks, restore from backup:
git checkout backup/before-major-change
git checkout -b main-fixed
# Fix and test
git checkout main
git merge main-fixed
```

### Periodic Repository Backups

```bash
# Clone to external storage
git clone --mirror https://github.com/fishingpvalues/potatostack.git /mnt/external/potatostack-mirror

# Update mirror periodically
cd /mnt/external/potatostack-mirror
git remote update --prune
```

---

## Troubleshooting

### "remote: Support for password authentication was removed"

GitHub no longer accepts password authentication. Use:

1. **Personal Access Token (PAT):**
   - GitHub Settings → Developer settings → Personal access tokens → Generate new token
   - Use token as password when pushing

2. **SSH (Recommended):**
   - See "Option 3: Using SSH" above

### "fatal: detected dubious ownership"

```bash
git config --global --add safe.directory /path/to/potatostack
```

### Accidentally Committed .env File

```bash
# Remove from tracking
git rm --cached .env

# Commit removal
git commit -m "Remove .env from tracking"

# Push
git push

# CRITICAL: Rotate ALL passwords in the exposed .env file!
# The file is now in git history and considered compromised
```

### Large Files Error

```bash
# If you have large files (>100MB)
# Install Git LFS
sudo apt install git-lfs
git lfs install

# Track large files
git lfs track "*.tar.gz"
git add .gitattributes
git commit -m "Track large files with LFS"
```

---

## Additional GitHub Features

### GitHub Actions (CI/CD)

Create `.github/workflows/test.yml`:

```yaml
name: Test Stack

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate docker-compose
        run: docker-compose config
      - name: Check for secrets
        run: |
          if grep -r "password.*=" . --exclude-dir=.git --exclude=.env.example; then
            echo "Found hardcoded passwords!"
            exit 1
          fi
```

### GitHub Releases

```bash
# Tag a release
git tag -a v1.0.0 -m "Release v1.0.0: Initial production-ready version"
git push origin v1.0.0

# Or use GitHub CLI
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
```

### GitHub Pages (for documentation)

If public repository:
- Settings → Pages
- Source: Deploy from a branch
- Branch: main, folder: /docs
- Create `docs/` folder with documentation

---

## Security Monitoring

### GitHub Security Advisories

- Check: https://github.com/fishingpvalues/potatostack/security/advisories
- Enable notifications for security alerts
- Review and update dependencies regularly

### Dependabot Pull Requests

- Dependabot will create PRs for updates
- Review changelogs before merging
- Test in development before production

### Secret Scanning Alerts

If GitHub detects committed secrets:
1. **Immediately rotate the secret**
2. Remove from git history using BFG
3. Force push (if no collaborators)
4. Verify secret is not accessible

---

## Final Checklist Before Upload

- [ ] Read `SECURITY.md` completely
- [ ] Verified `.env` is in `.gitignore`
- [ ] Tested `git status` - no sensitive files listed
- [ ] Scanned for hardcoded secrets
- [ ] Chose repository visibility (private recommended)
- [ ] Enabled 2FA on GitHub account
- [ ] Generated strong GitHub password or using password manager
- [ ] Read GitHub's terms of service regarding data breach
- [ ] Have backup of all files locally
- [ ] Documented any custom changes in README
- [ ] Tested stack works with `.env.example` → `.env` workflow

---

**You're now ready to upload PotatoStack to GitHub securely!**

Remember:
- Keep repository private unless intentionally sharing
- Never commit the `.env` file
- Rotate passwords if accidentally exposed
- Monitor security advisories
- Keep dependencies updated

For questions or issues: https://github.com/fishingpvalues/potatostack/issues

Last updated: December 2025
