# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via:
- Email: [Your security email]
- Private Security Advisory (preferred): Use GitHub's "Security" tab

### What to Include

When reporting a vulnerability, please include:

- Type of vulnerability (e.g., SQL injection, XSS, exposed secrets)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if available)
- Impact of the vulnerability
- Any potential fixes you've identified

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 7 days
  - Medium: 30 days
  - Low: 90 days

## Security Best Practices

### Secrets Management

**Never commit secrets to the repository!**

- Use `.env` files for secrets (gitignored by default)
- Copy `.env.example` to `.env` and fill in your values
- Use Docker secrets or external secret managers in production
- Rotate credentials regularly

### Environment Variables

Required secrets to configure:

```bash
# Databases
POSTGRES_SUPER_PASSWORD=
MONGO_ROOT_PASSWORD=

# Authentication
AUTHENTIK_SECRET_KEY=
VAULTWARDEN_ADMIN_TOKEN=

# VPN
WIREGUARD_PRIVATE_KEY=
WIREGUARD_ADDRESSES=

# And more in .env.example
```

### Image Security

- **Pin versions**: Never use `:latest` tags in production
- **Scan regularly**: Run `make security` before deployment
- **Update frequently**: Use Renovate bot for dependency updates
- **Minimal images**: Use Alpine or distroless where possible

### Network Security

- **Reverse Proxy**: Use Traefik with automatic SSL
- **Firewall**: Configure UFW or iptables
- **VPN Access**: Use Tailscale or WireGuard for remote access
- **Network Segmentation**: Use Docker networks to isolate services
- **Docker API**: Use a socket proxy with restricted permissions (Homarr uses `socket-proxy`)

### Access Control

- **Strong Passwords**: Use password managers (Vaultwarden included!)
- **2FA**: Enable where available (Authentik supports it)
- **RBAC**: Configure role-based access in Authentik
- **API Keys**: Rotate regularly, use scoped permissions

### Monitoring & Logging

- **Log Aggregation**: Loki collects all container logs
- **Alerting**: Configure Alertmanager for security events
- **Audit Logs**: Review regularly via Grafana
- **Intrusion Detection**: CrowdSec monitors for threats

## Security Scanning

### Automated Scans

Run security scan before deployment:

```bash
# Full security scan
make security

# Includes:
# - Secret detection
# - Configuration audit
# - Image version check
# - Trivy vulnerability scan
# - Permission check
```

### CI/CD Integration

GitHub Actions runs security scans automatically on:
- Every push to main
- Pull requests
- Weekly schedule

### Manual Scans

```bash
# Scan with Trivy (install first)
trivy config docker-compose.yml
trivy image <image-name>

# Check for secrets
git secrets --scan

# Audit dependencies
docker scout cves <image-name>
```

## Vulnerability Disclosure

When a security vulnerability is discovered:

1. **Assessment**: Evaluate severity and impact
2. **Fix Development**: Create patch in private
3. **Testing**: Verify fix resolves issue
4. **Coordination**: Notify affected users
5. **Release**: Publish fix and security advisory
6. **Disclosure**: Public disclosure after fix is available

## Security Features

### Built-in Security

- **CrowdSec**: Modern IPS/IDS with community intelligence
- **Fail2Ban**: Intrusion prevention
- **Traefik**: Automatic SSL/TLS with Let's Encrypt
- **Authentik**: SSO with 2FA support
- **Vaultwarden**: Self-hosted password manager
- **AdGuard Home**: DNS-level ad/malware blocking
- **Trivy**: Container vulnerability scanning

### Network Security

- **Gluetun**: VPN client with killswitch
- **Tailscale**: Secure mesh VPN for remote access
- **CrowdSec Bouncer**: Blocks malicious IPs

### Data Protection

- **Encryption at Rest**: Volume encryption (optional)
- **Encryption in Transit**: SSL/TLS everywhere
- **Backup Encryption**: Kopia with encryption
- **Database Security**: Network isolation, strong passwords

## Security Checklist

Before deployment:

- [ ] Change all default passwords
- [ ] Configure `.env` with secure secrets
- [ ] Enable firewall (UFW/iptables)
- [ ] Set up automatic updates (Renovate/Watchtower)
- [ ] Configure backup encryption (Kopia)
- [ ] Enable SSL/TLS (Traefik + Let's Encrypt)
- [ ] Set up monitoring alerts (Alertmanager)
- [ ] Review exposed ports
- [ ] Scan for vulnerabilities (`make security`)
- [ ] Enable 2FA where available
- [ ] Configure fail2ban rules
- [ ] Test disaster recovery

## Compliance

### Data Privacy

- GDPR considerations for EU users
- Data retention policies configured in Loki/Prometheus
- User data deletion procedures documented

### Standards

- CIS Docker Benchmark compliance
- OWASP Top 10 awareness
- Supply chain security (SLSA)

## Resources

- [OWASP Docker Security](https://owasp.org/www-project-docker-security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [CrowdSec Documentation](https://doc.crowdsec.net/)

## Security Updates

Subscribe to security advisories:
- GitHub Watch → Custom → Security alerts
- Enable Dependabot alerts
- Monitor Renovate PRs

---

Last updated: 2025-12-31

For questions or concerns, please open an issue or contact the maintainers.
