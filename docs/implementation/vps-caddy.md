# VPS Caddy and Authelia

## Status

Phase 3 enables Caddy, Authelia, and LLDAP in the native NixOS VPS target. The
current Ubuntu bundle remains focused on the existing WireGuard, WGDashboard,
RustDesk, and Nginx deployment.

## Context

Authelia is the common SSO and authorization layer for the infrastructure. LLDAP
stores users and groups. Caddy enforces Authelia on private web services with
`forward_auth`.

The VPS has 2 GB RAM, so Authelia and LLDAP are preferred over heavier identity
stacks.

## Design

Native target:

```text
internet
  |
  v
Caddy
  |
  +-- public: auth, headscale
  +-- Authelia forward_auth: users, Jellyfin, Jellyseerr, seedbox
      |
      v
Authelia -> LLDAP
```

## Source Files

- Caddy module: `modules/services/caddy.nix`
- Authelia module: `modules/services/authelia.nix`
- LLDAP module: `modules/services/identity-provider.nix`
- native VPS host: `hosts/vps/default.nix`

## Routes

| Host | Upstream | Access owner |
| --- | --- | --- |
| `auth.theau-vps.duckdns.org` | `127.0.0.1:9091` | public login endpoint |
| `headscale.theau-vps.duckdns.org` | `127.0.0.1:8081` | public Headscale endpoint, OIDC via Authelia |
| `users.theau-vps.duckdns.org` | `127.0.0.1:17170` | Authelia, `super-admin` only |
| `jellyfin.theau-vps.duckdns.org` | `jellyfin-kot.tailnet.theau-vps.duckdns.org:8096` | Authelia authenticated users |
| `jellyseerr.theau-vps.duckdns.org` | `jellyseerr-kot.tailnet.theau-vps.duckdns.org:5055` | Authelia authenticated users |
| `seedbox.theau-vps.duckdns.org` | `seedbox-kot.tailnet.theau-vps.duckdns.org:8080` | Authelia, `super-admin` only |

## Authorization Model

Authelia owns service access decisions:

- default policy is deny
- service routes are explicitly listed in `personalInfra.services.authelia.services`
- empty `groups` means any authenticated user
- `groups = [ "super-admin" ]` restricts access to infrastructure admins
- `theau` is the initial LLDAP super-admin account placeholder

LLDAP owns user records with at least:

- name
- password
- email

The LLDAP web UI is reachable only through `users.theau-vps.duckdns.org` and is
restricted by Authelia to `super-admin`.

## Secrets

No real secrets are committed. Runtime paths:

- `/run/secrets/lldap-admin-password`
- `/run/secrets/authelia-jwt-secret`
- `/run/secrets/authelia-storage-encryption-key`
- `/run/secrets/authelia-ldap-password`
- `/run/secrets/headscale-oidc-client-secret`

These files must be provided by SOPS or another secret manager before switching
the native VPS into production.

## TLS

Caddy uses Let's Encrypt defaults with account email
`theau.pauwels@gmail.com`.

DNS-01 credentials are not added in this phase. HTTP-01 is acceptable while the
VPS owns public ports `80` and `443`.

## Validation

Build the native target and the preserved Ubuntu bundle:

```bash
nix build .#vps-native .#theau-vps-bundle
```

Evaluate the central authorization rules:

```bash
nix eval .#nixosConfigurations.vps.config.services.authelia.instances.main.settings.access_control.rules
```

## Migration Notes

The production Ubuntu VPS still uses Nginx for WGDashboard. Caddy becomes active
when the native NixOS VPS target is deployed.

Cutover order:

1. provision runtime secrets
2. deploy LLDAP and Authelia
3. create `theau` and the `super-admin` group
4. validate Caddy routes
5. validate Jellyfin, Jellyseerr, and seedbox access through Authelia
6. enable Headscale OIDC against Authelia
7. keep WireGuard/WGDashboard available as break-glass access until cutover is
   proven

Rollback is to keep or reactivate the current Ubuntu bundle generation.
