# Immich

This role installs [Immich](https://immich.app/), a self-hosted photo and
video backup solution, with `immich-server`, `redis` and its `postgres`
database. It does **not** include the `immich-machine-learning` service, so
features that depend on it (Smart Search, Facial Recognition, Duplicate
Detection) are unavailable; core backup/browsing/albums work normally.
Commenting out that service in `docker-compose.yml` is the officially
supported way to disable it (see the
[FAQ](https://docs.immich.app/FAQ#how-can-i-disable-machine-learning)),
rather than only disabling it in the admin settings, which would still start
the container.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the service

## Required variables

```yaml
- role: server/immich
  vars:
    immich_ui_domain: "immich.statox.fr"
```

Plus a secret that must exist in `vars/secrets.yml.enc` (see the main repo
README for how to edit the vault):

```yaml
immich_db_password: somepassword
```

Deploy with:

```bash
./run install_panda.yml -e @vars/secrets.yml.enc --vault-password-file vars/get-vault-password.sh
```

## Storage layout

All data lives under `/home/immich`, created by this role with owner/group
`1000:1000`:

```
/home/immich
├── library   # Uploaded photos/videos (UPLOAD_LOCATION)
└── postgres  # Database files (DB_DATA_LOCATION)
```

## Cloud backup

A `backup` sidecar container runs `aws s3 sync` daily at **04:40** against
the entire `UPLOAD_LOCATION` directory (`/home/immich/library` on the host,
mounted read-only at `/library` in the container), pushing to a dedicated
`statox-immich-backup` S3 bucket (provisioned by Terraform in the
`statox-provisioning` repo, see `terraform/immich/s3-backup.tf`).

This one sync covers both halves of a full backup:

- **The media itself** — original assets. This instance has Storage
  Template **enabled**, so originals live under
  `UPLOAD_LOCATION/library/<userID>/...` (not the default `upload/`); user
  avatars are under `UPLOAD_LOCATION/profile/<userID>/...`.
- **The database** — Immich's own built-in "Automatic Database Backups" job
  (enabled by default, daily at 02:00, keeps the last 14) writes `.sql.gz`
  dumps to `UPLOAD_LOCATION/backups`. No separate `pg_dump` step is run by
  this role; the 04:40 sync time is chosen specifically to run after this
  02:00 job so the synced dump is never older than the synced media.

**Deletions in Immich are never mirrored to S3** — the sync never passes
`--delete`, and the IAM policy attached to the `immich-backup` S3 user does
not grant `s3:DeleteObject` at all, so even a compromised or buggy container
can't delete backed-up objects. This means storage in the bucket only grows
over time; there is no automatic pruning.

### Restoring

Restore is a manual, rare operation and is not automated by this role.
Follow the official procedure:
https://docs.immich.app/administration/backup-and-restore — in short,
restore the database backup first, then the filesystem, so the restored
database never references files missing from the filesystem restore.

### Required secret

In addition to `immich_db_password`, add to `vars/secrets.yml.enc`:

```yaml
immich_backup_s3_access_key: (from the `immich_backup_user_access_key` Terraform output)
immich_backup_s3_secret_key: (from the `immich_backup_user_access_key` Terraform output)
```

## Manual first-time configuration

Visit `immich_ui_domain` to create the admin account on first visit.

## Known limitation: large uploads may time out

Traefik's default `websecure` entrypoint timeouts can be too short for large
photo/video uploads. If uploads fail or time out, add a longer responding
timeout to the entrypoint in `server/traefik`'s `traefik.yml`:

```yaml
entryPoints:
  websecure:
    address: :443
    transport:
      respondingTimeouts:
        readTimeout: 600s
        idleTimeout: 600s
```

This is not currently configured by the `server/traefik` role.
