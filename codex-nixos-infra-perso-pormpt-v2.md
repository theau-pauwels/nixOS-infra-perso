# Codex task: evolve my existing Nix infra repo into a clean multi-site declarative infrastructure

You are working inside my existing repository:

```txt
https://github.com/theau-pauwels/nixOS-infra-perso
```

## Current repo state

The repository currently manages a personal infra deployment mainly for `theau-vps`.

Important current characteristics:

- The repo is currently centered around an Ubuntu 24.04 VPS target.
- Nix builds a reproducible deployment bundle locally.
- Deployment pushes a Nix-built bundle to the VPS.
- Activation scripts install configs and systemd units on Ubuntu.
- Current services include:
  - WireGuard via `wg-quick`
  - WGDashboard on `127.0.0.1:10086`
  - RustDesk OSS server
  - Nginx reverse proxy
  - nftables firewall
  - iperf3
  - certbot renewal timer
- Current main files include:
  - `flake.nix`
  - `hosts/theau-vps/default.nix`
  - `hosts/theau-vps/peers.nix`
  - `hosts/theau-vps/secrets.enc.yaml`
  - `packages/bundle/default.nix`
  - `packages/wgdashboard/default.nix`
  - `deploy/*.sh`
  - `scripts/*.sh`

Do not break the current deployment workflow.

## Infrastructure context

I have 4 sites:

```txt
1. VPS
   Provider: IONOS
   Public IP: 82.165.20.195
   Hostname/domain: theau-vps.duckdns.org
   Specs: 2 vCPU, 2 GB RAM, 80 GB NVMe
   Current role:
   - WireGuard gateway
   - WGDashboard
   - RustDesk OSS server
   - iperf3
   - reverse proxy

2. Kot / appartement
   Internet: fiber
   Public IP: yes
   LAN: 10.224.10.0/24
   Addressing convention: 10.[site].[VLAN].0/24
   Hardware:
   - Dell mini PC
   - Proxmox
   - Intel i5-8500 @ 3 GHz
   - 20 GB RAM
   - 256 GB SSD for Proxmox
   - 4 TB HDD passthrough to jellyfin_kot VM
   Current VM:
   - jellyfin_kot
   - /opt/seedbox
     - Jellyfin
     - qBittorrent
     - gluetun
   Future:
   - new NAS with 6 × 4 TB disks
   - expected around 16 TB usable
   - should not be exposed publicly
   - used for data and backups

3. Mom house
   Internet: VDSL
   Public IP: yes
   LAN: 10.10.10.0/24
   Addressing convention: 10.[site].[VLAN].0/24
   Hardware:
   - ISP router
   - BMAX B2 Pro mini PC
   - Proxmox
   - 8 GB RAM
   - 256 GB SSD
   - 2 × TP-Link Deco M5
   Current/Future role:
   - pfSense VM possible
   - Frigate or lightweight NVR
   - VPN site gateway
   - monitoring agent
   - maybe off-site backup later

4. Dad house
   Internet: Starlink CGNAT
   Public IP: no
   LAN: 10.7.10.0/24
   Addressing convention: 10.[site].[VLAN].0/24
   Hardware:
   - TP-Link Archer C6
   - extender
   - no current server
   Future role:
   - needs small always-on gateway or OpenWrt router
   - outbound VPN client to VPS
```

## Goals

I want to evolve this repo toward a fully declarative multi-site infrastructure.

Target architecture:

```txt
VPS:
- public entrypoint
- VPN/headscale control plane
- reverse proxy
- lightweight SSO
- uptime monitoring
- alerting
- RustDesk

Kot:
- main compute and storage site
- Jellyfin
- seedbox
- Filebrowser
- NAS
- monitoring/log backend

Mom:
- site-to-site VPN edge
- NVR/camera services if possible
- monitoring agent
- optional off-site backup

Dad:
- lightweight site-to-site VPN edge only
- must work behind Starlink CGNAT
```

## Design requirements

### General

- Keep the current working VPS bundle deployment intact.
- Do not delete existing files unless there is a safe migration path.
- Do not commit secrets.
- Do not introduce cleartext private keys, passwords, API tokens, WireGuard private keys, or live exported configs.
- Prefer modular Nix.
- Prefer incremental migration.
- All changes must be reproducible and documented.
- Add TODO comments where real secrets, host keys, or hardware-specific values are needed.

### Implementation documentation requirements

For every meaningful implemented component, produce implementation documentation similar to the style used for the "Boissons Magellan" project.

The documentation must explain:

- the context of the component
- why it exists
- what problem it solves
- the chosen design
- alternatives considered, if relevant
- how it is deployed
- how it is configured
- how to operate it
- how to debug it
- how to rollback or disable it
- what secrets or external dependencies are required
- what remains TODO

Documentation must not only describe *what* was changed, but also *why* the change was made.

Prefer creating one Markdown file per major component, for example:

```txt
docs/implementation/
├── current-vps-bundle.md
├── vps-wireguard.md
├── vps-headscale.md
├── vps-caddy.md
├── vps-authelia.md
├── jellyfin-kot-seedbox.md
├── nas-kot-zfs.md
├── monitoring.md
└── backup.md
```

Each file should be useful for a future maintainer who does not remember the original reasoning.

When a component is only prepared as a skeleton and not fully implemented yet, the documentation must clearly say so and separate:

- current state
- intended future state
- assumptions
- missing information
- next implementation steps

### Repo restructuring

Create a clean future-proof structure while preserving legacy code.

Desired direction:

```txt
.
├── flake.nix
├── hosts/
│   ├── theau-vps/             # existing legacy host must keep working
│   ├── vps/                   # future native NixOS VPS host skeleton
│   ├── kot/
│   ├── jellyfin-kot/
│   ├── nas-kot/
│   ├── mom-edge/
│   └── dad-edge/
├── modules/
│   ├── common/
│   ├── networking/
│   ├── services/
│   ├── observability/
│   └── backup/
├── docs/
│   ├── architecture.md
│   ├── addressing.md
│   ├── migration-plan.md
│   ├── security-model.md
│   ├── disaster-recovery.md
│   └── implementation/
└── legacy/
```

Do not necessarily move all old code immediately if it risks breaking the build. It is acceptable to keep legacy code in place and document the future structure.

### Nix flake

Update `flake.nix` carefully.

It should continue exposing the current package:

```txt
theau-vps-bundle
```

Add foundations for future native NixOS hosts, but do not require missing hardware configs to build unless they are clearly marked as skeleton/example.

Possible outputs:

```nix
packages.${system}.theau-vps-bundle
devShells.${system}.default
```

And, if safe:

```nix
nixosConfigurations.vps
nixosConfigurations.jellyfin-kot
nixosConfigurations.nas-kot
nixosConfigurations.mom-edge
nixosConfigurations.dad-edge
```

If adding `nixosConfigurations` would break because hardware configs are missing, create documented skeletons instead and explain how to activate them later.

### Networking

Prepare a declarative network plan.

Addressing convention:

```txt
10.<site>.<vlan>.0/24
```

Proposed site numbers:

```txt
VPS/control: 10.1.x.0/24
Dad:         10.7.x.0/24
Mom:         10.10.x.0/24
Kot:         10.224.x.0/24
```

VLAN plan:

```txt
10 = trusted LAN
20 = servers
30 = IoT
40 = cameras
50 = guests
60 = management
```

Create documentation and reusable Nix data structures if useful.

### VPN

I want sovereignty, so prepare for Headscale.

Recommended split:

```txt
Headscale:
- user devices
- laptops
- phones
- admin access
- MagicDNS
- ACLs

WireGuard:
- stable infrastructure site-to-site tunnels
```

VPS should eventually run:

```txt
- Headscale
- WireGuard hub or subnet routing
```

Dad is behind CGNAT, so Dad must initiate outbound tunnel connections.

Do not remove current WireGuard/WGDashboard yet. Add future modules/skeletons.

### Reverse proxy

Prepare for a Caddy-based reverse proxy on the VPS.

Public services may include:

```txt
jellyfin
filebrowser
status
rustdesk
```

Admin services must not be directly public:

```txt
WGDashboard
Proxmox
NAS UI
qBittorrent
Prometheus
Grafana admin
router/firewall UIs
SSH
```

These should be VPN-only or SSO-protected.

Add docs explaining the intended exposure model.

### SSO

Because the VPS has only 2 GB RAM, prefer:

```txt
Caddy + Authelia
```

over Authentik for now.

Create skeleton modules/docs for Authelia, but do not require real secrets.

### NAS and backup

The future NAS has:

```txt
6 × 4 TB disks
expected usable capacity: about 16 TB
```

Important: this implies RAID6 or ZFS RAIDZ2, not RAID5.

Document this clearly.

Recommended:

```txt
ZFS RAIDZ2
Sanoid or native ZFS snapshots
Restic for encrypted backups
No public exposure
SMB/NFS only on LAN/VPN
```

Create docs and skeleton Nix modules for:

```txt
modules/backup/zfs.nix
modules/backup/restic.nix
```

Do not create destructive disk configs that could accidentally format disks. Use safe examples with clear TODO placeholders.

### Monitoring and logs

Target:

```txt
VPS:
- Uptime Kuma
- Alertmanager or simple mail alerts

Kot:
- Prometheus or VictoriaMetrics
- Grafana
- Loki
```

Agents on machines:

```txt
node_exporter
smartctl_exporter
systemd metrics
blackbox checks
wireguard monitoring
```

Add skeleton modules and docs.

Mail alerts should be supported later, but no SMTP secrets should be committed.

### Security

Add a security model document.

Rules:

```txt
- No public Proxmox
- No public NAS UI
- No public qBittorrent
- No public WGDashboard unless behind SSO + 2FA
- SSH only by keys
- Root SSH disabled
- Admin services over VPN
- Public services through reverse proxy
- Secrets through sops-nix or agenix
```

Prefer `sops-nix` because the repo already has SOPS/age workflow.

### Deployment

Prepare for future deployment with:

```txt
deploy-rs
```

or document why not yet.

Current deployment scripts must continue working.

Add docs for migration phases:

```txt
Phase 0: keep current VPS bundle
Phase 1: add docs/modules/skeletons
Phase 2: make jellyfin_kot declarative
Phase 3: add Headscale and Caddy reverse proxy
Phase 4: add NAS host
Phase 5: add Mom site gateway
Phase 6: add Dad site gateway
Phase 7: optionally reinstall VPS as native NixOS
```

## Concrete tasks

Please implement the following:

1. Inspect the current repo structure.
2. Preserve current working deployment.
3. Add `docs/architecture.md` describing the target architecture.
4. Add `docs/addressing.md` with site/VLAN/IP plan.
5. Add `docs/security-model.md` with public vs admin exposure rules.
6. Add `docs/migration-plan.md` with phased migration steps.
7. Add `docs/disaster-recovery.md` with backup/rollback principles.
8. Add a `modules/` skeleton structure:
   - `modules/common/base.nix`
   - `modules/common/ssh.nix`
   - `modules/common/security.nix`
   - `modules/networking/headscale.nix`
   - `modules/networking/wireguard-site.nix`
   - `modules/networking/firewall.nix`
   - `modules/networking/vlans.nix`
   - `modules/services/caddy.nix`
   - `modules/services/authelia.nix`
   - `modules/services/rustdesk.nix`
   - `modules/services/seedbox.nix`
   - `modules/observability/exporters.nix`
   - `modules/observability/monitoring-server.nix`
   - `modules/backup/zfs.nix`
   - `modules/backup/restic.nix`
9. These modules may be skeletons, but they must:
   - be valid Nix files
   - not contain real secrets
   - have clear TODOs
   - avoid destructive defaults
10. Add future host skeletons if safe:
   - `hosts/vps/`
   - `hosts/jellyfin-kot/`
   - `hosts/nas-kot/`
   - `hosts/mom-edge/`
   - `hosts/dad-edge/`
11. Update `README.md` with:
   - current state
   - target architecture
   - warning that current VPS bundle remains legacy/current production path
   - links to the new docs
12. Run formatting:
   - `nix fmt` if available
13. Run checks:
   - `nix flake check` if possible
   - `nix build .#theau-vps-bundle`
14. If checks cannot run because of environment limitations, document exactly why.

## Very important constraints

- Do not rewrite everything.
- Do not break `.#theau-vps-bundle`.
- Do not remove current WireGuard peer handling.
- Do not remove current WGDashboard packaging.
- Do not remove current deploy scripts.
- Do not introduce secrets.
- Do not add real private IP keys or generated private keys.
- Do not make destructive disk/ZFS configs active by default.
- Prefer documentation + skeleton modules first.
- Make small, reviewable commits.

## Expected final output

At the end, provide:

1. Summary of changed files.
2. What remains unchanged.
3. Commands executed.
4. Whether `nix build .#theau-vps-bundle` still works.
5. Whether `nix flake check` works.
6. A proposed next task to actually implement one module, probably:
   - Headscale on VPS
   - Caddy reverse proxy on VPS
   - declarative seedbox on `jellyfin-kot`
   - NAS ZFS RAIDZ2 skeleton
```

This prompt is intentionally conservative. It asks Codex to prepare the repo for the new infra without breaking the current VPS deployment.
