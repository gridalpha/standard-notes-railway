#!/bin/sh
set -eu

: "${PORT:=8080}"
: "${SYNC_SERVER_URL:=}"
: "${FILES_HOST_URL:=${SYNC_SERVER_URL}}"

INDEX=/usr/share/nginx/html/index.html

if [ -z "$SYNC_SERVER_URL" ]; then
  echo "entrypoint: SYNC_SERVER_URL is empty, so this app would sync to Standard" >&2
  echo "entrypoint: Notes' hosted service instead of your own server. Point it at" >&2
  echo "entrypoint: the sync server's public URL and redeploy." >&2
  exit 1
fi

# The published bundle carries Standard Notes' own hosted endpoints as runtime
# globals in index.html rather than baking them into the JavaScript, so pointing
# the app at a self-hosted server is one substitution -- and doing it per boot is
# what a template needs, since the public domain does not exist at build time.
# The websocket URL is blanked: the self-hosted bundle ships no websockets tier.
sed -i \
  -e "s|window.defaultSyncServer = \"[^\"]*\"|window.defaultSyncServer = \"${SYNC_SERVER_URL}\"|" \
  -e "s|window.defaultFilesHost = \"[^\"]*\"|window.defaultFilesHost = \"${FILES_HOST_URL}\"|" \
  -e "s|window.websocketUrl = \"[^\"]*\"|window.websocketUrl = \"\"|" \
  "$INDEX"

if ! grep -q "window.defaultSyncServer = \"${SYNC_SERVER_URL}\"" "$INDEX"; then
  echo "entrypoint: the sync server global was not substituted; refusing to serve" >&2
  echo "entrypoint: a bundle still pointing at the vendor's hosted service." >&2
  exit 1
fi

# Railway hands the port at runtime; the stock config listens on 80.
sed -i "s|listen  *80;|listen ${PORT};|" /etc/nginx/conf.d/default.conf
grep -q "listen ${PORT};" /etc/nginx/conf.d/default.conf

exec /docker-entrypoint.sh "$@"
