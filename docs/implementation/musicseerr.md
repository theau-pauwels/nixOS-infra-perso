# MusicSeerr — music request UI

Podman container on VPS at `https://musicseerr.theau.net`.

- Port: 5056 (127.0.0.1)
- Image: `ghcr.io/mentalblank/musicseerr:latest`
- Connects to Lidarr (8686) + Navidrome (4533) on localhost
- Auth: Authelia `one_factor`, groups `admins, media-admins, media-users`

Post-deploy: configure Lidarr API key and Navidrome URL in the MusicSeerr UI.
