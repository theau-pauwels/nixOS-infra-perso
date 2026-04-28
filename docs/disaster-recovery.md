# Disaster Recovery

## Goals

Disaster recovery separates configuration, secrets, and data. Git is the source
for declarative configuration, SOPS protects deployable secrets, and backup
systems protect mutable runtime data.

## Recovery Targets

| Area | Target |
| --- | --- |
| Git configuration | Recover from GitHub or local clone |
| Encrypted secrets | Recover from Git plus private age key backup |
| VPS services | Rebuild or rollback from Nix bundle generations |
| Kot media data | Restore from NAS snapshots or backups |
| NAS datasets | Restore from ZFS snapshots or remote backup |
| Monitoring data | Best effort unless explicitly backed up |
| Certificates | Reissue from ACME where possible |

## Backup Classes

### Configuration Backup

Configuration backup includes:

- Git repository content
- encrypted SOPS files
- documented host inventory
- public SSH key inventory
- migration docs and runbooks

Configuration backup excludes:

- cleartext secrets
- live exported VPN configs
- raw backups
- runtime databases unless explicitly backed up elsewhere

### Secret Backup

Secret backup includes:

- SOPS age identity
- local bootstrap secrets that cannot be recreated
- password/TOTP bootstrap material where needed

Secret backups must be encrypted and stored separately from public Git.

### Data Backup

Data backup includes:

- media metadata that is hard to recreate
- personal files
- service databases
- NAS datasets
- application state under `/var/lib` when the service needs it

Large replaceable media can have lower priority than unique personal data.

## Site Strategy

### VPS

- Keep Nix bundle generations under `/opt/theau-vps/generations/`.
- Keep `/opt/theau-vps/current` pointing to the active generation.
- Back up encrypted secrets and the SOPS age key.
- Treat Let's Encrypt certificates as reissuable.
- Document any stateful service data under `/var/lib`.

### Kot

- Use ZFS snapshots for NAS datasets once available.
- Back up service configs and databases separately from bulk media.
- Keep seedbox rollback instructions for the current VM until migrated.

### Mom

- Back up gateway configuration and any NVR metadata.
- Camera footage retention can be shorter unless marked important.
- Consider Mom as a future off-site backup target only after storage and power
  constraints are understood.

### Dad

- Keep gateway config simple enough to rebuild.
- Because the site is behind CGNAT, preserve outbound VPN credentials securely.

## Recovery Time Objectives

| Component | Target RTO | Notes |
| --- | --- | --- |
| Admin SSH to VPS | 1 hour | Requires keys and reachable host |
| VPN gateway | 2 hours | Depends on secrets and DNS |
| Public reverse proxy | 2 hours | Certificates can be reissued |
| Jellyfin/seedbox | 1 day | Data volume can dominate |
| NAS data | Best effort by dataset | Depends on backup size |
| Monitoring history | Best effort | Lower priority than service recovery |

## Restore Principles

- Restore secrets first only on trusted machines.
- Prefer rebuilding hosts from declarative config over editing by hand.
- Verify network access before enabling dependent services.
- Restore data into a staging path when possible.
- Do not overwrite live datasets without a snapshot or external backup.
- After recovery, document the exact commands used and update runbooks.
