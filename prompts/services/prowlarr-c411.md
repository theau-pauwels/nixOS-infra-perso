# Service: Prowlarr Integration (C411)

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant excerpts:
- Existing media stack:
  - Jellyfin
  - Jellyseerr
  - qBittorrent + Gluetun
- Traffic must go through VPN for torrenting.

## This Service Implements

### Objective
Integrate Prowlarr to centralize indexers (including C411) and automate media search with Jellyseerr and qBittorrent.

### Target Use Cases
- Automated movie/series requests via Jellyseerr.
- Indexer aggregation through Prowlarr.
- Secure torrenting through Gluetun VPN.

### Tasks

1. **Create service module**
   - `modules/services/prowlarr.nix`
   - Disabled by default.
   - Options:
     - bind address
     - port
     - data directory
     - API key (placeholder)

2. **Indexer configuration**
   - Add C411 support.
   - Document RSS/API configuration.
   - Use placeholder credentials only.

3. **Integration with Jellyseerr**
   - Configure Prowlarr as indexer provider.
   - Ensure API connectivity.

4. **Integration with qBittorrent**
   - Connect through Gluetun network.
   - Ensure all traffic goes through VPN container.
   - No direct WAN access.

5. **Network design**
   - Prowlarr ↔ Jellyseerr (LAN)
   - Prowlarr ↔ qBittorrent (VPN network)
   - No public exposure.

6. **Documentation**
   - `docs/implementation/prowlarr.md`
     - Architecture
     - Flow:
       user → Jellyseerr → Prowlarr → qBittorrent
     - VPN constraints
     - Troubleshooting

## Constraints
- All torrent traffic MUST go through Gluetun.
- No credentials in repo.
- No public exposure.
- Respect legal considerations (no automation beyond indexing).

## Acceptance Criteria
- Module builds successfully.
- Prowlarr connects to Jellyseerr.
- Prowlarr connects to qBittorrent via VPN.
- Documentation complete.

## Questions to Ask Before Starting
1. C411 access method (RSS, API, flaresolverr?)  
2. Should Prowlarr run in same VM as Jellyseerr or separate?  
3. Any additional trackers to include?  