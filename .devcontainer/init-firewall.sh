#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Same egress-sandbox design as spades-dev-environment: default-DROP outbound,
# allow only an explicit domain allowlist + directly-connected networks. This
# is the control that makes `claude --dangerously-skip-permissions` safe.
#
# Two adaptations for this stack:
#   1. The base allowlist carries WordPress.org (core/plugin/theme installs) plus
#      the npm / Anthropic / GitHub / VS Code / Debian / sury hosts the container
#      needs. A profile can add more hosts: if /workspace/active-firewall-allowlist.txt
#      exists (symlinked by bin/use-profile.sh), each host in it is also allowed.
#   2. It allows ALL directly-connected subnets (not just the default-route
#      /24) so the dev container can reach the `db` and `wordpress` sibling
#      services on the docker-compose bridge network.

DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F; iptables -X
iptables -t nat -F; iptables -t nat -X
iptables -t mangle -F; iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# Reset default policies to ACCEPT. postStartCommand runs this on EVERY start,
# so a re-run must be safe: `iptables -F` clears rules but NOT the chain
# policies, so a prior run's `-P OUTPUT DROP` would survive and block the
# `curl api.github.com/meta` below (needed to rebuild the allowlist) — hanging
# until timeout. Resetting to ACCEPT first makes the rebuild idempotent.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s --connect-timeout 10 --max-time 30 https://api.github.com/meta)
if [ -z "$gh_ranges" ] || ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub meta fetch/validation failed"; exit 1
fi
while read -r cidr; do
    [[ "$cidr" =~ ^[0-9.]+/[0-9]{1,2}$ ]] || { echo "ERROR: bad CIDR $cidr"; exit 1; }
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve a hostname's A records into the allowed-domains ipset.
add_domain() {
    local domain="$1"
    echo "Resolving $domain..."
    local ips
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then echo "WARN: no A record for $domain"; return; fi
    while read -r ip; do
        [[ "$ip" =~ ^[0-9.]+$ ]] || continue
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
}

# Base allowlist for the plain WordPress stack.
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com" \
    "deb.debian.org" \
    "packages.sury.org" \
    "raw.githubusercontent.com" \
    "codeload.github.com" \
    "objects.githubusercontent.com" \
    "api.wordpress.org" \
    "downloads.wordpress.org" \
    "wordpress.org" \
    "plugins.svn.wordpress.org" \
    "themes.svn.wordpress.org"; do
    add_domain "$domain"
done

# Profile-specific extra hosts (bin/use-profile.sh symlinks the active profile's
# firewall-allowlist.txt here). One host per line; blank lines and # comments ok.
PROFILE_ALLOWLIST="/workspace/active-firewall-allowlist.txt"
if [ -f "$PROFILE_ALLOWLIST" ]; then
    echo "Adding profile allowlist from $PROFILE_ALLOWLIST..."
    while read -r domain; do
        domain="${domain%%#*}"; domain="${domain//[[:space:]]/}"
        [ -z "$domain" ] && continue
        add_domain "$domain"
    done < "$PROFILE_ALLOWLIST"
fi

# Allow every directly-connected subnet. On the compose bridge this covers the
# `db` and `wordpress` services; it also covers the host network.
for net in $(ip route show scope link | awk '/src/ {print $1}' | grep -E '/[0-9]+$'); do
    echo "Allowing connected network $net"
    iptables -A INPUT  -s "$net" -j ACCEPT
    iptables -A OUTPUT -d "$net" -j ACCEPT
done

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Verifying firewall..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: reached example.com — allowlist not enforced"; exit 1
fi
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: cannot reach api.github.com — allowlist too tight"; exit 1
fi
echo "Firewall configuration complete."
