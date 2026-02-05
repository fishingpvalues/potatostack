#!/bin/sh
################################################################################
# Gluetun Entrypoint Wrapper - Fixes post-rules.txt on startup
# This ensures /compose/config/gluetun/post-rules.txt is a file, not a directory
################################################################################

set -eu

GLUETUN_COMPOSE_CONFIG="/compose/config/gluetun"
GLUETUN_PROJECT_CONFIG="/home/daniel/potatostack/config/gluetun"

if [ -d "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt" ]; then
	rm -rf "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt"
fi

if [ -f "${GLUETUN_PROJECT_CONFIG}/post-rules.txt" ]; then
	mkdir -p "${GLUETUN_COMPOSE_CONFIG}"
	cp "${GLUETUN_PROJECT_CONFIG}/post-rules.txt" "${GLUETUN_COMPOSE_CONFIG}/post-rules.txt"
fi

exec /gluetun-entrypoint "$@"
