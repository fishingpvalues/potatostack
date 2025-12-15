# PotatoStack Test Suite

Enterprise-grade testing for Le Potato deployment.

## Test Structure

```
tests/
├── unit/           # Unit tests (fast, no cluster required)
├── integration/    # Integration tests (requires k8s cluster)
└── e2e/            # End-to-end smoke tests
```

## Running Tests

### Local Testing

```bash
# Run all tests
make test-all

# Run specific test suites
make test-unit          # Unit tests only
make test-integration   # Integration tests (requires k8s)
make test-e2e           # E2E smoke tests

# Linting
make lint
```

### CI/CD (GitHub Actions)

Tests run automatically on:
- Every push to `main` or `develop`
- Every pull request to `main`

## Unit Tests

### 1. Resource Limits Test
**File**: `tests/unit/test_resource_limits.sh`
**Purpose**: Verify all Helm values have proper resource limits for Le Potato (2GB RAM)

```bash
./tests/unit/test_resource_limits.sh
```

Checks:
- Memory limits exist for all services
- Total RAM usage ≤ 1.8GB (200MB buffer)
- CPU limits configured
- Ingress uses cert-manager

### 2. YAML Syntax Test
**File**: `tests/unit/test_yaml_syntax.sh`
**Purpose**: Validate all YAML files for syntax errors

Requirements: `yq` (install: `brew install yq`)

```bash
./tests/unit/test_yaml_syntax.sh
```

### 3. Shell Script Test
**File**: `tests/unit/test_shell_scripts.sh`
**Purpose**: Lint all shell scripts with shellcheck

Requirements: `shellcheck` (install: `brew install shellcheck`)

```bash
./tests/unit/test_shell_scripts.sh
```

## Integration Tests

### K8s Deployment Test
**File**: `tests/integration/test_k8s_deploy.sh`
**Purpose**: Verify k3s cluster and operators are properly deployed

```bash
./tests/integration/test_k8s_deploy.sh
```

Checks:
- kubectl connectivity
- cert-manager deployment
- ingress-nginx deployment
- kyverno deployment
- potatostack namespace
- Resource quotas
- Network policies

## E2E Tests

### Smoke Test
**File**: `tests/e2e/test_smoke.sh`
**Purpose**: Quick validation that critical services are running

```bash
./tests/e2e/test_smoke.sh
```

Checks:
- PostgreSQL service
- Redis service
- Prometheus service
- Grafana service
- Service endpoints

## Pre-commit Hooks

Install pre-commit hooks to run tests automatically:

```bash
pip install pre-commit
pre-commit install
```

Hooks run:
1. Trailing whitespace check
2. YAML syntax validation
3. Shellcheck
4. Resource limits test (on Helm values changes)

## GitHub Actions CI

### CI Pipeline
**File**: `.github/workflows/ci.yaml`

Jobs:
1. **lint** - Shellcheck + YAML validation
2. **unit-tests** - All unit tests
3. **integration-tests** - K8s deployment tests
4. **security-scan** - Trivy vulnerability scanning

### Release Pipeline
**File**: `.github/workflows/release.yaml`

Triggers on version tags (`v*`) and creates GitHub releases with packaged artifacts.

## Test Requirements

### Local Development
- `shellcheck` - Shell script linting
- `yq` - YAML processing
- `kubectl` - Kubernetes CLI (for integration tests)
- `helm` - Helm CLI (for integration tests)

### CI Environment
All dependencies installed automatically via GitHub Actions.

## Writing New Tests

### Unit Test Template

```bash
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "Test Name"
echo "=========="

# Test logic here
if test_passes; then
  echo -e "${GREEN}✓${NC} Test description"
  ((PASSED++))
else
  echo -e "${RED}✗${NC} Test description"
  ((FAILED++))
fi

# Exit
if [ "$FAILED" -gt 0 ]; then
  exit 1
else
  exit 0
fi
```

## Continuous Improvement

- Add new tests for new features
- Update resource limits as services are added/removed
- Keep CI pipeline fast (<5 minutes)
- Monitor test coverage

## Support

For test failures, check:
1. GitHub Actions logs
2. Local test output
3. Kubernetes events: `kubectl get events -A`
4. Pod logs: `kubectl logs -n potatostack <pod>`
