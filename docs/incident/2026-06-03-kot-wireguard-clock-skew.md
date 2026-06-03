# Failure: Kot VMs WireGuard disconnected due to clock skew from DNS failure

**Date:** 2026-06-03
**Severity:** Medium (partial service degradation — NAS and seedbox unreachable via WireGuard)

## Symptom

On the VPS, `wg show wg0` showed no recent handshake for `seedbox-kot`
(`10.8.0.22`) and `storage-kot` (`10.8.0.23`). Both peers had `latest handshake: 4
days ago`. `jellyfin-kot` (`10.8.0.21`) remained connected.

## Root Cause Chain

1. **Stale NetworkManager connection profiles**: After removing hardcoded static
   IPs from the NixOS host configs (commit `4dcf416`), the NetworkManager
   connection profiles for `ens18` persisted with `ipv4.method: manual` and no
   DNS servers configured (`ipv4.dns: --`).

2. **No DNS resolution**: Without DNS servers in `/etc/resolv.conf`, the
   machines could not resolve NTP pool hostnames (`pool.ntp.org`).

3. **NTP could not sync**: `systemd-timesyncd` could not synchronize the system
   clock because it could not resolve its fallback NTP server hostnames.

4. **System clock drifted to December 2024**: After the May 24 power loss, the
   system clock was ~18 months behind. NTP could not correct it because DNS was
   broken.

5. **WireGuard handshakes failed**: WireGuard uses timestamps in its handshake
   protocol. A clock skew of 18 months causes both sides to reject each other's
   handshake messages (initiator timestamp appears too old; responder timestamp
   appears too far in the future).

## Affected Hosts

| Host | NM Method | DNS | Clock | WireGuard |
|---|---|---|---|---|
| jellyfin-kot | auto (DHCP) | ✅ `10.224.20.1` | ✅ June 2026 | ✅ Connected |
| seedbox-kot | manual | ❌ None | ❌ Dec 2024 | ❌ No handshake |
| storage-kot | manual | ❌ None | ❌ Dec 2024 | ❌ No handshake |

`jellyfin-kot` was unaffected because its NM connection profile was already
DHCP-based (it never had a static IP assigned via NixOS that left a stale manual
profile).

## Fix Applied

### Immediate (live machines)

1. Switched NetworkManager connection to DHCP:
   ```bash
   nmcli con mod ens18 ipv4.method auto ipv4.addresses '' ipv4.gateway '' ipv4.dns ''
   nmcli con down ens18
   nmcli con up ens18
   ```

2. Restarted NTP sync and WireGuard:
   ```bash
   systemctl restart systemd-timesyncd.service
   systemctl restart wg-quick-theau-vps.service   # storage-kot
   systemctl restart podman-seedbox-gluetun.service # seedbox-kot
   ```

### Permanent (NixOS config)

Added explicit `networking.nameservers` to all Kot host configs as a safety net
(hosts `jellyfin-kot`, `seedbox-kot`, `storage-kot`):

```nix
networking.nameservers = [ "10.224.20.1" ];
```

This ensures `/etc/resolv.conf` always has a nameserver even if the DHCP lease
doesn't provide one or the NM profile is misconfigured.

## Verification

After fix, confirmed from the VPS:

| Peer | Last Handshake |
|---|---|
| jellyfin-kot (`10.8.0.21`) | 13 seconds ago |
| seedbox-kot (`10.8.0.22`) | 13 seconds ago |
| storage-kot (`10.8.0.23`) | 46 seconds ago |

Service health checks from VPS:
- qBittorrent WebUI at `10.8.0.22:8080` → HTTP 200 ✅
- Filebrowser at `10.8.0.23:8082` → Reachable ✅

## Prevention

- Always configure `networking.nameservers` on hosts that need DNS for
  time-sensitive protocols (NTP, TLS, WireGuard)
- After removing static IP configuration, verify NetworkManager connection
  profiles are cleaned up (`nmcli con show`)
- Consider adding a NixOS assertion or healthcheck that warns when
  `systemd-timesyncd` has not synchronized within a threshold

## Rollback

N/A — fix is a configuration addition, not a rollback. The live fix can be
reversed by re-creating the manual NM profile and removing the DNS
configuration, but this would re-create the original breakage.
