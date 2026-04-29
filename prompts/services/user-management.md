# Service: Full User Management with Authelia

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- All web authentication for infrastructure services must pass through Authelia.
- Access should be granted by user/group rather than by ad-hoc per-service passwords.
- Secrets must never be committed to the repository.
- The infrastructure should remain manageable for a personal/family self-hosted environment.

## This Service Implements

### Objective
Implement full user management for the self-hosted infrastructure using Authelia as the central authentication and authorization layer, with a web interface to manage users, groups, and service access.

The goal is to make it possible to grant access to specific parts of the infrastructure without giving every user full access to everything.

### Global Authentication Rule
Every web-exposed service must be protected by Authelia before the request reaches the service.

This means:
- Public and private web services go through Caddy/Traefik ForwardAuth to Authelia.
- Users authenticate once with Authelia.
- Authelia decides access using groups from LDAP/LLDAP.
- Services should not be directly reachable on their raw HTTP ports from untrusted networks.
- Per-service local accounts should only exist for bootstrap, emergency recovery, or app-internal authorization when unavoidable.

Allowed exceptions:
- Non-web protocols such as SSH, SMTP, LDAP, WireGuard, or direct Git SSH.
- Emergency break-glass access documented for recovery.
- Health checks that are private, local-only, and not externally exposed.
- Services that cannot delegate authentication may still keep local accounts, but their web UI must remain behind Authelia.

### Target Use Cases
- Create users for family, trusted friends, or personal admin accounts.
- Assign users to groups such as `admins`, `media-users`, `git-users`, `paas-admins`, or `wiki-users`.
- Protect all service web UIs through Authelia policies and group membership.
- Manage access without manually editing every individual service.
- Provide a UI for user/group management.
- Keep a recovery/admin path if Authelia or the management UI fails.

## Recommended Architecture

### Preferred Model
Use Authelia as the mandatory identity/access-control gateway and add a dedicated user-management backend/UI for maintaining users and groups.

Recommended components:
- **Authelia** for SSO, authentication, 2FA, and access-control policies.
- **LDAP directory** as the central user/group database.
- **LLDAP** as a lightweight LDAP server with a web administration UI.
- **Caddy ForwardAuth** or Traefik ForwardAuth for all protected web services.

Suggested flow:

```text
user
  -> Caddy / Traefik
  -> Authelia ForwardAuth
  -> LDAP/LLDAP user + group lookup
  -> protected service
```

### Why LLDAP
LLDAP is recommended for this infrastructure because it provides:
- lightweight LDAP
- web UI for user and group management
- group membership management
- simple deployment model
- good fit for home/self-hosted infrastructure

### Alternative Options

1. **Authelia file users only**
   - Simple and declarative.
   - No proper web UI for user management.
   - Not enough for the requested full user management goal.

2. **Authentik**
   - Full identity provider with UI, OIDC, SAML, LDAP-like features.
   - More complete but heavier and more complex.
   - Could replace Authelia rather than complement it.

3. **Keycloak**
   - Enterprise-grade identity provider.
   - Too heavy for this phase unless explicitly needed.

## Tasks

1. **Create service prompt and implementation docs**
   - Keep this file as the service prompt.
   - Create `docs/implementation/user-management.md`.
   - Explain architecture, trade-offs, user flows, and recovery procedure.

2. **Create NixOS module**
   - `modules/services/user-management.nix`
   - Disabled by default.
   - Options for:
     - enable
     - LLDAP domain/base DN
     - bind address/port
     - admin user
     - secret file paths
     - LDAP read-only bind user for Authelia
     - allowed groups
     - Caddy/Authelia integration flags
     - mandatory ForwardAuth policy for web services

3. **Deploy LLDAP or chosen LDAP backend**
   - Prefer LLDAP unless a better alternative is chosen.
   - Expose UI only through Authelia-protected admin route or VPN-local route.
   - Store data outside the Nix store.
   - Do not commit admin password, JWT secret, key seed, bind passwords, or database secrets.

4. **Integrate Authelia with LDAP**
   - Configure Authelia to use LDAP/LLDAP as the authentication backend.
   - Use a read-only bind account for Authelia.
   - Enable 2FA for privileged groups.
   - Keep fallback/recovery access documented.

5. **Define groups and access model**
   Suggested initial groups:
   - `admins`: full infrastructure/admin access.
   - `infra-admins`: infrastructure dashboards and internal admin tools.
   - `media-users`: Jellyseerr/Jellyfin/media request access.
   - `media-admins`: media stack administration.
   - `git-users`: Forgejo access.
   - `git-admins`: Forgejo admin/organization administration.
   - `paas-admins`: Coolify administration.
   - `wiki-users`: offline wiki access if protected.
   - `monitoring-users`: dashboards and status pages.
   - `service-accounts`: non-human accounts used by services.

6. **Define service access policies**
   Add Authelia access-control rules for:
   - Coolify admin UI: `paas-admins` or `admins` only.
   - Forgejo web UI: `git-users`, `git-admins`, or `admins`.
   - Prowlarr admin UI: `media-admins` or `admins` only.
   - Jellyseerr: `media-users`, `media-admins`, or `admins`.
   - Wiki offline: `wiki-users` or `admins` if exposed through HTTP route.
   - Monitoring/admin dashboards: `monitoring-users`, `infra-admins`, or `admins`.
   - LLDAP management UI: `admins` only.
   - Authelia portal: authenticated users only, with admin functions restricted where applicable.

7. **Enforce Authelia-first exposure**
   - Every Caddy/Traefik route for a service web UI must include Authelia ForwardAuth.
   - Raw service ports must bind to localhost, VPN-only, LAN-only, or private Docker networks.
   - No service web UI should be exposed directly to WAN.
   - If a service supports its own SSO/OIDC, it may also use Authelia/OIDC, but edge ForwardAuth remains the default requirement.
   - Document any exception explicitly.

8. **User lifecycle management**
   Document and/or implement workflows for:
   - create user
   - assign groups
   - reset password
   - disable user
   - remove user from groups
   - rotate service account credentials
   - emergency admin recovery

9. **Service account management**
   Track non-human accounts:
   - Gmail SMTP relay account
   - Forgejo deploy keys / tokens
   - Coolify deploy credentials
   - Prowlarr/Jellyseerr/qBittorrent API users
   - Authelia LDAP bind account

10. **Security hardening**
   - Require 2FA for admin groups.
   - Keep LLDAP UI private/protected.
   - Protect Authelia session cookies with secure domains.
   - Avoid public access to raw LDAP ports.
   - Document backup/restore for LDAP database and secrets.

11. **Host integration**
   - Prefer running user-management on a trusted internal host or VPS depending on exposure needs.
   - If Authelia already runs on VPS, ensure it can reach the LDAP backend securely.
   - If LDAP runs internally, route access through VPN only.

## Constraints
- All web-exposed service authentication must pass through Authelia.
- Do not expose any service web UI directly to WAN without Authelia ForwardAuth.
- Do not commit real users’ passwords, password hashes, LDAP secrets, JWT secrets, or admin tokens.
- Do not expose LDAP publicly to the Internet.
- Do not expose the user-management UI publicly without Authelia and admin-only policy.
- Do not rely only on per-service local admin passwords for web access control.
- Do not make every authenticated user an admin.
- Keep an emergency recovery path if Authelia or LDAP is misconfigured.

## Acceptance Criteria
- `modules/services/user-management.nix` exists and is disabled by default.
- LLDAP or the chosen user-management backend is declaratively deployable.
- Authelia can authenticate users against the central user database.
- A web UI exists to create users and assign groups.
- Access to services can be granted by group.
- Every web-exposed service route is protected by Authelia ForwardAuth or has a documented exception.
- Raw service ports are not publicly reachable.
- Admin-only services are restricted to admin groups.
- 2FA policy is documented for privileged users.
- Recovery/admin fallback procedure is documented.
- No real secrets or passwords are committed.
- Relevant Nix builds still pass.

## Questions to Ask Before Starting
1. Should the user-management backend be LLDAP, Authentik, or another solution?
2. Should users log in with local usernames/passwords only, or should OIDC be added later?
3. Should the user-management UI be VPN-only or exposed through Authelia to admins?
4. Which services should be accessible to non-admin users?
5. Should 2FA be mandatory for everyone or only admin groups?
6. Where should LDAP/LLDAP run: VPS, Kot, or a dedicated internal VM?
