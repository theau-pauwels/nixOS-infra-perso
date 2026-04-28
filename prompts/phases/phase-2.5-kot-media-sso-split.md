# Phase 2.5: Split Kot Media Services and Add SSO/User Management Design

## Reference Context

This phase refines phase 2 after deciding that Kot media services should be
split by VM instead of combined into one `jellyfin-kot` host.

Target Proxmox shape:

- `jellyfin-kot`: Jellyfin only
- `seedbox-kot`: qBittorrent and gluetun only
- `jellyseerr-kot`: Jellyseerr only
- VM storage backed by NAS-Kot
- central SSO exposed through IONOS-VPS2

## This Phase Implements

1. Split NixOS host skeletons:
   - `hosts/jellyfin-kot/default.nix`
   - `hosts/seedbox-kot/default.nix`
   - `hosts/jellyseerr-kot/default.nix`

2. Split service modules:
   - seedbox module handles only qBittorrent and gluetun
   - Jellyfin is configured on `jellyfin-kot`
   - Jellyseerr module wraps NixOS `services.seerr`

3. Add central identity provider skeleton:
   - LLDAP for web-based user management
   - Authelia for SSO
   - initial super-admin user: `theau`
   - group-based admin rule: `super-admin`
   - user attributes: name, password, email

4. Document the target:
   - VM split
   - NAS-Kot storage expectations
   - Jellyfin/Jellyseerr integration
   - SSO and user management flow

## Constraints

- Do not commit passwords or user databases.
- Do not expose the user manager publicly without SSO/VPN protection.
- Keep IONOS-VPS2 as the public access point for auth.
- Keep `theau` as the first super-admin placeholder.
- Keep services buildable without actual hardware access.

## Acceptance Criteria

- `nix build .#theau-vps-bundle` still succeeds.
- `nix build .#jellyfin-kot` succeeds.
- `nix build .#seedbox-kot` succeeds.
- `nix build .#jellyseerr-kot` succeeds.
- Docs explain the split and SSO model.
- No real secrets are committed.
