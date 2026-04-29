# Prowlarr C411 Integration

## Architecture

Prowlarr centralizes torrent indexers for the media request workflow:

```text
user -> Jellyseerr -> Prowlarr -> qBittorrent WebUI -> qBittorrent traffic via Gluetun
```

`modules/services/prowlarr.nix` wraps the NixOS `services.prowlarr` module and
keeps the UI internal. Prowlarr is not a public service.

## Host Placement

Planned placement is `seedbox-kot`, next to qBittorrent and Gluetun. This keeps
media automation close to the downloader and avoids exposing tracker tooling
through the public VPS.

The module is imported there but disabled by default:

```nix
personalInfra.services.prowlarr.enable = false;
```

## Network Exposure

Defaults:

- bind address: `127.0.0.1`
- port: `9696/tcp`
- firewall: closed
- Caddy reverse proxy: optional and internal only
- Authelia ForwardAuth: enabled if the optional Caddy vhost is enabled
- public exposure: not allowed

Documented trusted networks:

- `10.224.20.0/24`
- `10.8.0.0/24`
- `100.64.0.0/10`

## Gluetun And qBittorrent Constraint

The seedbox module already runs qBittorrent with:

```text
--network=container:seedbox-gluetun
```

Prowlarr is ordered after `podman-seedbox-gluetun.service` by default so app
integration starts only after the VPN container exists. qBittorrent remains the
only component performing torrent transfer, and its network namespace remains
Gluetun-bound.

Prowlarr-to-indexer traffic is ordinary HTTPS API/RSS traffic. If a tracker
requires that traffic to also egress through the VPN, run Prowlarr in the same
container namespace in a later hardening pass instead of the native service.

## C411 Configuration

C411 credentials are not declarative in this repo. Add the C411 indexer through
the Prowlarr UI after enabling the service. Use placeholders in docs and keep
real credentials in SOPS or a local password manager.

Expected runtime secret placeholders:

```text
/run/secrets/prowlarr-api-key
/run/secrets/prowlarr-c411-username
/run/secrets/prowlarr-c411-password
/run/secrets/qbittorrent-webui-password
```

## Jellyseerr And qBittorrent Integration

Default documented URLs:

```text
Jellyseerr:   http://jellyseerr-kot.tailnet.theau-vps.duckdns.org:5055
qBittorrent: http://127.0.0.1:8080
```

Configure the API keys through the applications' UIs until a safe declarative
secret wiring is added.

## Backup Considerations

Back up:

- Prowlarr data directory
- encrypted API key and tracker credential secrets
- screenshots or exported notes of indexer definitions if the UI remains the source of truth

Do not back up downloaded torrent payloads as part of Prowlarr.

## Test Procedure

After enabling:

```bash
systemctl status prowlarr podman-seedbox-gluetun podman-seedbox-qbittorrent
curl -fsSI http://127.0.0.1:9696/
```

From Prowlarr UI:

- add C411 with placeholder-free credentials
- add qBittorrent download client at `http://127.0.0.1:8080`
- test the download client connection
- add Prowlarr as indexer provider to Jellyseerr

Confirm qBittorrent traffic remains behind Gluetun:

```bash
podman exec seedbox-gluetun wget -qO- https://ifconfig.me
```

## Rollback And Troubleshooting

Rollback by disabling:

```nix
personalInfra.services.prowlarr.enable = false;
```

Keep the data directory until indexer configuration has been exported or backed
up.

Common failures:

- Prowlarr starts before qBittorrent: check `integrations.gluetunService`
- qBittorrent connection refused: verify the WebUI port exposed by Gluetun
- C411 fails behind Cloudflare: document whether FlareSolverr is required before adding it
- public reachability detected: remove Caddy host and close firewall immediately
