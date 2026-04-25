# Phase 7: Optional VPS Reinstall as Native NixOS

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- VPS: IONOS, 2 vCPU, 2GB RAM, 80GB NVMe
- Current: Ubuntu 24.04 with Nix bundle deployment
- Target: Native NixOS for full declarative control

## This Phase Only Implements:

### Objective
Optionally migrate VPS from Ubuntu + bundle to native NixOS.

### Important Note
This phase is OPTIONAL and should only be done when:
- All other phases are stable and tested
- You have a backup/rollback plan for VPS
- You can afford potential downtime during migration
- Other sites (Kot, Mom, Dad) are functional

### Tasks

1. **Migration planning documentation**
   - `docs/migration/vps-to-nixos.md`
     - Pre-migration checklist
     - Data to backup before reinstall
     - DNS/SSL certificate preservation
     - Step-by-step migration procedure
     - Rollback plan (reinstall Ubuntu from snapshot)
     - Post-migration verification

2. **VPS native NixOS configuration**
   - `hosts/vps/default.nix` - Convert skeleton to full config
   - All services migrated:
     - WireGuard site-to-site hub
     - Headscale control plane
     - Caddy reverse proxy
     - Authelia SSO
     - RustDesk server
     - iperf3
     - Monitoring (Uptime Kuma or similar)
   - Boot loader configuration for IONOS
   - Disk layout for 80GB NVMe

3. **Service migration modules**
   - Ensure all modules work on native NixOS:
     - `modules/networking/headscale.nix`
     - `modules/networking/wireguard-site.nix`
     - `modules/services/caddy.nix`
     - `modules/services/authelia.nix`
     - `modules/services/rustdesk.nix`

4. **Deployment transition**
   - Set up `deploy-rs` for VPS deployment
   - Or document SSH-based deployment
   - Phase out bundle deployment (keep as emergency rollback)

5. **Verification and testing**
   - All services functional after migration
   - Site-to-site tunnels established
   - Reverse proxy working
   - SSL certificates valid
   - Monitoring operational

### Constraints for This Phase
- Do NOT automate VPS reinstall (manual with documented procedure)
- Keep bundle deployment as emergency rollback option
- IONOS snapshot before any changes
- Test in staging if possible first

### Acceptance Criteria
- `nix build .#vps` produces valid NixOS image ✅
- All services migrated and functional ✅
- Site-to-site VPN working ✅
- Reverse proxy serving all public services ✅
- Rollback procedure documented and tested ✅
- Bundle deployment preserved as emergency option ✅

### Questions to Ask Before Starting
1. **Critical**: Are you ready to potentially reinstall your VPS?
2. Do you have IONOS snapshot capability enabled?
3. Any maintenance window constraints (must avoid certain hours/days)?
4. Should bundle deployment be kept indefinitely or can it be removed after X months?
5. Deploy-rs preferred or document SSH-based deployment?

### Warning
⚠️ **This is the most risky phase.** The VPS is the central hub for all infrastructure. Any mistake could take down:
- All site-to-site VPN tunnels
- Public service access
- Headscale/VPN for user devices
- Reverse proxy for all services

**Recommendation**: Only proceed when:
- You have time to troubleshoot immediately
- IONOS snapshot is taken
- Rollback procedure is clear
- Other sites don't critically depend on VPS being up 24/7 yet
