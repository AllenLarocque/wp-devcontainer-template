# wordpress/ — the webroot (bind mount)

Bind-mounted to `/var/www/html` in the `dev` and `wordpress` containers. On first
boot the WordPress image populates core + `wp-config.php` here and
`scripts/bootstrap-wp.sh` runs `wp core install`. Everything except this README
and `.gitkeep` is gitignored.
