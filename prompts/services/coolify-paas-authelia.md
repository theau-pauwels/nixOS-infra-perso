# Service: Coolify PaaS Self-Hosted with Authelia Protection

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant infrastructure expectations:
- Public domains are served through the VPS/reverse-proxy entry point.
- Administrative interfaces should be VPN-only or protected with SSO.
- Prefer Nix-managed, declarative configuration where practical.
- Do not commit real secrets, tokens, API keys, private keys, or passwords.

## This Service Implements

### Objective
Deploy Coolify through Nix as a self-hosted PaaS for publishing Git-based projects under `*.theau.net`, with optional Authelia protection through Traefik or Caddy ForwardAuth.

### Target Use Cases
- Deploy personal Git projects from self-hosted or external Git repositories.
- Expose public apps through wildcard subdomains such as `app.theau.net`.
- Protect sensitive apps or the Coolify administration interface with Authelia.
- Keep service deployment reproducible and documented from the infrastructure repository.

### Tasks

1. **Create a Coolify service module**
   - `modules/services/coolify.nix`
   - Disabled by default.
   - Options for:
     - domain / wildcard domain
     - bind address and ports
     - data directory
     - Docker network integration
     - reverse-proxy mode: Traefik or Caddy
     - Authelia ForwardAuth enablement
   - No hardcoded secrets.

2. **Create or update target host configuration**
   - Add Coolify to the appropriate host only when explicitly enabled.
   - Prefer a dedicated VM/container host if the service becomes resource-heavy.
   - Keep the VPS role limited to ingress/reverse proxy if Coolify runs elsewhere.

3. **Reverse proxy integration**
   - Document one preferred path:
     - Caddy as the external edge reverse proxy, or
     - Traefik if Coolify manages application routing internally.
   - Support wildcard routing for `*.theau.net`.
   - Add ForwardAuth examples for Authelia.
   - Clearly separate:
     - public applications
     - protected applications
     - Coolify admin UI

4. **Authelia integration**
   - Protect Coolify administration by default.
   - Provide example ForwardAuth snippets for Caddy and/or Traefik.
   - Use group-based authorization placeholders, for example `admin` or `super-admin`.
   - Do not create real users or passwords.

5. **DNS and TLS documentation**
   - Document wildcard DNS expectations for `*.theau.net`.
   - Document TLS strategy:
     - Caddy automatic HTTPS, or
     - DNS challenge if wildcard certificates are required.
   - Include TODO placeholders for provider-specific DNS credentials.

6. **Documentation**
   - `docs/implementation/coolify-paas.md`
     - Architecture and hosting location.
     - Reverse proxy flow.
     - Authelia protection model.
     - Git deployment flow.
     - Backup expectations.
     - Rollback and migration notes.

## Constraints
- Do not commit real Coolify secrets, database passwords, OAuth tokens, Git tokens, or DNS API credentials.
- Do not expose the Coolify admin UI publicly without Authelia or VPN protection.
- Do not assume wildcard DNS is already configured.
- Avoid conflicting reverse proxy ownership between Coolify, Traefik, and Caddy.
- Keep Nix configuration buildable even when Coolify is disabled.
- Avoid destructive Docker volume cleanup defaults.

## Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds.
- Any new NixOS host output still builds.
- `modules/services/coolify.nix` is valid Nix and disabled by default.
- Documentation explains DNS, TLS, reverse proxy, and Authelia integration.
- Coolify admin UI is documented as protected by default.
- No real secrets are committed.

## Questions to Ask Before Starting
1. Should Coolify run on the VPS, on the Kot Proxmox host, or on a dedicated VM?
2. Should Caddy remain the public edge proxy, or should Traefik handle Coolify routes directly?
3. Which DNS provider manages `theau.net` and can it support wildcard/DNS-01 automation?
4. Should deployed apps be public by default or protected by Authelia by default?
