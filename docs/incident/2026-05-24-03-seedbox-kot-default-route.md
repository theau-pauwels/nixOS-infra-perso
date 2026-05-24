# Failure: seedbox-kot missing default route after static IP assignment

**Incident:** [2026-05-24 Kot Power Loss Recovery](./2026-05-24-power-loss-kot-recovery.md)

## Symptom

`qbit.theau.net` returned 502/504 Gateway Timeout. Gluetun's WireGuard tunnel
never established. From the VPS, `wg show wg0` showed the seedbox-kot peer with
no handshake:

```
peer: pTPHLcyx2dh2gykKjljcOsbuNIoUfZlOHKAvV5S7GmM=
  preshared key: (hidden)
  allowed ips: 10.8.0.22/32
  # No endpoint, no handshake, no transfer
```

On seedbox-kot:

```
$ ping 8.8.8.8
ping: connect: Network is unreachable

$ ping 10.1.10.118       # jellyfin-kot, same subnet
PING 10.1.10.118: 64 bytes from 10.1.10.118 ... OK

$ ip route
10.1.10.0/24 dev ens18 proto kernel scope link src 10.1.10.123
10.88.0.0/16 dev podman0 proto kernel scope link src 10.88.0.1
# No default route!
```

The host could reach other hosts on the same subnet but had no route to the
internet. Gluetun's WireGuard handshake packets to `82.165.20.195:51820` never
left the host, so the tunnel never established.

## Cause

Before the outage, seedbox-kot obtained its IP via DHCP, which also provided
the default route (`via 10.1.10.1`). During recovery, a static IP
`10.1.10.123/24` was added to the NixOS config and deployed with
`nixos-rebuild switch`:

```nix
networking.networkmanager.enable = true;
networking.interfaces.ens18.ipv4.addresses = [
  { address = "10.1.10.123"; prefixLength = 24; }
];
# No default gateway configured!
```

The static IP assignment overrode the NetworkManager DHCP configuration,
which had been providing the default route. With only the static address
and no explicit `networking.defaultGateway`, the host had no path to the
internet.

The same issue affected storage-kot, but it had WireGuard via `wg-quick`
on the host (which uses a persistent keepalive and had already established
its handshake before the route was lost). Storage-kot's connectivity was
degraded but not completely broken.

## Fix

**Immediate (live):**
```bash
sudo ip route add default via 10.1.10.1 dev ens18
```

**Permanent:** Added to both seedbox-kot and storage-kot NixOS configs:
```nix
networking.defaultGateway = {
  address = "10.1.10.1";
  interface = "ens18";
};
```

## Prevention

- Always pair `networking.interfaces.*.ipv4.addresses` with
  `networking.defaultGateway` when the host needs internet access.
- Consider adding a post-deployment connectivity check to `nixos-rebuild`
  hooks (e.g., `ping -c 1 8.8.8.8`).
- For DHCP-based hosts, prefer letting NetworkManager manage the interface
  fully rather than mixing static IP assignments with NM.

## Affected services

| Service | Impact |
|---|---|
| `qbit.theau.net` | 502/504 — gluetun WireGuard tunnel dead |
| seedbox-kot internet access | None — host isolated from WAN |
| seedbox-kot CIFS mount | OK — `10.1.10.124` on same subnet |
| seedbox-kot DNS | None — no route to DNS servers |
