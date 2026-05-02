# Lidarr (Music) — self-hosted

Runs on the VPS like Sonarr/Radarr, proxied at `https://lidarr.theau.net`.

- Port: 8686 (127.0.0.1), config: `/var/lib/lidarr/config.xml`
- Root folder: `/srv/nas/jellyfin/music`
- Download client: qBittorrent at `10.8.0.22:8080`, category `lidarr`
- Hardlinks: from `/srv/nas/downloads/_arr-work/lidarr` to `/srv/nas/jellyfin/music`
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`
