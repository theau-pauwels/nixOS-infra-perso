# nixOS-infra-perso

Personal infrastructure repository for the NixOS migration.

## Scope

- NixOS host configuration
- Shared Nix modules
- Encrypted secrets metadata and templates
- Migration notes

## Safety rules

- Do not commit raw backups
- Do not commit live WireGuard exports
- Do not commit local SSH client config
- Keep secret material encrypted before it enters Git

## Planned hosts

- `theau-vps`

## Next milestones

- add the initial flake layout
- add `theau-vps` host configuration
- add `sops-nix` secret handling
- package and enable WGDashboard
