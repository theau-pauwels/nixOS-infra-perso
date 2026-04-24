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
