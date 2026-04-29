# Addressing Plan

## Goals

The addressing plan gives each site a stable number and keeps room for VLANs,
VPN ranges, and future services. The preferred LAN convention is:

```text
10.<site>.<vlan>.0/24
```

## Site Numbers

| Site | Number | Notes |
| --- | ---: | --- |
| VPS | `1` | Public edge and control plane |
| Dad | `7` | Starlink CGNAT site |
| Mom | `10` | VDSL site |
| Kot | `224` | Primary compute and storage site |

## VLAN Numbers

| VLAN | Purpose | Example at Kot |
| ---: | --- | --- |
| `10` | LAN clients | `10.224.10.0/24` |
| `20` | Servers | `10.224.20.0/24` |
| `30` | IoT | `10.224.30.0/24` |
| `40` | Cameras | `10.224.40.0/24` |
| `50` | Guests | `10.224.50.0/24` |
| `60` | Management | `10.224.60.0/24` |

## Planned Site Subnets

### VPS

- LAN/control subnet: `10.1.10.0/24`
- server services: `10.1.20.0/24`
- management: `10.1.60.0/24`
- current WireGuard road-warrior subnet: `10.8.0.0/24`

The current `10.8.0.0/24` WireGuard subnet is production state and should not be
renumbered without a separate migration.

### Kot

- LAN: `10.224.10.0/24`
- servers: `10.224.20.0/24`
- IoT: `10.224.30.0/24`
- cameras: `10.224.40.0/24`
- guests: `10.224.50.0/24`
- management: `10.224.60.0/24`

### Mom

- LAN: `10.10.10.0/24`
- servers: `10.10.20.0/24`
- IoT: `10.10.30.0/24`
- cameras: `10.10.40.0/24`
- guests: `10.10.50.0/24`
- management: `10.10.60.0/24`

### Dad

- LAN: `10.7.10.0/24`
- servers: `10.7.20.0/24`
- IoT: `10.7.30.0/24`
- cameras: `10.7.40.0/24`
- guests: `10.7.50.0/24`
- management: `10.7.60.0/24`

## VPN Allocations

Current production:

- WireGuard road-warrior subnet: `10.8.0.0/24`
- VPS WireGuard address: `10.8.0.1/24`
- existing peers are declared in `hosts/theau-vps/peers.nix`
- Mom site edge skeleton: `10.8.0.30/32`
- Dad site edge skeleton: `10.8.0.40/32`

Future allocations should avoid overlapping the site/VLAN convention:

- mesh control or Tailscale-compatible overlay: `100.64.0.0/10` if using
  Headscale defaults
- site-to-site point-to-point links: allocate small `/31` or `/30` ranges from a
  dedicated block such as `10.255.0.0/16`
- service VIPs, if needed later: reserve from a documented range before use

## Expansion Notes

- Keep VLAN numbers consistent across sites even when a VLAN is not currently
  deployed at a site.
- Reserve VLANs `70-99` for future local needs.
- Reserve VLANs `100-199` for lab or temporary networks.
- Avoid using `192.168.0.0/16` in declarative site plans because consumer
  routers and guest networks commonly overlap it.
- Do not renumber production networks as part of unrelated service work.
