# Storage Kot NAS

## Context

`storage-kot` is a NixOS VM providing centralized NAS storage via Samba/CIFS
and a FileBrowser web interface behind Authelia + LLDAP. It replaces local
storage on jellyfin-kot and seedbox-kot with a shared `vda` disk hosted on the
same Proxmox machine.

## Why

- Single storage host avoids media/download data duplication across VMs.
- Existing `vda` disk (3.6T exFAT with live data) retained as-is.
- exFAT cannot serve kernel NFS — Samba/CIFS provides cross-platform file
  sharing without reformatting.
- FileBrowser gives a web-based file manager for `/srv/nas`, protected by the
  same Authelia SSO as other `*.theau.net` services.

## Design

| Component | Details |
|---|---|
| OS | NixOS 25.11 on `/dev/sda` (32G) |
| Data disk | `/dev/vda` (3.6T exFAT), mounted at `/srv/nas` |
| Samba | `nas` (root), `jellyfin`, `downloads` shares, guest access |
| FileBrowser | `10.8.0.23:8082`, proxy auth via `Remote-User` header from Authelia |
| WireGuard | `10.8.0.23/32` to VPS hub (`82.165.20.195:51820`) |
| LAN IP | `10.1.10.124/24` (management bridge, DHCP) + `10.224.20.10/24` (secondary) |
| Firewall | TCP 22, 139, 445, 8082 |

## Alternatives considered

- **Kernel NFS**: exFAT lacks `export_operations` — kernel NFS server refuses to
  export. NFS-Ganesha (userspace) and unfs3 both failed to work reliably on
  this NixOS version.
- **Reformat vda to ext4**: Would enable kernel NFS but requires data migration
  and downtime. Deferred until data backup is in place.

## Unified mount strategy — why everything mounts the same share

All client machines mount the **same Samba share** (`nas`, root at `/srv/nas`)
at the **same mount point** (`/srv/nas`) instead of separate per-app shares
(`jellyfin`, `downloads`). This is the single most important design decision
in this setup.

### Problem with separate shares

If jellyfin-kot mounted `//storage/jellyfin` at `/srv/jellyfin/media` and
seedbox-kot mounted `//storage/downloads` at `/srv/seedbox/downloads`, these
are **two independent CIFS mount points**. Moving a file from downloads to
jellyfin requires a **copy + delete** across filesystems, which for a 4GB
movie takes minutes and doubles disk I/O.

### Solution: single mount

With a single `nas` share mounted at `/srv/nas` everywhere, all directories
live on the **same filesystem from every client's perspective**:

- `/srv/nas/jellyfin/movies/` — Radarr movie library
- `/srv/nas/jellyfin/shows/` — Sonarr TV library
- `/srv/nas/downloads/_arr-work/complete/` — completed downloads
- `/srv/nas/downloads/_arr-work/sonarr/` — Sonarr category in qBittorrent
- `/srv/nas/downloads/_arr-work/radarr/` — Radarr category in qBittorrent
- `/srv/nas/jellyfin/_NEED-REWORK/` — manual rework zone

Sonarr and Radarr use **hardlinks** instead of copies when importing completed
downloads. A hardlink creates a second directory entry pointing to the same
data on disk — it takes **milliseconds regardless of file size** and uses
**zero extra disk space**. This only works within a single filesystem, which
is exactly what the unified nas mount provides.

### Path consistency across machines

Every machine sees the same paths:

| Machine | Mount | Via |
|---|---|---|
| storage-kot | `/srv/nas` | local exFAT disk |
| jellyfin-kot | `/srv/nas` | CIFS `//10.1.10.124/nas` |
| seedbox-kot | `/srv/nas` | CIFS `//10.1.10.124/nas` |
| VPS (sonarr/radarr) | `/srv/nas` | CIFS `//10.8.0.23/nas` |

Jellyfin-kot and seedbox-kot use the management bridge IP (`10.1.10.124`) for
direct same-host throughput without WireGuard overhead. The VPS uses the
WireGuard IP (`10.8.0.23`) since it's remote.

### noperm requirement

All CIFS mounts include `noperm`. Without it, the Linux CIFS client enforces
local Unix permission checks against the mounted files. Since exFAT has no
Unix permissions, the CIFS layer applies `uid=`, `gid=`, `file_mode=`, and
`dir_mode=` to fake them. But containerized processes (qBittorrent, Sonarr,
Radarr) run with UIDs that differ from the CIFS-forced owner, causing
"Permission denied" errors on file creation.

`noperm` tells the CIFS client to skip local permission checks entirely and
delegate to the Samba server, which uses `force user = theau` so all files
are owned by a single user.

### CIFS stability tuning

exFAT + CIFS on a busy Proxmox bridge can experience socket stalls (observed
in dmesg as "stuck for 15 seconds"). The following mount options mitigate this:

- `hard` — retries I/O indefinitely instead of returning errors (default is
  `soft`, which fails fast and causes torrent "Permission denied" errors)
- `rsize=1048576,wsize=1048576` — 1MB I/O chunks (reduced from 4MB to avoid
  large contiguous reads blocking the socket)
- `echo_interval=15` — SMB keepalive every 15 seconds (down from 60) for
  faster dead-socket detection

## Samba shares

| Share | Path | Purpose |
|---|---|---|
| `nas` | `/srv/nas` | **Primary** — single mount for hardlinks, used by all clients |
| `jellyfin` | `/srv/nas/jellyfin` | Legacy, kept for backward compatibility |
| `downloads` | `/srv/nas/downloads` | Legacy, kept for backward compatibility |

Samba is scoped to subnets (`10.8.0.0/24`, `10.224.20.0/24`, `10.1.10.0/24`,
`127.0.0.0/8`) with guest access and `force user = theau`.

## FileBrowser configuration

FileBrowser uses Authelia's proxy auth mechanism:

1. User accesses `https://file.theau.net`.
2. Nginx → Authelia `auth_request` → validates session cookie.
3. Authelia returns `Remote-User` header (e.g. `theau`).
4. Nginx forwards `Remote-User` to FileBrowser at `10.8.0.23:8082`.
5. FileBrowser (configured with `--auth.method=proxy --auth.header=Remote-User`)
   identifies the user without its own login.

Admin access is mapped to the LLDAP `theau` user via the FileBrowser database.
Public share URLs (`/share/*`) bypass Authelia entirely — static assets, API
calls, and share pages are served without authentication.

## *Arr stack integration

The VPS runs Sonarr and Radarr as systemd services (like Prowlarr and Seerr).
They connect to qBittorrent on seedbox-kot and Prowlarr on localhost:

### Sonarr (TV) — `https://sonarr.theau.net`
- Port: 8989 (127.0.0.1)
- Root folder: `/srv/nas/jellyfin/shows/`
- Download client: qBittorrent at `10.8.0.22:8080`
- Indexer: Prowlarr at `http://127.0.0.1:9696`
- No Remote Path Mapping needed — same filesystem
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`

### Radarr (Movies) — `https://radarr.theau.net`
- Port: 7878 (127.0.0.1)
- Root folder: `/srv/nas/jellyfin/movies/`
- Download client: qBittorrent at `10.8.0.22:8080`
- Indexer: Prowlarr at `http://127.0.0.1:9696`
- No Remote Path Mapping needed — same filesystem
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`

### qBittorrent — `https://qbit.theau.net`
- Container volume: `/srv/nas:/srv/nas` (same path as host)
- DefaultSavePath: `/srv/nas/downloads`
- Category `sonarr`: `/srv/nas/downloads/_arr-work/sonarr`
- Category `radarr`: `/srv/nas/downloads/_arr-work/radarr`
- Auth bypass: `WebUI\AuthSubnetWhitelist=10.8.0.0/24`

### Download → library flow

```
1. Sonarr/Radarr send request to qBittorrent
2. qBittorrent downloads to /srv/nas/downloads/_arr-work/{sonarr|radarr}/
3. On completion, qBittorrent notifies Sonarr/Radarr via API
4. Sonarr/Radarr hardlink the file from _arr-work/ to jellyfin/{shows|movies}/
   (same filesystem — instant, no disk space used)
5. Sonarr/Radarr notify Jellyfin to scan the library
6. Jellyfin picks up the new media
```

## App configuration summary

```
storage-kot:/srv/nas/               ← single source of truth
  ├── jellyfin/
  │   ├── movies/                   ← Radarr root folder
  │   ├── shows/                    ← Sonarr root folder
  │   └── _NEED-REWORK/             ← manual rework zone
  │       ├── movies/
  │       └── shows/
  ├── downloads/
  │   └── _arr-work/                ← qBittorrent download target
  │       ├── complete/
  │       ├── incomplete/
  │       ├── sonarr/               ← Sonarr category
  │       └── radarr/               ← Radarr category
  └── ...
```

## Deployment

- NixOS config: `hosts/storage-kot/default.nix`
- Live config at `/etc/nixos/configuration.nix`
- Admin user: `theau` with `~/.ssh/theau-vps-deploy` key
- FileBrowser database: `/var/lib/filebrowser/database.db`
- FileBrowser admin password auto-generated on first start (idempotent via
  `systemd.services.filebrowser.preStart`)

## Operation notes

- After NixOS rebuild, FileBrowser proxy auth is configured by the
  `systemd.services.filebrowser.preStart` hook.
- Samba restarts on config changes via `nixos-rebuild switch`.
- qBittorrent `Session\DefaultSavePath` must be `/srv/nas/downloads` —
  enforced by seedbox module preStart.
- The `nas` Samba share must be accessible from `10.8.0.0/24` (WireGuard)
  for VPS access, and from `10.1.10.0/24` (management bridge) for VM access.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| qBittorrent "Permission denied" | Missing `noperm` on CIFS mount | Add `noperm` to mount options |
| qBittorrent "Cannot make save path" | DefaultSavePath mismatch container/host | Ensure `/srv/nas:/srv/nas` volume + DefaultSavePath `/srv/nas/downloads` |
| CIFS socket stuck (dmesg) | exFAT I/O latency | Use `hard,rsize=1M,wsize=1M,echo_interval=15` |
| Sonarr/Radarr can't see files | Wrong root folder | Use `/srv/nas/jellyfin/{shows\|movies}/` on VPS |
| Hardlinks not working | Different mount points | Ensure all clients mount the single `nas` share, not per-app shares |

## Rollback

- Config rollback: restore previous `/etc/nixos/configuration.nix` and
  `nixos-rebuild switch`.
- Data rollback: `vda` is mounted read-write but never formatted by NixOS;
  data survives OS reinstalls.
