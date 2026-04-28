# Mom NVR

## Status

Phase 5 adds a disabled Frigate module for the Mom site. No cameras, credentials,
or live NVR service are enabled.

## Design

Frigate is optional because the Mom edge hardware is small:

- 8 GB RAM
- 256 GB SSD
- VDSL upload constraints

The default storage path is:

```text
/srv/frigate
```

The module uses conservative retention defaults when enabled:

- recordings: 3 days
- snapshots: 3 days
- MQTT disabled by default

## Camera Configuration

Camera definitions are placeholders under:

```nix
personalInfra.services.frigate.cameras
```

Do not commit camera passwords, RTSP credentials, or live URLs containing
credentials. Store them through the secrets workflow and inject them at runtime.

## Network Exposure

Frigate must remain LAN/VPN-only. Do not expose the NVR UI directly to the public
internet.

## Future Work

Before enabling Frigate:

1. choose camera models
2. document RTSP paths without credentials
3. decide whether storage stays on local SSD or moves to NAS over VPN
4. validate CPU load and memory pressure
5. add monitoring checks for disk usage and Frigate process health
