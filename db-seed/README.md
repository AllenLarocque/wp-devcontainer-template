# db-seed/ — database dumps

Any `*.sql` here is available to the `db` container at
`/docker-entrypoint-initdb.d-seed` (a non-auto path). Import manually:

    wp --path=/var/www/html --allow-root db import ./db-seed/dump.sql

Then localize prod URLs with `bash scripts/import-site.sh`. Gitignored.
