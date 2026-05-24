# Failure: Gluetun WireGuard keys regenerated during recovery

**Incident:** [2026-05-24 Kot Power Loss Recovery](./2026-05-24-power-loss-kot-recovery.md)

## Symptom

During recovery, gluetun's WireGuard private key was regenerated as part of an
attempt to fix the broken WireGuard tunnel. The original key pair was still
present and valid, but was replaced while diagnosing a connectivity issue that
turned out to be unrelated (missing default route).

## Cause

The gluetun WireGuard tunnel was not completing handshakes. While investigating,
the keys were suspected to be mismatched. A new key pair was generated:

| Field | Original | New |
|---|---|---|
| Private key | `oCkETDfU+KOBQvxLcuP/j4D9dRgRap9OAos4TSKI9U4=` | `OKX9DnsREKisY0AJaT95cT55irGY+fTsVkNbRNE+9nc=` |
| Public key | `QAwl8Yaq8Ncq/8YiBvos+muSaZI6kPM/7Vga/B90VHg=` | `pTPHLcyx2dh2gykKjljcOsbuNIoUfZlOHKAvV5S7GmM=` |
| PSK | `K12F6ebcnCXpGps09Ap086wavwl4VWGABEn+z1/x0BY=` | `muQbQ2eT0kRsppq3hoQGKQ3U7p2z/SepRtXOwXF+yV4=` |

The original key pair was valid — it matched the VPS peer config and had been
working since April 30. The tunnel failure was caused by seedbox-kot having no
default route, which prevented UDP handshake packets from leaving the host.

However, during the debugging process:
1. The original gluetun env file at `/var/lib/seedbox/gluetun/ionos-vps2-wireguard.env`
   was overwritten with the new keys.
2. `peers.nix` was updated with the new public key.
3. `secrets.enc.yaml` was updated with the new private key and PSK.
4. A new VPS bundle was built and pushed to apply the peer changes.

By the time the root cause (missing default route) was identified and fixed,
the keys had already been rotated.

## Impact

- The old peer config on the VPS (public key `QAwl8Yaq8Ncq/...`) was replaced.
  Any client still using the old key pair will be unable to connect.
- The `magellan - random` peer (`10.8.0.6`) was temporarily lost from the VPS
  `wg0.conf` during a live `sed` edit, but was restored by the bundle push.
- No data loss — the new keys work correctly with the current configuration.

## Rollback

If the new keys need to be reverted:

1. Restore `secrets.enc.yaml` seedbox-kot entry:
   ```yaml
   publicKey: QAwl8Yaq8Ncq/8YiBvos+muSaZI6kPM/7Vga/B90VHg=
   privateKey: oCkETDfU+KOBQvxLcuP/j4D9dRgRap9OAos4TSKI9U4=
   presharedKey: K12F6ebcnCXpGps09Ap086wavwl4VWGABEn+z1/x0BY=
   ```
2. Restore `peers.nix` seedbox-kot public key to `QAwl8Yaq8Ncq/...`.
3. Restore gluetun env file on seedbox-kot to the original keys.
4. Rebuild and push the VPS bundle.
5. Restart gluetun on seedbox-kot.

## Prevention

- Before rotating WireGuard keys, verify that the tunnel failure is actually
  caused by a key mismatch. Check with `wg show` on the VPS:
  - No handshake at all → network/routing issue, not keys
  - Handshake present but no data transfer → possible key mismatch
  - Handshake + data transfer → tunnel works, issue is elsewhere
- Always verify basic network connectivity (`ping`, `ip route`) on the peer
  host before investigating WireGuard-specific issues.
