# Supabase PostgreSQL on Wodby

What Wodby and the image set up for the database of a Supabase project. Check it before creating databases or roles, or changing passwords and JWT settings by hand.

## What the image provisions

The image is the Supabase PostgreSQL image with Wodby backup, import and readiness operations. On an empty data directory it runs Supabase's own initialization: the reserved roles, internal schemas and extensions of the Supabase bundle.

- The database is always `postgres`. The administrator is `supabase_admin`; applications connect as `postgres`. Both use the same generated password (token `postgres_password`, in the container as `POSTGRES_PASSWORD`).
- The JWT secret is generated once per environment (token `jwt_secret`, in the container as `JWT_SECRET`); `JWT_EXP` sets the token lifetime.
- Wodby declares no create or drop actions for databases and users on this service: these resources belong to Supabase. Application tables and policies are managed with Supabase migrations, not by adding databases or reserved roles.
- Keep `POSTGRES_DB` and the data directory as they are; the image requires these values.

## How a linked service reaches it

- Host: the name of this app service inside the environment. Port: `5432`. The port is private: it is reachable inside the cluster and gets no public route.
- The Supabase service linked to this one receives the host, the port, `postgres_password` and `jwt_secret` through its `db` link. The password and the JWT secret are owned by this service; change them here, never on the Supabase service alone.

## Data, backups and imports

- The `data` volume is mounted at `/var/lib/postgresql`. It holds the PostgreSQL `data/` directory and `wodby-keys/` with the root encryption key. Both must stay together: an existing database refuses to start when its key is missing.
- The backup is a `.tar.gz` with custom-format dumps of all non-template databases, role attributes and memberships, the root encryption key and a checksummed inventory. It contains secrets. Table patterns in the token `exclude_tables` (separated by `;`) keep their definition and lose their rows. The backup is staged on the data volume, so it needs free space there.
- The import accepts only a `.tar.gz` or `.tgz` backup made by this service with the same Supabase bundle. It is restored into a new, empty data volume before the server accepts connections. An ordinary SQL dump is not accepted. After the import the built-in logins use the target environment's `postgres_password` and the JWT settings follow its `jwt_secret`; passwords of custom roles come from the backup.
- A failed initialization or import leaves a marker that blocks a normal start. The fix is a new import on a fresh volume, not removing the marker.
- The database backup does not include storage objects or the Supabase service's tokens.

## Check the result

In the database container, `supabase-ops check-ready` succeeds when the database is ready; `psql -c '\du'` lists the roles (the container's `PG*` variables select the administrator and the database).
