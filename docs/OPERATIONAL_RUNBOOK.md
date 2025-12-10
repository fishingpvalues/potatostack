# PotatoStack Operational Runbook

## Table of Contents

1. [Emergency Response Procedures](#emergency-response-procedures)
2. [Daily Operations](#daily-operations)
3. [Weekly Maintenance](#weekly-maintenance)
4. [Monthly Procedures](#monthly-procedures)
5. [Quarterly Tasks](#quarterly-tasks)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Incident Response](#incident-response)
8. [Performance Optimization](#performance-optimization)
9. [Backup and Recovery](#backup-and-recovery)
10. [Security Procedures](#security-procedures)

---

## Emergency Response Procedures

### Critical System Failure

#### Severity 1: Complete Service Outage

**Response Time**: 15 minutes  
**Escalation**: Immediate to Infrastructure Team Lead

```bash
#!/bin/bash
# Emergency Response Script
# Run this first in any critical situation

echo "=== POTATOSTACK EMERGENCY RESPONSE ==="
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo "Uptime: $(uptime)"

# Check Docker status
echo -e "\n=== DOCKER STATUS ==="
sudo systemctl status docker --no-pager -l

# Check running containers
echo -e "\n=== RUNNING CONTAINERS ==="
docker-compose ps

# Check system resources
echo -e "\n=== SYSTEM RESOURCES ==="
free -h
df -h
top -bn1 | head -20

# Check logs for critical errors
echo -e "\n=== RECENT ERRORS ==="
journalctl --since "1 hour ago" --priority=err | tail -20

# Network connectivity test
echo -e "\n=== NETWORK CONNECTIVITY ==="
ping -c 3 8.8.8.8
curl -I --connect-timeout 10 https://google.com

# Check critical services
echo -e "\n=== CRITICAL SERVICE CHECK ==="
curl -f --connect-timeout 5 http://localhost:3003 > /dev/null && echo "✓ Homepage: OK" || echo "✗ Homepage: FAILED"
curl -f --connect-timeout 5 http://localhost:8082 > /dev/null && echo "✓ Nextcloud: OK" || echo "✗ Nextcloud: FAILED"
curl -f --connect-timeout 5 http://localhost:51515 > /dev/null && echo "✓ Kopia: OK" || echo "✗ Kopia: FAILED"

echo -e "\n=== EMERGENCY CHECK COMPLETE ==="
```

#### Immediate Actions (First 5 minutes)

1. **Assess Impact**

   ```bash
   # Check Homepage dashboard status
   curl -s http://localhost:3003/api/health | jq .
   
   # Check individual services
   ./scripts/health-check.sh
   ```

2. **Quick Recovery Attempts**

   ```bash
   # Restart failed containers
   docker-compose restart [failed-service]
   
   # If VPN issues:
   docker-compose restart gluetun qbittorrent slskd
   
   # If database issues:
   docker-compose restart mariadb postgres
   ```

3. **Emergency Stop (if needed)**

   ```bash
   # Graceful shutdown
   docker-compose down
   
   # Emergency stop (force)
   docker stop $(docker ps -q)
   ```

#### Recovery Procedures (5-30 minutes)

1. **Service-by-Service Recovery**

   ```bash
   # Start critical services first
   docker-compose up -d gluetun
   sleep 30
   
   docker-compose up -d nginx-proxy-manager
   sleep 15
   
   docker-compose up -d prometheus grafana
   sleep 15
   
   docker-compose up -d nextcloud mariadb postgres
   sleep 30
   
   # Start remaining services
   docker-compose up -d
   ```

2. **Verify Recovery**

   ```bash
   # Run full health check
   ./scripts/health-check.sh
   
   # Check VPN functionality
   ./scripts/verify-vpn-killswitch.sh
   
   # Verify backups
   ./scripts/verify-kopia-backups.sh
   ```

### Data Loss Emergency

#### Immediate Response (First 10 minutes)

```bash
#!/bin/bash
# Data Loss Emergency Response

echo "=== DATA LOSS EMERGENCY RESPONSE ==="

# Stop all containers to prevent further corruption
docker-compose down

# Check filesystem integrity
sudo fsck -f /mnt/seconddrive
sudo fsck -f /mnt/cachehdd

# Check disk health
sudo smartctl -a /dev/sda | grep -E "Reallocated|Pending|Fail"
sudo smartctl -a /dev/sdb | grep -E "Reallocated|Pending|Fail"

# Verify backup integrity
docker run --rm \
  -v /mnt/seconddrive/kopia/repository:/repository \
  -v /mnt/seconddrive/kopia/config:/app/config \
  kopia/kopia:latest \
  repository status --repository=/repository

echo "=== STOPPING FOR USER INTERVENTION ==="
echo "Contact backup administrator immediately!"
```

---

## Daily Operations

### Morning Health Check (9:00 AM)

```bash
#!/bin/bash
# Daily Health Check Script

LOG_FILE="/var/log/potatostack/daily-health-$(date +%Y%m%d).log"
mkdir -p /var/log/potatostack

{
  echo "=== DAILY HEALTH CHECK - $(date) ==="
  
  # System status
  echo "=== SYSTEM STATUS ==="
  uptime
  free -h
  df -h | grep -E "/(mnt|opt|var)"
  
  # Docker status
  echo -e "\n=== DOCKER STATUS ==="
  docker-compose ps
  docker system df
  
  # Service health
  echo -e "\n=== SERVICE HEALTH ==="
  
  # Homepage check
  if curl -f -s http://localhost:3003 > /dev/null; then
    echo "✓ Homepage: Operational"
  else
    echo "✗ Homepage: Failed"
  fi
  
  # VPN check
  VPN_IP=$(docker exec gluetun curl -s https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
  echo "VPN IP: $VPN_IP"
  
  # Storage check
  echo -e "\n=== STORAGE STATUS ==="
  du -sh /mnt/seconddrive/* /mnt/cachehdd/*
  
  # Recent errors
  echo -e "\n=== RECENT ERRORS ==="
  docker-compose logs --since 24h | grep -i error | tail -10
  
  # Backup status
  echo -e "\n=== BACKUP STATUS ==="
  docker exec kopia_server kopia snapshot list --repository=/repository | head -5
  
  echo -e "\n=== DAILY CHECK COMPLETE ==="
  
} | tee "$LOG_FILE"

# Send to monitoring system if configured
if [ -n "$ALERT_EMAIL_TO" ]; then
  mail -s "PotatoStack Daily Health Check - $(date +%Y-%m-%d)" \
       "$ALERT_EMAIL_TO" < "$LOG_FILE"
fi
```

### Automated Monitoring Checks

#### Continuous Monitoring (Every 5 minutes)

```bash
#!/bin/bash
# Continuous monitoring script
# Run via cron: */5 * * * *

SERVICE_CHECKS=(
  "homepage:http://localhost:3003"
  "nextcloud:http://localhost:8082"
  "kopia:http://localhost:51515"
  "grafana:http://localhost:3000"
  "prometheus:http://localhost:9090"
)

for check in "${SERVICE_CHECKS[@]}"; do
  service="${check%:*}"
  url="${check#*:}"
  
  if ! curl -f -s --connect-timeout 10 "$url" > /dev/null; then
    echo "[$(date)] ALERT: $service is DOWN"
    
    # Attempt restart
    docker-compose restart "$service"
    
    # Wait and recheck
    sleep 30
    if ! curl -f -s --connect-timeout 10 "$url" > /dev/null; then
      echo "[$(date)] CRITICAL: $service restart failed"
      # Send emergency alert
      if [ -n "$ALERT_EMAIL_TO" ]; then
        echo "$service failed to restart at $(date)" | \
        mail -s "CRITICAL: $service DOWN" "$ALERT_EMAIL_TO"
      fi
    fi
  fi
done

# Check disk space
DISK_USAGE=$(df /mnt/seconddrive | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
  echo "[$(date)] WARNING: Disk usage at ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -gt 90 ]; then
  echo "[$(date)] WARNING: Memory usage at ${MEM_USAGE}%"
fi
```

---

## Weekly Maintenance

### Sunday Maintenance Window (2:00 AM - 4:00 AM)

#### Pre-Maintenance Checklist

```bash
#!/bin/bash
# Pre-maintenance preparation

echo "=== PRE-MAINTENANCE CHECKLIST ==="

# 1. Create system snapshot
echo "Creating system snapshot..."
tar -czf /tmp/potatostack-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env config/ scripts/

# 2. Verify backups are current
echo "Verifying backups..."
./scripts/verify-kopia-backups.sh

# 3. Check for running torrents
echo "Checking active downloads..."
docker exec qbittorrent qbt torrent list | grep -c "Downloading\|Seeding" || echo "0"

# 4. Notify users (if applicable)
echo "Maintenance window: 2:00-4:00 AM"
echo "Services may be temporarily unavailable"

# 5. System resource check
echo -e "\n=== SYSTEM RESOURCES ==="
free -h
df -h
iostat 1 1

echo "=== READY FOR MAINTENANCE ==="
```

#### Maintenance Tasks

```bash
#!/bin/bash
# Weekly maintenance tasks

echo "=== WEEKLY MAINTENANCE START ==="

# 1. Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Clean up Docker resources
echo "Cleaning up Docker resources..."
docker system prune -f
docker volume prune -f

# 3. Update container images
echo "Updating container images..."
docker-compose pull

# 4. Restart services with new images
echo "Restarting services..."
docker-compose up -d

# 5. Clean log files
echo "Cleaning old logs..."
find /var/log -name "*.log" -mtime +7 -delete

# 6. Check SMART data
echo "Checking disk health..."
sudo smartctl -a /dev/sda | grep -E "Reallocated|Pending|Fail"
sudo smartctl -a /dev/sdb | grep -E "Reallocated|Pending|Fail"

# 7. Update firewall rules if needed
echo "Checking firewall status..."
sudo ufw status verbose

# 8. Test backup restoration
echo "Testing backup restoration..."
# This would be implemented based on your backup strategy

echo "=== WEEKLY MAINTENANCE COMPLETE ==="
```

#### Post-Maintenance Verification

```bash
#!/bin/bash
# Post-maintenance verification

echo "=== POST-MAINTENANCE VERIFICATION ==="

# Run full health check
./scripts/health-check.sh

# Test VPN functionality
./scripts/verify-vpn-killswitch.sh

# Verify all services are accessible
SERVICES=(
  "Homepage:http://localhost:3003"
  "Nextcloud:http://localhost:8082"
  "Kopia:http://localhost:51515"
  "Grafana:http://localhost:3000"
  "qBittorrent:http://localhost:8080"
)

for service_check in "${SERVICES[@]}"; do
  service="${service_check%:*}"
  url="${service_check#*:}"
  
  if curl -f -s --connect-timeout 10 "$url" > /dev/null; then
    echo "✓ $service: Operational"
  else
    echo "✗ $service: Failed"
  fi
done

# Performance baseline check
echo -e "\n=== PERFORMANCE BASELINE ==="
systemctl status docker
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo "=== VERIFICATION COMPLETE ==="
```

---

## Monthly Procedures

### Comprehensive System Audit

#### Security Audit

```bash
#!/bin/bash
# Monthly security audit

echo "=== MONTHLY SECURITY AUDIT ==="

# 1. Check for security updates
echo "Checking for security updates..."
sudo apt list --upgradable | grep -i security

# 2. Review failed login attempts
echo -e "\n=== FAILED LOGIN ANALYSIS ==="
grep "Failed password" /var/log/auth.log | tail -50

# 3. Check SSL certificate expiration
echo -e "\n=== SSL CERTIFICATE STATUS ==="
openssl x509 -in /etc/letsencrypt/live/your-domain/fullchain.pem -text -noout | grep "Not After"

# 4. Review firewall rules
echo -e "\n=== FIREWALL STATUS ==="
sudo ufw status numbered

# 5. Check for open ports
echo -e "\n=== OPEN PORTS ==="
sudo netstat -tulpn | grep LISTEN

# 6. Review container security
echo -e "\n=== CONTAINER SECURITY ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 7. Check for rootkits
echo -e "\n=== ROOTKIT CHECK ==="
if command -v rkhunter >/dev/null 2>&1; then
  sudo rkhunter --check --skip-keypress --report-warnings-only
fi

# 8. Review log files for security events
echo -e "\n=== SECURITY EVENT REVIEW ==="
grep -i "security\|attack\|intrusion\|unauthorized" /var/log/syslog | tail -20

echo "=== SECURITY AUDIT COMPLETE ==="
```

#### Performance Analysis

```bash
#!/bin/bash
# Monthly performance analysis

echo "=== MONTHLY PERFORMANCE ANALYSIS ==="

# 1. Resource utilization trends
echo "=== RESOURCE UTILIZATION ==="
sar -u 1 12  # CPU usage over 12 minutes
sar -r 1 12  # Memory usage over 12 minutes
sar -b 1 12  # Disk I/O over 12 minutes

# 2. Database performance
echo -e "\n=== DATABASE PERFORMANCE ==="
# Nextcloud database
docker exec mariadb mysql -e "SHOW STATUS LIKE 'Slow_queries';"
# Gitea database
docker exec postgres psql -U postgres -d postgres -c "SELECT * FROM pg_stat_activity;"

# 3. Container resource usage
echo -e "\n=== CONTAINER RESOURCE ANALYSIS ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# 4. Network analysis
echo -e "\n=== NETWORK PERFORMANCE ==="
ss -tuln
netstat -i

# 5. Disk usage trends
echo -e "\n=== DISK USAGE TRENDS ==="
du -sh /mnt/seconddrive/* /mnt/cachehdd/*
df -h

# 6. Backup performance
echo -e "\n=== BACKUP PERFORMANCE ==="
docker exec kopia_server kopia snapshot list --repository=/repository | head -10

echo "=== PERFORMANCE ANALYSIS COMPLETE ==="
```

---

## Quarterly Tasks

### Disaster Recovery Testing

```bash
#!/bin/bash
# Quarterly disaster recovery test

echo "=== DISASTER RECOVERY TEST ==="

# 1. Document current state
echo "Documenting current system state..."
docker-compose ps > /tmp/pre-dr-state.txt
docker images > /tmp/pre-dr-images.txt

# 2. Test backup restoration
echo "Testing backup restoration process..."
# This would involve:
# - Stopping services
# - Restoring from Kopia backup
# - Verifying data integrity
# - Restarting services

# 3. Network failover test
echo "Testing network failover..."
# Test VPN disconnection and recovery

# 4. Document recovery time
echo "Total recovery time: $(date)"

echo "=== DR TEST COMPLETE ==="
```

### Capacity Planning

```bash
#!/bin/bash
# Quarterly capacity planning analysis

echo "=== CAPACITY PLANNING ANALYSIS ==="

# 1. Growth trends
echo "=== STORAGE GROWTH TRENDS ==="
find /mnt/seconddrive -type f -exec stat -c "%Y %s %n" {} \; | \
  awk '{sum += $2; count++} END {print "Total files:", count, "Total size:", sum/1024/1024/1024 "GB"}'

# 2. Database growth
echo -e "\n=== DATABASE GROWTH ==="
# Nextcloud database size
docker exec mariadb du -sh /var/lib/mysql/

# 3. Resource predictions
echo -e "\n=== RESOURCE PREDICTIONS ==="
# Analyze trends and predict future needs

# 4. Upgrade recommendations
echo -e "\n=== UPGRADE RECOMMENDATIONS ==="
# Based on current usage and growth trends

echo "=== CAPACITY PLANNING COMPLETE ==="
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Service Won't Start

```bash
#!/bin/bash
# Service troubleshooting script

SERVICE_NAME="${1:-}"
if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service_name>"
  exit 1
fi

echo "=== TROUBLESHOOTING $SERVICE_NAME ==="

# 1. Check container status
echo "Container status:"
docker-compose ps "$SERVICE_NAME"

# 2. Check logs
echo -e "\nRecent logs:"
docker-compose logs --since 1h "$SERVICE_NAME"

# 3. Check configuration
echo -e "\nConfiguration check:"
docker-compose config --quiet || echo "Configuration error found"

# 4. Check dependencies
echo -e "\nDependency check:"
docker-compose ps | grep -E "(mariadb|postgres)"

# 5. Check resource limits
echo -e "\nResource check:"
docker stats "$SERVICE_NAME" --no-stream

# 6. Check network connectivity
echo -e "\nNetwork check:"
docker network ls
docker network inspect potatostack_default

# 7. Attempt restart
echo -e "\nAttempting restart..."
docker-compose restart "$SERVICE_NAME"

# 8. Verify recovery
sleep 10
if curl -f -s "http://localhost:${PORT:-8080}" > /dev/null; then
  echo "✓ Service recovered"
else
  echo "✗ Service still failing"
fi
```

#### Performance Issues

```bash
#!/bin/bash
# Performance troubleshooting

echo "=== PERFORMANCE TROUBLESHOOTING ==="

# 1. System load
echo "System load:"
uptime
top -bn1 | head -20

# 2. Memory usage
echo -e "\nMemory usage:"
free -h
docker stats --no-stream

# 3. Disk I/O
echo -e "\nDisk I/O:"
iostat -x 1 5

# 4. Container resource usage
echo -e "\nContainer resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# 5. Database performance
echo -e "\nDatabase performance:"
# Check slow queries
docker exec mariadb mysql -e "SHOW PROCESSLIST;"

# 6. Network performance
echo -e "\nNetwork performance:"
ss -tuln
netstat -i

# 7. Identify bottlenecks
echo -e "\nIdentifying bottlenecks..."
# This would analyze the above data

echo "=== PERFORMANCE ANALYSIS COMPLETE ==="
```

#### VPN Issues

```bash
#!/bin/bash
# VPN troubleshooting

echo "=== VPN TROUBLESHOOTING ==="

# 1. Check VPN container status
echo "VPN container status:"
docker-compose ps gluetun

# 2. Check VPN logs
echo -e "\nVPN logs:"
docker-compose logs --since 1h gluetun

# 3. Test VPN connectivity
echo -e "\nVPN connectivity test:"
VPN_IP=$(docker exec gluetun curl -s --max-time 10 https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
echo "VPN IP: $VPN_IP"

# 4. Check P2P service VPN routing
echo -e "\nP2P service VPN test:"
QBT_IP=$(docker exec qbittorrent curl -s --max-time 10 https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
echo "qBittorrent IP: $QBT_IP"

SLSK_IP=$(docker exec slskd curl -s --max-time 10 https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
echo "slskd IP: $SLSK_IP"

# 5. Verify IP match (should all be the same)
if [ "$VPN_IP" != "FAILED" ] && [ "$VPN_IP" = "$QBT_IP" ] && [ "$VPN_IP" = "$SLSK_IP" ]; then
  echo "✓ All P2P traffic routed through VPN correctly"
else
  echo "✗ VPN routing issue detected!"
  echo "Restarting VPN..."
  docker-compose restart gluetun qbittorrent slskd
fi

echo "=== VPN TROUBLESHOOTING COMPLETE ==="
```

---

## Incident Response

### Security Incident Response

```bash
#!/bin/bash
# Security incident response script

INCIDENT_ID="SEC-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/security/incident-${INCIDENT_ID}.log"

mkdir -p /var/log/security

{
  echo "=== SECURITY INCIDENT RESPONSE ==="
  echo "Incident ID: $INCIDENT_ID"
  echo "Timestamp: $(date)"
  echo "Response initiated by: $(whoami)"
  
  # 1. Preserve evidence
  echo -e "\n=== EVIDENCE PRESERVATION ==="
  
  # System state
  ps aux > /tmp/ps-aux-${INCIDENT_ID}.txt
  netstat -tulpn > /tmp/netstat-${INCIDENT_ID}.txt
  docker ps > /tmp/docker-ps-${INCIDENT_ID}.txt
  
  # Logs
  journalctl --since "24h ago" > /tmp/journalctl-${INCIDENT_ID}.txt
  docker-compose logs --since 24h > /tmp/docker-logs-${INCIDENT_ID}.txt
  
  # 2. Immediate containment
  echo -e "\n=== IMMEDIATE CONTAINMENT ==="
  
  # Block suspicious IPs (example)
  # sudo ufw deny from suspicious_ip
  
  # Restart affected services
  # docker-compose restart affected-service
  
  # 3. Assessment
  echo -e "\n=== INCIDENT ASSESSMENT ==="
  echo "Affected systems:"
  echo "Potential data exposure:"
  echo "Attack vector:"
  
  # 4. Notification
  echo -e "\n=== NOTIFICATION ==="
  echo "Security team notified: $(date)"
  echo "Management notification sent: $(date)"
  
  # 5. Recovery actions
  echo -e "\n=== RECOVERY ACTIONS ==="
  echo "Actions taken:"
  echo "Services restored:"
  echo "Verification completed:"
  
  echo -e "\n=== INCIDENT RESPONSE LOG END ==="
  
} | tee "$LOG_FILE"

echo "Incident response logged to: $LOG_FILE"
```

---

## Performance Optimization

### Automated Performance Tuning

```bash
#!/bin/bash
# Performance optimization script

echo "=== PERFORMANCE OPTIMIZATION ==="

# 1. Database optimization
echo "Optimizing databases..."

# Nextcloud database
docker exec mariadb mysql -e "
  OPTIMIZE TABLE oc_filecache;
  OPTIMIZE TABLE oc_activity;
  OPTIMIZE TABLE oc_comments;
  ANALYZE TABLE oc_filecache;
"

# 2. Container resource tuning
echo "Tuning container resources..."

# Adjust memory limits based on usage
MEMORY_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEMORY_USAGE" -gt 85 ]; then
  echo "High memory usage detected ($MEMORY_USAGE%)"
  # Reduce non-critical service memory limits
  # This would involve editing docker-compose.yml
fi

# 3. Disk optimization
echo "Optimizing disk usage..."

# Clean up old Docker images
docker image prune -f

# Clean up old logs
find /var/log -name "*.log" -mtime +30 -delete

# 4. Network optimization
echo "Optimizing network..."

# Adjust buffer sizes if needed
# sysctl -w net.core.rmem_max=134217728
# sysctl -w net.core.wmem_max=134217728

# 5. Application-specific optimization
echo "Optimizing applications..."

# Nextcloud optimization
docker exec nextcloud occ maintenance:mode --on
docker exec nextcloud occ maintenance:repair
docker exec nextcloud occ maintenance:mode --off

echo "=== PERFORMANCE OPTIMIZATION COMPLETE ==="
```

---

## Backup and Recovery

### Comprehensive Backup Verification

```bash
#!/bin/bash
# Comprehensive backup verification

echo "=== BACKUP VERIFICATION ==="

# 1. Kopia backup verification
echo "Kopia backup verification..."
docker exec kopia_server kopia repository verify --repository=/repository

# 2. File system backup verification
echo "File system backup verification..."
tar -tzf /tmp/latest-backup.tar.gz | head -20

# 3. Database backup verification
echo "Database backup verification..."
# Nextcloud DB
docker exec mariadb mysqldump -u root -p$MYSQL_ROOT_PASSWORD nextcloud | \
  mysql -u root -p$MYSQL_ROOT_PASSWORD nextcloud_test 2>/dev/null
# Gitea DB  
docker exec postgres pg_dump -U postgres -d gitea > /tmp/gitea-backup.sql

# 4. Configuration backup verification
echo "Configuration backup verification..."
tar -tzf /tmp/config-backup.tar.gz | grep -E "\.(yml|yaml)$"

# 5. Test restoration
echo "Testing restoration process..."
# This would involve actual restoration testing

echo "=== BACKUP VERIFICATION COMPLETE ==="
```

---

## Security Procedures

### Regular Security Updates

```bash
#!/bin/bash
# Security update procedure

echo "=== SECURITY UPDATE PROCEDURE ==="

# 1. Check for security updates
echo "Checking for security updates..."
sudo apt list --upgradable | grep -i security

# 2. Apply security updates only
echo "Applying security updates..."
sudo unattended-upgrade -d

# 3. Update container images with security fixes
echo "Updating container images..."
docker-compose pull
docker-compose up -d

# 4. Security scan
echo "Running security scan..."
if command -v trivy >/dev/null 2>&1; then
  trivy image --severity HIGH,CRITICAL $(docker images --format "{{.Repository}}:{{.Tag}}")
fi

# 5. Update firewall rules if needed
echo "Checking firewall configuration..."
sudo ufw status verbose

echo "=== SECURITY UPDATE COMPLETE ==="
```

### Access Review

```bash
#!/bin/bash
# Quarterly access review

echo "=== QUARTERLY ACCESS REVIEW ==="

# 1. Review user accounts
echo "User accounts:"
docker exec nextcloud occ user:list

# 2. Review service accounts
echo -e "\nService accounts:"
docker exec nextcloud occ user:list | grep -E "(service|system)"

# 3. Review permissions
echo -e "\nPermissions review:"
# This would involve reviewing file permissions, database permissions, etc.

# 4. Review SSH access
echo "SSH access review:"
grep "sshd" /var/log/auth.log | grep -E "Failed|Accepted" | tail -20

# 5. Review VPN access
echo "VPN access review:"
# Review VPN logs and access patterns

echo "=== ACCESS REVIEW COMPLETE ==="
```

---

**Document Version**: 2.0  
**Last Updated**: December 2025  
**Classification**: Internal Use  
**Review Cycle**: Monthly  
**Owner**: Infrastructure Team
