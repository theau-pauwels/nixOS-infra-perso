# Mom Edge

## Status

Phase 5 adds `mom-edge` as a NixOS target for the Mom site. The target is a
site gateway and monitoring agent with optional NVR support disabled by default.

No live infrastructure deployment is performed by this phase.

## Hardware and Placement

Expected hardware:

- BMAX B2 Pro mini PC
- 8 GB RAM
- 256 GB SSD
- Mom VDSL connection with public IP
- LAN: `10.10.10.0/24`
- WiFi: 2 x TP-Link Deco M5

The default NixOS config assumes a Proxmox VM:

- interface: `ens18`
- address: `10.10.10.2/24`
- gateway: `10.10.10.1`
- root disk: `/dev/disk/by-label/nixos`

Bare metal is also acceptable, but interface and boot disk identifiers must be
updated first.

## WireGuard Site Tunnel

`mom-edge` uses a site-to-site WireGuard client interface:

- interface: `wg-mom`
- local tunnel IP: `10.8.0.30/32`
- endpoint: `theau-vps.duckdns.org:51820`
- private key path: `/run/secrets/wireguard/site-private-key`
- keepalive: 25 seconds

The Mom LAN routed behind the edge is:

```text
10.10.10.0/24
```

The VPS peer skeleton is present in `hosts/theau-vps/peers.nix` with
`enabled = false`. It is intentionally not active in the current Ubuntu VPS
bundle until the real Mom public key is available in encrypted secrets.

## Monitoring

`mom-edge` enables:

- node exporter
- blackbox exporter

Both listen on the tunnel IP `10.8.0.30` and do not open public firewall ports.
The future Kot monitoring server should scrape them over the private network.

## Optional Backups

Mom is not configured as a backup receiver in this phase. The 256 GB SSD is too
small to treat as a primary backup target.

Acceptable future use:

- small encrypted config backups
- emergency off-site copy of selected secrets or metadata
- no large media or NAS dataset replication without external storage

## Secrets

Encrypted source:

```text
hosts/mom-edge/secrets.enc.yaml
```

Local cleartext source, if needed, must stay under:

```text
local-secrets/
```

Required secret:

- `wireguard/site-private-key`

## Validation

Build the Mom target:

```bash
nix build .#mom-edge
```

Build the preserved VPS bundle:

```bash
nix build .#theau-vps-bundle
```

## Rollback

Before activation, rollback is simply to keep the current Mom host unchanged.

After activation:

1. disable `personalInfra.networking.wireguardSite.enable`
2. rebuild or boot a previous generation
3. remove the Mom peer from the active VPS WireGuard peer list if it had been
   enabled

The current VPS peer skeleton is disabled and does not affect production.
