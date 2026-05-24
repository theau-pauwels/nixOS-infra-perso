# Incident: Kot Site Power Loss Recovery — 2026-05-24

## Summary

A power loss at the Kot site caused all Kot VMs to reboot. After rebooting, several
services failed to recover automatically. Recovery required manual intervention and
configuration fixes on three hosts.

## Timeline

| Time (CEST) | Event |
|---|---|
| Before 11:00 | Power loss at Kot site. All VMs lose power. |
| ~11:00 | Power restored. VMs boot. |
| 11:03 | storage-kot boots. Filebrowser, Samba start but `/srv/nas` permissions are broken. |
| 11:44 | seedbox-kot boots after manual redeploy. |
| 11:44 - 12:30 | Debugging and recovery. |
| 12:20 | VPS bundle pushed with updated WireGuard peer keys. |
| 12:28 | Root cause identified: seedbox-kot missing default route. |
| 12:30 | All services restored. |

## Services affected

| Service | Impact | Duration |
|---|---|---|
| `file.theau.net` | 504 Gateway Timeout | ~1h 30m |
| `qbit.theau.net` | 502/504 Gateway Timeout | ~1h 45m |
| Samba shares (storage-kot) | Permission denied for CIFS clients | ~30m |
| jellyfin-kot CIFS mount | Intermittent | ~30m |
| seedbox-kot CIFS mount | Failed until permissions fixed | ~30m |

## Root causes

Each failure has a detailed standalone report:

- [01 — storage-kot NAS permissions](./2026-05-24-01-storage-kot-nas-permissions.md)
- [02 — Firewall `mkDefault` bug](./2026-05-24-02-firewall-mkdefault-bug.md)
- [03 — seedbox-kot missing default route](./2026-05-24-03-seedbox-kot-default-route.md)
- [04 — Gluetun WireGuard keys regenerated](./2026-05-24-04-gluetun-keys-regenerated.md)

### Summary

### 1. storage-kot: `/srv/nas` filesystem permissions lost

**Why:** After reboot, the data disk at `/srv/nas` (ext4, UUID
`5d45548a-3a2e-4db5-9db8-97f6a4b23902`) mounted but its permissions were not
re-applied. The `fix-nas-permissions` oneshot service is configured with
`RemainAfterExit=true`, which means it did not re-execute after the reboot.

**Symptom:** Samba clients (jellyfin-kot, seedbox-kot) got "Permission denied"
when mounting CIFS shares. Samba logs showed:
```
chdir_current_service: vfs_ChDir(/srv/nas) failed: Permission denied
```

**Fix:** Ran `sudo systemctl restart fix-nas-permissions` on storage-kot,
which re-ran `chown -R theau:users /srv/nas && chmod -R 777 /srv/nas`.

**Prevention:** Consider removing `RemainAfterExit=true` so the service runs
on every boot, or using `tmpfiles.d` to set permissions at boot time.

### 2. storage-kot: Filebrowser port 8082 blocked by firewall

**Why:** The `personalInfra.networking.firewall` module used `lib.mkDefault` for
`networking.firewall.allowedTCPPorts`. NixOS service modules (SSH, Samba) set
their ports at default priority (without `mkDefault`), silently overriding the
lower-priority `mkDefault` values. Port 8082 was configured but not present in
running iptables rules. This was a pre-existing bug that only became visible
because filebrowser was diagnosed alongside other issues.

**Symptom:** `file.theau.net` returned 504. VPS nginx could not reach
`10.8.0.23:8082` (storage-kot filebrowser).

**Fix:** Removed `lib.mkDefault` wrapper in `modules/networking/firewall.nix`,
changing:
```nix
allowedTCPPorts = lib.mkDefault cfg.allowedTCPPorts;
allowedUDPPorts = lib.mkDefault cfg.allowedUDPPorts;
```
to:
```nix
allowedTCPPorts = cfg.allowedTCPPorts;
allowedUDPPorts = cfg.allowedUDPPorts;
```
This lets the custom ports merge with NixOS service module ports at equal priority.

### 3. seedbox-kot: Missing default route after static IP assignment

**Why:** This was the critical failure. Before the outage, seedbox-kot obtained
its IP via DHCP. During recovery, a static IP `10.1.10.123/24` was added to the
NixOS config and deployed with `nixos-rebuild switch`. The static IP assignment
overrode the DHCP-provided configuration, which included the default route via
`10.1.10.1`. With no default gateway, the host could not reach the internet —
and neither could the gluetun container, whose WireGuard handshake packets to
the VPS (`82.165.20.195:51820`) never left the host.

**Symptom:**
- `ping 8.8.8.8` returned "Network is unreachable"
- `ping 10.1.10.118` (jellyfin-kot, same subnet) worked fine
- `ip route` showed only the local subnet route, no default
- VPS `wg show wg0` showed the seedbox-kot peer with no handshake, no endpoint,
  no transfer
- gluetun healthcheck looped every 6 seconds: DNS lookups timed out because
  the WireGuard tunnel never established

**Fix:**
1. **Immediate (live):** `sudo ip route add default via 10.1.10.1 dev ens18`
2. **Permanent:** Added to NixOS config:
   ```nix
   networking.defaultGateway = {
     address = "10.1.10.1";
     interface = "ens18";
   };
   ```

### 4. seedbox-kot: Gluetun WireGuard keys regenerated

**Why:** During deployment and debugging, gluetun's WireGuard private key was
regenerated (new key pair: `OKX9DnsR...` → `pTPHLcyx...`). The original key
pair was still present in the environment file from April 30 and matched the
VPS peer config. This change was not strictly necessary — the original keys
would have worked once the default route was restored — but was done while
isolating the root cause. Both `peers.nix` and `secrets.enc.yaml` were updated
and a new VPS bundle was pushed.

**Note:** The new keys are now the canonical configuration.

## Configuration changes

| File | Change |
|---|---|
| `hosts/seedbox-kot/default.nix` | Added static IP `10.1.10.123/24` and default gateway `10.1.10.1` |
| `hosts/storage-kot/default.nix` | Added static IP `10.1.10.124/24` and default gateway `10.1.10.1` |
| `hosts/theau-vps/peers.nix` | Updated seedbox-kot WireGuard public key |
| `hosts/theau-vps/secrets.enc.yaml` | Updated seedbox-kot WireGuard private key and preshared key |
| `modules/networking/firewall.nix` | Removed `lib.mkDefault` from `allowedTCPPorts`/`allowedUDPPorts` |

## Services verified after recovery

| Host | Service | Check |
|---|---|---|
| storage-kot | Samba | `//10.1.10.124/nas` mounted on jellyfin-kot and seedbox-kot |
| storage-kot | Filebrowser | `file.theau.net` → 302 (Authelia redirect) |
| seedbox-kot | Gluetun WireGuard | VPS `wg show`: handshake, endpoint `193.190.211.21` |
| seedbox-kot | qBittorrent | `qbit.theau.net` → 302 (Authelia redirect) |
| jellyfin-kot | CIFS mount | `/srv/nas` mounted at `//10.1.10.124/nas` |
| VPS | Nginx | All virtual hosts responding |
| VPS | WireGuard | All peers with active handshakes |

## Lessons learned

1. **Static IP + NetworkManager without a default gateway is dangerous.**
   `networking.interfaces.*.ipv4.addresses` with NetworkManager enabled can
   drop DHCP-provided routes. Always pair static addresses with
   `networking.defaultGateway` unless the host is intentionally isolated.

2. **`lib.mkDefault` on list options silently fails when service modules use
   default priority.** NixOS SSH and Samba modules add their firewall ports
   without `mkDefault`, so any `mkDefault` list values from custom modules
   are discarded entirely. Use equal priority (no wrapper) for list merges.

3. **Oneshot services with `RemainAfterExit=true` don't re-run after reboot.**
   The `fix-nas-permissions` service did not re-apply permissions post-reboot.
   Consider using `tmpfiles.d` for idempotent permission fixing at boot.

4. **Always verify network connectivity after `nixos-rebuild` on remote hosts.**
   A simple `ping` test after deployment would have caught the missing default
   route immediately.

## Rollback notes

- If the new gluetun WireGuard keys cause issues, the original keys are:
  - Private: `oCkETDfU+KOBQvxLcuP/j4D9dRgRap9OAos4TSKI9U4=`
  - Public: `QAwl8Yaq8Ncq/8YiBvos+muSaZI6kPM/7Vga/B90VHg=`
  - PSK: `K12F6ebcnCXpGps09Ap086wavwl4VWGABEn+z1/x0BY=`
  Restore these in `secrets.enc.yaml`, `peers.nix`, and gluetun's env file,
  then rebuild and push the VPS bundle.
- The VPS bundle can be rolled back with `./deploy/rollback.sh` if needed.
- The previous VPS generation is at `/opt/theau-vps/generations/20260430134153`.
