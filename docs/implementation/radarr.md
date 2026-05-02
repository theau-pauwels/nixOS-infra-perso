# Radarr (Movies) — self-hosted

## Context

Radarr is a movie collection manager integrated with Prowlarr (indexer) and
qBittorrent (download client). It runs on the Ubuntu VPS alongside Prowlarr
and Seerr, exposed at `https://radarr.theau.net` behind Authelia + LLDAP.

## Deployment

- **Host**: Ubuntu VPS (`IONOS-VPS2-DEPLOY`)
- **Port**: 7878 (127.0.0.1)
- **Config**: `/var/lib/radarr/config.xml`, `AuthenticationMethod=External`
- **API key**: `/opt/theau-vps/state/radarr/api-key`
- **Systemd**: `theau-vps-radarr.service`

## Reverse proxy

Nginx on the VPS proxies `radarr.theau.net` → `http://127.0.0.1:7878` through
Authelia `auth_request`. Access requires `admins`, `media-admins`, or
`media-users` LLDAP group membership.

## Post-deploy configuration

1. Access `https://radarr.theau.net`
2. Add Prowlarr as indexer: `http://127.0.0.1:9696` with Prowlarr API key
3. Add qBittorrent as download client: `http://10.8.0.22:8080`
4. Add root folder: `/srv/jellyfin/media/movies`
5. Connect to Jellyfin for library management
