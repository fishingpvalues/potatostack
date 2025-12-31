# Contributing to PotatoStack

Thank you for considering contributing to PotatoStack! This document provides guidelines and best practices for contributing.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Guidelines](#commit-guidelines)
- [Testing](#testing)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Basic understanding of Docker, YAML, and shell scripting

### Development Tools (Recommended)

Install the following tools for the best development experience:

```bash
# Termux/Android
pkg install shellcheck shfmt yamllint docker git

# Linux/macOS
# Install via package manager or npm
npm install -g prettier
```

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/potatostack.git
   cd potatostack
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/potatostack.git
   ```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 2. Make Changes

- Write clean, readable code
- Follow existing code style and patterns
- Update documentation if needed
- Add tests for new features

### 3. Run Validators

Before committing, run:

```bash
make lint      # Run all linters and validators
make format    # Auto-format code
make security  # Run security scan
make validate  # Validate docker-compose.yml
```

### 4. Test Your Changes

```bash
# Validate configuration
make validate

# Run full test suite (requires Docker daemon)
make test

# Quick health check
make test-quick
```

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

### Format

```
type(scope): subject

body (optional)

footer (optional)
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `build`: Build system or dependency changes
- `ci`: CI/CD pipeline changes
- `chore`: Other changes that don't modify src or test files

### Examples

```bash
feat: add health check endpoint for Grafana
fix(monitoring): correct Prometheus scrape interval
docs: update README with installation steps
chore: upgrade dependencies to latest versions
```

### Git Hooks

The repository has automatic git hooks that will:

**Pre-commit**: Auto-format shell scripts and YAML files
**Commit-msg**: Validate commit message format
**Pre-push**: Run security and validation checks

To bypass hooks (not recommended):
```bash
git commit --no-verify
git push --no-verify
```

## Testing

### Validation Tests

```bash
# YAML syntax validation
yamllint docker-compose.yml

# Docker Compose config validation
docker-compose config

# Shell script linting
shellcheck *.sh

# Comprehensive validation (SOTA 2025)
./validate-stack.sh
```

### Integration Tests

```bash
# Full integration test suite
./stack-test.sh

# Or using Make
make test
```

### Security Scanning

```bash
# Run security vulnerability scan
./security-scan.sh

# Or using Make
make security
```

## Code Style

### Shell Scripts

- Use `#!/bin/bash` shebang
- Set `set -euo pipefail` for safety
- Use shellcheck for linting
- Format with shfmt (2 spaces, no tabs)
- Add comments for complex logic
- Use meaningful variable names

```bash
#!/bin/bash
set -euo pipefail

# Good variable names
SERVICE_NAME="grafana"
MAX_RETRIES=3

# Use functions for reusability
check_service_health() {
    local service=$1
    docker inspect --format='{{.State.Health.Status}}' "$service"
}
```

### YAML Files

- Use 2 spaces for indentation
- No tabs
- Max line length: 120 characters
- Format with prettier or yq
- Use yamllint for validation

### Docker Compose

- Pin image versions (avoid `:latest`)
- Use health checks where applicable
- Set resource limits
- Use secrets for sensitive data
- Document environment variables

## Pull Request Process

### 1. Update Your Branch

```bash
git fetch upstream
git rebase upstream/main
```

### 2. Run All Checks

```bash
make lint      # Validation
make format    # Formatting
make security  # Security scan
```

### 3. Push to Your Fork

```bash
git push origin your-branch-name
```

### 4. Create Pull Request

- Go to GitHub and create a PR from your fork
- Fill in the PR template
- Link related issues
- Add clear description of changes

### PR Title Format

Follow the same convention as commit messages:

```
feat: add new monitoring dashboard
fix: resolve database connection timeout
docs: improve installation guide
```

### PR Checklist

- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Commit messages follow conventions
- [ ] No merge conflicts
- [ ] Security scan passed

## Review Process

1. Automated checks run via GitHub Actions
2. Maintainers review code
3. Address feedback and requested changes
4. Once approved, maintainers will merge

## Need Help?

- Open an issue for bugs or feature requests
- Check existing issues before creating new ones
- Be respectful and constructive

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to PotatoStack! 🥔
