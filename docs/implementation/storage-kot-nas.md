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
| Samba | `jellyfin` (media) + `downloads` (seedbox), guest access on LAN |
| FileBrowser | `10.8.0.23:8082`, proxy auth via `Remote-User` header from Authelia |
| WireGuard | `10.8.0.23/32` to VPS hub (`82.165.20.195:51820`) |
| LAN IP | `10.1.10.124/24` (management bridge, DHCP) + `10.224.20.10/24` (secondary) |
| Firewall | TCP 22, 139, 445, 8082 |

## Alternatives considered

- **Kernel NFS**: exFAT lacks export_operations — kernel NFS server refuses to
  export. NFS-Ganesha (userspace) and unfs3 both failed to work reliably on
  this NixOS version.
- **CIFS-only**: Chosen for seedbox downloads (performance less critical).
  Jellyfin media uses optimized CIFS mount (`vers=3.1.1`, 4MB I/O,
  `cache=loose`).
- **Reformat vda to ext4**: Would enable kernel NFS but requires data migration
  and downtime. Deferred until data backup is in place.

## FileBrowser configuration

FileBrowser uses Authelia's proxy auth mechanism:

1. User accesses `https://file.theau.net`.
2. Nginx → Authelia auth_request → validates session cookie.
3. Authelia returns `Remote-User` header (e.g. `theau`).
4. Nginx forwards `Remote-User` to FileBrowser at `10.8.0.23:8082`.
5. FileBrowser (configured with `--auth.method=proxy --auth.header=Remote-User`)
   identifies the user without its own login.

Admin access is mapped to the LLDAP `theau` user via the FileBrowser database.
The `admins`, `media-admins`, and `media-users` LLDAP groups are authorized by
Authelia's access control.

## Samba shares

| Share | Path | Purpose | Clients |
|---|---|---|---|
| `nas` | `/srv/nas` | Root share — single mount for hardlinks | All clients |
| `jellyfin` | `/srv/nas/jellyfin` | Legacy — Jellyfin media library | Deprecated (use nas share) |
| `downloads` | `/srv/nas/downloads` | Legacy — qBittorrent downloads | Deprecated (use nas share) |

Samba is scoped to subnets (`10.8.0.0/24`, `10.224.20.0/24`, `10.1.10.0/24`,
`127.0.0.0/8`) with guest access and `force user = theau`.

## Client mounts

All clients mount the same `nas` share for a unified filesystem view.
This enables hardlinks instead of copies — `mv` and `ln` between
`downloads/_arr-work/` and `jellyfin/` are instant (server-side).

| Client | Device | Mount | Options |
|---|---|---|---|
| jellyfin-kot | `//10.1.10.124/nas` | `/srv/nas` | `vers=3.1.1`, `rsize=4194304`, `cache=loose`, `actimeo=3` |
| seedbox-kot | `//10.1.10.124/nas` | `/srv/nas` | `uid=991,gid=991,noperm`, `_netdev` |
| VPS (*arr apps) | `//10.8.0.23/nas` | `/data/media` | `noperm` |

**Important**: All mounts include `noperm` to bypass client-side CIFS
permission checks. The Samba server handles permissions via `force user`.
Without `noperm`, containerized apps (qBittorrent, Sonarr, Radarr) cannot
write to CIFS directories even with correct UID mapping.

Seedbox-kot has a symlink for qBittorrent compatibility:
`/srv/seedbox/downloads` → `/srv/nas/downloads`.

## Deployment

- NixOS config: `hosts/storage-kot/default.nix`
- Live config at `/etc/nixos/configuration.nix`
- Admin user: `theau` with `~/.ssh/theau-vps-deploy` key
- FileBrowser database: `/var/lib/filebrowser/database.db`
- FileBrowser admin password auto-generated on first start

## Operation notes

- After NixOS rebuild, FileBrowser proxy auth is configured by the
  `systemd.services.filebrowser.preStart` hook.
- The `filebrowser-config` oneshot service ensures the `theau` user has
  admin permissions.
- Samba restarts on config changes via `nixos-rebuild switch`.
- qBittorrent `Session\DefaultSavePath` must be `/downloads` (container
  path, not host path) — enforced by seedbox module preStart.

## Rollback

- Config rollback: restore previous `/etc/nixos/configuration.nix` and
  `nixos-rebuild switch`.
- Data rollback: `vda` is mounted read-write but never formatted by NixOS;
  data survives OS reinstalls.
