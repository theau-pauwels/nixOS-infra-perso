# Future Personal SSH Access Platform

## Status

This feature is not implemented yet.

This document captures the target design expectations so the infrastructure can
be shaped around them. No SSH CA private key, user database, web UI, approval
workflow, or certificate issuing service is added in the current phase.

## External Reference

The external `mag-Ansible` project can be used as architectural inspiration for
short-lived SSH access management.

Rules:

- do not vendor `mag-Ansible`
- do not clone it into this repository
- do not assume it is already deployed
- do not integrate its code directly

## Problem

Personal infrastructure needs two separate SSH access modes:

- stable break-glass admin access for trusted personal administration
- temporary delegated access for other users or limited use cases

Long-lived shared keys do not give enough expiry, scoping, or auditability for
delegated access.

## Target Use Case

The future platform should allow an approved user to bring their own SSH public
key and receive a short-lived OpenSSH certificate scoped to selected hosts and
principals.

Expected properties:

- no private key escrow
- user-owned private keys
- short certificate lifetime
- per-user access grants
- per-host and optional host-group authorization
- automatic expiry
- audit logs for certificate issuance and access changes
- optional login event reporting from managed hosts

## Trust Model

Trusted components:

- SSH user CA private key, stored outside Git and outside the Nix store
- approval and issuance service
- admin identities that can approve grants
- managed hosts that trust the CA public key

Untrusted or less trusted components:

- user devices
- delegated user public keys until approved
- public networks
- application logs that may be copied or aggregated

The SSH CA private key is the highest-value secret and must be backed up,
monitored, and rotated with a documented process.

## OpenSSH CA Design Expectations

Managed hosts should eventually receive:

- trusted user CA public key
- allowed principals file or command
- sshd configuration enabling certificate authentication
- explicit separation between admin principals and delegated principals

The platform should issue certificates with:

- short validity windows
- principal list matching approved access
- source identity in certificate key id
- clear serial or audit identifier
- conservative critical options and extensions

## Network Placement

The web UI and API should not be directly public by default.

Preferred placement:

```text
admin/user device
  |
  | VPN and/or SSO
  v
VPS or internal service endpoint
  |
  | issues short-lived cert
  v
managed hosts over SSH
```

Acceptable exposure:

- VPN-only
- SSO-protected behind reverse proxy, preferably still VPN-restricted

Avoid:

- public unauthenticated UI
- public admin API
- direct exposure of signing service without SSO and rate limits

## Secrets Requirements

Never commit:

- SSH CA private key
- web session secrets
- database passwords
- OIDC client secrets
- signing service tokens

Future secret storage should use SOPS or another documented encrypted secret
workflow. The CA private key should not be written to the Nix store.

## Backup Requirements

Back up:

- encrypted CA private key backup
- CA public key
- grant database
- audit logs
- service configuration

Test restore before relying on the system for delegated access.

## Monitoring Requirements

Monitor:

- certificate issuance failures
- suspicious issuance volume
- failed admin logins
- CA key file permission drift
- audit log ingestion failures
- service availability

Alert on:

- CA key missing or unreadable
- issuance outside expected policy
- repeated failed login attempts to the platform

## Future Nix Module Skeleton

The disabled-by-default module should eventually expose options for:

- `enable`
- package or container image
- listen address and port
- trusted reverse proxy settings
- SSO/OIDC configuration
- CA public key deployment
- CA private key file path
- database path or DSN secret file
- audit log destination
- host groups and principal policy

The skeleton module added in phase 1 does not implement the service. It exists
only to reserve a clear integration shape.

## Risks

- CA private key compromise allows unauthorized SSH certificate issuance.
- Incorrect principals can grant wider access than intended.
- Losing the CA private key backup can break delegated access recovery.
- Public exposure of the UI increases brute-force and application risk.
- Confusing personal admin access with delegated access can remove break-glass
  reliability.

## TODO

- Choose implementation approach.
- Choose database and audit storage.
- Define host group model.
- Define certificate lifetimes.
- Define CA rotation process.
- Define backup and restore test.
- Define NixOS host-side SSH CA trust module.
