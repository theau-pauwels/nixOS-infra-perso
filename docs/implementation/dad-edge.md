# Dad Edge

## Status

Phase 6 adds `dad-edge` as a NixOS target for the Dad site. The target is a
minimal site gateway and monitoring agent for a Starlink connection behind
CGNAT.

No live infrastructure deployment is performed by this phase.

## CGNAT Design

Dad has no public IPv4 address because the site uses Starlink CGNAT. The edge
therefore cannot receive inbound VPN sessions or rely on router port forwards.

The selected design is Option B from the phase prompt: a WireGuard site tunnel
initiated outbound from `dad-edge` to the VPS hub, with
`persistentKeepalive = 25`. This keeps the NAT binding fresh while preserving a
separate infrastructure tunnel instead of coupling the site route to a user VPN
or Headscale device identity.

Alternatives considered:

- Headscale device mode: simpler enrollment, but ties site routing to the user
  device VPN model.
- Hybrid Headscale and WireGuard: flexible, but too complex for a lightweight
  edge with no local services.

## Network Model

Dad site:

- LAN: `10.7.10.0/24`
- default gateway: `10.7.10.1`
- edge LAN address: `10.7.10.2/24`
- WireGuard interface: `wg-dad`
- tunnel address: `10.8.0.40/32`
- VPS endpoint: `theau-vps.duckdns.org:51820`

The Dad edge advertises these routes to the VPS peer:

```text
10.8.0.40/32
10.7.10.0/24
```

The VPS peer entry in `hosts/theau-vps/peers.nix` is present as a disabled
skeleton. It must stay disabled until the real Dad edge public key is known and
the site is ready to route traffic.

## Host Configuration

The NixOS host lives in:

```text
hosts/dad-edge/default.nix
```

The default config assumes small generic hardware or a VM-like install:

- LAN interface: `eth0`
- boot disk: `/dev/vda`
- root filesystem label: `nixos`

Before deployment, replace those identifiers with the real interface and disk
names for the chosen device. On Raspberry Pi or bare metal, prefer stable disk
identifiers instead of mutable kernel names.

The host enables:

- SSH for admin access
- bounded system logging
- WireGuard site tunnel
- IPv4 forwarding for the Dad LAN route
- Prometheus node exporter on `10.8.0.40:9100`

No public inbound service is required. The WireGuard tunnel is client-side and
uses outbound UDP only.

## Hardware Options

Small x86 mini PC:

- preferred for easiest NixOS install and reliable storage
- keep `x86_64-linux`
- update interface and boot disk identifiers after install

Raspberry Pi 4 or 5:

- acceptable for a low-power edge
- use a proper NixOS image and reliable power supply
- keep the root filesystem on quality SSD storage when possible
- adjust the flake system if the final build target is ARM

OpenWrt router:

- viable if replacing or supplementing the Archer C6 with a WireGuard-capable
  OpenWrt device
- this NixOS host config is not directly deployable to OpenWrt
- mirror the same tunnel values: local `10.8.0.40/32`, endpoint
  `theau-vps.duckdns.org:51820`, `PersistentKeepalive = 25`, and routed LAN
  `10.7.10.0/24`

## Secrets

Encrypted source:

```text
hosts/dad-edge/secrets.enc.yaml
```

Local cleartext source, if needed, must stay under:

```text
local-secrets/
```

Required secret:

- `wireguard/site-private-key`

The committed encrypted file contains placeholder material only. Replace it
with the real Dad WireGuard private key before production activation.

## Activation Notes

1. install NixOS on the selected edge hardware
2. replace interface and disk identifiers in `hosts/dad-edge/default.nix`
3. create the real WireGuard private key under `local-secrets/`
4. encrypt it to `hosts/dad-edge/secrets.enc.yaml`
5. put the real Dad public key in `hosts/theau-vps/peers.nix`
6. enable the Dad peer on the VPS only when the edge is ready
7. deploy the edge and confirm `wg show` has a recent handshake

Starlink-specific checks:

- no router port forwarding is needed
- Starlink router mode or bypass mode both work if outbound UDP reaches the VPS
- if handshakes stop, check `PersistentKeepalive`, endpoint DNS resolution, and
  local firewall policy
- if large transfers stall, test a lower WireGuard MTU on the edge

## Validation

Build the Dad target:

```bash
nix build .#dad-edge
```

Build the preserved VPS bundle:

```bash
nix build .#theau-vps-bundle
```

## Rollback

Before activation, rollback is to keep Dad unchanged and leave the VPS peer
skeleton disabled.

After activation:

1. disable `personalInfra.networking.wireguardSite.enable`
2. rebuild or boot a previous NixOS generation on the Dad edge
3. disable or remove the Dad peer from the active VPS WireGuard peer list

The committed VPS peer skeleton is disabled and does not affect production.
