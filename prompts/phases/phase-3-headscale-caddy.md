# Phase 3: Headscale and Caddy Reverse Proxy on VPS

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- VPS: 2 vCPU, 2GB RAM - resource constrained
- Headscale for user devices, WireGuard for site-to-site
- Caddy + Authelia preferred over Authentik (RAM constraints)
- Public services: jellyfin, filebrowser, status, rustdesk
- Admin services: VPN-only or SSO-protected

## This Phase Only Implements:

### Objective
Add Headscale (WireGuard control plane) and Caddy reverse proxy to VPS.

### Tasks

1. **Headscale implementation**
   - `modules/networking/headscale.nix` - Convert from skeleton
   - Server configuration for VPS
   - Client configuration for user devices
   - MagicDNS setup
   - ACL structure (skeleton with examples)
   - Documentation: `docs/implementation/vps-headscale.md`

2. **Caddy reverse proxy implementation**
   - `modules/services/caddy.nix` - Convert from skeleton
   - Basic reverse proxy config
   - TLS automation via Caddy
   - Upstream service definitions
   - Documentation: `docs/implementation/vps-caddy.md`

3. **Authelia skeleton (proper setup)**
   - `modules/services/authelia.nix` - Convert from skeleton
   - Basic Authelia config structure
   - Caddy integration for SSO
   - Placeholder for users/2FA (no real secrets)
   - Documentation notes in vps-caddy.md

4. **Update VPS bundle to include new services**
   - Integrate Headscale into current Ubuntu deployment
   - Add Caddy as reverse proxy layer
   - Preserve existing WireGuard/WGDashboard/RustDesk/Nginx
   - Migration path: Nginx → Caddy (documented)

5. **Service exposure documentation**
   - Update `docs/security-model.md` with actual exposure matrix
   - Which services go behind Caddy
   - Which remain VPN-only
   - Authelia protection paths

### Constraints for This Phase
- Do NOT remove existing WireGuard/WGDashboard
- Headscale and WireGuard coexist (different purposes)
- Caddy alongside Nginx initially (migration path documented)
- No real Authelia user passwords or secrets
- RAM-conscious configuration (2GB limit)

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- Headscale config valid (can be parsed by headscale) ✅
- Caddyfile valid syntax ✅
- Existing services still functional ✅
- Documentation explains Headscale vs WireGuard split ✅

### Questions to Ask Before Starting
1. What domain names should be used for Headscale/Caddy configs?
2. Should WGDashboard move behind Authelia in this phase or later?
3. Any specific TLS certificate preferences (Let's Encrypt default OK?)?
4. Headscale CLI token should remain as TODO placeholder?
