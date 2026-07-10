# wp-devcontainer-template

A reusable VS Code devcontainer for developing a WordPress site with Claude Code
running `--dangerously-skip-permissions` safely, behind an egress firewall.

**One base, optional profiles.** The repo root is a complete plain-WordPress dev
stack. A *profile* is an additive overlay you switch on — no forking or
stripping. Today's profiles:

- **none** (default) — plain WordPress.
- **civicrm** — adds the CiviCRM PHP extensions + `cv` CLI, a CiviCRM-extension
  web image, a second `civicrm` database, and CiviCRM/Composer firewall hosts.

## Using it for a site

1. Clone this repo into a per-site folder (or "Use this template" on GitHub).
2. `cp .env.example .env` and set at least `PROJECT_NAME`, `WEB_PORT`/`ADMINER_PORT`/`DB_PORT`/`MAILPIT_PORT`
   (bump them if running more than one site at once), and the `WP_*` install values.
3. Pick a profile: `bin/use-profile.sh civicrm` (or leave the default `none`).
4. Open the folder in VS Code → **Reopen in Container**. First build takes a few
   minutes (longer for civicrm — it compiles PHP extensions).
5. On first boot the stack comes up, the firewall initializes, and
   `scripts/bootstrap-wp.sh` runs `wp core install`. Then:
   - Site `http://localhost:${WEB_PORT}` · Admin `/wp-admin` (`WP_ADMIN_USER`/`WP_ADMIN_PASS`)
   - Adminer `http://localhost:${ADMINER_PORT}` · Mailpit `http://localhost:${MAILPIT_PORT}`
6. Run `claude --dangerously-skip-permissions`.

## How profiles work

`bin/use-profile.sh <name>` writes `docker-compose.override.yml` from
`profiles/<name>/overlay.yml` (Compose merges it onto `docker-compose.yml`) and
symlinks the profile's `firewall-allowlist.txt` to `active-firewall-allowlist.txt`
(read by `init-firewall.sh`). The dev image is a single arg-driven Dockerfile —
profiles switch on extras (`INSTALL_CV`, `EXTRA_PHP_EXTS`) via `build.args`
rather than a second Dockerfile. **Rebuild the container after switching.**

Add a new profile by creating `profiles/<name>/overlay.yml` (+ any
`firewall-allowlist.txt`, Dockerfiles, or init SQL it needs).

## Layout

```
.devcontainer/   dev image (node20 + PHP 8.3 CLI + wp-cli; arg-driven profile extras),
                 devcontainer.json (base + override), init-firewall.sh (base + profile allowlist)
docker-compose.yml           base stack: dev + wordpress(stock) + db + adminer + mailpit
docker-compose.override.yml  active profile overlay (managed by bin/use-profile.sh)
config/php.ini   base PHP settings
scripts/         bootstrap-wp.sh (first-boot install), import-site.sh (URL localize)
profiles/<name>/ overlay.yml (+ Dockerfile.web, init-databases.sql, firewall-allowlist.txt, …)
bin/use-profile.sh   selects the active profile
wordpress/       webroot bind mount (gitignored)
db-seed/         SQL dumps (gitignored)
```

## Network sandbox

Egress defaults to DROP; only the base allowlist (npm, api.anthropic.com, GitHub,
VS Code, Debian/sury, WordPress.org) + the active profile's extra hosts + the
compose network are reachable. This is what makes skip-permissions defensible. If
a fetch is blocked, add the host to the base list in `.devcontainer/init-firewall.sh`
(or the profile's `firewall-allowlist.txt`) and rebuild. **Never disable the
firewall to work around a block.**

## Baked-in gotchas (why the base is shaped the way it is)

- The `dev` service passes **all** of `WORDPRESS_DB_HOST/NAME/USER/PASSWORD` —
  the stock image's `wp-config.php` resolves creds from env at runtime, so wp-cli
  in the dev container fails with only `DB_HOST` set.
- The `wordpress` service re-owns the bind-mounted webroot to `node`(1000)`:www-data`(33)
  with setgid dirs on first boot, so wp-cli (uid 1000) can write it and Apache
  can still serve/upload. It calls `docker-ensure-installed.sh` first because
  overriding the image `command` otherwise skips the stock populate step.
