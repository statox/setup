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
