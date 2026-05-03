# User Management

## Architecture

User and service access is managed with LLDAP plus Authelia:

```text
browser -> Nginx/Caddy/Traefik -> Authelia ForwardAuth -> LLDAP groups -> service
```

LLDAP stores users and groups and provides the user-management UI. Authelia
authenticates against LLDAP and acts as the WAN login portal, 2FA gate, session
manager, and authorization decision point.

LLDAP's own UI is different from normal apps: the route can be gated by
Authelia, but the UI still uses LLDAP credentials for its internal login.
Application web UIs should bind locally or privately; WAN requests must pass
through Authelia before reaching them.

## Groups

Each service has two groups: `{service}` for users who can USE the service,
`{service}-admin` for users who can MANAGE it. The `admins` group (containing
user `theau`) has access to everything.

```text
admins           # super-admin (theau)
infra-admins     # infrastructure admins
service-accounts # machine accounts

# Per-service groups (17 services × 2 groups each)
authelia         authelia-admin
coolify          coolify-admin
file             file-admin
git              git-admin
jellyfin         jellyfin-admin
lidarr           lidarr-admin
monitoring       monitoring-admin
musicseerr       musicseerr-admin
navidrome        navidrome-admin
prowlarr         prowlarr-admin
qbit             qbit-admin
radarr           radarr-admin
seer             seer-admin
sonarr           sonarr-admin
users            users-admin
wg               wg-admin
wiki             wiki-admin
```

## Access Policies

Authelia policies use the per-service groups:

| Service | Policy | Groups |
| --- | --- | --- |
| Authelia portal | one_factor | (public) |
| LLDAP UI | two_factor | `users-admin`, `admins` |
| WGDashboard | two_factor | `wg`, `wg-admin`, `admins` |
| Coolify | two_factor | `coolify-admin`, `admins` |
| Prowlarr | two_factor | `prowlarr-admin`, `admins` |
| Sonarr | one_factor | `sonarr`, `sonarr-admin`, `admins` |
| Radarr | one_factor | `radarr`, `radarr-admin`, `admins` |
| Lidarr | one_factor | `lidarr`, `lidarr-admin`, `admins` |
| Navidrome | one_factor | `navidrome`, `navidrome-admin`, `admins` |
| MusicSeerr | one_factor | `musicseerr`, `musicseerr-admin`, `admins` |
| qBittorrent | one_factor | `qbit`, `qbit-admin`, `admins` |
| Jellyfin | one_factor | `jellyfin`, `jellyfin-admin`, `admins` |
| Seerr | one_factor | `seer`, `seer-admin`, `admins` |
| FileBrowser | one_factor | `file`, `file-admin`, `admins` |
| Forgejo | one_factor | `git`, `git-admin`, `admins` |
| Wiki | one_factor | `wiki`, `wiki-admin`, `admins` |
| Monitoring | one_factor | `monitoring`, `monitoring-admin`, `infra-admins`, `admins` |

## Application Accounts

LLDAP is the source of truth for edge access to service web UIs. Some
applications can also delegate their own user accounts to SSO/OIDC, but this is
application-specific.

Coolify is a current exception. The deployed Coolify version supports local
accounts and a fixed list of OAuth providers, but it does not support LDAP,
LLDAP, or generic OIDC against Authelia. Its web UI is still protected by
Authelia before any request reaches Coolify, and only users in `paas-admins` or
`admins` can reach the login page. Coolify teams, project permissions, deploy
keys, and API tokens remain Coolify-local until upstream supports a compatible
identity provider.

## Current VPS Bundle

The current Ubuntu VPS bundle runs:

- LLDAP on `0.0.0.0:17170` (HTTP) and `0.0.0.0:3890` (LDAP, reachable from WireGuard peers via nftables restriction)
- Authelia on `127.0.0.1:9091`
- `users.theau.net` -> LLDAP UI, route-gated by Authelia `users-admin` or `admins`; LLDAP still handles its own UI login
- `wg.theau.net` -> WGDashboard, protected by Authelia `wg`, `wg-admin`, or `admins`
- `coolify.theau.net` -> Coolify, edge-protected by Authelia `coolify-admin` or `admins`
- `jellyfin.theau.net` -> Jellyfin, edge-protected by Authelia `jellyfin`, `jellyfin-admin`, or `admins`
- `prowlarr.theau.net` -> Prowlarr, edge-protected by Authelia `prowlarr-admin` or `admins`
- `sonarr.theau.net` -> Sonarr, edge-protected by Authelia `sonarr`, `sonarr-admin`, or `admins`
- `radarr.theau.net` -> Radarr, edge-protected by Authelia `radarr`, `radarr-admin`, or `admins`
- `lidarr.theau.net` -> Lidarr, edge-protected by Authelia `lidarr`, `lidarr-admin`, or `admins`
- `music.theau.net` -> Navidrome, edge-protected by Authelia `navidrome`, `navidrome-admin`, or `admins`
- `musicseerr.theau.net` -> MusicSeerr, edge-protected by Authelia `musicseerr`, `musicseerr-admin`, or `admins`
- `qbit.theau.net` -> qBittorrent WebUI, edge-protected by Authelia `qbit`, `qbit-admin`, or `admins`
- `seer.theau.net` -> Seerr, edge-protected by Authelia `seer`, `seer-admin`, or `admins`
- `file.theau.net` -> FileBrowser, edge-protected by Authelia `file`, `file-admin`, or `admins`

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

WGDashboard has an additional in-app guard: Nginx forwards Authelia `Remote-*`
headers to WGDashboard, and the packaged app creates an admin session only when
the authenticated user is in `wg-admin`. The app does not bind directly to LDAP;
LLDAP remains the group source through Authelia.

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
