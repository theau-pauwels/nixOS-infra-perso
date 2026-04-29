# Service: Self-Hosted Git Platform

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- Centralize personal projects and documentation.
- Prefer self-hosted, reproducible services.
- Protect administrative interfaces.

## This Service Implements

### Objective
Deploy a self-hosted Git platform (e.g., Gitea or Forgejo) to manage, version, and document personal projects directly on the infrastructure.

### Tasks

1. **Choose implementation**
   - Gitea or Forgejo (preferred lightweight solutions).

2. **Create service module**
   - `modules/services/git.nix`
   - Disabled by default.
   - Options:
     - domain
     - SSH and HTTP ports
     - data directory
     - backup configuration

3. **Authentication and security**
   - Integrate with Authelia optionally.
   - Disable public registration by default.
   - Admin user placeholder only.

4. **Reverse proxy integration**
   - Integrate with Caddy.
   - Provide HTTPS endpoints.

5. **Backup strategy**
   - Document repository backups (Restic).
   - Include config and database.

6. **Documentation**
   - `docs/implementation/git-selfhosted.md`

## Constraints
- No public open registration.
- No real secrets.

## Acceptance Criteria
- Builds succeed.
- Module valid and disabled by default.

## Questions
1. Gitea or Forgejo?
2. Public or VPN-only access?
