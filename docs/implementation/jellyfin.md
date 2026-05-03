# Jellyfin — self-hosted media server

Runs on jellyfin-kot at `https://jellyfin.theau.net`.

- Server: `10.8.0.21:8096` (via WireGuard tailnet, jellyfin-kot VM)
- Auth: Authelia `one_factor`, any authenticated user (web UI)
- Auth: LLDAP via LDAP plugin (all clients)
- Clients: web UI, Jellyfin Mobile, Android TV, Kodi, Finamp, etc.

## Authelia bypass for Jellyfin API

Jellyfin clients (mobile, smart TV, Kodi) cannot complete the browser-based
Authelia SSO flow. These clients authenticate directly via the Jellyfin API,
which uses the LDAP Auth plugin connected to LLDAP.

**What is bypassed**: All paths except `/web/` and `/` — the entire Jellyfin
REST API. The root `/` redirects to `/web/`.

**What remains protected**: `/web/` (the Jellyfin web UI) still goes through
Authelia. Users accessing the web UI must authenticate via Authelia SSO.

**Why this is safe**: Jellyfin enforces its own authentication on every API
call, backed by the LDAP plugin connected to LLDAP. A client must provide
valid LLDAP credentials with every request. The API bypass does not disable
Jellyfin auth.

## LDAP authentication

Jellyfin uses the LDAP-Auth plugin to authenticate directly against LLDAP
on the VPS (`10.8.0.1:3890`, reachable via WireGuard).

Plugin: `jellyfin-plugin-ldapauth` v22, installed automatically by a
systemd oneshot service (`jellyfin-ldap-plugin.service`).

### Initial setup

After first deployment, configure the LDAP bind password:

1. Go to `https://jellyfin.theau.net` → Authelia login
2. Jellyfin Dashboard → Plugins → LDAP Auth → Settings
3. Set **LDAP Bind Password** (the LLDAP admin password from the VPS:
   `/opt/theau-vps/state/lldap/admin-password`)
4. Save

All other LDAP settings are pre-configured:
- Server: `10.8.0.1`, port `3890`
- Base DN: `dc=theau,dc=net`
- Search filter: `(uid={0})`
- Admin filter: `(memberOf=cn=admins,ou=groups,dc=theau,dc=net)`
- Username attribute: `uid`
- Create users from LDAP: enabled

### User provisioning

With `CreateUsersFromLdap = true`, the first time a user logs in with
valid LDAP credentials, Jellyfin automatically creates a local user
account linked to their LDAP identity. No manual user creation needed.

## Client setup

### Web UI

Go to `https://jellyfin.theau.net` → Authelia login → Jellyfin web UI.

### Mobile / TV / Kodi apps

- Server URL: `https://jellyfin.theau.net`
- Username: your LLDAP username (same as Authelia)
- Password: your LLDAP password

### Finamp (music)

Finamp is a Subsonic-compatible music client. It connects to Navidrome
at `https://music.theau.net`, not to Jellyfin directly.
