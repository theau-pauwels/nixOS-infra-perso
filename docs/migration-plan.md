# Migration Plan

## Overview

The migration is split into eight phases. Each phase should preserve rollback
paths and keep the current VPS production bundle working until phase 7 replaces
it deliberately.

## Phase 0: Preserve Current VPS Bundle Deployment

Entry criteria:

- Current repository builds the VPS bundle.
- Current deployment workflow is understood.

Exit criteria:

- Current bundle architecture is documented.
- `nix flake check` and `nix build .#theau-vps-bundle` pass.
- Bundle output is inspected.

Rollback:

- No runtime change. Revert documentation if needed.

Risk:

- Low. Documentation and validation only.

## Phase 1: Documentation and Skeleton Modules

Entry criteria:

- Phase 0 documentation exists.
- Current VPS bundle still builds.

Exit criteria:

- Architecture, addressing, security, migration, and disaster recovery docs
  exist.
- Future SSH access platform design doc exists.
- Skeleton Nix modules and host files parse.
- README links the new docs and phase status.

Rollback:

- Remove or revert skeleton files and docs. No live infrastructure is changed.

Risk:

- Low. Skeleton files are not imported into the production bundle.

## Phase 2: Jellyfin Kot Declarative Migration

Entry criteria:

- Kot Jellyfin VM current state is audited.
- Data locations and rollback compose files are known.

Exit criteria:

- Jellyfin/seedbox service definitions are declarative.
- Secrets are managed without cleartext commits.
- Rollback to previous VM configuration is documented.

Rollback:

- Stop declarative services and restore the previous `/opt/seedbox` deployment
  or VM snapshot.

Risk:

- Medium. Media and download services can be disrupted.

## Phase 3: Headscale and Caddy

Entry criteria:

- VPS public edge requirements are documented.
- DNS and certificate rollback are understood.

Exit criteria:

- VPN control plane and reverse proxy are declaratively modeled.
- Admin and service access routes are documented.
- Public exposure matrix is updated.

Rollback:

- Repoint DNS or service proxy to previous endpoints.
- Reactivate previous VPS generation if still on the Ubuntu bundle.

Risk:

- Medium to high. VPN and public ingress can affect admin access.

## Phase 4: NAS ZFS

Entry criteria:

- NAS hardware and disk identifiers are recorded.
- Backup plan exists before destructive storage operations.

Exit criteria:

- ZFS pools and datasets are declarative.
- Snapshot and backup policies are documented.
- No auto-format behavior is enabled without explicit operator action.

Rollback:

- Preserve importable pools.
- Boot from previous system generation or installer media if needed.

Risk:

- High. Storage mistakes can destroy data.

## Phase 5: Mom Edge

Entry criteria:

- Mom network topology is documented.
- Hardware role is chosen.

Exit criteria:

- Site gateway, VPN, firewall, and monitoring agent are declarative.
- Optional NVR placement is documented.

Rollback:

- Revert router/gateway changes or restore previous Proxmox/VM snapshot.

Risk:

- Medium. Site internet or LAN routing can be affected.

## Phase 6: Dad Edge

Entry criteria:

- Dad hardware choice and Starlink constraints are known.
- Outbound VPN model is selected.

Exit criteria:

- Lightweight gateway connects outbound to the mesh or VPS.
- No inbound public access is assumed.

Rollback:

- Disconnect gateway or restore previous router-only topology.

Risk:

- Medium. Remote troubleshooting is harder behind CGNAT.

## Phase 7: VPS NixOS Native

Entry criteria:

- Current Ubuntu bundle is fully documented and reproducible.
- NixOS VPS configuration is tested separately.
- DNS, certificate, SSH, VPN, and rollback plans are explicit.

Exit criteria:

- VPS runs native NixOS or an equivalent fully declarative target.
- Current services are preserved or intentionally replaced.
- Old Ubuntu bundle rollback path is retained until cutover is proven.

Rollback:

- Repoint DNS or restore the previous VPS/image.
- Keep fixed-IP SSH access to the old VPS until success is confirmed.

Risk:

- High. This phase affects public ingress, VPN, SSH, and remote access.
