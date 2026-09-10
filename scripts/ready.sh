#!/bin/sh
set -eu
# TCP connections are accepted only after the image finishes its temporary-server initialization.
pg_isready -h 127.0.0.1 -U supabase_admin >/dev/null
[ "$(psql -h 127.0.0.1 -U supabase_admin -d postgres -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM pg_roles WHERE rolname IN ('authenticator','supabase_auth_admin','supabase_storage_admin')")" = 3 ]
psql -h 127.0.0.1 -U supabase_admin -d postgres -At -v ON_ERROR_STOP=1 -c "SELECT 'supabase_functions'::regnamespace, '_realtime'::regnamespace" >/dev/null
