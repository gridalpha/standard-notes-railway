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

INSERT INTO subscription_settings
  (uuid, name, value, server_encryption_version, created_at, updated_at, sensitive, user_subscription_uuid)
SELECT UUID(), d.name, d.value, 0,
       FLOOR(UNIX_TIMESTAMP(NOW(6)) * 1000000), FLOOR(UNIX_TIMESTAMP(NOW(6)) * 1000000), 0, us.uuid
FROM user_subscriptions us
CROSS JOIN (
  SELECT 'FILE_UPLOAD_BYTES_LIMIT' AS name, '107374182400' AS value
  UNION ALL SELECT 'FILE_UPLOAD_BYTES_USED', '0'
  UNION ALL SELECT 'MUTE_SIGN_IN_EMAILS', 'not_muted'
) d
WHERE us.plan_name = 'PRO_PLAN'
  AND NOT EXISTS (
    SELECT 1 FROM subscription_settings ss
    WHERE ss.user_subscription_uuid = us.uuid AND ss.name = d.name
  );
SQLEOF

read -r -d '' STATUS_SQL <<'SQLEOF' || true
SELECT CONCAT(
  'grant-pro-plan: users=', (SELECT COUNT(*) FROM users),
  ' pro_role_grants=', (SELECT COUNT(*) FROM user_roles ur
                        JOIN roles r ON r.uuid = ur.role_uuid WHERE r.name = 'PRO_USER'),
  ' subscriptions=', (SELECT COUNT(*) FROM user_subscriptions),
  ' subscription_settings=', (SELECT COUNT(*) FROM subscription_settings),
  ' roles=', (SELECT GROUP_CONCAT(DISTINCT name ORDER BY name) FROM roles)
);
SQLEOF

run_sql() {
  mysql --protocol=TCP -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" \
    -D "${DB_DATABASE}" -N -B -e "$1" 2>&1
}

while true; do
  if ! run_sql "${SQL}"; then
    echo "grant-pro-plan: auth schema not ready yet, retrying in ${INTERVAL}s"
  else
    run_sql "${STATUS_SQL}"
  fi
  sleep "${INTERVAL}"
done
