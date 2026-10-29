# Servarr stack (Prowlarr + Sonarr + Radarr + Bazarr + Seerr + Transmission + qBittorrent + Jellyfin)

This role installs a self-contained "servarr" stack to find and automatically
fetch torrents for TV shows and movies, and make them available in a media
library. It is **fully independent** from the `server/transmission` role:
separate containers, separate domains, separate data directory
(`/home/servarr`), separate Transmission P2P port (`51414`). The existing
transmission/jellyfin setup is never touched, so this stack can be removed
entirely at any time without affecting it.

qBittorrent (with the [VueTorrent](https://github.com/VueTorrent/VueTorrent)
web UI) runs in parallel with Transmission, sharing the same data directory,
with its own P2P port (`51415`). Sonarr/Radarr still use Transmission.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the services
- `server/firewall` with `51414` and `51415` added to `open_ports` (this
  stack's Transmission and qBittorrent P2P ports)

## Required variables

```yaml
- role: server/servarr
  vars:
    prowlarr_ui_domain: "prowlarr.statox.fr"
    sonarr_ui_domain: "sonarr.statox.fr"
    radarr_ui_domain: "radarr.statox.fr"
    servarr_transmission_ui_domain: "servarr-transmission.statox.fr"
    servarr_qbittorrent_ui_domain: "torrent.statox.fr"
    servarr_jellyfin_domain: "servarr-jellyfin.statox.fr"
    bazarr_ui_domain: "bazarr.statox.fr"
    seerr_ui_domain: "seerr.statox.fr"
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
│   ├── qbittorrent
│   ├── prowlarr
│   ├── sonarr
│   ├── radarr
│   ├── jellyfin
│   ├── bazarr
│   └── seerr
└── cache
    └── jellyfin
```

`servarr-transmission`, `servarr-qbittorrent`, `sonarr`, `radarr` and `bazarr`
all mount the entire `/home/servarr/data` directory to `/data` inside the container — this is
required for hardlinks/atomic moves to work between the torrents and library
folders (see the [servarr docker guide](https://wiki.servarr.com/docker-guide)),
and for `bazarr` to see files at the exact same paths Sonarr/Radarr report,
avoiding the need for remote path mappings.
Transmission and qBittorrent download to the same folders; this is safe as
long as the same torrent is never added to both clients.
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
5. If an indexer fails with a Cloudflare-related error (e.g. "Unable to
   access ..., blocked by CloudFlare Protection"), configure the bundled
   [Byparr](https://github.com/ThePhaseless/Byparr) FlareSolverr-compatible
   proxy: in Prowlarr, Settings > Indexers > FlareSolverr Proxies > add one
   with URL `http://byparr:8191`, then tag the failing indexer with that
   proxy under its own settings.
6. In **Bazarr**, connect it to Sonarr and Radarr under Settings > Sonarr /
   Settings > Radarr: host `sonarr` (or `radarr`), port `8989` (or `7878`),
   and the API key from each app's Settings > General. Then under
   Settings > Languages, create a Languages Profile with French as the
   first (cutoff) priority and English as fallback, and set it as the
   default profile so it applies to newly added series/movies.
7. In **Seerr**, sign in with your Jellyfin credentials, then under
   Settings > Services add Sonarr (host `sonarr`, port `8989`) and Radarr
   (host `radarr`, port `7878`) with their API keys and the same root
   folders/quality profiles configured above, and add Jellyfin (host
   `servarr-jellyfin`, port `8096`) under Settings > Jellyfin so Seerr can
   check what's already in the library.
8. In **qBittorrent**, get the temporary admin password printed in
   `docker logs servarr-qbittorrent` on first start, log in and set a
   permanent password under Settings > WebUI. The rest of the configuration
   is seeded by the role from `templates/qBittorrent.conf.j2` and
   `templates/categories.json.j2`:
   - save paths `/data/torrents/complete` and `/data/torrents/incomplete`
   - the allowed WebUI domain
   - the VueTorrent web UI, installed in `/vuetorrent` by the `DOCKER_MODS`
     in `docker-compose.yml`
   - Automatic torrent management by default: each category is saved in its
     own folder, `/data/torrents/complete/<category>` unless the category
     sets another path (subcategories become nested folders), and files are
     moved when a torrent's category changes. Tags don't affect paths. Avoid
     category names used by Transmission (`radarr`, `tv-sonarr`) to keep
     the two clients' folders separate
   - two default categories, `iso_linux` and `other`

   These files are only written when they don't exist yet: qBittorrent
   rewrites them itself (settings on shutdown, categories when they change),
   so afterwards the UI is the source of truth.
