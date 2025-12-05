package main

# List of services that are allowed to run in privileged mode.
allowed_privileged_services = {
    "cadvisor",
    "smartctl-exporter"
}

# Deny if a service is privileged and not in the allowed list.
deny[msg] {
    # a service is a key in the services object of the input yaml file
    some service
    # input[service] is the service object
    input.services[service].privileged == true
    # check if the service is not in the allowed list
    not allowed_privileged_services[service]
    # if all conditions are met, create an error message
    msg = sprintf("Service '%s' is not allowed to run in privileged mode.", [service])
}
