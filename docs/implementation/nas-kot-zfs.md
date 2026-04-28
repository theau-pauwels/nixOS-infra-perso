# NAS Kot ZFS

## Status

Phase 4 adds a declarative NixOS target for `nas-kot` with safe ZFS, Sanoid
snapshots, LAN-only SMB/NFS/FileBrowser shares, and Restic wired to `sops-nix`.

The module does not create or format disks.

## Storage Design

The planned NAS has six 4 TB disks:

```text
6 x 4 TB raw = 24 TB raw
RAIDZ2 parity = 2 disks
usable before filesystem overhead = about 16 TB
```

RAIDZ2 is chosen because it can survive two disk failures. RAIDZ1/RAID5 is not
appropriate for this size and disk count.

## Manual Pool Creation

Disk identifiers in `hosts/nas-kot/default.nix` are TODO placeholders. Before
creating the pool, list real stable disk IDs:

```bash
ls -l /dev/disk/by-id/
```

Manual creation procedure:

```bash
zpool create \
  -o ashift=12 \
  -O acltype=posixacl \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O mountpoint=none \
  nas raidz2 \
  /dev/disk/by-id/TODO-nas-disk-1 \
  /dev/disk/by-id/TODO-nas-disk-2 \
  /dev/disk/by-id/TODO-nas-disk-3 \
  /dev/disk/by-id/TODO-nas-disk-4 \
  /dev/disk/by-id/TODO-nas-disk-5 \
  /dev/disk/by-id/TODO-nas-disk-6
```

Datasets:

```bash
zfs create -o mountpoint=/srv/nas/data nas/data
zfs create -o mountpoint=/srv/nas/media nas/media
zfs create -o mountpoint=/srv/nas/backups nas/backups
zfs create -o mountpoint=/srv/nas/snapshots nas/snapshots
```

## Shares

Shares are LAN/VPN-only. There is no Authelia dependency for SMB or NFS.

| Share | Path | Access group |
| --- | --- | --- |
| `data` | `/srv/nas/data` | `nas-users` |
| `media` | `/srv/nas/media` | `nas-media`, `nas-users` |
| `backups` | `/srv/nas/backups` | `nas-admins` |

SMB binds to `eno1` and allows only Kot LAN/server subnets plus the Headscale
range. NFS exports are restricted per share to Kot LAN/server CIDRs.

FileBrowser listens on the NAS LAN address only and exists for private browser
access from LAN/VPN clients.

## Snapshots

Sanoid manages snapshots for declared datasets with the default `nas` template:

- 24 hourly snapshots
- 14 daily snapshots
- 6 monthly snapshots
- 1 yearly snapshot

Sanoid prunes automatically according to that retention.

## Restic and SOPS

Restic jobs use `sops-nix` secret files:

- `/run/secrets/restic/nas-kot-password`
- `/run/secrets/restic/nas-kot-repository`

The encrypted source is `hosts/nas-kot/secrets.enc.yaml`. The committed file
contains only encrypted placeholder values; replace them before production.

The default job backs up:

- `/etc/nixos`
- `/srv/nas/data`

Large media is intentionally not included by default.

## Validation

Build the NAS target:

```bash
nix build .#nas-kot
```

Build the preserved VPS bundle:

```bash
nix build .#theau-vps-bundle
```

## Rollback

If the NixOS config fails before data migration, keep the pool imported manually
and boot a previous generation.

If sharing configuration fails:

```bash
systemctl stop smb nmb nfs-server filebrowser
```

ZFS data remains on disk because this repo does not automate destructive pool
operations.
