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
    "nextcloud": {"NEXTCLOUD_ADMIN_USER", "NEXTCLOUD_ADMIN_PASSWORD", "NEXTCLOUD_DB_PASSWORD"},
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
