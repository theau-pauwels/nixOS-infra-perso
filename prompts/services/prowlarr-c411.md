# Service: Prowlarr Integration (C411)

## Objective
Integrate Prowlarr with Jellyseerr and qBittorrent + Gluetun.

## Tasks
- Create module `modules/services/prowlarr.nix`
- Configure indexers (C411)
- Connect to Jellyseerr
- Connect to qBittorrent via Gluetun

## Constraints
- VPN-only traffic via Gluetun
- No credentials in repo

## Acceptance Criteria
- Automated search works

## Questions
1. API keys source?
