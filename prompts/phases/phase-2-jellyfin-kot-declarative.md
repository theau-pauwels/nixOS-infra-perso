# Phase 2: Declarative Jellyfin-Kot Seedbox

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Kot site: Dell mini PC, Proxmox, i5-8500, 20GB RAM
- jellyfin_kot VM with /opt/seedbox (Jellyfin, qBittorrent, gluetun)
- 4TB HDD passthrough to VM

## This Phase Only Implements:

### Objective
Make the jellyfin_kot VM configuration declarative using Nix.

### Tasks

1. **Create jellyfin-kot host configuration**
   - `hosts/jellyfin-kot/default.nix` - Full host config
   - Hardware-specific settings (disk passthrough notes)
   - Proxmox guest agent setup

2. **Implement seedbox module properly**
   - `modules/services/seedbox.nix` - Convert from skeleton to real module
   - Jellyfin service configuration
   - qBittorrent service configuration  
   - gluetun WireGuard client for torrent privacy
   - Shared data directory structure

3. **Add seedbox-specific documentation**
   - `docs/implementation/jellyfin-kot-seedbox.md`
   - Context and design decisions
   - Deployment to Proxmox VM
   - Data directory migration notes
   - gluetun configuration for torrent exit nodes

4. **Update flake.nix**
   - Add `nixosConfigurations.jellyfin-kot` output
   - Ensure it doesn't break existing builds

### Constraints for This Phase
- Do NOT modify VPS bundle code
- Do NOT assume access to actual hardware yet
- Use TODO placeholders for hardware-specific values (disk sizes, NIC names)
- gluetun config should use sensible defaults with TODOs

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- `nix build .#jellyfin-kot` produces valid tarball ✅
- Seedbox module has real Jellyfin/qBittorrent configs ✅
- Documentation explains deployment to Proxmox VM ✅

### Questions to Ask Before Starting
1. What's the current jellyfin_kot VM OS (Ubuntu? NixOS already?)?
2. Are there specific torrent exit countries you want in gluetun config?
3. Should Jellyfin scan paths be configurable or hardcoded with TODOs?
