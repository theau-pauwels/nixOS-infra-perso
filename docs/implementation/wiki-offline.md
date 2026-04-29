# Offline Wikipedia

## Architecture

Offline Wikipedia uses Kiwix ZIM files served by the NixOS
`services.kiwix-serve` module, wrapped by `modules/services/wiki-offline.nix`.

```text
LAN/VPN client -> optional internal Caddy name -> kiwix-serve -> ZIM files on NAS storage
```

Kiwix was chosen instead of a live MediaWiki mirror because it is simpler,
static, searchable, and works without Internet access once ZIM files are
present.

## Host Placement

Planned placement is `nas-kot`, where large datasets belong. The module is
imported there but disabled by default:

```nix
personalInfra.services.wikiOffline.enable = false;
```

ZIM files should live under NAS-backed storage such as:

```text
/srv/wiki-offline
```

Do not store ZIM files in Git or fetch them into the Nix store.

## Network Exposure

Defaults:

- bind address: `127.0.0.1`
- port: `8088/tcp`
- firewall: closed
- Caddy reverse proxy: optional
- public exposure: not allowed

When enabled for LAN/VPN users, bind to a concrete LAN/VPN address and open the
host firewall only for trusted networks at the perimeter.

Documented trusted networks:

- `10.224.10.0/24`
- `10.224.20.0/24`
- `10.8.0.0/24`
- `100.64.0.0/10`

## Storage And Update Workflow

Use either `library` or `libraryPath`.

Example with a runtime library file:

```nix
personalInfra.services.wikiOffline = {
  enable = true;
  bindAddress = "10.224.20.10";
  libraryPath = "/srv/wiki-offline/library.xml";
};
```

Create or refresh the library with `kiwix-manage` outside the Nix build. Large
datasets can range from tens to hundreds of GB depending on language and media
selection.

## Secret Handling

No application secret is required. If automated downloads are added later, any
mirror credentials or API tokens must live in SOPS or another runtime secret
path outside Git.

## Backup Considerations

ZIM files are reproducible downloads and may be excluded from expensive backup
sets if bandwidth is acceptable. Back up:

- `library.xml`
- selected dataset manifest
- any custom local documentation ZIMs that cannot be redownloaded

For disaster recovery, document the exact ZIM filenames and source URLs in the
NAS operations notes before enabling automatic refresh.

## Test Procedure

After enabling:

```bash
systemctl status kiwix-serve
curl -fsSI http://127.0.0.1:8088/
```

From a LAN/VPN client:

```bash
curl -fsSI http://wiki.internal/
```

Disconnect Internet access and verify search and article reads still work.

## Rollback And Troubleshooting

Rollback by disabling:

```nix
personalInfra.services.wikiOffline.enable = false;
```

Keep `/srv/wiki-offline` intact. Common failures:

- service assertion failure: set exactly one of `library` or `libraryPath`
- empty UI: `library.xml` references missing or unreadable ZIM files
- permission denied: make ZIM files world-readable or readable by the dynamic service user
- not reachable from LAN: check bind address, firewall, and internal DNS
