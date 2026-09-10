# Supabase PostgreSQL service for Wodby

PostgreSQL 17 for the Supabase self-hosted/v0.8.1 bundle, using `supabase/postgres:17.6.1.136` and the Wodby `stateful` chart. The upstream image entrypoint performs initialization; replacing it with the PostgreSQL executable would bypass setup and privilege dropping.

## Database contract

Supabase owns the `postgres` database, reserved roles, internal schemas and extensions. The service exports its `postgres_password` and `jwt_secret` tokens to linked Supabase services. Database and user creation actions are intentionally absent: the upstream image provisions these resources. Manage additional application schemas through Supabase migrations; remove the owning service when the entire database is no longer needed.

The data volume and `/etc/postgresql-custom` encryption-key volume are both persistent. Preserve both when moving or restoring an environment. Initialization SQL is mounted at the paths used by the pinned upstream image and runs only for an empty data directory.

## Backup and restore

The database backup contains custom-format dumps for all non-template databases, role attributes/memberships, and the database encryption-key directory. It uses temporary space on the data volume and needs headroom for the dumps and final archive. Database and role identifiers containing tabs/newlines are rejected instead of producing an ambiguous backup index.

Take the backup with Supabase application writers stopped when matching it to an object-storage backup. Save the Wodby database and application tokens separately; neither a logical database dump nor object storage contains those credentials.

Restore only into a fresh, isolated PostgreSQL instance running the same bundle, with application writers stopped. Extract the trusted backup archive, then run:

```sh
SUPABASE_RESTORE_CONFIRM=fresh-instance sh /opt/wodby/restore.sh /path/to/extracted-backup
```

The restore creates missing roles, applies saved attributes and memberships, restores each database, and restores encryption material. Restore matching source tokens and objects before restarting PostgreSQL and Supabase. Restoring role passwords changes the required connection credentials; use the matching database token for the target.

Do not change the PostgreSQL major image tag against an existing data directory. Major upgrades and restoring a backup from another bundle need a separately tested migration procedure.

## Upstream source

Initialization SQL comes from [Supabase self-hosted/v0.8.1](https://github.com/supabase/supabase/tree/self-hosted/v0.8.1/docker/volumes/db), commit `8c7a4d9dbbaf8b552893822e89d7bf06f33f9220`. The upstream license is retained in this repository.
