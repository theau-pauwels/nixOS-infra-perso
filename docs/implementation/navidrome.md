# Navidrome — self-hosted music server

Runs on the VPS at `https://music.theau.net`.

- Port: 4533 (127.0.0.1)
- Music folder: `/srv/nas/jellyfin/music` (read-only via CIFS)
- Scan interval: 30 minutes
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`
- Clients: Feishin (desktop), Subsonic-compatible apps (DSub, play:Sub, Amperfy)

## Authelia bypass for Subsonic API

Navidrome exposes a Subsonic-compatible REST API at `/rest/*`. This path
bypasses Authelia entirely because Subsonic clients (Amperfy, DSub, etc.)
cannot complete the browser-based Authelia login flow, but they CAN provide
Navidrome's own username/password.

**What is bypassed**: Only `/rest/*` — all Subsonic API calls.

**What remains protected**: `/`, `/app`, `/login`, and all other non-API paths
still go through Authelia. The Navidrome web UI requires Authelia login.

**Why this is safe**: Navidrome enforces its own authentication on every
Subsonic API call. A client must provide valid Navidrome credentials with
every request. The `/rest/*` bypass does not disable Navidrome auth.

## Client setup

### Amperfy (iOS)

- Server URL: `https://music.theau.net`
- Username: your Navidrome username
- Password: your Navidrome password

Do NOT use your Authelia/LDAP credentials — use the Navidrome account
created during first-time setup.

### Feishin (desktop)

Feishin connects to the Navidrome web UI through a browser, so it uses
the normal Authelia login flow on `https://music.theau.net/`.

### Other Subsonic clients

Any Subsonic-compatible client (DSub, play:Sub, Ultrasonic, SubStreamer)
can connect to `https://music.theau.net` with Navidrome credentials.
