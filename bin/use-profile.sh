#!/bin/bash
# Select the active devcontainer profile.
#
#   bin/use-profile.sh            # plain WordPress (default)
#   bin/use-profile.sh none       # same
#   bin/use-profile.sh civicrm    # WordPress + CiviCRM
#
# It writes docker-compose.override.yml from profiles/<name>/overlay.yml (which
# `docker compose` and the devcontainer both merge onto docker-compose.yml), and
# symlinks the profile's firewall-allowlist.txt to active-firewall-allowlist.txt
# so init-firewall.sh grants the profile's extra hosts. Rebuild the container
# after switching (the dev/web images differ per profile).
set -euo pipefail

PROFILE="${1:-none}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY="$ROOT/profiles/$PROFILE/overlay.yml"

if [ ! -f "$OVERLAY" ]; then
  echo "Unknown profile '$PROFILE'. Available:" >&2
  ls -1 "$ROOT/profiles" >&2
  exit 1
fi

cp "$OVERLAY" "$ROOT/docker-compose.override.yml"

ALLOWLIST="$ROOT/profiles/$PROFILE/firewall-allowlist.txt"
if [ -f "$ALLOWLIST" ]; then
  ln -sf "profiles/$PROFILE/firewall-allowlist.txt" "$ROOT/active-firewall-allowlist.txt"
else
  rm -f "$ROOT/active-firewall-allowlist.txt"
fi

echo "Active profile: $PROFILE"
echo "Next: (re)build the container — 'docker compose up -d --build' or Rebuild Container in VS Code."
