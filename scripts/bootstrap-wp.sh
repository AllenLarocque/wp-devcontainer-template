#!/bin/bash
# First-boot WordPress installer. Runs from the dev container's
# postCreateCommand. The stock `wordpress` image populates the shared webroot
# (core + generated wp-config.php); this waits for that and for the DB, then
# runs `wp core install`. Idempotent: exits early if WP is already installed.
set -euo pipefail

WP_PATH="/var/www/html"

echo "== bootstrap-wp: waiting for webroot (wp-config.php) =="
for _ in $(seq 1 60); do
  [ -f "$WP_PATH/wp-config.php" ] && break
  sleep 2
done
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "ERROR: $WP_PATH/wp-config.php not present after ~120s (is the wordpress service up?)" >&2
  exit 1
fi

echo "== bootstrap-wp: waiting for database (db:3306) =="
for _ in $(seq 1 60); do
  mysqladmin --connect-timeout=2 -h db -uwordpress -pwordpress ping >/dev/null 2>&1 && break
  sleep 2
done
if ! mysqladmin --connect-timeout=2 -h db -uwordpress -pwordpress ping >/dev/null 2>&1; then
  echo "ERROR: database not reachable after ~120s" >&2
  exit 1
fi

if wp --path="$WP_PATH" --allow-root core is-installed 2>/dev/null; then
  echo "== bootstrap-wp: WordPress already installed — nothing to do =="
  exit 0
fi

echo "== bootstrap-wp: installing WordPress =="
wp --path="$WP_PATH" --allow-root core install \
  --url="${WP_URL:-http://localhost:8090}" \
  --title="${WP_TITLE:-Allen Larocque}" \
  --admin_user="${WP_ADMIN_USER:-admin}" \
  --admin_password="${WP_ADMIN_PASS:-admin}" \
  --admin_email="${WP_ADMIN_EMAIL:-allen.larocque@gmail.com}" \
  --skip-email

echo "== bootstrap-wp: done. Site at ${WP_URL:-http://localhost:8090} =="
