# Target Architecture

## Context

This repository currently manages a production Ubuntu 24.04 VPS through a
Nix-built bundle. The target architecture is a multi-site, mostly declarative
personal infrastructure managed with Nix and NixOS modules over time.

The current VPS bundle remains the production deployment path until a later
phase replaces it with a tested migration and rollback process.

## Current State

Current production scope:

- Ubuntu 24.04 VPS at `82.165.20.195`
- domain `theau-vps.duckdns.org`
- Nix-built bundle deployed to `/opt/theau-vps/generations/<timestamp>`
- activation scripts install Ubuntu config and systemd units
- services: OpenSSH, WireGuard, WGDashboard, Nginx, nftables, iperf3, certbot,
  and RustDesk OSS

Current operational model:

```text
admin laptop
  |
  | nix build .#theau-vps-bundle
  | nix copy + temporary decrypted secrets
  v
Ubuntu VPS
  |
  | activate-theau-vps-generation
  v
/etc, /var/lib, /etc/systemd/system, /opt/theau-vps/current
```

## Target State

The target architecture separates public entrypoints, site gateways, compute,
storage, observability, and backups.

```text
                         public internet
                              |
                              v
                    +--------------------+
                    | VPS public edge    |
                    | VPN control plane  |
                    | reverse proxy      |
                    | SSO entrypoint     |
                    | RustDesk           |
                    +---------+----------+
                              |
                       VPN / private mesh
                              |
      +-----------------------+-----------------------+
      |                       |                       |
      v                       v                       v
+-------------+        +-------------+        +-------------+
| Kot site    |        | Mom site    |        | Dad site    |
| compute     |        | edge/NVR    |        | CGNAT edge  |
| NAS/storage |        | monitoring  |        | VPN client  |
| media       |        | backup later|        | gateway     |
+-------------+        +-------------+        +-------------+
```

## Site Roles

### VPS

The VPS is the public and control-plane entrypoint:

- public reverse proxy
- Headscale or equivalent VPN coordination
- SSO-protected service ingress
- RustDesk OSS server
- uptime checks and alert fan-out
- temporary compatibility home for the current WireGuard/WGDashboard bundle

### Kot

The Kot site is the primary compute and storage site:

- Jellyfin and seedbox workloads
- future NAS with ZFS
- Filebrowser or similar private file access
- monitoring/log backend when capacity is available
- backup source for important local datasets

### Mom

The Mom site is a smaller edge site:

- site-to-site VPN gateway
- possible Frigate or lightweight NVR
- monitoring agent
- possible off-site backup target later

### Dad

The Dad site is behind Starlink CGNAT and should be simple:

- outbound VPN client to the VPS or mesh
- lightweight site gateway only
- no public inbound exposure assumption

## Technology Choices

- Nix and NixOS modules: reproducible host configuration and safer drift
  control.
- Current Nix bundle: compatibility path for the active Ubuntu VPS.
- WireGuard and/or Headscale: private connectivity between sites and admin
  clients.
- Caddy: simple TLS reverse proxy for future NixOS-managed services.
- Authelia: lightweight SSO for private web applications.
- nftables: explicit host firewalling.
- ZFS: future NAS storage with snapshots and replication.
- Restic: encrypted off-site backups for selected datasets and configs.
- Prometheus, Grafana, Loki, exporters: future observability stack.

## Data Flows

### Admin Access

```text
admin device
  |
  | SSH public key or future short-lived SSH certificate
  v
managed host
```

Personal break-glass admin keys remain distinct from any future delegated
temporary access platform.

### Private Service Access

```text
admin/client device
  |
  | VPN or mesh
  v
VPS reverse proxy / SSO
  |
  | private upstream
  v
site service
```

Public access should be the exception. Most administrative and personal services
should be VPN-only or SSO-protected.

### Backup Flow

```text
site datasets
  |
  | snapshots / restic backup jobs
  v
local backup target and/or remote encrypted repository
```

Configuration backup and data backup are treated separately. Git stores
declarative configuration, not private runtime state or secrets.

## Migration Approach

The migration is incremental:

1. Preserve the existing VPS bundle and document it.
2. Add documentation and non-active skeleton modules.
3. Move site workloads one at a time into declarative models.
4. Add VPN, SSO, monitoring, backups, and native NixOS hosts gradually.
5. Replace the Ubuntu VPS bundle only after a tested NixOS-native migration path
   exists.

No future skeleton in this phase is imported by the current flake or deployed to
production.
