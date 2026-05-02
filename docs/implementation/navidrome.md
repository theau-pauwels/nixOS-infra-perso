# Navidrome — self-hosted music server

Runs on the VPS at `https://music.theau.net`.

- Port: 4533 (127.0.0.1)
- Music folder: `/srv/nas/jellyfin/music` (read-only via CIFS)
- Scan interval: 30 minutes
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`
- Clients: Feishin (desktop), Subsonic-compatible apps (DSub, play:Sub, etc.)
