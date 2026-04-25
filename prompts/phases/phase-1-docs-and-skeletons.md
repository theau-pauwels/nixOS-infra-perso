# Phase 1: Documentation and Skeleton Modules

## Reference Context (from MASTER.md)
See `../MASTER.md` for full infrastructure context.

**Relevant excerpts:**
- Sites: VPS, Kot, Mom, Dad (see MASTER.md §Infrastructure context)
- Addressing: 10.<site>.<vlan>.0/24 (see MASTER.md §Networking)
- Security model requirements (see MASTER.md §Security)

## This Phase Only Implements:

### Documentation Files
Create the following documentation:

1. **`docs/architecture.md`** - Target architecture overview
   - Current state vs target state
   - Site roles and responsibilities
   - Data flow diagrams (text-based)
   - Technology choices and rationale

2. **`docs/addressing.md`** - Site/VLAN/IP plan  
   - Site numbers: VPS=1, Dad=7, Mom=10, Kot=224
   - VLAN plan: 10=LAN, 20=servers, 30=IoT, 40=cameras, 50=guests, 60=mgmt
   - Future expansion notes
   - VPN subnet allocations

3. **`docs/security-model.md`** - Public vs admin exposure rules
   - Service exposure matrix (public/VPN-only/internal)
   - SSH access models (admin break-glass vs delegated)
   - Secrets management approach
   - Network security boundaries

4. **`docs/migration-plan.md`** - Phased migration steps
   - All 8 phases with entry/exit criteria
   - Rollback procedures per phase
   - Risk assessment per phase

5. **`docs/disaster-recovery.md`** - Backup/rollback principles
   - Backup strategies per site
   - Recovery time objectives
   - Config backup vs data backup separation

6. **`docs/implementation/future-personal-ssh-access-platform.md`**
   - Feature not implemented yet (clearly stated)
   - mag-Ansible as external reference only
   - Target use case and trust model
   - OpenSSH CA design expectations
   - Network placement, SSO/VPN exposure
   - Secrets, backup, monitoring requirements
   - Future Nix module skeleton design
   - Risks and TODOs

### Skeleton Modules (valid Nix, no real secrets)
Create these skeleton modules with proper structure:

**Common modules:**
- `modules/common/base.nix` - System defaults, locale, time zone
- `modules/common/ssh.nix` - SSH server hardening, admin keys placeholder
- `modules/common/security.nix` - Firewall base, security options

**Networking modules:**
- `modules/networking/headscale.nix` - Headscale server/client skeleton
- `modules/networking/wireguard-site.nix` - Site-to-site tunnel skeleton
- `modules/networking/firewall.nix` - nftables module skeleton
- `modules/networking/vlans.nix` - VLAN configuration skeleton

**Services modules:**
- `modules/services/caddy.nix` - Caddy reverse proxy skeleton
- `modules/services/authelia.nix` - Authelia SSO skeleton
- `modules/services/rustdesk.nix` - RustDesk server skeleton
- `modules/services/seedbox.nix` - Jellyfin + qBittorrent skeleton
- `modules/services/personal-ssh-access-platform.nix` - Disabled-by-default skeleton

**Observability modules:**
- `modules/observability/exporters.nix` - Node exporter, etc.
- `modules/observability/monitoring-server.nix` - Prometheus/Grafana/Loki skeleton

**Backup modules:**
- `modules/backup/zfs.nix` - ZFS pool/dataset skeleton (SAFE - no auto-format)
- `modules/backup/restic.nix` - Restic backup skeleton

### Skeleton Module Requirements
Each skeleton must:
- Be valid Nix syntax (parse without errors)
- Have proper module structure (`{ config, lib, ... }: { options, config }`)
- Use `lib.mkDefault` or similar for non-intrusive defaults
- Contain clear TODO comments where real values needed
- NOT contain real secrets, keys, passwords
- NOT have destructive defaults (especially ZFS/disk modules)
- Include basic documentation in comments

### Host Skeletons (if safe to add)
Create minimal host skeletons:
- `hosts/vps/default.nix` - Future NixOS VPS
- `hosts/jellyfin-kot/default.nix` - Kot jellyfin VM
- `hosts/nas-kot/default.nix` - Kot NAS
- `hosts/mom-edge/default.nix` - Mom site gateway
- `hosts/dad-edge/default.nix` - Dad site gateway

### Update README.md
Add sections:
- Current state summary
- Target architecture link
- Warning: VPS bundle is legacy/production path
- Links to new docs
- Migration phase status

### Constraints for This Phase
- Do NOT modify existing VPS bundle code (`hosts/theau-vps/`, `packages/bundle/`)
- Skeletons must parse without errors
- No real secrets, keys, or passwords
- Clear TODO comments where values needed
- ZFS modules must be SAFE (no auto-format on load)

### Acceptance Criteria
- `nix build .#theau-vps-bundle` still succeeds ✅
- All new docs exist and are readable ✅
- All skeleton modules parse: `nix eval . --expr 'null'` ✅
- README updated with migration status ✅
- No modifications to legacy VPS bundle code ✅

### Questions to Ask Before Starting
1. Should addressing.md include future VLAN expansion notes beyond the 6 defined?
2. Any specific security compliance requirements for security-model.md?
3. For ZFS skeleton: should I use `zfs.pool.options` only or also show dataset examples?
4. What admin SSH public key placeholder format do you prefer in ssh.nix?
