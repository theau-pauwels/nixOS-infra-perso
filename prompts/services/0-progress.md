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
| NixOS service modules | ✅ | SMTP, Forgejo, Kiwix, Prowlarr, and Coolify modules are implemented and disabled by default. |
| Host integration | ✅ | Modules are imported on the planned target hosts without enabling new services. |
| Reverse proxy integration | ✅ | Optional Caddy vhosts exist for HTTP services; Coolify admin and private/admin UIs support ForwardAuth. |
| Authelia integration | ✅ | Caddy ForwardAuth snippets are included where admin/private UI exposure is supported. |
| Full user management | 🔴 | Not implemented yet. Needs a coherent account/identity strategy across Forgejo, Authelia, Coolify, service admins, groups, onboarding/offboarding, and secrets. |
| Secrets integration | 🟡 | Runtime secret paths are modeled and documented; final host SOPS wiring remains a production enablement step. |
| Documentation | ✅ | Implementation docs exist under `docs/implementation/` for all phase 6.5 services. |
| Build validation | 🟡 | Must be run with local Nix before production enablement. |

## Service Status

### 0. Full User Management / Identity Layer

| Item | Status | Notes |
|---|---:|---|
| Prompt | 🔴 | No dedicated service prompt exists yet. |
| Module | 🔴 | No `modules/services/users.nix`, `identity.nix`, or equivalent exists yet. |
| User lifecycle | 🔴 | No declarative onboarding/offboarding workflow. |
| Groups / roles | 🔴 | Admin/service/user groups not centrally modeled. |
| Authelia users | 🔴 | No centralized Authelia user/group source implemented. |
| Forgejo users | 🔴 | Forgejo registration is disabled, but user provisioning/admin policy is not implemented. |
| Coolify users | 🔴 | Coolify admin/user management not modeled. |
| Service accounts | 🔴 | SMTP/Jellyseerr/Prowlarr/qBittorrent/Coolify service accounts are not centrally tracked. |
| SSH/admin users | 🔴 | Human admin access policy is not part of this service layer yet. |
| Documentation | 🔴 | No `docs/implementation/user-management.md` yet. |

#### Remaining work
- Create `prompts/services/user-management.md`.
- Decide the identity model:
  - Authelia file users,
  - LDAP,
  - OIDC provider,
  - or simple per-service local accounts.
- Define user groups, for example:
  - `admins`
  - `family`
  - `media-users`
  - `git-users`
  - `service-accounts`
- Decide which services should delegate authentication to Authelia/OIDC and which keep local accounts.
- Add onboarding/offboarding procedure.
- Define password reset / 2FA policy.
- Define service account ownership and secret rotation policy.
- Document recovery access when SSO/Authelia is unavailable.
- Create `docs/implementation/user-management.md`.

---

### 1. SMTP Internal Relay via Gmail

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/smtp-internal.md` defines Gmail relay mode. |
| Module | ✅ | `modules/services/smtp.nix` configures Postfix relayhost and runtime SASL secret material. |
| Implementation quality | ✅ | Disabled by default, IP-trusted, runtime secret file, and open-relay assertions. |
| Gmail relay | ✅ | Configured through Postfix relayhost with STARTTLS to Gmail. |
| Secret management | 🟡 | Runtime secret path documented; final SOPS host binding remains before enablement. |
| User management impact | 🔴 | Dedicated sender/service account ownership and rotation policy are not centrally modeled yet. |
| Firewall / exposure | ✅ | Closed by default with assertions against public wildcard listeners. |
| Documentation | ✅ | `docs/implementation/smtp.md` exists. |
| Test procedure | ✅ | Test mail procedure is documented. |

#### Remaining work
- Send a test email to an external address.
- Wire the Gmail app password to the chosen host secret backend before enabling.
- Add SMTP sender/service account to the future user-management inventory.

---

### 2. Self-Hosted Git Platform

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/git-selfhosted.md` exists. |
| Module | ✅ | `modules/services/git.nix` wraps `services.forgejo`. |
| Implementation quality | ✅ | Forgejo, registration disabled, SSH/HTTP options, dumps, optional Caddy/Authelia. |
| Forgejo/Gitea choice | ✅ | Forgejo selected. |
| Public registration disabled | ✅ | Disabled in module settings. |
| Full user management | 🔴 | User provisioning, organizations, teams, admin bootstrap, recovery admin, and offboarding are not implemented yet. |
| Reverse proxy | ✅ | Optional Caddy integration implemented. |
| Authelia / SSO | ✅ | Optional ForwardAuth protection implemented for the web UI. |
| Backup | ✅ | Forgejo dump timer enabled by default when service is enabled. |
| Documentation | ✅ | `docs/implementation/git-selfhosted.md` exists. |

#### Remaining work
- Enable on the target host only after DNS, SSH port policy, and backup storage are confirmed.
- Decide whether Forgejo keeps local users or uses SSO/OIDC through Authelia/future identity provider.
- Define Git organizations, teams, admin users, and recovery users.

---

### 3. Offline Wikipedia / Kiwix

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/wiki-offline.md` exists. |
| Module | ✅ | `modules/services/wiki-offline.nix` wraps `services.kiwix-serve`. |
| Implementation quality | ✅ | Kiwix, explicit library input, LAN/VPN-only defaults, optional Caddy. |
| Storage strategy | ✅ | NAS placement and `/srv/wiki-offline` runtime storage documented. |
| ZIM management | ✅ | Manual `kiwix-manage` workflow documented. |
| User management impact | 🟡 | Usually read-only/no login, but access groups may be needed if exposed through Authelia. |
| Network exposure | ✅ | Firewall closed by default; public routes asserted against. |
| Documentation | ✅ | `docs/implementation/wiki-offline.md` exists. |

#### Remaining work
- Download selected ZIM datasets outside Git before enabling the service.
- Decide whether access is anonymous LAN/VPN-only or group-protected through Authelia.

---

### 4. Prowlarr Integration for C411

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/prowlarr-c411.md` exists. |
| Module | ✅ | `modules/services/prowlarr.nix` wraps the NixOS Prowlarr module. |
| Implementation quality | ✅ | Internal-only defaults, environment file support, optional Caddy/Authelia. |
| C411 indexer | 🟡 | Credentials and indexer creation remain UI/runtime steps; no credentials in Git. |
| Jellyseerr integration | 🟡 | URLs and API-key paths documented; final API keys are runtime secrets. |
| qBittorrent integration | 🟡 | qBittorrent URL and Gluetun ordering modeled; final app credentials are runtime secrets. |
| Full user management | 🔴 | Admin/user access to Prowlarr and related media tools is not centrally modeled yet. |
| Gluetun/VPN routing | ✅ | Prowlarr orders after the Gluetun unit; qBittorrent remains Gluetun-bound. |
| Public exposure blocked | ✅ | Firewall closed by default; public default routes asserted against. |
| Documentation | ✅ | `docs/implementation/prowlarr.md` exists. |

#### Remaining work
- Confirm whether C411 requires FlareSolverr before production enablement.
- Enter real tracker/API credentials through runtime secret handling, never Git.
- Add Prowlarr/Jellyseerr/qBittorrent access roles to the future user-management layer.

---

### 5. Coolify PaaS with Authelia Protection

| Item | Status | Notes |
|---|---:|---|
| Prompt | ✅ | `prompts/services/coolify-paas-authelia.md` exists. |
| Module | ✅ | `modules/services/coolify.nix` manages an external Coolify Compose stack. |
| Implementation quality | ✅ | Disabled by default, runtime `.env`, no destructive cleanup, Caddy admin proxy optional. |
| PaaS routing | 🟡 | Admin route implemented; wildcard app routing remains a DNS/TLS production decision. |
| Wildcard DNS | ✅ | DNS requirements documented; not assumed configured. |
| Reverse proxy | ✅ | Preferred `caddy-edge` admin model documented and implemented. |
| Authelia ForwardAuth | ✅ | Coolify admin protection is required in Caddy edge mode. |
| Full user management | 🔴 | Coolify admin bootstrap, project teams, Git credentials, deploy keys, and recovery access are not centrally modeled yet. |
| TLS | ✅ | Caddy hostname TLS and DNS-01 wildcard strategy documented. |
| Backup | ✅ | `/data/coolify`, DB/volumes, and secrets are documented. |
| Documentation | ✅ | `docs/implementation/coolify-paas.md` exists. |

#### Remaining work
- Decide final production host and wildcard DNS provider before enabling.
- Place official Coolify Compose files and `.env` outside Git.
- Add Coolify users, teams, deploy keys, and recovery access to the future user-management layer.

---

## Suggested Next Implementation Order

1. **Full user management / identity layer**
   - Needed before exposing Forgejo, Coolify, and admin/private UIs seriously.
   - Defines users, groups, service accounts, onboarding/offboarding, and recovery access.

2. **SMTP relay via Gmail**
   - Smallest module.
   - Immediately useful for alerts.
   - Good first production-ready target.

3. **Self-hosted Git platform**
   - Useful for managing personal projects and infrastructure.
   - Easier than Coolify.

4. **Offline Wikipedia / Kiwix**
   - Internal-only service.
   - Mostly storage and update workflow.

5. **Prowlarr**
   - Depends on the existing media stack and VPN routing.
   - Requires careful Gluetun/qBittorrent integration.

6. **Coolify**
   - Most complex due to wildcard DNS, reverse proxy ownership, TLS, Authelia, and team/project access.

## Definition of Done for Phase 6.5

Phase 6.5 can be considered complete when:

- All service modules are production-ready.
- Services are imported into the correct host configurations.
- Each service is disabled by default unless intentionally enabled.
- Reverse proxy rules are implemented where required.
- Authelia or VPN protection is applied to admin/private services.
- Full user management is implemented or explicitly scoped out.
- Secret management is fully wired and no secrets are committed.
- Documentation exists for every service under `docs/implementation/`.
- Relevant Nix builds pass.
- Test procedures are documented and executed.

## Current Summary

Current state: **phase 6.5 service implementation mostly complete, but full user management is not implemented**.

The repository is ready for the next step: design and implement a dedicated user-management/identity layer before exposing Forgejo, Coolify, and admin/private services broadly.
