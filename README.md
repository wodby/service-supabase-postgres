# Supabase PostgreSQL service for Wodby

PostgreSQL 17 for the Supabase self-hosted/v0.8.1 bundle, using `wodby/supabase-postgres:17-0.1.0` and the Wodby `stateful` chart. The image retains the official Supabase runtime and entrypoint, and provides Wodby backup and import operations.

## Use this service

Use this service through the [Supabase stack](https://github.com/wodby/stack-supabase).

## Database contract

The service pins `wodby/supabase-postgres:17-0.1.0`, retaining the official Supabase runtime and entrypoint with Wodby backup/import helpers.

Supabase owns the `postgres` database, reserved roles, internal schemas and extensions. The service exports its `postgres_password` and `jwt_secret` tokens to linked Supabase services. Database and user creation actions are intentionally absent: the image provisions these resources. Manage application schemas through Supabase migrations.

Mount the persistent data volume at `/var/lib/postgresql`. It contains the PostgreSQL `data/` directory and `wodby-keys/`, including the root encryption key. Keeping these together lets native import replace both on one fresh volume. Initialization SQL is packaged in the image and runs only on an empty data directory. This layout is not an in-place conversion of another PostgreSQL service.

## Backup and import

The database backup contains custom-format dumps of all non-template databases, role attributes and memberships, the root encryption key, and a checksummed inventory. It needs space on the data volume for both the staged dumps and the final archive. The `exclude_tables` token accepts semicolon-separated table patterns; matching tables retain their definitions but omit their rows. Role names containing newlines are rejected.

Use the service's **Supabase database import** operation with a `.tar.gz` or `.tgz` backup produced by the same image bundle. The workflow extracts it into a read-only mount and starts the image on a fresh replacement volume. The image validates the files, installs the saved root key, initializes PostgreSQL and restores the databases before opening TCP connections. Corrupt backups and live-database imports are rejected. After incomplete initialization, retry with a fresh volume; do not remove its failure marker.

Supabase-owned database passwords are set from the target environment's `postgres_password`; custom role passwords are restored from the backup. Database JWT settings follow the target `jwt_secret`. An unchanged import is safe across a container restart and is not replayed against the existing database.

A coordinated recovery also needs matching application signing/encryption tokens and stored objects. Stop application writers when capturing that recovery point. Database import does not restore filesystem or S3 objects. Preserve the tokens needed to decrypt application data and rotate client-facing credentials separately when appropriate. Backups contain secrets and require protected storage.

Only the checksummed format from the same supported Supabase bundle is accepted. Ordinary SQL dumps, another bundle, or a PostgreSQL major upgrade need a separately tested migration procedure. A Helm rollback does not undo database migrations.

## Upstream source

The [Supabase PostgreSQL image](https://github.com/wodby/supabase-postgres) packages initialization SQL from [Supabase self-hosted/v0.8.1](https://github.com/supabase/supabase/tree/self-hosted/v0.8.1/docker/volumes/db), commit `8c7a4d9dbbaf8b552893822e89d7bf06f33f9220`, and retains the upstream license.

## Maintain a custom version

Fork this repository, update the manifest, and validate the complete Supabase bundle before importing your service.
