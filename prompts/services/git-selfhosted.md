# Service: Self-Hosted Git Platform

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- Centralize personal projects and infrastructure code.
- Prefer lightweight, maintainable services.
- Administrative interfaces must be protected (SSO or VPN).

## This Service Implements

### Objective
Deploy a self-hosted Git platform (Gitea or Forgejo) to centralize, version, and document personal projects.

### Target Use Cases
- Host personal Git repositories.
- Store infrastructure-as-code (this repo).
- Provide web UI for browsing, issues, and documentation.
- Optional CI/CD hooks later.

### Tasks

1. **Choose implementation**
   - Prefer Forgejo or Gitea (lightweight, low RAM).
   - Document rationale.

2. **Create service module**
   - `modules/services/git.nix`
   - Disabled by default.
   - Options:
     - domain (e.g., `git.theau.net`)
     - SSH port
     - HTTP(S) port
     - data directory
     - backup integration

3. **Host integration**
   - Decide placement:
     - VPS (public access), or
     - Kot (VPN-only)
   - Keep build working without enabling service.

4. **Authentication & security**
   - Disable public registration by default.
   - Admin user as placeholder only.
   - Optional Authelia SSO integration.
   - SSH access via keys only.

5. **Reverse proxy**
   - Integrate with Caddy.
   - HTTPS enabled automatically.
   - Optional Authelia protection for UI.

6. **Backup strategy**
   - Integrate with Restic:
     - repositories
     - database
     - config
   - Document restore procedure.

7. **Documentation**
   - `docs/implementation/git-selfhosted.md`
     - Architecture
     - Access model
     - Backup strategy
     - Migration notes

## Constraints
- No real credentials in repo.
- No open public registration.
- Must work without Internet for local usage (optional).
- Avoid high resource usage.

## Acceptance Criteria
- `modules/services/git.nix` valid and disabled by default.
- Builds succeed.
- Documentation complete.
- Backup strategy defined.

## Questions to Ask Before Starting
1. Forgejo or Gitea?
2. Public access or VPN-only?
3. Should repos be mirrored from GitHub?
4. Expected number of users?