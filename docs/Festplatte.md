- le potato mit Armbian davor only reachable on home network
- i need sota solution which is safe, easy and can be used as torrent HDD and Soulseek and my backups
- welche Software für PC und alle Geräte? Nextcloud?
- will Soulseek darauf haben
- alle Systeme sollen darauf zugreifen cachy os windows android Apple mit Fritzbox wireguard vpn
- Backups live verschlüsselt und entschlüsselt mit kopia
- small HDD as well for Soulseek as cache and algorithm of most used files then the folders should be moved there as cache
- Soulseek docker compose mit surfshark also nicotine also known as nicotine + choose best docker image SOTA not old which is updated recently with surfshark and then only communication via surfshark interface for this stack and access to cache HDD for nicotine plus and also qbittottent in this stack as well communication only via surfshark interface no leaks I want hard Killswitch and wireguard or openvpn
- cache HDD mounted as cache and then common folder for torrents and Soulseek organized as pr0n, music, tv shows and movies
- Dashboard for triggering, stats etc access kopia metrics with Prometheus and setup grafana, thanos and Loki for logs folder of kopia
- make sure the stack is resilient always updated runs stable every time and performs best SOTA with stability tests and alerts etc
- gitea server as well integrated in the stack with server on not cache HDD, the other one
- 1. prom/node-exporter (For System-Wide Metrics Including Disk Usage and I/O)

Why this benefits you: Provides broad OS/hardware metrics like filesystem usage (alert on low space on /mnt/seconddrive or /mnt/cachehdd), disk I/O rates (spot bottlenecks from torrents/Soulseek/Kopia), CPU/RAM (prevent SBC crashes during heavy backups/P2P), and network (VPN traffic). Ties into HDD health by alerting on usage thresholds, complementing Kopia's backup metrics.
Key metrics for HDD: node_filesystem_avail_bytes, node_disk_io_time_seconds_total, node_disk_reads_completed_total (for error tracking).
Alerts potential: High disk usage (>90%), high I/O wait (slowdowns), low free space (before backups fail).
Grafana integration: Import dashboard ID 1860 (Node Exporter Full) or 11074 (Node Exporter for Prometheus Dashboard) from grafana.com—add panels for your mounted HDDs.
Resource impact: Very low (~10-20MB RAM); runs as non-root.2. prometheuscommunity/smartctl-exporter (For SMART HDD Health Metrics)

Why this benefits you: Directly monitors SMART attributes on your HDDs (e.g., temperature, reallocated sectors, error logs, wear level)—crucial for predicting failures in your torrent/Soulseek/backup storage. Your cache HDD (for "most used" files) could wear faster from frequent access, so alerts on rising errors/temp prevent data corruption. Complements node-exporter by focusing on hardware health, not just usage.
Key metrics for HDD: smartctl_device_smart_status (PASSED/FAILED), smartctl_device_temperature_celsius, smartctl_ata_smart_attributes_reallocated_sector_ct_raw_value, smartctl_ata_error_count.
Alerts potential: SMART health failed, temp >45°C (overheating from prolonged P2P), reallocated sectors >0 (early failure sign), high power-on hours (replace soon).
Grafana integration: Import dashboard ID 20204 (Smart HDD) or 22604 (SMARTctl Exporter Dashboard) from grafana.com—visualize per-HDD stats, trends for your two drives.
Resource impact: Minimal (~15MB RAM); polls every 60s by default.3. prom/alertmanager (For Alert Notifications)

Why this benefits you: Turns metrics from above (and existing Kopia) into actionable alerts. E.g., get emailed if cache HDD temp spikes during Soulseek caching, or if main HDD space is low before backups fill it. Integrates with your Grafana for unified dashboards/triggers, but handles routing/deduplication/grouping for reliability.
Key features for HDD: Define rules for combined alerts (e.g., high usage + high temp = critical). Supports receivers like email (via SMTP), Slack, Telegram, or PagerDuty—easy for your multi-device access (Android/iOS apps for notifications).
Alerts potential: Custom rules for all above, plus Kopia backup failures. Suppress duplicates during maintenance.
Grafana integration: Grafana can visualize Alertmanager states; use dashboard ID 11094 (Alertmanager Overview) if needed.
Resource impact: Low (~20MB RAM).
- portainer ce
- watchtower
- uptime Kuma
- dozzle
- gethomepage/Homepage which links all this on starting page
- nginx proxy manager for reverse proxy and https and logs all to Prometheus, grafana
- stack should be resilient if stopped and pickup all nicely and all logs should be aggregated in Prometheus for every container and grafana should see everything
- add 2.facror and oauth and restrict to VPN ips

Best apps for iOS and android to access this