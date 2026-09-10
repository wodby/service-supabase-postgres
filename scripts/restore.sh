#!/bin/sh
set -eu
# Restore only into a fresh, isolated instance of the same PostgreSQL/Supabase bundle, with application writers stopped.
[ "${SUPABASE_RESTORE_CONFIRM:-}" = fresh-instance ] || { echo 'Set SUPABASE_RESTORE_CONFIRM=fresh-instance after stopping application writers on a fresh target.' >&2; exit 1; }
[ "$#" = 1 ] || { echo 'Usage: restore.sh extracted-backup-directory' >&2; exit 1; }
stage=$1
[ "$(cat "$stage/format")" = supabase-self-hosted-v0.8.1-pg17 ] || { echo 'Unsupported backup format' >&2; exit 1; }
export PGHOST="${PGHOST:-127.0.0.1}" PGUSER=supabase_admin PGDATABASE=postgres
psql -v ON_ERROR_STOP=1 -f "$stage/roles.sql"
i=0
while IFS= read -r database; do
  i=$((i+1))
  # A fresh target has Supabase's predefined databases; create any additional databases through psql quoting.
  psql -v ON_ERROR_STOP=1 -v db="$database" <<'SQL'
SELECT format('CREATE DATABASE %I', :'db') WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname=:'db') \gexec
SQL
  pg_restore --clean --if-exists --exit-on-error --dbname="$database" "$stage/db-$i.dump"
done < "$stage/databases.txt"
cp -a "$stage/database-keys/." /etc/postgresql-custom/
echo 'Database restored. Restore the matching database/application tokens and storage objects, then restart PostgreSQL and Supabase.'
