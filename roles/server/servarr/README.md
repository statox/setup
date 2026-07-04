# Servarr stack (Prowlarr + Sonarr + Radarr + Transmission + Jellyfin)

This role installs a self-contained "servarr" stack to find and automatically
fetch torrents for TV shows and movies, and make them available in a media
library. It is **fully independent** from the `server/transmission` role:
separate containers, separate domains, separate data directory
(`/home/servarr`), separate Transmission P2P port (`51414`). The existing
transmission/jellyfin setup is never touched, so this stack can be removed
entirely at any time without affecting it.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the services
- `server/firewall` with `51414` added to `open_ports` (this stack's
  Transmission P2P port)

## Required variables

```yaml
- role: server/servarr
  vars:
    prowlarr_ui_domain: "prowlarr.statox.fr"
    sonarr_ui_domain: "sonarr.statox.fr"
    radarr_ui_domain: "radarr.statox.fr"
    servarr_transmission_ui_domain: "servarr-transmission.statox.fr"
    servarr_jellyfin_domain: "servarr-jellyfin.statox.fr"
```

Plus two secrets that must exist in `vars/secrets.yml.enc` (see the main repo
README for how to edit the vault):

```yaml
servarr_transmission_user: someusername
servarr_transmission_password: somepassword
```

Deploy with:

```bash
./run install_panda.yml -e @vars/secrets.yml.enc --vault-password-file vars/get-vault-password.sh
```

## Storage layout

All data lives under `/home/servarr`, created by this role with owner/group
`1000:1000` (matching every container's `PUID`/`PGID`):

```
/home/servarr
├── data
│   ├── torrents
│   │   ├── incomplete
│   │   └── complete
│   │       ├── movies
│   │       └── tv
│   └── library
│       ├── movies
│       └── tv
├── config
│   ├── transmission
│   ├── prowlarr
│   ├── sonarr
│   ├── radarr
│   └── jellyfin
└── cache
    └── jellyfin
```

`servarr-transmission`, `sonarr` and `radarr` all mount the entire
`/home/servarr/data` directory to `/data` inside the container — this is
required for hardlinks/atomic moves to work between the torrents and library
folders (see the [servarr docker guide](https://wiki.servarr.com/docker-guide)).
`servarr-jellyfin` only mounts `/home/servarr/data/library`, read-only.

## Manual first-time configuration

These apps store their configuration through their own web UI, so a few
one-time manual steps are needed after the first deploy:

1. Visit each app's URL and set up the admin account on first visit
   (Prowlarr, Sonarr, Radarr, Jellyfin all prompt for this).
2. In **Sonarr**, add `servarr-transmission` as a download client:
   host `servarr-transmission`, port `9091`, category `tv`. Set the root
   folder to `/data/library/tv`.
3. In **Radarr**, same as Sonarr but category `movies` and root folder
   `/data/library/movies`.
4. In **Prowlarr**, add your indexers, then connect Sonarr and Radarr under
   Settings > Apps so indexers sync to both automatically.
