# User Management

## Architecture

User and service access is managed with LLDAP plus Authelia:

```text
browser -> Nginx/Caddy/Traefik -> Authelia ForwardAuth -> LLDAP groups -> service
```

LLDAP stores users and groups and provides the user-management UI. Authelia is
the login portal, 2FA gate, session manager, and authorization decision point.
Application web UIs should bind locally or privately; WAN requests must pass
through Authelia before reaching them.

## Groups

Initial groups:

```text
admins
infra-admins
media-users
media-admins
git-users
git-admins
paas-users
paas-admins
wiki-users
monitoring-users
service-accounts
wg-admin
```

`wg-admin` is intentionally separate from `admins`: WGDashboard access is
granted by membership in `wg-admin`.

## Access Policies

Authelia policies use LLDAP groups:

| Service | Groups |
| --- | --- |
| LLDAP UI | `admins` |
| WGDashboard | `wg-admin` |
| Coolify admin UI | `paas-admins`, `admins` |
| Forgejo web UI | `git-users`, `git-admins`, `admins` |
| Prowlarr admin UI | `media-admins`, `admins` |
| Jellyseerr | `media-users`, `media-admins`, `admins` |
| Wiki offline | `wiki-users`, `admins` |
| Monitoring | `monitoring-users`, `infra-admins`, `admins` |

Privileged routes should use Authelia `two_factor`. Public raw service ports
remain closed or bound to localhost.

## Current VPS Bundle

The current Ubuntu VPS bundle runs:

- LLDAP on `127.0.0.1:17170` and LDAP on `127.0.0.1:3890`
- Authelia on `127.0.0.1:9091`
- `users.theau.net` -> LLDAP UI, protected by Authelia `admins`
- `wg.theau.net` -> WGDashboard, protected by Authelia `wg-admin`
- `coolify.theau.net` -> Coolify, protected by Authelia `paas-admins` or `admins`

Bootstrap credentials are generated on the VPS:

```text
/opt/theau-vps/state/lldap/admin-credentials.txt
/opt/theau-vps/state/authelia/admin-credentials.txt
```

Both files are root-readable only. The bootstrap user is `theau`. Read them
with:

```bash
ssh IONOS-VPS2-DEPLOY
sudo cat /opt/theau-vps/state/lldap/admin-credentials.txt
sudo cat /opt/theau-vps/state/authelia/admin-credentials.txt
```

Until SMTP is configured for Authelia, verification and recovery messages are
written to the filesystem notifier instead of being sent by email:

```bash
sudo cat /opt/theau-vps/state/authelia/notification.txt
```

## NixOS Module

The future native NixOS target uses:

```text
modules/services/user-management.nix
```

It is disabled by default and composes the existing LLDAP and Authelia modules.
When enabled, it configures LLDAP as the authentication backend and writes the
Authelia authorization matrix from group policies.

## User Lifecycle

Create a user:

1. Log in to `https://users.theau.net`.
2. Create the user in LLDAP.
3. Assign only the groups needed for the requested services.
4. Ask the user to enroll 2FA in Authelia before granting admin groups.

Grant access:

1. Add the user to the service group in LLDAP.
2. The next Authelia authorization check uses the updated group membership.

Revoke access:

1. Remove the user from the LLDAP group.
2. For urgent revocation, disable the user in LLDAP and clear active Authelia
   sessions by restarting Authelia.

Reset password:

1. Use the LLDAP UI as an `admins` user.
2. If SMTP reset mail is not configured, set a temporary password and require
   the user to change it.

## Recovery

If Authelia or LLDAP is misconfigured:

1. Use SSH break-glass access to IONOS-VPS2.
2. Read bootstrap credentials with `sudo cat`.
3. Check `theau-vps-lldap.service` and `theau-vps-authelia.service`.
4. Roll back the VPS bundle by activating a previous generation under
   `/opt/theau-vps/generations`.

Do not expose LLDAP LDAP ports publicly during recovery.

## Backups

Back up:

- `/opt/theau-vps/state/lldap`
- `/opt/theau-vps/state/authelia`
- service account credentials and app tokens from the secret manager

Do not commit passwords, LDAP bind secrets, JWT secrets, database files, or
exported user data.
