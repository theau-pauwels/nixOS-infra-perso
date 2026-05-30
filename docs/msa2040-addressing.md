# HPE MSA2040 Addressing

## Scope

This document records the management addressing for the HPE MSA2040 storage array
installed at the Kot site.

The MSA2040 is connected to the ProLiant DL360 Gen9 through SAS. The IP
addresses below are only for management access to the MSA controllers. They are
not used for the SAS storage data path.

## Network Placement

The MSA2040 management interfaces belong in the Kot management VLAN.

| Field | Value |
| --- | --- |
| Site | Kot |
| Site number | `224` |
| VLAN | `60` |
| Purpose | Management |
| Subnet | `10.224.60.0/24` |
| Gateway | `10.224.60.1` |

This follows the repository addressing convention:

```text
10.<site>.<vlan>.0/24
```

## Assigned Addresses

| Device / Interface | Address | Notes |
| --- | --- | --- |
| MSA2040 controller A management | `10.224.60.21/24` | Primary controller management IP |
| MSA2040 controller B management | `10.224.60.22/24` | Secondary controller management IP |
| Default gateway | `10.224.60.1` | Kot management gateway / firewall |
| DNS | `10.224.60.1` or unset | DNS is optional for local-only management |

## Related Management Addresses

These addresses are reserved as a coherent management block for the DL360/MSA
setup.

| Device / Interface | Address | Notes |
| --- | --- | --- |
| Proxmox host management | `10.224.60.10/24` | Host management interface |
| DL360 Gen9 iLO | `10.224.60.11/24` | Out-of-band management |
| MSA2040 controller A | `10.224.60.21/24` | Storage array management |
| MSA2040 controller B | `10.224.60.22/24` | Storage array management |

## Cabling and Data Path Notes

- The MSA2040 management Ethernet ports should be connected to an access port or
  tagged path that reaches VLAN `60`.
- The SAS cables between the DL360 HBA and the MSA2040 controllers carry storage
  traffic directly and do not use IP addressing.
- With two SAS paths/controllers, Linux/Proxmox may see the same MSA volumes more
  than once until multipath is configured.
- The MSA controller management addresses should be static, not DHCP.

## Access Policy

The MSA2040 web interface is an administrative surface. It should only be
reachable from trusted administration devices or trusted management networks. It
should not be exposed publicly and should not be placed in the regular servers,
LAN clients, guests, IoT, or cameras VLANs.
