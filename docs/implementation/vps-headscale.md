# VPS Headscale

## Status

Phase 3 enables Headscale in the native NixOS VPS target. It is not shipped as a
preview artifact in the current Ubuntu bundle.

## Context

The current VPS already runs WireGuard through the production Ubuntu bundle.
That deployment remains in place until the native VPS cutover.

Headscale has a different role:

- Headscale coordinates users and service nodes in a Tailscale-compatible mesh.
- WireGuard remains the current explicit site/torrent tunnel path.
- Both can coexist because they use different ports, address ranges, and
  operational models.

## Design

Headscale listens locally and is exposed by Caddy:

```text
Tailscale client
  |
  | HTTPS
  v
headscale.theau-vps.duckdns.org
  |
  | Caddy reverse proxy
  v
127.0.0.1:8081
  |
  v
Headscale
```

Default values:

- server URL: `https://headscale.theau-vps.duckdns.org`
- local listen address: `127.0.0.1`
- local port: `8081`
- MagicDNS base domain: `tailnet.theau-vps.duckdns.org`
- IPv4 prefix: `100.64.0.0/10`
- IPv6 prefix: `fd7a:115c:a1e0::/48`
- database: SQLite

## Source Files

- NixOS module: `modules/networking/headscale.nix`
- native VPS host: `hosts/vps/default.nix`
- central SSO and authorization: `modules/services/authelia.nix`
- identity storage: `modules/services/identity-provider.nix`

## ACL Model

The policy is intentionally conservative:

- `group:super-admin` can reach everything.
- normal users can reach tagged public service ports.
- SSH through the mesh is reserved for `group:super-admin`.
- `tag:server` and `tag:admin` are owned by `group:super-admin`.

The placeholder identity is `theau@infra.local`. Replace it after the Authelia
and LLDAP user model is live.

## SSO

Authelia is the single SSO authority for the infrastructure. For Headscale, the
integration point is OIDC rather than Caddy `forward_auth`, because Headscale
clients need an OIDC login flow.

Planned values:

- issuer: `https://auth.theau-vps.duckdns.org`
- client id: `headscale`
- client secret path: `/run/secrets/headscale-oidc-client-secret`

The client secret must not be committed.

## Validation

Build the native VPS target:

```bash
nix build .#vps-native
```

Evaluate the generated Headscale URL:

```bash
nix eval .#nixosConfigurations.vps.config.services.headscale.settings.server_url
```

## Migration Notes

Do not remove the current WireGuard/WGDashboard deployment during this phase.
Move devices gradually:

1. deploy the native VPS target on a test or cutover host
2. enable Authelia and LLDAP secrets
3. create the `theau` super-admin user and groups in LLDAP
4. enable Headscale OIDC against Authelia
5. register one test device
6. verify MagicDNS
7. tag server nodes
8. only then move service ingress to tailnet names

## Rollback

Rollback before production cutover is to keep using the current Ubuntu bundle.

If activated later and Headscale fails, stop Headscale and keep WireGuard as the
operational remote access path.
