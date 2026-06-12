# Kot Media Stack: Jellyfin, Seedbox, Jellyseerr, and SSO

## Status

This is the phase 2 and phase 2.5 declarative target for Kot media services.
`jellyfin-kot` and `seedbox-kot` were deployed as fresh NixOS VMs on
2026-04-30. `jellyseerr-kot` remains a declarative target only.

Current deployed VMs on the `10.224.20.0/24` subnet (DHCP-managed):

| VM | LAN IP | WireGuard IP | Role |
|---|---|---|---|
| `jellyfin-kot` | `10.224.20.21` | `10.8.0.21/32` | Jellyfin media server |
| `seedbox-kot` | `10.224.20.22` | `10.8.0.22/32` (gluetun) | qBittorrent + gluetun + Filebrowser |
| `storage-kot` | `10.224.20.10` | `10.8.0.23/32` | Samba NAS + Filebrowser |

All deployed VMs use UEFI `systemd-boot`, root label `nixos`, boot label
`NIXBOOT`, NetworkManager with DHCP, and the `theau-vps-deploy` SSH key for
the `theau` admin account. The live installer password was used only to
bootstrap the key.

DNS is provided by `networking.nameservers = [ "10.224.20.1" ]` as a safety
net in case DHCP does not supply nameservers (see
[incident 2026-06-03](../incident/2026-06-03-kot-wireguard-clock-skew.md)).

## Context

The Kot site currently has a Proxmox VM named `jellyfin_kot` with an
imperative `/opt/seedbox` deployment. The stack contains Jellyfin, qBittorrent,
and gluetun. The target changes this into one VM per service, with VM storage
backed by NAS-Kot.

Target VMs:

- `jellyfin-kot`: Jellyfin only
- `seedbox-kot`: qBittorrent plus gluetun only
- `jellyseerr-kot`: Jellyseerr only

The current torrent privacy path exits through the WireGuard endpoint on
`IONOS-VPS2` in Germany:

- endpoint IP: `82.165.20.195`
- endpoint port: `51820/udp`
- legacy qBittorrent peer address: `10.8.0.20/32`
- Jellyfin ingress peer address: `10.8.0.21/32`
- seedbox-kot Gluetun peer address: `10.8.0.22/32`

## Design

The NixOS target separates service lifecycle and blast radius:

- Jellyfin can be tuned for media serving and hardware acceleration later.
- Seedbox traffic is isolated behind gluetun.
- Jellyseerr can be SSO-protected and integrated with Jellyfin users.
- NAS-Kot can provide VM disks and shared media datasets.

Network shape:

```text
IONOS-VPS2 (82.165.20.195)
  |
  | WireGuard hub (10.8.0.1/24)
  v
  +-- jellyfin-kot:   Jellyfin, TCP 8096 via 10.8.0.21
  +-- seedbox-kot:    qBittorrent via gluetun, TCP 8080 via 10.8.0.22
  |                   Filebrowser on LAN, TCP 8082 (noauth)
  +-- storage-kot:    Samba NAS, Filebrowser, TCP 8082 via 10.8.0.23

Kot LAN (10.224.20.0/24):
  |
  +-- storage-kot (10.224.20.10): Samba //10.224.20.10/nas
  +-- jellyfin-kot (10.224.20.21): CIFS mount /srv/nas
  +-- seedbox-kot  (10.224.20.22): CIFS mount /srv/nas, Filebrowser :8082
```

Torrent egress:

```text
seedbox-kot qBittorrent container
  |
  | --network=container:seedbox-gluetun
  v
seedbox-kot gluetun container
  |
  | WireGuard
  v
IONOS-VPS2 Germany
```

qBittorrent does not get its own independent network namespace. If gluetun is
down, qBittorrent should not have a normal direct egress path.

## Source Files

- Jellyfin host: `hosts/jellyfin-kot/default.nix`
- Seedbox host: `hosts/seedbox-kot/default.nix`
- Jellyseerr host: `hosts/jellyseerr-kot/default.nix`
- Seedbox module: `modules/services/seedbox.nix`
- Jellyseerr module: `modules/services/jellyseerr.nix`
- Identity provider skeleton: `modules/services/identity-provider.nix`
- phase 2.5 prompt: `prompts/phases/phase-2.5-kot-media-sso-split.md`

Flake outputs:

- `nixosConfigurations.jellyfin-kot`
- `nixosConfigurations.seedbox-kot`
- `nixosConfigurations.jellyseerr-kot`
- `packages.x86_64-linux.jellyfin-kot`
- `packages.x86_64-linux.seedbox-kot`
- `packages.x86_64-linux.jellyseerr-kot`
- `packages.x86_64-linux.kot-media-stack`

## Storage Layout

All Kot VMs mount the shared Samba NAS from `storage-kot` at `/srv/nas` via
CIFS. Service-specific data (Jellyfin config, seedbox container volumes) lives
on local disks under `/srv`.

```text
storage-kot   /srv/nas  (local ext4 disk) — shared via Samba
jellyfin-kot  /srv/nas  (CIFS mount //10.224.20.10/nas)
              /srv/jellyfin (local root disk) — config, cache, data, logs
seedbox-kot   /srv/nas  (CIFS mount //10.224.20.10/nas)
              /srv/seedbox (local root disk) — container volumes
```

## Jellyfin

`jellyfin-kot` runs native NixOS Jellyfin 10.11.11 (nixpkgs 2026-06-10,
NixOS 26.11).

```text
/srv/jellyfin/cache
/srv/jellyfin/config
/srv/jellyfin/data
/srv/jellyfin/log
```

Jellyfin is exposed internally on `8096/tcp` and publicly through
`https://jellyfin.theau.net`. The public route terminates TLS on `IONOS-VPS2`,
uses Authelia/LLDAP group policy for `media-users`, `media-admins`, or
`admins`, then proxies to `10.8.0.21:8096` over WireGuard.

To update Jellyfin, update the nixpkgs input in `flake.nix` and run:

```bash
nix flake update nixpkgs
nixos-rebuild boot --flake github:theau-pauwels/nixOS-infra-perso#jellyfin-kot
sudo reboot
```

The `boot` action (instead of `switch`) is required when systemd or dbus
changes across nixpkgs bumps.

### Jellyfin CIFS write permissions

Jellyfin runs as UID/GID 999. The CIFS mount at `/srv/nas` must set the
correct ownership and force write permissions so Jellyfin can save downloaded
subtitles next to media files:

```nix
fileSystems."/srv/nas" = {
  device = "//10.224.20.10/nas";
  fsType = "cifs";
  options = [
    "guest"
    "uid=999"          # Jellyfin system user
    "gid=999"
    "forceuid"         # Force all files to appear owned by uid=999
    "forcegid"
    "file_mode=0664"
    "dir_mode=0775"
    "noperm"           # Skip local permission checks (CIFS with containers)
    "hard"
    "rsize=1048576"    # 1 MB I/O chunks
    "wsize=1048576"
    "echo_interval=15"
    "actimeo=3"
    "noacl"
    "noserverino"
    "nofail"
    "_netdev"
    "x-systemd.requires=network-online.target"
    "cache=loose"
    "vers=3.1.1"
  ];
};
```

Without `uid=999`, `forceuid`, `forcegid`, and `noperm`, Jellyfin cannot
create or modify files on the CIFS share even if the Samba server allows guest
writes.

### Jellyfin NVIDIA Passthrough

`jellyfin-kot` is prepared for a Proxmox PCI passthrough of the NVIDIA Quadro
P400:

```text
01:00.0 VGA compatible controller: NVIDIA GP107GL [Quadro P400]
01:00.1 Audio device: NVIDIA GP107GL High Definition Audio Controller
```

The NixOS host config enables the proprietary NVIDIA 580 legacy driver, disables
the open NVIDIA kernel module because the P400 is a Pascal GPU, and grants
Jellyfin the `video` and `render` groups for hardware transcoding access. Do not
use the current stable 595 driver for this card: the kernel reports the Quadro
P400 is supported by the 580.xx legacy branch and 595 ignores the GPU.

In Proxmox, pass both PCI functions to the VM with `All Functions` and
`PCI-Express` enabled. Do not make the NVIDIA card the primary GPU during the
first boot unless the guest console has already been validated.

After deployment, validate the guest sees the card:

```bash
nvidia-smi
systemctl status jellyfin
```

Validated on `2026-04-30`: `nvidia-smi` reports driver `580.142` and the
`Quadro P400` at PCI address `00000000:01:00.0`.

Then enable hardware acceleration in the Jellyfin UI with the NVIDIA NVENC
backend.

## Seedbox

`seedbox-kot` runs:

- gluetun container
- qBittorrent container sharing gluetun's network namespace

Default seedbox paths:

```text
/srv/seedbox/downloads
/srv/seedbox/gluetun
/srv/seedbox/qbittorrent/config
```

gluetun reads WireGuard secret material from:

```text
/var/lib/seedbox/gluetun/ionos-vps2-wireguard.env
```

Expected shape:

```bash
WIREGUARD_PRIVATE_KEY=REPLACE_WITH_REAL_PRIVATE_KEY
WIREGUARD_PRESHARED_KEY=REPLACE_WITH_REAL_PRESHARED_KEY
WIREGUARD_PUBLIC_KEY=REPLACE_WITH_IONOS_VPS2_SERVER_PUBLIC_KEY
```

This file must not be committed.

The seedbox containers are gated by this file. Until it exists,
`podman-seedbox-gluetun.service` and `podman-seedbox-qbittorrent.service` are
skipped instead of starting with incomplete VPN credentials.

qBittorrent is exposed publicly through `https://qbit.theau.net`. The public
route terminates TLS on `IONOS-VPS2`, uses Authelia/LLDAP group policy for
`media-admins` or `admins`, then proxies to `10.8.0.22:8080` over the seedbox
Gluetun WireGuard interface. The Gluetun firewall must allow both the
qBittorrent WebUI port `8080/tcp` and the torrent port `6881/tcp+udp` as VPN
input ports.

Do not put `10.8.0.0/24` in Gluetun `FIREWALL_OUTBOUND_SUBNETS`: Gluetun routes
those outbound subnets over `eth0`, which breaks replies to the VPS WireGuard
address `10.8.0.1`.

### Filebrowser on seedbox-kot

`seedbox-kot` runs Filebrowser on port `8082` rooted at `/srv/nas`, accessible
from the Kot LAN (`10.224.0.0/16`) without authentication. The database was
migrated from `storage-kot` to preserve existing share links.

| Detail | Value |
|---|---|
| Port | `8082` (firewall: `allowedTCPPorts = [ ... 8082 ]`) |
| Address | `0.0.0.0` (accessible from LAN) |
| Auth | `noauth` (open to `10.224.0.0/16`) |
| Root | `/srv/nas` |
| Database | `/var/lib/filebrowser/database.db` (migrated from storage-kot) |

```nix
services.filebrowser = {
  enable = true;
  openFirewall = false;
  settings = {
    address = "0.0.0.0";
    port = 8082;
    root = "/srv/nas";
    database = "/var/lib/filebrowser/database.db";
  };
};

# Switch from storage-kot's proxy auth to noauth for LAN access.
systemd.services.filebrowser.preStart = ''
  if [ -f /var/lib/filebrowser/database.db ]; then
    PATH=${pkgs.filebrowser}/bin:$PATH
    filebrowser config set --auth.method=noauth --database /var/lib/filebrowser/database.db 2>/dev/null || true
    filebrowser users update 1 --username=theau --perm.admin=true --database /var/lib/filebrowser/database.db 2>/dev/null || true
  fi
'';

users.users.filebrowser.extraGroups = [ "users" ];
```

The `storage-kot` Filebrowser instance at `10.8.0.23:8082` continues to run
with its existing proxy auth through Authelia.

## Jellyseerr

`jellyseerr-kot` runs NixOS `services.seerr`, the renamed Jellyseerr module.

Jellyseerr data path:

```text
/srv/jellyseerr/config
```

Jellyseerr should be connected to:

- Jellyfin at the future private URL for `jellyfin-kot`
- qBittorrent through the future private URL for `seedbox-kot`
- SSO through Authelia/OIDC once the identity provider is active

## SSO and User Management

Target identity model:

- LLDAP provides a web-based user manager.
- Authelia provides SSO.
- IONOS-VPS2 exposes the auth entrypoint through the reverse proxy.
- The initial super-admin is `theau`.
- Only users in the `super-admin` group may manage users.
- Each user record must include name, password, and email.
- Email is required for operational notifications and account recovery flows.

The repository contains `modules/services/identity-provider.nix` as a skeleton
for this target. It does not include real passwords, JWT secrets, session
secrets, SMTP credentials, or OIDC client secrets.

LLDAP admin password placeholder path:

```text
/run/secrets/lldap-admin-password
```

Future public routes:

```text
auth.theau-vps.duckdns.org   -> Authelia
users.theau-vps.duckdns.org  -> LLDAP web UI, super-admin only
```

## Deployment to Proxmox

Expected future deployment model:

1. Create three NixOS VMs in Proxmox.
2. Store VM disks on NAS-Kot once NAS-Kot is available.
3. Attach or mount the relevant service data path per VM.
4. Replace placeholder disk labels in each host file.
5. Place gluetun WireGuard secrets on `seedbox-kot`.
6. Build each host output:

```bash
nix build .#jellyfin-kot
nix build .#seedbox-kot
nix build .#jellyseerr-kot
```

The flake packages produce tarball artifacts containing symlinks to evaluated
NixOS system closures. They validate host configuration; they are not Proxmox
installer images.

## Migration Notes

Before cutover, audit the current VM:

- current OS and boot mode
- current `/opt/seedbox/docker-compose.yml`
- current Jellyfin config and metadata paths
- current qBittorrent config path and download paths
- current gluetun environment
- current HDD device identifier and filesystem
- current UID/GID ownership of media and downloads

Suggested migration:

1. Create new VMs without touching the existing VM.
2. Take a backup or snapshot of the current VM.
3. Copy Jellyfin state to `jellyfin-kot`.
4. Copy qBittorrent state to `seedbox-kot`.
5. Configure Jellyseerr against the new Jellyfin and qBittorrent URLs.
6. Validate gluetun egress through IONOS-VPS2 Germany.
7. Move users to the SSO-backed flow.
8. Retire the old `/opt/seedbox` stack only after all checks pass.

## Storage integration (storage-kot NAS)

Jellyfin media and seedbox downloads are served from a shared `storage-kot`
NixOS VM via Samba/CIFS, replacing local disk storage. All clients mount the
same `nas` share for a unified filesystem view — hardlinks work between
`downloads/_arr-work/` and `jellyfin/` because they're on the same mount.

### CIFS mounts (unified)

All machines mount `//storage-ip/nas` at a standard path:

| Machine | Mount | Path |
|---|---|---|
| jellyfin-kot | `//10.224.20.10/nas` | `/srv/nas` |
| seedbox-kot | `//10.224.20.10/nas` | `/srv/nas` |
| VPS (*arr) | `//10.8.0.23/nas` | `/data/media` |

**jellyfin-kot** (`hosts/jellyfin-kot/default.nix`):

```nix
fileSystems."/srv/nas" = {
  device = "//10.224.20.10/nas";
  fsType = "cifs";
  options = [
    "guest"
    "uid=999"          # Jellyfin system user
    "gid=999"
    "forceuid"
    "forcegid"
    "file_mode=0664"
    "dir_mode=0775"
    "noperm"           # Required: Jellyfin writes need this
    "hard"
    "rsize=1048576"
    "wsize=1048576"
    "echo_interval=15"
    "actimeo=3"
    "noacl"
    "noserverino"
    "nofail"
    "_netdev"
    "x-systemd.requires=network-online.target"
    "cache=loose"
    "vers=3.1.1"
  ];
};
```

Jellyfin library paths: `/srv/nas/jellyfin/movies/`, `/srv/nas/jellyfin/shows/`.

**seedbox-kot** (`hosts/seedbox-kot/default.nix`):

```nix
fileSystems."/srv/nas" = {
  device = "//10.224.20.10/nas";
  fsType = "cifs";
  options = [
    "guest" "uid=991" "gid=991" "file_mode=0664" "dir_mode=0775"
    "noperm" "nofail" "_netdev"
    "x-systemd.requires=network-online.target"
  ];
};
```

Symlink for qBittorrent container compatibility:
`/srv/seedbox/downloads` → `/srv/nas/downloads`. The container maps
`/srv/seedbox/downloads:/downloads` (podman resolves the symlink to
`/srv/nas/downloads`). The seedbox module preStart enforces
`Session\DefaultSavePath=/downloads`.

**Critical**: Use `noperm` on all CIFS mounts where containerized apps
(qBittorrent, Sonarr, Radarr) need write access. Without it, the CIFS client
enforces local permission checks that don't match the container's UID mapping,
causing "Permission denied" on file creation.

### qBittorrent reverse proxy auth

qBittorrent v5.1.x uses `bypass_auth_subnet_whitelist` (stored as
`WebUI\AuthSubnetWhitelist` in the INI config) to skip its own authentication
for requests from the VPS WireGuard IP (`10.8.0.1`). The seedbox module
preStart writes this on first config creation.

If qBittorrent shows "Unauthorized" after Authelia login, check:
- qBittorrent container is running (`systemctl status podman-seedbox-qbittorrent`)
- `WebUI\AuthSubnetWhitelist=10.8.0.0/24` in the qBittorrent config
- `WebUI\AuthSubnetWhitelistEnabled=true`
- VPS can reach qBittorrent: `curl -sI http://10.8.0.22:8080/` should return 200

## Rollback

Rollback before cutover:

- keep the current VM untouched
- use the new NixOS VMs only for testing

Rollback after cutover:

1. Stop affected NixOS service or roll back to the previous NixOS generation.
2. Restore VM snapshot if needed.
3. Restart the previous `/opt/seedbox` compose stack if preserved.
4. Repoint clients or reverse proxy routes to the previous endpoints.

Do not delete the old `/opt/seedbox` deployment until Jellyfin libraries,
qBittorrent state, downloads, Jellyseerr requests, and gluetun egress have been
verified.

## TODO

- Replace placeholder disk labels with real stable identifiers.
- Pin OCI image digests for gluetun and qBittorrent.
- Move WireGuard secret material into a SOPS-backed host secret workflow.
- Configure Authelia OIDC clients for Jellyfin and Jellyseerr if supported by
  the chosen integration path.
- Deploy `nixos-rebuild` for `seedbox-kot` with current config changes
  (Filebrowser, nameserver). `jellyfin-kot` deployed 2026-06-13.
- Remove `storage-kot` Filebrowser instance once `seedbox-kot` Filebrowser is fully adopted.
