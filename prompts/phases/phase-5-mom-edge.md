# Phase 5: Mom Site Gateway

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Mom house: VDSL, public IP yes
- LAN: 10.10.10.0/24
- Hardware: BMAX B2 Pro mini PC, Proxmox, 8GB RAM, 256GB SSD
- Role: site-to-site VPN edge, NVR/camera services, monitoring agent
- 2 × TP-Link Deco M5 for WiFi

## This Phase Only Implements:

### Objective
Add Mom house as a VPN edge site with optional camera/NVR services.

### Tasks

1. **Mom-edge host configuration**
   - `hosts/mom-edge/default.nix` - Site gateway config
   - Proxmox guest or bare metal options (document both)
   - Network config for 10.10.x.x addressing

2. **Site-to-site WireGuard tunnel**
   - WireGuard client to VPS hub
   - Route Mom LAN (10.10.10.0/24) through tunnel
   - Persistent keepalive for NAT traversal
   - Integration with existing VPS WireGuard setup

3. **Optional NVR/Frigate module**
   - `modules/services/frigate.nix` - Skeleton for Frigate NVR
   - Camera configuration placeholders
   - Motion detection basics
   - Storage path to local SSD (or NAS over VPN later)
   - Documentation: `docs/implementation/mom-nvr.md`

4. **Monitoring agent**
   - Node exporter (from `modules/observability/exporters.nix`)
   - Blackbox exporter for uptime checks
   - Send metrics to Kot monitoring server

5. **Optional off-site backup target**
   - Restic repository for backups FROM other sites
   - NOT a primary backup location yet
   - Document capacity constraints (256GB SSD)

6. **Documentation**
   - `docs/implementation/mom-edge.md`
     - Site gateway architecture
     - WireGuard tunnel to VPS
     - Camera/NVR considerations
     - Monitoring integration
     - Hardware limitations and workarounds

### Constraints for This Phase
- Do NOT modify existing site configurations
- WireGuard peer added to VPS config (non-breaking)
- Frigate module disabled by default (optional service)
- Respect 8GB RAM constraint

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- `nix build .#mom-edge` produces valid tarball ✅
- WireGuard tunnel config valid ✅
- VPS WireGuard config includes Mom peer skeleton ✅
- Monitoring agent exports metrics ✅

### Questions to Ask Before Starting
1. Will Mom-edge run on bare metal or Proxmox VM?
2. Any cameras already purchased/planned for Frigate?
3. Should Mom site receive backups from other sites in this phase?
4. VDSL upload speed (affects backup/NVR feasibility)?
