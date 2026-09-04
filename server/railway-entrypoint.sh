#!/bin/bash
set -euo pipefail

# Every Node process in this image reads its port from a .env file the upstream
# entrypoint generates, and dotenv never overrides a variable that is already in
# the environment -- so a Railway PORT would make all five servers bind the same
# port. Hand it to Caddy and hide it from the rest.
export CADDY_PORT="${PORT:-8080}"
unset PORT

# The uploads directory sits one level below the volume mount root, so the
# filesystem's own lost+found is never inside a directory the app enumerates.
: "${FILES_SERVER_FILE_UPLOAD_PATH:=/opt/shared/uploads}"
export FILES_SERVER_FILE_UPLOAD_PATH
: "${SYNCING_SERVER_FILE_UPLOAD_PATH:=${FILES_SERVER_FILE_UPLOAD_PATH}}"
export SYNCING_SERVER_FILE_UPLOAD_PATH
mkdir -p "$FILES_SERVER_FILE_UPLOAD_PATH"

# TypeORM's shipped default here is "all", which logs every statement and blows
# past Railway's 500 logs/sec ceiling during a sync.
: "${DB_DEBUG_LEVEL:=error}"
export DB_DEBUG_LEVEL

# Clients fetch attachments straight from the files server at the URL the API
# gateway advertises, so it has to be this deployment's own public origin rather
# than upstream's http://localhost:3125 default.
if [ -z "${PUBLIC_FILES_SERVER_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export PUBLIC_FILES_SERVER_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

# A ${{localstack.RAILWAY_PRIVATE_DOMAIN}} reference renders empty until that
# service owns a deployment, which is exactly the case on a template's first
# deploy -- the servers would then publish domain events to "http://:4566" and
# the workers would sit idle behind a green container. The hostname is
# deterministic, so repair it here on the value's shape.
LOCALSTACK_DEFAULT="http://${LOCALSTACK_HOST:-localstack.railway.internal}:4566"
for prefix in AUTH_SERVER SYNCING_SERVER FILES_SERVER REVISIONS_SERVER; do
  for suffix in SNS_ENDPOINT SQS_ENDPOINT; do
    var="${prefix}_${suffix}"
    case "${!var:-}" in
      "" | "http://:"* | "http://:") export "$var=$LOCALSTACK_DEFAULT" ;;
    esac
  done
  var="${prefix}_SQS_QUEUE_URL"
  case "${!var:-}" in
    "http://:4566"*) export "$var=${LOCALSTACK_DEFAULT}${!var#http://:4566}" ;;
    "http://localstack:4566"*) export "$var=${LOCALSTACK_DEFAULT}${!var#http://localstack:4566}" ;;
  esac
done

# Upstream's docs ask the operator to run this SQL by hand for every account that
# should have server-side premium features. A template has no manual steps.
if [ "${GRANT_PRO_PLAN:-true}" = "true" ]; then
  /usr/local/bin/grant-pro-plan.sh &
fi

exec /usr/local/bin/docker-entrypoint.sh
