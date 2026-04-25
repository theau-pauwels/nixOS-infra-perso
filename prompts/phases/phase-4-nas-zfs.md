# Phase 4: NAS Host with ZFS RAIDZ2

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Kot site: new NAS with 6 × 4TB disks
- Expected usable: ~16TB (RAIDZ2/RAID6, NOT RAID5)
- ZFS recommended with sanoid snapshots
- Restic for encrypted backups
- No public exposure - LAN/VPN only
- SMB/NFS shares

## This Phase Only Implements:

### Objective
Create declarative NAS configuration with safe ZFS RAIDZ2 setup.

### Tasks

1. **NAS host configuration**
   - `hosts/nas-kot/default.nix` - Full NixOS config
   - Hardware-specific settings (TODO placeholders)
   - Network configuration for Kot site (10.224.x.x)

2. **ZFS module implementation**
   - `modules/backup/zfs.nix` - Convert from skeleton to real module
   - SAFE defaults: NO auto-pool creation on first boot
   - Pool configuration structure with TODOs
   - Dataset hierarchy examples:
     ```
     nas/data        # General storage
     nas/media       # Jellyfin media
     nas/backups     # Restic backup destination
     nas/snapshots   # Sanoid snapshot storage
     ```
   - Sanoid automation config
   - ZFS sending/receiving for replication

3. **Restic backup module**
   - `modules/backup/restic.nix` - Convert from skeleton
   - Backup repository configuration
   - Backup profiles (config files, databases, etc.)
   - Prune and forget policies
   - NO real passwords - use environment variable or TODO

4. **File sharing services**
   - SMB/CIFS for Windows compatibility
   - NFS for Linux clients
   - User/group mapping skeleton
   - LAN-only binding (no public exposure)

5. **Documentation**
   - `docs/implementation/nas-kot-zfs.md`
     - RAIDZ2 vs other options rationale
     - Why ~16TB usable from 24TB raw
     - Pool creation procedure (manual, not automated)
     - Dataset organization
     - Backup strategy with Restic
     - Sanoid snapshot retention
     - Rollback procedures

### Constraints for This Phase
- CRITICAL: ZFS module must NOT auto-create/format pools on first build
- All disk device paths must be TODO placeholders
- Pool creation must be manual with documented procedure
- NO public network binding for SMB/NFS
- Restic password via environment variable or age decryption

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- `nix build .#nas-kot` produces valid tarball ✅
- ZFS module has NO destructive defaults ✅
- Pool creation documented as manual procedure ✅
- Restic config has no cleartext passwords ✅

### Questions to Ask Before Starting
1. What NAS hardware form factor (case, motherboard) are you planning?
2. Should SMB shares use existing system users or dedicated NAS users?
3. Restic: prefer environment variable for password or sops-nix integration?
4. Any specific dataset hierarchy requirements beyond the examples?
