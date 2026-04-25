# Phase 0: Preserve Current VPS Bundle Deployment

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Current deployment: Ubuntu 24.04 VPS with Nix-built bundle
- Services: WireGuard, WGDashboard, RustDesk, Nginx, nftables, iperf3, certbot
- Key files: `flake.nix`, `hosts/theau-vps/`, `packages/bundle/`, `deploy/*.sh`

## This Phase Only Implements:

### Objective
Verify and document the current working deployment before any changes.

### Tasks
1. **Inspect current repo structure**
   - List all files and their purposes
   - Document current flake outputs
   - Map service configurations to source files

2. **Document current VPS bundle architecture**
   Create `docs/implementation/current-vps-bundle.md` explaining:
   - How the bundle is built
   - How deployment works
   - Current services and their configs
   - Secrets management (age/SOPS)
   - Activation scripts behavior

3. **Verify build pipeline**
   Run and confirm these commands work:
   ```bash
   nix flake check
   nix build .#theau-vps-bundle
   ```

4. **Document deployment workflow**
   Create notes on:
   - Current deploy script mechanics
   - What gets transferred to VPS
   - How activation works on Ubuntu target

### Constraints for This Phase
- NO code changes allowed
- Purely documentation and verification
- If build fails, document exact error and stop

### Acceptance Criteria
- `nix build .#theau-vps-bundle` succeeds ✅
- `docs/implementation/current-vps-bundle.md` exists ✅
- Repo structure documented in notes ✅
- Build output verified (bundle contains expected files) ✅

### Questions to Ask Before Starting
1. Is the current VPS deployment active and must remain operational?
2. Are there any known issues with the current build I should be aware of?
3. Should I document the exact deploy command you use in production?
