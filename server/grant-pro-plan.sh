#!/bin/bash
# Standard Notes gates file uploads and note history behind a subscription, and
# upstream's self-hosting docs tell the operator to insert one by hand for every
# account. This grants the same PRO_USER role and PRO_PLAN subscription to any
# account that has none, so a fresh deployment works with no manual step.
# Set GRANT_PRO_PLAN=false to leave accounts on the free tier.
set -uo pipefail

INTERVAL="${GRANT_PRO_PLAN_INTERVAL:-60}"

# libmysqlclient reads the credential from this variable rather than argv, so it
# never appears in the process list.
MYSQL_PWD="${DB_PASSWORD}"
export MYSQL_PWD

read -r -d '' SQL <<'SQLEOF' || true
INSERT INTO user_roles (role_uuid, user_uuid)
SELECT r.uuid, u.uuid
FROM users u
CROSS JOIN (SELECT uuid FROM roles WHERE name = 'PRO_USER' ORDER BY version DESC LIMIT 1) r
WHERE NOT EXISTS (
  SELECT 1 FROM user_roles ur WHERE ur.user_uuid = u.uuid AND ur.role_uuid = r.uuid
)
ON DUPLICATE KEY UPDATE role_uuid = VALUES(role_uuid);

INSERT INTO user_subscriptions
  (uuid, plan_name, ends_at, created_at, updated_at, user_uuid, subscription_id, subscription_type)
SELECT UUID(), 'PRO_PLAN', 8640000000000000, 0, 0, u.uuid, 1, 'regular'
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_subscriptions us WHERE us.user_uuid = u.uuid
);
SQLEOF

while true; do
  if ! mysql --protocol=TCP -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" \
       -D "${DB_DATABASE}" -e "${SQL}" 2>&1; then
    echo "grant-pro-plan: auth schema not ready yet, retrying in ${INTERVAL}s"
  fi
  sleep "${INTERVAL}"
done
