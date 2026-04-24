# Addition: future personal SSH access management inspired by `mag-Ansible`

This Markdown content is meant to replace the previous `mag-Ansible` addition.

Important correction:

- `mag-Ansible` is **not** part of the personal Nix infrastructure yet.
- It belongs to another infrastructure/project.
- It should only be used as an architectural reference.
- The personal infra should prepare for a **similar future SSH access management system**, but should not integrate, vendor, clone, or assume the existing `mag-Ansible` project.

---

## Add under `## Infrastructure context`

```markdown
## Future feature: personal SSH access management

I have another project, outside this repository, that can be used as architectural inspiration:

```txt
https://github.com/Cercle-Magellan-FPMs/mag-Ansible
```

That project is not part of this personal infrastructure yet.

Do not integrate it directly.
Do not vendor it.
Do not clone it into this repository.
Do not assume it is already deployed.

Instead, design the personal Nix infrastructure so it can later support a similar SSH access management system.

The future personal SSH access management system should provide:

- short-lived OpenSSH certificates
- no private key escrow
- user-owned SSH private keys
- centralized approval of access
- access grants per user, per host, and optionally per host group
- automatic expiry of access
- audit logs for certificate issuance, access changes, deployments, and SSH logins
- a web UI exposed only through VPN and/or SSO
- deployment of SSH CA trust to managed hosts
- deployment of allowed principals to managed hosts
- optional login event reporting from managed hosts
- clear separation between personal admin access and delegated temporary access

This feature is only a future design target for now.

The repository should prepare:

- documentation
- network placement
- security model
- secret-management expectations
- backup expectations
- monitoring expectations
- optional disabled-by-default Nix module skeletons

It should not implement a full SSH access platform yet unless explicitly requested.
```

---

## Add under `## Design requirements`

```markdown
### Future SSH access management

Prepare the infrastructure for a future personal SSH access management service inspired by `mag-Ansible`, but do not integrate the existing `mag-Ansible` project directly.

The future service should eventually support:

- OpenSSH user CA
- short-lived SSH certificates
- per-user access grants
- per-host and per-host-group authorization
- access expiry
- audit logs
- deployment of trusted CA and authorized principals to hosts
- optional SSH session logging
- VPN-only or SSO-protected web access

The design must keep two SSH models separate:

1. Personal break-glass/admin access:
   - declared directly in Nix
   - stable admin SSH keys
   - used only by trusted administrators

2. Delegated/temporary access:
   - future certificate-based access platform
   - short-lived certificates
   - scoped access to selected machines
   - intended for temporary or non-root access

For now, only prepare documentation and optional skeletons.

Do not:

- add real CA keys
- add private keys
- add admin passwords
- expose any future SSH management UI publicly
- assume the service already exists
- import the `mag-Ansible` codebase into this repository
```

---

## Add to `## Concrete tasks`

```markdown
18. Add documentation for a future personal SSH access management feature inspired by `mag-Ansible`:
   - `docs/implementation/future-personal-ssh-access-platform.md`

19. This documentation must explain:
   - that the feature is not implemented yet
   - that `mag-Ansible` is only an external reference/inspiration
   - the target use case
   - how it differs from direct personal admin SSH keys
   - expected trust model
   - expected OpenSSH CA model
   - expected network placement
   - expected SSO/VPN exposure
   - expected secrets
   - expected backup requirements
   - expected monitoring requirements
   - possible future NixOS module design
   - risks and TODOs

20. Optionally add a disabled-by-default skeleton module:
   - `modules/services/personal-ssh-access-platform.nix`

The module must not implement real access management yet.
It must not contain real secrets, CA keys, private keys, or passwords.
```

---

## Add to the module list

Use this:

```txt
modules/services/personal-ssh-access-platform.nix
```

Do not use this:

```txt
modules/services/magellan-ssh-platform.nix
```

Reason: this is for the personal infrastructure, not Magellan’s production/access platform.

---

## Add to the implementation docs list

Use this:

```txt
docs/implementation/future-personal-ssh-access-platform.md
```

Do not use this:

```txt
docs/implementation/future-magellan-ssh-platform.md
```

---

## Add to `## Expected final output`

```markdown
9. Explain how the future personal SSH access management concept was accounted for.
10. Explain that `mag-Ansible` was used only as an external architectural reference, not as a dependency.
11. List any docs or skeleton modules created for this future SSH access management feature.
```

---

## Add to the security model

```markdown
SSH access must be split into two models:

1. Personal infra administration:
   - direct SSH keys declared through Nix
   - stable admin keys
   - break-glass access
   - used only by trusted administrators

2. Future delegated/temporary access:
   - inspired by `mag-Ansible`
   - based on short-lived OpenSSH certificates
   - scoped to selected hosts or host groups
   - intended for temporary, auditable, non-permanent access
   - not implemented yet

These two models must not be mixed accidentally.
```

---

## Where to paste these sections

```txt
## Infrastructure context
  └── Future feature: personal SSH access management

## Design requirements
  ├── Security
  ├── Future SSH access management
  └── Deployment

## Concrete tasks
  └── add tasks 18-20

## Expected final output
  └── add points 9-11

Module list:
  └── add modules/services/personal-ssh-access-platform.nix

Implementation docs list:
  └── add docs/implementation/future-personal-ssh-access-platform.md
```
