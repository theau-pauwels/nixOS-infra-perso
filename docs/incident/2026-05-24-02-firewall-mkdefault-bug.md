# Failure: Firewall `mkDefault` silently drops custom ports

**Incident:** [2026-05-24 Kot Power Loss Recovery](./2026-05-24-power-loss-kot-recovery.md)

**Affected hosts:** All hosts using `personalInfra.networking.firewall` (storage-kot,
seedbox-kot, jellyfin-kot, nas-kot, mom-edge, dad-edge).

## Symptom

`file.theau.net` returned 504 Gateway Timeout. The VPS nginx reverse proxy
could not reach `10.8.0.23:8082` (storage-kot filebrowser). Running iptables
on storage-kot showed port 8082 was missing despite being declared in the
NixOS config:

```
# iptables -L nixos-fw -n
...
tcp dpt:22     # from SSH module
tcp dpt:139    # from Samba module
tcp dpt:445    # from Samba module
               # 8082 MISSING
```

But the Nix evaluation of `personalInfra.networking.firewall.allowedTCPPorts`
correctly returned `[22, 139, 445, 8082]`. The port was configured but never
reached the running firewall.

## Cause

`modules/networking/firewall.nix` used `lib.mkDefault` to map the custom module
ports to `networking.firewall.allowedTCPPorts`:

```nix
networking.firewall.allowedTCPPorts = lib.mkDefault cfg.allowedTCPPorts;
```

In the NixOS module system, `lib.mkDefault` has priority 1000. NixOS service
modules (SSH, Samba) add their ports at **default priority** (100, no wrapper).
When both priorities are present, **only the higher priority wins** — the
`mkDefault` values are silently discarded:

| Module | Priority | Value | Result |
|---|---|---|---|
| `services.openssh` | 100 (default) | `[22]` | Used |
| `services.samba` | 100 (default) | `[139, 445]` | Used |
| `personalInfra.firewall` | 1000 (mkDefault) | `[22, 139, 445, 8082]` | **Discarded** |
| **Final** | | | `[22, 139, 445]` |

This is specific to list-type options. For scalar options, `mkDefault` values
merge correctly as fallbacks. For lists, the highest-priority definition wins
entirely, and lower-priority definitions are dropped.

Every host with custom ports beyond what NixOS services required was affected,
but the bug was invisible until a port was audited.

## Fix

Removed `lib.mkDefault` in `modules/networking/firewall.nix`:

```diff
-networking.firewall.allowedTCPPorts = lib.mkDefault cfg.allowedTCPPorts;
-networking.firewall.allowedUDPPorts = lib.mkDefault cfg.allowedUDPPorts;
+networking.firewall.allowedTCPPorts = cfg.allowedTCPPorts;
+networking.firewall.allowedUDPPorts = cfg.allowedUDPPorts;
```

At equal priority (100), all definitions concatenate as expected:

| Module | Value |
|---|---|
| `services.openssh` | `[22]` |
| `services.samba` | `[139, 445]` |
| `personalInfra.firewall` | `[22, 139, 445, 8082]` |
| **Final (merged)** | `[22, 22, 139, 445, 139, 445, 8082]` → deduplicated to `[22, 139, 445, 8082]` |

## Affected services

| Host | Ports that were missing |
|---|---|
| storage-kot | 8082 (filebrowser) |
| seedbox-kot | 8080 (qBittorrent web UI, mitigated by seedbox module) |
| jellyfin-kot | 8096 (Jellyfin, mitigated by `services.jellyfin.openFirewall`) |
