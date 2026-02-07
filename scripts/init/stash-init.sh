#!/bin/sh
# Stash init script - install runtime dependencies needed by plugins
# Haven VLM Connector requires git for PythonDepManager

apk add --no-cache git >/dev/null 2>&1

exec stash "$@"
