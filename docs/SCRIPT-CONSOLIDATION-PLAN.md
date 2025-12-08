# PotatoStack Script Consolidation Plan

## Current State Analysis

You have **20 shell scripts** scattered across the repository. This analysis categorizes them and provides recommendations for consolidation.

## Script Inventory & Analysis

### 📦 **Core Setup Scripts** (Root Level)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `setup.sh` | Main setup orchestrator | 240 | **KEEP** | Primary entry point - consolidate features from others |
| `preflight-check.sh` | Pre-deployment validation | 259 | **MERGE** | Integrate into `setup.sh` as `--preflight` flag |
| `setup-lepotato.sh` | Le Potato-specific setup | 504 | **MERGE** | Largely duplicates `setup.sh` - merge unique features |
| `deploy.sh` | Remote deployment script | 339 | **KEEP** | Unique SSH deployment functionality |
| `01-setup-zfs.sh` | ZFS pool creation | 154 | **KEEP** | Standalone ZFS setup (rarely used) |
| `02-migrate-and-update-docker.sh` | ZFS migration | 82 | **MERGE** | Integrate into `01-setup-zfs.sh` as Part 2 |

### 🔧 **Operational Scripts** (scripts/)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `scripts/health-check.sh` | System health validation | ~200 | **KEEP** | Essential for monitoring |
| `scripts/run_checks.sh` | Security/policy checks | ~100 | **MERGE** | Integrate into `health-check.sh` |
| `scripts/verify-vpn-killswitch.sh` | VPN leak testing | ~150 | **KEEP** | Critical security check |
| `scripts/verify-kopia-backups.sh` | Backup verification | ~180 | **KEEP** | Essential for backup validation |

### ⚙️ **System Optimization** (scripts/)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `scripts/setup-zram.sh` | ZRAM configuration | ~80 | **KEEP** | Useful for low-RAM systems |
| `scripts/usb-io-tuning.sh` | USB storage optimization | ~120 | **KEEP** | Le Potato-specific tuning |
| `scripts/nextcloud-optimize.sh` | Nextcloud tuning | ~90 | **KEEP** | Service-specific optimization |

### 🔐 **Secrets Management** (scripts/)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `scripts/edit-secrets.sh` | Edit encrypted secrets | ~60 | **MERGE** | Integrate into `scripts/secrets.sh` |
| `scripts/setup-secrets.sh` | Initialize secret store | ~100 | **MERGE** | Integrate into `scripts/secrets.sh` |
| `scripts/setup-decrypt-service.sh` | Decrypt service setup | ~80 | **MERGE** | Integrate into `scripts/secrets.sh` |

### 💾 **Kopia Backup Scripts** (scripts/kopia/)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `scripts/kopia/setup-policies.sh` | Kopia policy config | ~120 | **KEEP** | Essential for backup setup |
| `scripts/kopia/verify-backups.sh` | Backup verification | ~150 | **MERGE** | Duplicates `scripts/verify-kopia-backups.sh` |
| `scripts/kopia/multi-repo-example.sh` | Multi-repo example | ~80 | **KEEP** | Documentation/example |

### 🔄 **Systemd Integration** (systemd/)

| Script | Purpose | Lines | Keep/Merge? | Recommendation |
|--------|---------|-------|-------------|----------------|
| `systemd/install-systemd-services.sh` | Systemd service installer | ~100 | **KEEP** | Essential for auto-start |
| `systemd/ensure-potatostack-swap.sh` | Swap management | ~60 | **KEEP** | Critical for 2GB RAM |

---

## 🎯 Consolidation Strategy

### Phase 1: Merge Duplicate Setup Scripts

**Create: `setup.sh` (Enhanced Master Setup)**

Consolidate these into ONE setup script with modes:
- `setup-lepotato.sh` ← Merge Le Potato-specific optimizations
- `preflight-check.sh` ← Add as `./setup.sh --preflight` mode
- Core features from both

**Benefits**:
- Single entry point for all setup tasks
- Reduces confusion ("Which script do I run?")
- Easier to maintain

**Implementation**:
```bash
# New unified setup.sh usage:
./setup.sh                    # Full interactive setup
./setup.sh --preflight        # Pre-flight checks only
./setup.sh --non-interactive  # CI/CD mode
./setup.sh --zfs              # Include ZFS setup
```

### Phase 2: Consolidate Secrets Management

**Create: `scripts/secrets.sh` (Unified Secrets Manager)**

Merge these three into one tool:
- `scripts/edit-secrets.sh`
- `scripts/setup-secrets.sh`
- `scripts/setup-decrypt-service.sh`

**Implementation**:
```bash
# New unified secrets.sh usage:
./scripts/secrets.sh init               # Setup secret store
./scripts/secrets.sh edit [secret-name] # Edit specific secret
./scripts/secrets.sh decrypt            # Decrypt secrets
./scripts/secrets.sh setup-service      # Install decrypt service
```

### Phase 3: Merge Backup Verification Scripts

**Action**: Delete duplicate `scripts/kopia/verify-backups.sh`

Keep only `scripts/verify-kopia-backups.sh` (already in scripts/ root for easier access).

### Phase 4: Consolidate Check Scripts

**Merge: `scripts/run_checks.sh` → `scripts/health-check.sh`**

Create modes:
```bash
./scripts/health-check.sh             # Full health check
./scripts/health-check.sh --security  # Security checks only
./scripts/health-check.sh --quick     # Quick status
```

### Phase 5: Clean Up ZFS Scripts

**Action**: Merge `02-migrate-and-update-docker.sh` into `01-setup-zfs.sh`

Make ZFS setup a single script with two stages:
```bash
./01-setup-zfs.sh --create    # Stage 1: Create pool
./01-setup-zfs.sh --migrate   # Stage 2: Migrate Docker
```

---

## 📊 Summary of Changes

### Scripts to **KEEP AS-IS** (11 scripts)
1. ✅ `deploy.sh` - Remote deployment
2. ✅ `01-setup-zfs.sh` - ZFS setup (enhanced)
3. ✅ `scripts/health-check.sh` - Health monitoring (enhanced)
4. ✅ `scripts/verify-vpn-killswitch.sh` - VPN security
5. ✅ `scripts/verify-kopia-backups.sh` - Backup verification
6. ✅ `scripts/setup-zram.sh` - ZRAM config
7. ✅ `scripts/usb-io-tuning.sh` - USB optimization
8. ✅ `scripts/nextcloud-optimize.sh` - Nextcloud tuning
9. ✅ `scripts/kopia/setup-policies.sh` - Kopia policies
10. ✅ `scripts/kopia/multi-repo-example.sh` - Documentation
11. ✅ `systemd/install-systemd-services.sh` - Systemd installer
12. ✅ `systemd/ensure-potatostack-swap.sh` - Swap management

### Scripts to **CREATE** (2 new unified scripts)
1. 🆕 `setup.sh` - Enhanced master setup (merges 3 scripts)
2. 🆕 `scripts/secrets.sh` - Unified secrets manager (merges 3 scripts)

### Scripts to **DELETE** (7 redundant scripts)
1. ❌ `setup-lepotato.sh` - Merged into `setup.sh`
2. ❌ `preflight-check.sh` - Merged into `setup.sh --preflight`
3. ❌ `02-migrate-and-update-docker.sh` - Merged into `01-setup-zfs.sh`
4. ❌ `scripts/run_checks.sh` - Merged into `scripts/health-check.sh`
5. ❌ `scripts/edit-secrets.sh` - Merged into `scripts/secrets.sh`
6. ❌ `scripts/setup-secrets.sh` - Merged into `scripts/secrets.sh`
7. ❌ `scripts/setup-decrypt-service.sh` - Merged into `scripts/secrets.sh`
8. ❌ `scripts/kopia/verify-backups.sh` - Duplicate of root version

---

## 🔢 Final Script Count

**Before**: 20 scripts
**After**: 13 scripts
**Reduction**: 35% fewer scripts

---

## 📋 Implementation Checklist

### Step 1: Create Unified Setup Script
- [ ] Merge `setup.sh` + `setup-lepotato.sh` + `preflight-check.sh`
- [ ] Add CLI flags: `--preflight`, `--non-interactive`, `--zfs`
- [ ] Test all modes
- [ ] Update README with new usage

### Step 2: Create Unified Secrets Manager
- [ ] Create `scripts/secrets.sh`
- [ ] Merge functionality from 3 secrets scripts
- [ ] Add subcommands: `init`, `edit`, `decrypt`, `setup-service`
- [ ] Test all modes
- [ ] Update documentation

### Step 3: Enhance ZFS Setup
- [ ] Merge `02-migrate-and-update-docker.sh` into `01-setup-zfs.sh`
- [ ] Add `--create` and `--migrate` flags
- [ ] Test migration workflow
- [ ] Update docs

### Step 4: Enhance Health Check
- [ ] Merge `scripts/run_checks.sh` into `scripts/health-check.sh`
- [ ] Add `--security` and `--quick` modes
- [ ] Test all modes
- [ ] Update cron jobs

### Step 5: Clean Up Duplicates
- [ ] Delete 7 redundant scripts
- [ ] Update references in README
- [ ] Update Makefile targets
- [ ] Test all remaining scripts

### Step 6: Documentation
- [ ] Update `README.md` with new script structure
- [ ] Create `docs/SCRIPTS-REFERENCE.md`
- [ ] Update setup guides
- [ ] Update troubleshooting docs

---

## 🎨 New Simplified Structure

```
potatostack/
├── setup.sh                      # ⭐ Master setup (unified)
├── deploy.sh                     # Remote deployment
├── 01-setup-zfs.sh              # ZFS setup (2-stage)
├── Makefile                      # Quick commands
├── scripts/
│   ├── secrets.sh               # 🆕 Unified secrets manager
│   ├── health-check.sh          # Enhanced health monitoring
│   ├── verify-vpn-killswitch.sh
│   ├── verify-kopia-backups.sh
│   ├── setup-zram.sh
│   ├── usb-io-tuning.sh
│   ├── nextcloud-optimize.sh
│   └── kopia/
│       ├── setup-policies.sh
│       └── multi-repo-example.sh
└── systemd/
    ├── install-systemd-services.sh
    └── ensure-potatostack-swap.sh
```

---

## 🚀 Benefits of Consolidation

### For Users
- ✅ **Clearer onboarding** - One setup script to run
- ✅ **Less confusion** - Fewer "which script?" questions
- ✅ **Better discoverability** - `./setup.sh --help` shows all options
- ✅ **Faster setup** - No guessing which scripts to run

### For Maintainers
- ✅ **Less code duplication** - DRY principle
- ✅ **Easier updates** - Change once, not 3 times
- ✅ **Better testing** - Fewer integration points
- ✅ **Cleaner repo** - Professional appearance

### For Documentation
- ✅ **Simpler guides** - Fewer steps to document
- ✅ **Less confusion** - Clear entry points
- ✅ **Better examples** - Unified patterns

---

## 🔍 Migration Path for Users

### Old Way (Confusing)
```bash
# Users had to figure out the order:
sudo ./preflight-check.sh      # Maybe?
sudo ./setup.sh                 # Or this first?
sudo ./setup-lepotato.sh       # Wait, which one?
sudo ./01-setup-zfs.sh         # And this?
sudo ./02-migrate-and-update-docker.sh  # Then this?
```

### New Way (Clear)
```bash
# Simple, obvious workflow:
sudo ./setup.sh --preflight    # Check readiness
sudo ./setup.sh                # Full setup
sudo ./01-setup-zfs.sh --create   # (Optional) ZFS
sudo ./01-setup-zfs.sh --migrate  # (Optional) Migrate
```

---

## ⚠️ Backward Compatibility

To avoid breaking existing workflows during transition:

1. **Keep old scripts temporarily** with deprecation warnings:
   ```bash
   #!/bin/bash
   echo "WARNING: This script is deprecated."
   echo "Use: ./setup.sh --preflight"
   echo "Redirecting in 5 seconds..."
   sleep 5
   exec ./setup.sh --preflight "$@"
   ```

2. **Add symlinks** for common old patterns:
   ```bash
   ln -s setup.sh preflight-check.sh  # Redirect
   ```

3. **Update all docs** in a single PR after testing

---

## 📝 Next Steps

1. Review this consolidation plan
2. Confirm approach with maintainers
3. Implement in feature branch
4. Test thoroughly
5. Update documentation
6. Merge and announce changes

**Estimated effort**: 4-6 hours of focused work

**Impact**: Significantly improved UX and maintainability
