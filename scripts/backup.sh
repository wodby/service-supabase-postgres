#!/bin/sh
set -eu
umask 077
# Pause Supabase application writers for a coordinated database/object-storage recovery point.
export PGHOST="${1:-${PGHOST:-127.0.0.1}}" PGUSER=supabase_admin PGDATABASE=postgres
stage=$(mktemp -d /var/lib/postgresql/data/.supabase-backup.XXXXXX)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
# Keep the archive's line-oriented index unambiguous; fail rather than omit an unsupported identifier.
invalid=$(psql -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM (SELECT datname AS name FROM pg_database UNION ALL SELECT rolname FROM pg_roles) names WHERE name ~ E'[\\n\\r\\t]'")
[ "$invalid" = 0 ] || { echo 'Backup does not support database or role names containing tabs or newlines' >&2; exit 1; }
psql -At -v ON_ERROR_STOP=1 -c "SELECT datname FROM pg_database WHERE NOT datistemplate ORDER BY datname" > "$stage/databases.txt"
# The restore function creates missing roles before applying pg_dumpall's role attributes and memberships.
printf '%s\n' 'CREATE FUNCTION pg_temp.ensure_role(n text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname=n) THEN EXECUTE format('\''CREATE ROLE %I'\'',n); END IF; END $$;' > "$stage/roles.sql"
psql -At -v ON_ERROR_STOP=1 -c "SELECT format('SELECT pg_temp.ensure_role(%L);',rolname) FROM pg_roles WHERE rolname !~ '^pg_' ORDER BY rolname" >> "$stage/roles.sql"
pg_dumpall --roles-only > "$stage/roles-raw.sql"
sed '/^CREATE ROLE /d' "$stage/roles-raw.sql" >> "$stage/roles.sql"
rm "$stage/roles-raw.sql"
i=0
while IFS= read -r database; do
  i=$((i+1))
  pg_dump --format=custom --file="$stage/db-$i.dump" --dbname="$database"
done < "$stage/databases.txt"
mkdir "$stage/database-keys"
cp -a /etc/postgresql-custom/. "$stage/database-keys/"
printf '%s\n' 'supabase-self-hosted-v0.8.1-pg17' > "$stage/format"
tar -czf /var/lib/postgresql/data/supabase-backup.tar.gz -C "$stage" .
echo 'Supabase database backup prepared; back up application tokens and stored objects separately.'
