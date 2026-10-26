#!/bin/sh
# Translates Runsite env vars into Vaultwarden settings, then starts Vaultwarden.
set -eu

# The platform injects PORT when the user overrides the service port.
if [ -n "${PORT:-}" ]; then
    export ROCKET_PORT="$PORT"
fi

# SQLite on the disk is the default; an empty DATABASE_URL would make Vaultwarden fail.
if [ -z "${DATABASE_URL:-}" ]; then
    unset DATABASE_URL
    echo "Using SQLite in ${DATA_FOLDER}/db.sqlite3."
fi

# PUBLIC_URL is the service's public https URL. Vaultwarden needs it as DOMAIN,
# without a trailing slash, for invite links, WebAuthn and attachment downloads.
public_url="${PUBLIC_URL:-${DOMAIN:-}}"
if [ -n "$public_url" ]; then
    export DOMAIN="${public_url%/}"
else
    echo "WARNING: PUBLIC_URL is not set. Invite links and passkeys will not work." >&2
fi

if [ -z "${ADMIN_TOKEN:-}" ]; then
    echo "WARNING: ADMIN_TOKEN is not set, the /admin panel is disabled." >&2
fi

# The persistent disk holds the RSA signing key, attachments and Sends.
# Without it every redeploy would sign all users out and lose their files.
mkdir -p "$DATA_FOLDER"
if ! touch "$DATA_FOLDER/.runsite-write-test" 2>/dev/null; then
    echo "FATAL: ${DATA_FOLDER} is not writable. Attach a persistent disk at ${DATA_FOLDER}." >&2
    exit 1
fi
rm -f "$DATA_FOLDER/.runsite-write-test"

exec /start.sh "$@"
