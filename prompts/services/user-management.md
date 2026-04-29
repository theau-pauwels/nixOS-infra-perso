# Service: Full User Management with Authelia and LLDAP

## Objective

Implement full user management for the self-hosted infrastructure using:

- **LLDAP** as the central user and group directory with a web management UI.
- **Authelia** as the central authentication, 2FA, and authorization layer.
- **Caddy/Traefik ForwardAuth** as the enforcement point in front of every web-exposed service.

The goal is to manage all users and groups from LLDAP, then use those groups in Authelia policies to decide which parts of the infrastructure each user can access.

## Global Rule

All web-exposed services must pass through Authelia.

Allowed exceptions:

- SSH
- SMTP
- WireGuard
- LDAP internal traffic
- emergency break-glass access
- private health checks

No service web UI should be directly exposed to WAN.

Services that do not support LDAP/LLDAP or a compatible SSO backend may keep
local application accounts, but their web UI must still be protected by
Authelia at the edge and the exception must be documented.

## Architecture

```text
user
  -> Caddy / Traefik
  -> Authelia ForwardAuth
  -> LLDAP user + group lookup
  -> protected service
```

## Selected Backend

LLDAP is the selected backend for user and group management.

LLDAP responsibilities:

- store human users
- store groups
- provide web UI for user and group management
- provide LDAP backend to Authelia
- store service/bind users when needed

Authelia responsibilities:

- login portal
- 2FA
- session management
- group-based authorization
- ForwardAuth responses to Caddy/Traefik

## Groups

Initial groups:

- `admins`: full infrastructure access
- `infra-admins`: internal admin tools and dashboards
- `media-users`: Jellyseerr/Jellyfin access
- `media-admins`: Prowlarr/qBittorrent/media administration
- `git-users`: Forgejo access
- `git-admins`: Forgejo administration
- `paas-users`: access to internal PaaS apps
- `paas-admins`: Coolify administration
- `wiki-users`: offline wiki access
- `monitoring-users`: monitoring dashboards
- `service-accounts`: non-human accounts

## Access Policies

Authelia rules must use LLDAP groups:

- Coolify admin UI: `paas-admins` or `admins`
- Forgejo web UI: `git-users`, `git-admins`, or `admins`
- Prowlarr admin UI: `media-admins` or `admins`
- Jellyseerr: `media-users`, `media-admins`, or `admins`
- qBittorrent web UI: `media-admins` or `admins`
- Wiki offline: `wiki-users` or `admins`
- Monitoring dashboards: `monitoring-users`, `infra-admins`, or `admins`
- LLDAP management UI: `admins` only

Known limitation: Coolify web access can be restricted by Authelia + LLDAP
groups, but Coolify's internal users, teams, project roles, API tokens, and
deploy keys remain Coolify-local unless a compatible upstream SSO backend is
available and configured.

## User Lifecycle

Document workflows for:

- create user in LLDAP
- assign user to groups
- reset password
- disable user
- remove user from groups
- grant access to a service
- revoke access to a service
- rotate service account credentials
- emergency admin recovery

## Security

- Require 2FA for admin groups.
- Do not expose raw LDAP publicly.
- Do not expose LLDAP UI without Authelia admin-only policy.
- Do not expose service web UIs directly.
- Keep emergency recovery documented.
- Backup LLDAP database and secrets.
- Do not commit passwords, password hashes, LDAP secrets, JWT secrets, or tokens.

## Acceptance Criteria

- `modules/services/user-management.nix` exists and is disabled by default.
- LLDAP is deployable.
- LLDAP provides a web UI to create users and assign groups.
- Authelia authenticates against LLDAP.
- Authelia authorization policies use LLDAP groups.
- Access can be granted/revoked by changing LLDAP group membership.
- Every web-exposed service is protected by Authelia ForwardAuth.
- Raw service ports are not publicly reachable.
- Admin-only services are restricted to admin groups.
- 2FA is documented for privileged users.
- Recovery procedure is documented.
- No secrets are committed.
