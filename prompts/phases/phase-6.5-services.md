# Phase 6.5: Self-Hosted Services Implementation

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- VPS acts as the public ingress and VPN hub.
- Kot infrastructure hosts heavier internal services and storage-backed workloads.
- Administrative interfaces should be protected by VPN and/or Authelia.
- Public exposure must be intentional and documented.
- Secrets must never be committed to the repository.
- Services should be implemented declaratively through Nix modules where practical.

## This Phase Only Implements:

### Objective
Implement the service prompts defined in `prompts/services/` as real NixOS service modules, host integrations, reverse-proxy rules, secret placeholders, and implementation documentation.

This phase turns the service design prompts into concrete infrastructure code while keeping every service disabled by default unless explicitly enabled on a host.

### Services Covered

1. **Coolify PaaS with Authelia protection**
   - Prompt: `prompts/services/coolify-paas-authelia.md`
   - Goal: self-hosted PaaS for Git deployments on `*.theau.net`.
   - Integrate with Caddy or Traefik and Authelia ForwardAuth.

2. **Offline Wikipedia / Kiwix instance**
   - Prompt: `prompts/services/wiki-offline.md`
   - Goal: local offline knowledge base available on LAN/VPN.
   - Prefer Kiwix/ZIM-based deployment.

3. **Self-hosted Git platform**
   - Prompt: `prompts/services/git-selfhosted.md`
   - Goal: centralize personal repositories, documentation, and infrastructure code.
   - Prefer Forgejo or Gitea.

4. **Prowlarr integration for C411**
   - Prompt: `prompts/services/prowlarr-c411.md`
   - Goal: integrate indexers with Jellyseerr and qBittorrent + Gluetun.
   - Ensure torrent-related traffic remains VPN-bound.

5. **Internal SMTP relay via Gmail**
   - Prompt: `prompts/services/smtp-internal.md`
   - Goal: internal SMTP relay for alerts and notifications, forwarding through Gmail SMTP.
   - Must not become an open relay.

### Tasks

1. **Read and normalize service prompts**
   - Inspect every file in `prompts/services/`.
   - Preserve each service’s constraints and acceptance criteria.
   - If a service prompt is incomplete, improve it before implementation.

2. **Create NixOS service modules**
   Add or update modules under `modules/services/`:
   - `modules/services/coolify.nix`
   - `modules/services/wiki-offline.nix`
   - `modules/services/git.nix`
   - `modules/services/prowlarr.nix`
   - `modules/services/smtp.nix`

   Each module must:
   - Be disabled by default.
   - Expose a clear `enable` option.
   - Use explicit options for ports, domains, data directories, secrets, and allowed networks.
   - Avoid hardcoded host-specific values where possible.
   - Avoid committing real secrets.

3. **Integrate services into host configurations**
   - Add service imports to the relevant host(s), without enabling them by default unless explicitly requested.
   - Prefer placement based on service role:
     - VPS: public ingress, reverse proxy, lightweight public-facing endpoints.
     - Kot / internal host: storage-heavy services, media automation, offline datasets.
   - Document the final placement decision for each service.

4. **Reverse proxy integration**
   - Add Caddy or Traefik configuration where needed.
   - Clearly separate:
     - public apps
     - LAN/VPN-only apps
     - admin interfaces
   - Use Authelia ForwardAuth where required.
   - Avoid conflicting ownership between Coolify, Caddy, and Traefik.

5. **Secret management**
   - Add placeholders only.
   - Integrate with the existing secret management mechanism if one already exists.
   - If no secret mechanism exists yet, document the expected secret file paths and TODOs.
   - Required secrets may include:
     - Gmail app password
     - Coolify secrets
     - Git platform admin credentials
     - Prowlarr/Jellyseerr/qBittorrent API keys
     - tracker credentials
     - DNS provider tokens for wildcard TLS, if needed

6. **Networking and firewall rules**
   - Restrict each service to the minimum required exposure.
   - Ensure SMTP is LAN/VPN-only and never an open relay.
   - Ensure wiki-offline is LAN/VPN-only.
   - Ensure Prowlarr is not publicly exposed.
   - Ensure qBittorrent/Prowlarr torrent workflows remain behind Gluetun where applicable.
   - Ensure public services use HTTPS through the reverse proxy.

7. **Documentation**
   Create or update:
   - `docs/implementation/coolify-paas.md`
   - `docs/implementation/wiki-offline.md`
   - `docs/implementation/git-selfhosted.md`
   - `docs/implementation/prowlarr.md`
   - `docs/implementation/smtp.md`

   Each document must include:
   - Architecture
   - Host placement
   - Network exposure
   - Secret handling
   - Backup considerations
   - Test procedure
   - Rollback/troubleshooting notes

8. **Build and validation**
   - Run the relevant Nix formatting/check commands used by the repository.
   - Ensure existing outputs still build.
   - At minimum, preserve:
     - `nix build .#theau-vps-bundle`
   - Build any newly added host outputs if introduced.

### Constraints for This Phase
- Do NOT commit real credentials, tokens, API keys, passwords, private keys, or tracker credentials.
- Do NOT expose admin interfaces publicly without Authelia or VPN protection.
- Do NOT create an SMTP open relay.
- Do NOT expose Prowlarr, qBittorrent, or tracker tooling publicly.
- Do NOT store large Wikipedia/ZIM datasets in Git or in the Nix store.
- Do NOT assume wildcard DNS for `*.theau.net` is already configured; document DNS requirements.
- Keep modules disabled by default.
- Keep existing phases and existing services buildable.

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- All new modules under `modules/services/` are valid Nix ✅
- Each service is disabled by default ✅
- Each service has implementation documentation under `docs/implementation/` ✅
- Public services have documented HTTPS/reverse-proxy integration ✅
- Protected/admin services have documented Authelia or VPN protection ✅
- SMTP relay uses Gmail as upstream and is not an open relay ✅
- Prowlarr integration respects qBittorrent + Gluetun VPN constraints ✅
- Offline Wikipedia does not store large datasets in Git ✅
- No real secrets are committed ✅

### Suggested Implementation Order
1. SMTP relay via Gmail
2. Self-hosted Git platform
3. Wiki offline / Kiwix
4. Prowlarr integration
5. Coolify PaaS and wildcard routing

Rationale:
- SMTP is small and useful for later alerts.
- Git is foundational for project hosting.
- Wiki and Prowlarr are internal services with limited public exposure.
- Coolify has the most reverse-proxy and wildcard-DNS complexity.

### Questions to Ask Before Starting
1. Which host should run each service: VPS, Kot, or a dedicated VM?
2. Should the Git platform be Forgejo or Gitea?
3. Should Coolify use Caddy as the edge proxy, Traefik internally, or both?
4. Which DNS provider manages `theau.net` and can it support wildcard/DNS-01 automation?
5. Which Gmail/Google Workspace account should be used for SMTP relay?
6. Which secret mechanism should be used: `sops-nix`, `agenix`, or host-local secret files?
7. Should internal services be reachable through VPN-only DNS names or LAN-local names?
