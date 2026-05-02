---
name: repo-map
description: Use when working in this repository to locate important files quickly, avoid repeated repository scans, and understand which folders to inspect or ignore.
---

# Repo Map

Nix flake infrastructure repo — NixOS configs, deployment scripts, SOPS secrets.

## Important paths

- `flake.nix`: top-level flake — all outputs (packages, NixOS configs, bundles)
- `hosts/`: per-machine NixOS configurations (theau-vps, vps, jellyfin-kot, seedbox-kot, storage-kot, nas-kot, mom-edge, dad-edge, jellyseerr-kot)
- `modules/`: reusable NixOS modules by domain — common, networking, services, backup, observability
- `packages/`: custom packages — bundle (VPS deployment bundle), wgdashboard
- `deploy/`: deployment scripts — push-generation, rollback, certificates, DNS cutover, activate-generation
- `scripts/`: helper scripts — SSH key registration, wg-easy import, secret vault, Nix install
- `docs/`: architecture, implementation notes, migration plan, security model
- `prompts/`: phase-based and service-specific LLM prompt templates
- `local-secrets/`: local secret backup vault
- `backups/`: backup configurations
- `.tools/`: vendored binaries (SOPS)

## Key service hostnames

- `theau-vps.duckdns.org` — VPS main domain (WGDashboard)
- `*.theau.net` — service domains via VPS Nginx + Authelia (file, jellyfin, qbit, seer, prowlarr, wg, users, authelia, coolify)
- `storage-kot` (10.1.10.124, WG 10.8.0.23) — NFS/CIFS/Samba + FileBrowser
- `jellyfin-kot` (10.8.0.21) — Jellyfin media server
- `seedbox-kot` (10.1.10.123, WG via gluetun 10.8.0.22) — qBittorrent + gluetun

## Entry points

- Main entry point: `flake.nix` — defines all Nix outputs
- Primary host config: `hosts/theau-vps/default.nix` — current Ubuntu VPS bundle
- Native NixOS host: `hosts/vps/default.nix` — future native NixOS VPS
- Storage host: `hosts/storage-kot/default.nix` — Samba + FileBrowser + exFAT
- Build config: `flake.nix` (Nix flake)
- Test/validate: `nix flake check`

## Ignore unless explicitly needed

- `result/` (symlink to Nix store build output)
- `local-secrets/` (sensitive secrets vault)
- `.tools/` (vendored binaries)
- `scripts/__pycache__/`
- `.git/`
