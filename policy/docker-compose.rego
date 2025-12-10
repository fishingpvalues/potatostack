package main

# List of services that are allowed to run in privileged mode.
allowed_privileged_services = {
    "cadvisor",
    "smartctl-exporter"
}

# List of services that are allowed to run in network_mode: service:surfshark
allowed_vpn_services = {
    "qbittorrent",
    "slskd"
}

# List of required environment variables for each service
required_env_vars = {
    "surfshark": {"SURFSHARK_USER", "SURFSHARK_PASSWORD"},
    "kopia": {"KOPIA_PASSWORD", "KOPIA_SERVER_PASSWORD"},
    "gitea": {"GITEA_DB_PASSWORD"},
    "grafana": {"GF_SECURITY_ADMIN_PASSWORD"},
    "alertmanager": {"ALERT_EMAIL_USER", "ALERT_EMAIL_PASSWORD", "ALERT_EMAIL_TO"},
    "slskd": {"SLSKD_PASSWORD"}
}

# Deny if a service is privileged and not in the allowed list.
deny[msg] {
    some service
    input.services[service].privileged == true
    not allowed_privileged_services[service]
    msg = sprintf("Service '%s' is not allowed to run in privileged mode.", [service])
}

# Deny if a service has a network_mode other than service:surfshark when it's not allowed
deny[msg] {
    some service
    input.services[service].network_mode == "service:surfshark"
    not allowed_vpn_services[service]
    msg = sprintf("Service '%s' is not allowed to use network_mode: service:surfshark.", [service])
}

# Deny if a service has cap_add but no explicit resource limits
deny[msg] {
    some service
    count(input.services[service].cap_add) > 0
    not input.services[service].mem_limit
    msg = sprintf("Service '%s' has capabilities added but no memory limit set.", [service])
}

# Deny if a service has devices but no explicit resource limits
deny[msg] {
    some service
    input.services[service].devices
    not input.services[service].mem_limit
    msg = sprintf("Service '%s' has devices exposed but no memory limit set.", [service])
}

# Deny if a service doesn't have required environment variables
deny[msg] {
    some service
    required_env_vars[service]
    some var
    required_env_vars[service][var]
    not input.services[service].environment[_] = sprintf("%s=", [var])
    msg = sprintf("Service '%s' is missing required environment variable: %s", [service, var])
}

# Deny if a service has a port exposed to all interfaces (0.0.0.0) without specific restrictions
deny[msg] {
    some service
    some port_mapping
    input.services[service].ports[_] = port_mapping
    startswith(port_mapping, "0.0.0.0:")
    msg = sprintf("Service '%s' has a port exposed to all interfaces. Consider restricting to specific interfaces.", [service])
}

# Deny if a service has host network mode
deny[msg] {
    some service
    input.services[service].network_mode == "host"
    msg = sprintf("Service '%s' uses host network mode which is not allowed.", [service])
}

# Deny if a service has no resource limits at all
deny[msg] {
    some service
    not input.services[service].mem_limit
    not input.services[service].mem_reservation
    not input.services[service].cpus
    not input.services[service].mem_swappiness
    # Skip services that don't need resource limits (like network tools)
    service != "node-exporter"
    service != "smartctl-exporter"
    service != "portainer"
    msg = sprintf("Service '%s' has no resource limits configured (mem_limit, cpus, etc.).", [service])
}

# Deny if a service has volumes mounted as writable to sensitive paths
deny[msg] {
    some service
    some vol
    input.services[service].volumes[_] = vol
    startswith(vol, "/etc/")
    not endswith(vol, ":ro")
    not contains(vol, "/etc/localtime")
    not contains(vol, "/etc/timezone")
    msg = sprintf("Service '%s' has writable mount to sensitive /etc/ path: %s", [service, vol])
}

################################################################################
# Le Potato Specific Rules (2GB RAM, ARM Cortex-A53, Resource-Constrained)
################################################################################

# Calculate total memory allocation across all services
total_mem_limit_mb = sum([to_number(mem_limit_value) |
    some service
    input.services[service].mem_limit
    mem_limit_value := replace(replace(input.services[service].mem_limit, "m", ""), "M", "")
])

# Warn if total memory limits exceed reasonable threshold for 2GB system
warn[msg] {
    total_mem_limit_mb > 6000
    msg = sprintf("WARNING: Total memory limits (%dMB) significantly exceed physical RAM (2GB). Swap is REQUIRED.", [total_mem_limit_mb])
}

# Deny if critical services lack memory limits (Le Potato requires strict limits)
deny[msg] {
    some service
    critical_services := {"surfshark", "kopia", "prometheus", "qbittorrent"}
    critical_services[service]
    not input.services[service].mem_limit
    msg = sprintf("CRITICAL: Service '%s' must have mem_limit for Le Potato (2GB RAM)", [service])
}

# Deny if any service has memory limit > 1GB (unrealistic for Le Potato)
deny[msg] {
    some service
    input.services[service].mem_limit
    mem_limit := replace(replace(input.services[service].mem_limit, "m", ""), "M", "")
    to_number(mem_limit) > 1024
    msg = sprintf("Service '%s' has excessive memory limit (%s) for Le Potato. Max recommended: 768MB", [service, input.services[service].mem_limit])
}

# Deny if services with heavy I/O don't have explicit CPU limits
deny[msg] {
    some service
    heavy_io_services := {"kopia", "qbittorrent", "prometheus"}
    heavy_io_services[service]
    not input.services[service].cpus
    msg = sprintf("Service '%s' needs CPU limit for Le Potato's single storage bus", [service])
}

# Warn if ARM64-incompatible image patterns are detected
warn[msg] {
    some service
    image := input.services[service].image
    not contains(image, "arm")
    not contains(image, "multi-arch")
    not contains(image, "latest")  # Latest should support multi-arch
    contains(image, "amd64")
    msg = sprintf("WARNING: Service '%s' image may not support ARM64: %s", [service, image])
}

# Deny if Surfshark VPN lacks health check (critical for killswitch)
deny[msg] {
    input.services["surfshark"]
    not input.services["surfshark"].healthcheck
    msg = "CRITICAL: Surfshark VPN must have healthcheck configured for killswitch reliability"
}

# Deny if P2P services don't depend on Surfshark
deny[msg] {
    some service
    p2p_services := {"qbittorrent", "slskd"}
    p2p_services[service]
    not input.services[service].depends_on["surfshark"]
    msg = sprintf("CRITICAL: P2P service '%s' must depend on surfshark for killswitch", [service])
}

# Warn if critical data paths are not on /mnt/ (SD card wear)
warn[msg] {
    some service
    some vol
    input.services[service].volumes[_] = vol
    data_services := {"kopia", "qbittorrent", "slskd", "gitea"}
    data_services[service]
    not startswith(vol, "/mnt/")
    not endswith(vol, ":ro")
    contains(vol, "/")  # It's a bind mount
    msg = sprintf("WARNING: Service '%s' writes to '%s' (not /mnt/). Consider moving to HDD to protect SD card", [service, vol])
}

# Deny if docker socket is writable (unless Portainer/Diun/Autoheal)
deny[msg] {
    some service
    some vol
    input.services[service].volumes[_] = vol
    contains(vol, "/var/run/docker.sock")
    not endswith(vol, ":ro")
    service != "portainer"
    service != "autoheal"
    service != "homepage"
    service != "uptime-kuma"
    service != "dozzle"
    msg = sprintf("Service '%s' has writable access to Docker socket - security risk", [service])
}

# Recommend swap file size based on memory allocation
recommend_swap_gb = ceil(total_mem_limit_mb / 1024) {
    total_mem_limit_mb > 2048
}

# Informational message about swap requirements
info[msg] {
    recommend_swap_gb > 0
    msg = sprintf("INFO: Recommended swap file size: %dGB (based on %dMB total mem_limit)", [recommend_swap_gb, total_mem_limit_mb])
}

# Warn if qBittorrent or heavy services lack memory reservation
warn[msg] {
    some service
    heavy_services := {"qbittorrent", "kopia", "prometheus"}
    heavy_services[service]
    input.services[service].mem_limit
    not input.services[service].mem_reservation
    msg = sprintf("Service '%s' should have mem_reservation for better performance on Le Potato", [service])
}

# Deny if services use swap aggressively (mem_swappiness > 60)
deny[msg] {
    some service
    input.services[service].mem_swappiness
    to_number(input.services[service].mem_swappiness) > 60
    msg = sprintf("Service '%s' has mem_swappiness > 60. For Le Potato, keep it low to avoid thrashing", [service])
}
