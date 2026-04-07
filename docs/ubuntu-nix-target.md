# Ubuntu + Nix Target

## Target model

- OS stays Ubuntu 24.04
- Nix builds the application bundle locally
- `nix copy` pushes the bundle to the VPS store
- activation scripts install configs and `systemd` units on Ubuntu
- rollback re-activates a previous bundle

## Managed services

- custom `systemd` unit for WireGuard
- custom `systemd` unit for WGDashboard
- custom `systemd` unit for Nginx
- custom `systemd` unit for nftables firewall
- custom `systemd` unit for iperf3
- custom `systemd` timer for cert renewal

## Rollback

- each deployment is symlinked under `/opt/theau-vps/generations/<timestamp>`
- `/opt/theau-vps/current` points to the active bundle
- rollback re-runs a previous bundle activation script and repoints `current`

## Caveat

- this is reproducible infra on Ubuntu, not a full NixOS host
- `nixos-rebuild` does not apply on this target
