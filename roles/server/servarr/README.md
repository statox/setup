# Servarr stack (Prowlarr + Sonarr + Radarr + Whisparr + Bazarr + Seerr + Transmission + qBittorrent + Jellyfin)

This role installs a self-contained "servarr" stack to find and automatically
fetch torrents for TV shows and movies, and make them available in a media
library. It is **fully independent** from the `server/transmission` role:
separate containers, separate domains, separate data directory
(`/home/servarr`), separate Transmission P2P port (`51414`). The existing
transmission/jellyfin setup is never touched, so this stack can be removed
entirely at any time without affecting it.

qBittorrent (with the [VueTorrent](https://github.com/VueTorrent/VueTorrent)
web UI) runs in parallel with Transmission, with its own P2P port (`51415`).
Its data lives on a Hetzner Storage Box mounted on panda (see
[Storage Box](#storage-box)). Sonarr/Radarr use Transmission.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the services
- `server/firewall` with `51414` and `51415` added to `open_ports` (this
  stack's Transmission and qBittorrent P2P ports)
- the Storage Box, created by Terraform in the `provisioning` repo
  (`terraform/torrents/storage_box.tf`)

## Required variables

```yaml
- role: server/servarr
  vars:
    prowlarr_ui_domain: "prowlarr.statox.fr"
    sonarr_ui_domain: "sonarr.statox.fr"
    radarr_ui_domain: "radarr.statox.fr"
    whisparr_ui_domain: "whisparr.statox.fr"
    servarr_transmission_ui_domain: "servarr-transmission.statox.fr"
    servarr_qbittorrent_ui_domain: "torrent.statox.fr"
    servarr_jellyfin_domain: "servarr-jellyfin.statox.fr"
    bazarr_ui_domain: "bazarr.statox.fr"
    seerr_ui_domain: "seerr.statox.fr"
```

And the Storage Box holding qBittorrent's data:

```yaml
    servarr_storage_box_host: "servarr-storage.statox.fr"
    servarr_storage_box_user: "u706669" # Terraform output
    # known_hosts line of the box, see "Storage Box" below
    servarr_storage_box_host_key: "[servarr-storage.statox.fr]:23 ssh-ed25519 AAAA..."
```

Optional, with their defaults (`defaults/main.yml`):

```yaml
servarr_storage_box_port: 23
servarr_storage_box_remote_dir: qbittorrent # folder of the box mounted as /data
servarr_storage_box_uid: 1000 # owner of the files on the mount, as seen on panda
servarr_storage_box_gid: 1000
servarr_storage_box_read_ahead_kb: 4096
```

Plus secrets that must exist in `vars/secrets.yml.enc` (see the main repo
README for how to edit the vault):

```yaml
servarr_transmission_user: someusername
servarr_transmission_password: somepassword
# Private key of the Storage Box (Dashlane note "servarr-storage ssh key")
servarr_storage_box_ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
```

Deploy with:

```bash
./run install_panda.yml -e @vars/secrets.yml.enc --vault-password-file vars/get-vault-password.sh
```

## Storage layout

Data lives under `/home/servarr`, created by this role with owner/group
`1000:1000` (matching every container's `PUID`/`PGID`). The folders under
`qbittorrent-data` are on the box, created by the role through the mount:

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
│       ├── tv
│       └── whisparr
├── qbittorrent-data       Storage Box mount, qBittorrent's /data
│   ├── torrents
│   │   ├── incomplete
│   │   └── complete/<category>
│   └── library
│       ├── movies
│       └── tv
├── config
│   ├── transmission
│   ├── qbittorrent
│   ├── prowlarr
│   ├── sonarr
│   ├── radarr
│   ├── whisparr
│   ├── jellyfin
│   ├── bazarr
│   └── seerr
└── cache
    └── jellyfin
```

`servarr-transmission`, `sonarr`, `radarr`, `whisparr` and `bazarr` all mount
the entire `/home/servarr/data` directory to `/data` inside the container — this is
required for hardlinks/atomic moves to work between the torrents and library
folders (see the [servarr docker guide](https://wiki.servarr.com/docker-guide)),
and for `bazarr` to see files at the exact same paths Sonarr/Radarr report,
avoiding the need for remote path mappings.
`servarr-qbittorrent` mounts `/home/servarr/qbittorrent-data` (the Storage
Box) to `/data`. The other containers don't see qBittorrent's files: Whisparr,
which uses qBittorrent as download client, can't import its downloads.
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
   - the allowed WebUI domains: the public domain, and `servarr-qbittorrent`
     so the other containers (e.g. Whisparr) can reach it by container name
   - the VueTorrent web UI, installed in `/vuetorrent` by the `DOCKER_MODS`
     in `docker-compose.yml`
   - Automatic torrent management by default: each category is saved in its
     own folder, `/data/torrents/complete/<category>` unless the category
     sets another path (subcategories become nested folders), and files are
     moved when a torrent's category changes. Tags don't affect paths
   - two default categories, `iso_linux` and `other`

   These files are only written when they don't exist yet: qBittorrent
   rewrites them itself (settings on shutdown, categories when they change),
   so afterwards the UI is the source of truth.

## Storage Box

qBittorrent's `/data` is a [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box)
mounted on panda with SSHFS at `/home/servarr/qbittorrent-data`
(`tasks/storage_box.yml`). Three pieces work together:

| Piece | Role |
|---|---|
| `/etc/fstab` entry (`vars/main.yml`) | Mounts the box at boot as the systemd unit `home-servarr-qbittorrent\x2ddata.mount`. Reconnects after network drops; `nofail` lets panda boot when the box is unreachable |
| `servarr-storage-box-read-ahead.service` | Started by each mount of the box. Sets the mount's read-ahead to `servarr_storage_box_read_ahead_kb` (4 MB): SSHFS waits one round trip per read request, and the kernel's 128 KB default limits reads to ~16 MB/s, 4 MB reaches the link's ~115 MB/s |
| `servarr-qbittorrent.service` | One unit per container on the box (`servarr_storage_box_containers` in `vars/main.yml`, template `templates/servarr-storage-box-container.service.j2`). Started by each mount of the box, after the read-ahead: `docker compose up --force-recreate` of the container. Stopping the mount unit stops them first. The containers have the compose profile `storage-box`, so these units are the only thing that starts them. `restart: on-failure` restarts a crashed container, but not on a Docker daemon restart, when the box may be unmounted. Each deploy of the role restarts them |

Security:

- The SSH key and the pinned host key are in `/etc/servarr-storage-box`
  (`root:root`, `0700`/`0600`); SSH refuses a box whose host key differs.
- `allow_other` + `default_permissions` + `uid`/`gid`/`umask=0027`: every
  file shows as owned by `servarr_storage_box_uid`/`servarr_storage_box_gid`
  with mode `0750`. That UID (and root) reads and writes, that GID reads,
  other users get nothing. `nosuid,nodev,noexec`.
- Unmounted, `/home/servarr/qbittorrent-data` is an empty `root:root 0755`
  directory: qBittorrent can't write to panda's disk through it.
- The mount runs on the host, independently of Docker. With rootless Docker,
  set `servarr_storage_box_uid`/`servarr_storage_box_gid` to the host UID/GID
  that container UID 1000 maps to, and run the containers units as
  user units of the Docker user.

### Behaviour

| Situation | What happens |
|---|---|
| Panda boots, box reachable | Box mounted, read-ahead set, qBittorrent started |
| Panda boots, box unreachable | Boot continues, the box containers stay stopped. `systemctl start 'home-servarr-qbittorrent\x2ddata.mount'` once the box is back mounts it and starts them |
| Deploy while the box is unreachable | The mount gives up after 10 s, the rest of the stack deploys, the box containers stay stopped and the deploy prints a warning |
| Deploy fails on the box while it is mounted (e.g. a container doesn't start) | The deploy fails with the error |
| Short network drop | SSHFS reconnects. Files qBittorrent had open return I/O errors: their torrents go into error. Force a recheck / resume them in the UI |
| SSHFS process dies | The mount stays but every access fails ("Transport endpoint is not connected"). Run `umount -l /home/servarr/qbittorrent-data` (this stops the box containers) then `systemctl start 'home-servarr-qbittorrent\x2ddata.mount'` |
| A box container crashes | Docker restarts it. If it keeps crashing: `systemctl restart <container>` (`servarr-qbittorrent`) |

Useful commands:

```bash
findmnt -o TARGET,FSTYPE,OPTIONS /home/servarr/qbittorrent-data
cat /sys/class/bdi/$(mountpoint -d /home/servarr/qbittorrent-data)/read_ahead_kb
systemctl status 'home-servarr-qbittorrent\x2ddata.mount' servarr-storage-box-read-ahead servarr-qbittorrent
# Unmount (stops the box containers first) / mount (starts them again)
systemctl stop 'home-servarr-qbittorrent\x2ddata.mount'
systemctl start 'home-servarr-qbittorrent\x2ddata.mount'
```

### Known limitations

- After a network drop, torrents whose files were open stay in error until
  they are rechecked or resumed by hand in the UI: nothing resumes them
  automatically.
- Two parallel reads from the box were not measured: whether they share the
  ~115 MB/s of a single read or need `max_conns` is unknown.

### First-time setup

1. Get the box's host key and check it against the fingerprint panda saw on
   its first connection to the box:

   ```bash
   ssh-keyscan -p 23 -t ed25519 servarr-storage.statox.fr | tee /tmp/sb-key | ssh-keygen -lf -
   sudo ssh-keygen -lF '[servarr-storage.statox.fr]:23' -f /root/.ssh/known_hosts
   ```

   Put the `ssh-keyscan` line in `servarr_storage_box_host_key` in
   `install_panda.yml`.
2. Add `servarr_storage_box_ssh_private_key` to the vault.
3. Create the folder mounted on panda (the role creates the folders inside
   it on each deploy):

   ```bash
   sftp -P 23 -i ~/.ssh/servarr-storage u706669@servarr-storage.statox.fr <<'SFTP'
   mkdir qbittorrent
   SFTP
   ```

4. Deploy the role.

### Moving torrents from panda's disk to the box

Paths inside the container are the same on the box
(`/data/torrents/complete/<category>/...`), so a moved torrent only needs a
recheck.

1. Stop qBittorrent: `sudo systemctl stop servarr-qbittorrent`.
2. Copy the torrents' files from `/home/servarr/data/torrents/...` to the box
   at the same relative path, with rsync over SSH (`-H` keeps hardlinks; faster than through the
   SSHFS mount, ~31 MB/s writes: about 9 hours per TB):

   ```bash
   sudo rsync -aH --info=progress2 -e 'ssh -p 23 -i /etc/servarr-storage-box/id_ed25519 -o UserKnownHostsFile=/etc/servarr-storage-box/known_hosts' \
     /home/servarr/data/torrents/complete/<category>/ \
     u706669@servarr-storage.statox.fr:qbittorrent/torrents/complete/<category>/
   ```

3. Start qBittorrent: `sudo systemctl start servarr-qbittorrent`.
4. In the UI, force a recheck of the moved torrents and check they reach
   100 % and seed.
5. Remove from qBittorrent the torrents whose files stay on panda (their
   files are missing on the box).
6. Once the moved torrents have seeded correctly for a while, delete their
   copies on panda.
