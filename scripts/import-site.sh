#!/bin/bash
# Optional: localize a production WordPress dump for local development.
# Run from the dev container AFTER importing a DB dump, e.g.:
#   wp --path=/var/www/html --allow-root db import ./db-seed/dump.sql
# Then rewrite the production URL to the local one across all tables.
#
# PROD_URL comes from arg 1, else the PROD_URL env var (.env). LOCAL_URL follows
# WEB_PORT; export LOCAL_URL=http://localhost:<port> to override.
set -euo pipefail

LOCAL_URL="${LOCAL_URL:-${WP_URL:-http://localhost:8090}}"
PROD_URL="${1:-${PROD_URL:-}}"
WP_PATH="/var/www/html"

if [ -z "$PROD_URL" ]; then
  echo "ERROR: no production URL. Pass it as an arg or set PROD_URL in .env." >&2
  exit 1
fi

echo "== WordPress URL rewrite: $PROD_URL -> $LOCAL_URL =="
wp --path="$WP_PATH" --allow-root option update siteurl "$LOCAL_URL"
wp --path="$WP_PATH" --allow-root option update home "$LOCAL_URL"
wp --path="$WP_PATH" --allow-root search-replace "$PROD_URL" "$LOCAL_URL" \
  --all-tables --report-changed-only

echo "== Done. Verify at $LOCAL_URL =="
