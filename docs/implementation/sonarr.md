# Sonarr (TV) — self-hosted

## Context

Sonarr is a TV show collection manager integrated with Prowlarr (indexer) and
qBittorrent (download client). It runs on the Ubuntu VPS alongside Prowlarr
and Seerr, exposed at `https://sonarr.theau.net` behind Authelia + LLDAP.

## Deployment

- **Host**: Ubuntu VPS (`IONOS-VPS2-DEPLOY`)
- **Port**: 8989 (127.0.0.1)
- **Config**: `/var/lib/sonarr/config.xml`, `AuthenticationMethod=External`
- **API key**: `/opt/theau-vps/state/sonarr/api-key`
- **Systemd**: `theau-vps-sonarr.service`

## Reverse proxy

Nginx on the VPS proxies `sonarr.theau.net` → `http://127.0.0.1:8989` through
Authelia `auth_request`. Access requires `admins`, `media-admins`, or
`media-users` LLDAP group membership.

## Post-deploy configuration

1. Access `https://sonarr.theau.net`
2. Add Prowlarr as indexer: `http://127.0.0.1:9696` with Prowlarr API key
3. Add qBittorrent as download client: `http://10.8.0.22:8080`
4. Add root folder: `/srv/jellyfin/media/shows`
5. Connect to Jellyfin for library management
