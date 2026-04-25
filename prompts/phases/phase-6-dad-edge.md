# Phase 6: Dad Site Gateway (Behind Starlink CGNAT)

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Dad house: Starlink with CGNAT, NO public IP
- LAN: 10.7.10.0/24
- Hardware: TP-Link Archer C6 + extender, no server yet
- Role: lightweight site-to-site VPN edge only
- Must work behind CGNAT - outbound connections only

## This Phase Only Implements:

### Objective
Add Dad house as a minimal VPN edge that works behind Starlink CGNAT.

### Technical Challenge
Dad cannot receive inbound connections due to CGNAT. Solution options:

**Option A: Headscale Device Mode**
- Dad runs as Headscale client device
- Outbound-only connection to VPS Headscale
- MagicDNS for easy naming
- Simplest but ties infra to user VPN

**Option B: WireGuard with Persistent Keepalive**
- Dad initiates outbound WG tunnel to VPS
- Persistent keepalive maintains NAT binding
- Separate from user device VPN
- More control, slightly more complex

**Option C: Hybrid Approach**
- Headscale for admin access
- WireGuard for site-to-site routing
- Best of both but most complex

### Tasks

1. **Choose and implement CGNAT solution**
   - Document chosen approach in `docs/implementation/dad-edge.md`
   - Implement selected option (recommend Option B for infra separation)

2. **Dad-edge host configuration**
   - `hosts/dad-edge/default.nix` - Minimal edge config
   - Designed for small hardware (Raspberry Pi? OpenWrt router?)
   - Outbound-only network design

3. **VPN client configuration**
   - If WireGuard: client config with persistent keepalive
   - If Headscale: device registration and config
   - Route Dad LAN (10.7.10.0/24) through tunnel

4. **VPS hub updates**
   - Add Dad peer to VPS WireGuard config
   - Route 10.7.10.0/24 through Dad peer
   - Update Headscale ACLs if using Headscale

5. **Lightweight deployment options**
   - Document deployment to:
     - Small x86 mini PC (if purchased)
     - Raspberry Pi 4/5
     - OpenWrt router (if replacing Archer C6)
   - Minimal resource footprint design

6. **Documentation**
   - `docs/implementation/dad-edge.md`
     - CGNAT challenge explanation
     - Chosen solution and rationale
     - Alternative options considered
     - Deployment hardware options
     - Troubleshooting CGNAT issues
     - Starlink-specific considerations

### Constraints for This Phase
- Do NOT modify existing site configurations (only add Dad peer)
- Must work with outbound-only connectivity
- Minimal resource usage (small hardware target)
- No inbound services hosted on Dad site

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- `nix build .#dad-edge` produces valid tarball ✅
- VPN config works behind CGNAT (outbound only) ✅
- VPS can route to Dad LAN through tunnel ✅
- Documentation explains CGNAT solution clearly ✅

### Questions to Ask Before Starting
1. **Critical**: Which approach do you prefer for CGNAT?
   - Option A: Headscale device mode (simplest)
   - Option B: WireGuard outbound (infra separation)
   - Option C: Hybrid both
2. Any hardware planned for Dad site or should I support multiple options?
3. Should Dad site have any local services or VPN-only?
4. Starlink in bypass mode or routing mode currently?
