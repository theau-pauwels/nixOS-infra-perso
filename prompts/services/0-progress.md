# Services Implementation Progress

This file tracks the implementation state of the service prompts in `prompts/services/` and their corresponding NixOS modules under `modules/services/`.

## Legend

- ✅ Done
- 🟡 Started / skeleton exists
- 🔴 Not implemented yet
- ⚠️ Needs review before production use

## Global Status

| Area | Status | Notes |
|---|---:|---|
| Service prompts | ✅ | Service design prompts exist under `prompts/services/`. |
| Phase integration | ✅ | `prompts/phases/phase-6.5-services.md` exists and describes implementation work. |
| NixOS service modules | 🟡 | Skeleton modules exist under `modules/services/`. |
| Host integration | 🔴 | Services are not yet wired into final host configurations. |
| Reverse proxy integration | 🔴 | Caddy/Traefik integration still needs to be implemented service by service. |
| Authelia integration | 🔴 | Not implemented yet in service modules. |
| Secrets integration | 🔴 | Placeholder paths exist, but no final `sops-nix`/`agenix`/host-local secret wiring. |
| Documentation | 🔴 | Implementation docs under `docs/implementation/` still need to be created or completed. |
| Build validation | 🔴 | Full Nix build validation still needs to be run after host integration. |

## Service Status

### 1. SMTP Internal Relay via Gmail

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/smtp-internal.md` defines Gmail relay mode. |
| Module | 🟡 | `modules/services/smtp.nix` exists. |
| Implementation quality | ⚠️ | Good skeleton, but secret handling must be reviewed before production. |
| Gmail relay | 🟡 | Configured conceptually through Postfix relayhost. |
| Secret management | 🔴 | Gmail app password must be wired through a real secret mechanism. |
| Firewall / exposure | 🔴 | Host-level firewall rules still need to restrict access to LAN/VPN only. |
| Documentation | 🔴 | `docs/implementation/smtp.md` still needs to be written. |
| Test procedure | 🔴 | Test mail procedure still needs to be documented and run. |

#### Remaining work
- Decide secret backend: `sops-nix`, `agenix`, or host-local secret file.
- Replace build-time placeholder password handling with runtime secret handling.
- Define allowed LAN/VPN subnets explicitly.
- Add host-level firewall rules.
- Write documentation.
- Send a test email to an external address.

---

### 2. Self-Hosted Git Platform

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/git-selfhosted.md` exists. |
| Module | 🟡 | `modules/services/git.nix` exists. |
| Implementation quality | ⚠️ | Basic Gitea module only. |
| Forgejo/Gitea choice | 🟡 | Current skeleton uses Gitea. Forgejo decision still open. |
| Public registration disabled | ✅ | Disabled in module settings. |
| Reverse proxy | 🔴 | Caddy integration not implemented. |
| Authelia / SSO | 🔴 | Not implemented. |
| Backup | 🔴 | Not implemented. |
| Documentation | 🔴 | `docs/implementation/git-selfhosted.md` still needs to be written. |

#### Remaining work
- Confirm Gitea vs Forgejo.
- Decide whether access is public, VPN-only, or public with Authelia.
- Add Caddy reverse proxy configuration.
- Add backup integration for repositories, database, and config.
- Add restore procedure.
- Write documentation.

---

### 3. Offline Wikipedia / Kiwix

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/wiki-offline.md` exists. |
| Module | 🟡 | `modules/services/wiki-offline.nix` exists. |
| Implementation quality | ⚠️ | Minimal Kiwix service skeleton. |
| Storage strategy | 🔴 | NAS/local storage choice not implemented. |
| ZIM management | 🔴 | No download/update workflow yet. |
| Network exposure | 🔴 | LAN/VPN-only firewall/reverse proxy rules not implemented. |
| Documentation | 🔴 | `docs/implementation/wiki-offline.md` still needs to be written. |

#### Remaining work
- Confirm Kiwix as final implementation.
- Decide storage path for ZIM files.
- Add ZIM update workflow or manual procedure.
- Add LAN/VPN-only exposure.
- Write documentation.

---

### 4. Prowlarr Integration for C411

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/prowlarr-c411.md` exists. |
| Module | 🟡 | `modules/services/prowlarr.nix` exists. |
| Implementation quality | ⚠️ | Very minimal service skeleton. |
| C411 indexer | 🔴 | Not configured. |
| Jellyseerr integration | 🔴 | Not configured. |
| qBittorrent integration | 🔴 | Not configured. |
| Gluetun/VPN routing | 🔴 | Not implemented. |
| Public exposure blocked | 🔴 | Firewall/reverse proxy policy not implemented. |
| Documentation | 🔴 | `docs/implementation/prowlarr.md` still needs to be written. |

#### Remaining work
- Confirm how C411 should be integrated.
- Decide whether FlareSolverr is required.
- Wire Prowlarr to Jellyseerr.
- Wire Prowlarr to qBittorrent.
- Ensure torrent-related traffic stays behind Gluetun.
- Keep Prowlarr LAN/VPN-only.
- Write documentation.

---

### 5. Coolify PaaS with Authelia Protection

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/coolify-paas-authelia.md` exists. |
| Module | 🟡 | `modules/services/coolify.nix` exists. |
| Implementation quality | ⚠️ | Minimal Docker-based skeleton only. |
| PaaS routing | 🔴 | Not implemented. |
| Wildcard DNS | 🔴 | Not implemented/documented in final infra docs. |
| Reverse proxy | 🔴 | Caddy/Traefik ownership not decided. |
| Authelia ForwardAuth | 🔴 | Not implemented. |
| TLS | 🔴 | Wildcard/DNS-01 strategy not implemented. |
| Backup | 🔴 | Not implemented. |
| Documentation | 🔴 | `docs/implementation/coolify-paas.md` still needs to be written. |

#### Remaining work
- Decide host placement: VPS, Kot, or dedicated VM.
- Decide reverse proxy ownership: Caddy edge, Traefik internal, or hybrid.
- Configure wildcard DNS for `*.theau.net`.
- Add Authelia protection for Coolify admin UI.
- Define app exposure policy: public by default or protected by default.
- Add backup strategy.
- Write documentation.

---

## Suggested Next Implementation Order

1. **SMTP relay via Gmail**
   - Smallest module.
   - Immediately useful for alerts.
   - Good first production-ready target.

2. **Self-hosted Git platform**
   - Useful for managing personal projects and infrastructure.
   - Easier than Coolify.

3. **Offline Wikipedia / Kiwix**
   - Internal-only service.
   - Mostly storage and update workflow.

4. **Prowlarr**
   - Depends on the existing media stack and VPN routing.
   - Requires careful Gluetun/qBittorrent integration.

5. **Coolify**
   - Most complex due to wildcard DNS, reverse proxy ownership, TLS, and Authelia.

## Definition of Done for Phase 6.5

Phase 6.5 can be considered complete when:

- All service modules are production-ready.
- Services are imported into the correct host configurations.
- Each service is disabled by default unless intentionally enabled.
- Reverse proxy rules are implemented where required.
- Authelia or VPN protection is applied to admin/private services.
- Secret management is fully wired and no secrets are committed.
- Documentation exists for every service under `docs/implementation/`.
- Relevant Nix builds pass.
- Test procedures are documented and executed.

## Current Summary

Current state: **design complete, skeleton implementation started, production integration pending**.

The repository is ready for the next step: turning the skeleton service modules into production-ready NixOS modules and wiring them into the appropriate hosts.
