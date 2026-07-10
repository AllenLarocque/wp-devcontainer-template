-- Runs once on first DB init (docker-entrypoint-initdb.d). The `wordpress`
-- DB/user is created by the image env vars; this adds CiviCRM's recommended
-- separate `civicrm` DB and grants the same user access + the privileges
-- CiviCRM needs to build triggers/routines on MariaDB.
CREATE DATABASE IF NOT EXISTS civicrm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON civicrm.* TO 'wordpress'@'%';
GRANT TRIGGER, LOCK TABLES, CREATE ROUTINE, ALTER ROUTINE, CREATE TEMPORARY TABLES
  ON wordpress.* TO 'wordpress'@'%';
GRANT TRIGGER, LOCK TABLES, CREATE ROUTINE, ALTER ROUTINE, CREATE TEMPORARY TABLES
  ON civicrm.* TO 'wordpress'@'%';
FLUSH PRIVILEGES;
