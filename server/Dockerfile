# Standard Notes' published self-hosted bundle, adapted for Railway.
#
# Four things upstream's image cannot do here:
#   * it logs every component to files under /var/lib/server/logs, so Railway's
#     log stream is empty (server/supervisord.conf);
#   * it serves the API gateway and the files server on two ports, and Railway
#     publishes one per service (server/Caddyfile);
#   * its final `supervisord` is not exec'd, so SIGTERM never reaches it;
#   * server-side premium features need a row inserted by hand
#     (server/grant-pro-plan.sh).
FROM standardnotes/server:latest

USER root

# Caddy joins the two HTTP ports onto Railway's $PORT. COPY --from brings the
# binary and nothing else, so its config directory has to be created here.
COPY --from=caddy:2-alpine /usr/bin/caddy /usr/local/bin/caddy
RUN mkdir -p /etc/caddy

# mariadb-connector-c is what carries caching_sha2_password.so; Railway's managed
# MySQL is 9.x, where every role authenticates with that plugin and the client
# alone cannot complete the handshake.
RUN apk add --no-cache mariadb-client mariadb-connector-c \
 && ls -1 /usr/lib/mariadb/plugin/caching_sha2_password.so \
 && caddy version

COPY server/Caddyfile /etc/caddy/Caddyfile
COPY server/supervisord.conf /etc/supervisord.conf
COPY server/railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY server/grant-pro-plan.sh /usr/local/bin/grant-pro-plan.sh

RUN chmod +x /usr/local/bin/railway-entrypoint.sh /usr/local/bin/grant-pro-plan.sh \
 && bash -n /usr/local/bin/railway-entrypoint.sh \
 && bash -n /usr/local/bin/grant-pro-plan.sh \
 && caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# Upstream's entrypoint ends on a bare `supervisord`, which leaves bash as the
# process Railway signals on redeploy. An in-place edit survives into the running
# container where a file deletion in a build layer does not.
RUN sed -i 's|^supervisord -c /etc/supervisord.conf$|exec supervisord -c /etc/supervisord.conf|' \
      /usr/local/bin/docker-entrypoint.sh \
 && grep -q '^exec supervisord -c /etc/supervisord.conf$' /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
