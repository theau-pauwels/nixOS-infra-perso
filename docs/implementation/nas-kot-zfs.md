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

## Boot and Data Layout

Disk identifiers in `hosts/nas-kot/default.nix` are TODO placeholders. Before
partitioning, list real stable disk IDs:

```bash
ls -l /dev/disk/by-id/
```

The target layout is:

| Disk | EFI | NixOS root | ZFS data |
| --- | --- | --- | --- |
| disk 1 | `NASBOOT1`, 1 GiB | RAID1 member, 30-50 GiB | RAIDZ2 member |
| disk 2 | `NASBOOT2`, 1 GiB | RAID1 member, 30-50 GiB | RAIDZ2 member |
| disk 3 | none | none | RAIDZ2 member |
| disk 4 | none | none | RAIDZ2 member |
| disk 5 | none | none | RAIDZ2 member |
| disk 6 | none | none | RAIDZ2 member |

NixOS root is an ext4 filesystem labeled `nixos-root` on a manually created
mdadm RAID1 device. GRUB is installed to both boot disks using stable
`/dev/disk/by-id` paths. The second EFI partition is mounted at `/boot-fallback`
so it can be synchronized after bootloader updates.

Example manual partitioning for the first two disks:

```bash
sgdisk --zap-all /dev/disk/by-id/TODO-nas-disk-1
sgdisk --new=1:1MiB:+1GiB --typecode=1:EF00 --change-name=1:NASBOOT1 /dev/disk/by-id/TODO-nas-disk-1
sgdisk --new=2:0:+50GiB --typecode=2:FD00 --change-name=2:nixos-root-a /dev/disk/by-id/TODO-nas-disk-1
sgdisk --new=3:0:0 --typecode=3:BF01 --change-name=3:nas-zfs-a /dev/disk/by-id/TODO-nas-disk-1

sgdisk --zap-all /dev/disk/by-id/TODO-nas-disk-2
sgdisk --new=1:1MiB:+1GiB --typecode=1:EF00 --change-name=1:NASBOOT2 /dev/disk/by-id/TODO-nas-disk-2
sgdisk --new=2:0:+50GiB --typecode=2:FD00 --change-name=2:nixos-root-b /dev/disk/by-id/TODO-nas-disk-2
sgdisk --new=3:0:0 --typecode=3:BF01 --change-name=3:nas-zfs-b /dev/disk/by-id/TODO-nas-disk-2
```

Example manual partitioning for disks 3-6:

```bash
sgdisk --zap-all /dev/disk/by-id/TODO-nas-disk-3
sgdisk --new=1:1MiB:0 --typecode=1:BF01 --change-name=1:nas-zfs-c /dev/disk/by-id/TODO-nas-disk-3
```

Repeat the same data-only layout for disks 4, 5, and 6.

Format the EFI partitions and root mirror manually:

```bash
mkfs.vfat -F32 -n NASBOOT1 /dev/disk/by-id/TODO-nas-disk-1-part1
mkfs.vfat -F32 -n NASBOOT2 /dev/disk/by-id/TODO-nas-disk-2-part1

mdadm --create /dev/md/nixos-root --level=1 --raid-devices=2 \
  /dev/disk/by-id/TODO-nas-disk-1-part2 \
  /dev/disk/by-id/TODO-nas-disk-2-part2
mkfs.ext4 -L nixos-root /dev/md/nixos-root
```

After creating the array, copy the output of this command into
`boot.swraid.mdadmConf`:

```bash
mdadm --detail --scan
```

After each bootloader update, synchronize the fallback EFI partition:

```bash
rsync -a --delete /boot/ /boot-fallback/
```

## Manual Pool Creation

Use the ZFS data partitions, not whole disks. The first two disks contribute
their remaining space after EFI and root. The other four disks contribute their
single data partition.

```bash
zpool create \
  -o ashift=12 \
  -O acltype=posixacl \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O mountpoint=none \
  nas raidz2 \
  /dev/disk/by-id/TODO-nas-disk-1-zfs-part \
  /dev/disk/by-id/TODO-nas-disk-2-zfs-part \
  /dev/disk/by-id/TODO-nas-disk-3-zfs-part \
  /dev/disk/by-id/TODO-nas-disk-4-zfs-part \
  /dev/disk/by-id/TODO-nas-disk-5-zfs-part \
  /dev/disk/by-id/TODO-nas-disk-6-zfs-part
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
