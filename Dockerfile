# syntax=docker/dockerfile:1
#
# Vaultwarden for Runsite: the upstream image plus an entrypoint that maps the
# platform's public URL and port onto Vaultwarden's own settings.

ARG VAULTWARDEN_VERSION=1.37.4
FROM vaultwarden/server:${VAULTWARDEN_VERSION}-alpine

COPY --chmod=0755 deploy/entrypoint.sh /runsite-entrypoint.sh

ENV ROCKET_PORT=8080 \
    DATA_FOLDER=/data \
    SIGNUPS_ALLOWED=false \
    INVITATIONS_ALLOWED=true \
    SHOW_PASSWORD_HINT=false \
    IP_HEADER=X-Forwarded-For \
    DB_CONNECTION_RETRIES=90 \
    TZ=Europe/Kyiv

EXPOSE 8080

ENTRYPOINT ["/runsite-entrypoint.sh"]
