# Standard Notes' own web client, pointed at this project's sync server.
#
# The published image is nginx serving a static bundle whose endpoints live in
# index.html as runtime globals, so no rebuild is needed -- but the listen port
# and those globals both have to be set per boot (web/entrypoint.sh).
# Pinned to the client build contemporary with standardnotes/server's own
# `latest` (2026-04-11). The two images float independently, and a client months
# ahead of the server reads the server's entitlement responses as a free plan.
FROM standardnotes/web:8490e81d19ca9904e3feec13ae851a3feeb4a12d

COPY web/entrypoint.sh /usr/local/bin/railway-entrypoint.sh

RUN chmod +x /usr/local/bin/railway-entrypoint.sh \
 && sh -n /usr/local/bin/railway-entrypoint.sh \
 && grep -q 'window.defaultSyncServer' /usr/share/nginx/html/index.html

# Declaring an ENTRYPOINT empties the inherited CMD, so the image's own default
# argv is restated here.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
