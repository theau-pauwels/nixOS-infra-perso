# Security Model

## Goals

The security model keeps public exposure small, administrative access explicit,
and secrets out of Git, logs, docs, and the Nix store.

## Exposure Rules

Default rule: internal services are not public unless a document explains why
public exposure is required.

| Service class | Exposure | Notes |
| --- | --- | --- |
| Public web entrypoint | Public | Reverse proxy only, TLS required |
| VPN control plane | Public when required | Minimal ports, hardened service |
| RustDesk rendezvous/relay | Public | Required for remote support use case |
| WireGuard endpoint | Public UDP when used | Current VPS production path |
| SSO-protected apps | VPN or public behind SSO | Prefer VPN-only for admin tools |
| Monitoring UI | VPN-only | Never public without SSO and VPN |
| NAS/Filebrowser | VPN-only | No direct public exposure |
| Cameras/NVR | Internal or VPN-only | No direct public exposure |
| SSH | Admin networks or public with keys only | Disable passwords |
| Databases | Internal only | No public exposure |
| Backup repositories | Internal or authenticated remote | Encrypted before leaving site |

## Phase 3 Service Exposure Matrix

| Service | Route or port | Exposure | Protection |
| --- | --- | --- | --- |
| SSH | `22/tcp` | public for now | public keys only, no passwords |
| Current WireGuard | `51820/udp` | public | WireGuard keys and preshared keys |
| Current WGDashboard | `theau-vps.duckdns.org` via Nginx | public for now | WGDashboard auth |
| RustDesk hbbs/hbbr | `21115-21117` selected TCP/UDP | public | RustDesk protocol/key model |
| iperf3 | `5201/tcp` | public for now | operational test service |
| Headscale | `headscale.theau-vps.duckdns.org` | public HTTPS | Headscale OIDC through Authelia |
| Authelia | `auth.theau-vps.duckdns.org` | public HTTPS | central login/2FA and service authorization |
| LLDAP user manager | `users.theau.net` / `users.theau-vps.duckdns.org` | SSO-protected | Authelia `admins` only |
| Jellyfin | `jellyfin.theau-vps.duckdns.org` | SSO-protected | Authelia authenticated users |
| Jellyseerr | `jellyseerr.theau-vps.duckdns.org` | SSO-protected | Authelia authenticated users |
| Seedbox UI | `seedbox.theau-vps.duckdns.org` | SSO-protected | Authelia `super-admin` only |
| NAS SMB/NFS/FileBrowser | Kot LAN/VPN only | private subnets only | local Unix/Samba groups, no public ingress |
| Mom edge exporters | `10.8.0.30:9100`, `10.8.0.30:9115` | VPN only | scrape from private monitoring |
| Dad edge exporter | `10.8.0.40:9100` | VPN only | scrape from private monitoring |
| Mom NVR | future LAN/VPN route | private only | disabled until cameras/storage are chosen |
| Monitoring UI | future route | VPN-only | Authelia plus VPN |

Headscale and the current WireGuard service have separate roles. WireGuard is
the existing production tunnel and torrent egress path. Headscale is the future
control plane for user devices and service nodes.

Authelia is the single authorization point for private web services. LLDAP owns
users and groups; the edge proxy only asks Authelia whether a request may reach
a service. Service access is granted by LLDAP group membership, for example
`wg-admin` for WGDashboard and `paas-admins` for Coolify.

## SSH Access Models

### Personal Admin Access

Personal admin access is the break-glass path:

- declared directly in Nix or host inventory
- stable user-owned SSH public keys
- no private key escrow
- intended only for trusted administrators
- should work even if SSO or future access platforms are down

### Future Delegated Access

Future delegated access is separate:

- short-lived OpenSSH user certificates
- scoped principals per user and host
- expiry-based grants
- auditable issuance
- no private key escrow
- UI exposed only through VPN and/or SSO

The delegated model is not implemented yet.

## Secrets Approach

- Encrypted deployable secrets live in SOPS-managed files.
- Cleartext secrets are local-only and ignored.
- Public keys may be committed when they are intentionally public inventory.
- Private keys, passwords, API tokens, WireGuard private keys, preshared keys,
  SSH CA private keys, and live exported configs must never be committed.
- Secrets must not be embedded in Nix derivations that end up in the store.

## Network Boundaries

- Public internet reaches only deliberate edge services.
- Site LANs are private and routed over VPN only when required.
- Dad site routing is outbound-only from `dad-edge` because Starlink CGNAT
  prevents inbound sessions.
- Guest and IoT networks should not reach management networks by default.
- Camera networks should reach only NVR services and required update endpoints.
- Management VLANs should be reachable only from admin devices and trusted
  gateways.
- Backup traffic should use authenticated and encrypted channels.

## Firewall Principles

- Default deny inbound.
- Allow loopback and established traffic.
- Open only documented service ports.
- Keep site-to-site forwarding explicit.
- Avoid implicit broad forwarding between VLANs.
- Prefer host firewalls even when network firewalls exist.
