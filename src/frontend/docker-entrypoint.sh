#!/bin/sh
set -eu

if [ -z "${BACKEND_URL:-}" ]; then
    echo "BACKEND_URL must be configured" >&2
    exit 1
fi

if ! printf '%s\n' "$BACKEND_URL" | grep -Eq '^https?://[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]{1,5})?$'; then
    echo "BACKEND_URL must be an HTTP(S) origin without a path or query" >&2
    exit 1
fi

sed "s|__BACKEND_URL__|${BACKEND_URL}|g" \
    /etc/nginx/support-desk.conf.template \
    > /etc/nginx/conf.d/default.conf
