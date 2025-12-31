# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub issue templates for bug reports and feature requests
- Pull request template with comprehensive checklist
- CODEOWNERS file for code ownership and review automation
- MIT License
- CHANGELOG.md for tracking version history
- Enterprise-ready repository governance files

### Changed
- Updated repository structure for better organization

## [1.0.0] - 2025-12-31

### Added
- Comprehensive SOTA 2025 testing suite for both main and light stacks
- Complete monitoring stack with Grafana, Prometheus, and Loki
- RSS reader service integration
- Security scanning with Trivy integration (`security-scan.sh`)
- SOTA 2025 formatters and linters (shellcheck, shfmt, yamllint, prettier, yq)
- Validation suite with 7-step validation process (`validate-stack.sh`)
- Git hooks for code quality enforcement:
  - `pre-commit`: Auto-formats shell scripts and YAML files
  - `commit-msg`: Validates Conventional Commits format
  - `pre-push`: Runs validation and security checks
- CONTRIBUTING.md with development guidelines and commit conventions
- SECURITY.md with security policy and best practices
- GitHub Actions workflow with linting, validation, and security scanning
- Makefile targets: `lint`, `format`, `validate`, `security`
- .prettierrc configuration for consistent YAML formatting
- OS-aware testing with Docker availability detection
- 3-tier storage optimization for SSD+HDD configurations

### Changed
- Enhanced stack-test.sh with Termux/proot support
- Improved Docker Compose configuration validation
- Updated .gitignore to exclude test reports and temporary files
- Optimized slskd service with SOTA 2025 best practices

### Fixed
- Docker Compose path resolution in proot environments
- Temporary directory permissions in Termux
- Shell script formatting consistency across all scripts
- YAML syntax validation and formatting

### Security
- Implemented secret detection in pre-push hooks
- Added comprehensive security scanning in CI/CD pipeline
- Configured proper file permissions checks
- Added Docker Compose security best practices validation

## [0.1.0] - 2025-12-30

### Added
- Initial PotatoStack release
- Main stack with 100 services (16GB RAM)
- Light stack with 13 core services (2GB RAM)
- Basic Docker Compose configuration
- README documentation

[Unreleased]: https://github.com/fishingpvalues/potatostack/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/fishingpvalues/potatostack/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/fishingpvalues/potatostack/releases/tag/v0.1.0
