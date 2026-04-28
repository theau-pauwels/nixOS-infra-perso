# Absolute Rules for This Infrastructure Repository

These rules are mandatory for every change in this repository.

The repository manages personal infrastructure. A change can affect live network
access, VPN connectivity, SSH access, public services, secrets, backups, and
rollback paths. Treat every modification as an infrastructure change unless it
is explicitly documentation-only.

## Core Principles

- Preserve the current working VPS deployment workflow unless a phase explicitly
  replaces it with a documented migration path.
- Prefer incremental, reversible changes.
- Prefer declarative Nix code and explicit host data over ad hoc scripts.
- Keep implementation scope tied to the active phase or task.
- Do not delete existing files, services, secrets workflows, or deployment
  paths unless the replacement is implemented, documented, tested, and rollback
  is clear.
- Do not introduce secrets into the Nix store, Git history, logs, generated
  docs, or command output.
- Keep personal admin access and future delegated or certificate-based access as
  separate models.

## Documentation Rules

- Every meaningful implementation change must include or update implementation
  documentation.
- Documentation must explain:
  - context
  - why the component exists
  - what problem it solves
  - chosen design
  - alternatives considered, when relevant
  - deployment workflow
  - configuration model
  - operation and rollback notes
- For current implementation docs, use `docs/implementation/`.
- For phase execution notes, keep the relevant `prompts/phases/*.md` acceptance
  criteria in mind.
- Update `README.md` when an operator command, target path, service list, port,
  secret workflow, or rollback workflow changes.
- Update `docs/secrets.md` whenever secret shape, secret location, encryption
  flow, or local-only material changes.
- Do not document fake secrets, private keys, tokens, or live exported client
  configs.
- If a value is required but unknown or environment-specific, document it as a
  `TODO` placeholder and state where the real value must be provided.

## Code Rules

- Read the existing code and docs before changing behavior.
- Keep existing patterns unless there is a concrete reason to change them.
- Prefer small, reviewable changes.
- Keep host-specific data in host files such as `hosts/<host>/`.
- Keep reusable Nix logic in modules or packages, not embedded in unrelated
  host files.
- Avoid broad refactors during migration phases unless they are required for
  the active task.
- Do not vendor external projects into this repo unless explicitly requested.
- Do not integrate the external `mag-Ansible` project directly. It can only be
  used as architectural inspiration.
- Do not add cleartext private keys, passwords, API tokens, WireGuard private
  keys, SOPS age private keys, SSH CA private keys, or live exported configs.
- Do not write secrets into Nix derivations, generated store paths, logs, docs,
  examples, tests, or committed fixtures.
- Examples must use obviously fake placeholders.

## Validation Rules

- Run the narrowest relevant validation before considering a task complete.
- For Nix changes, run at least:

```bash
nix flake check
nix build .#theau-vps-bundle
```

- If `nix` is not in `PATH`, use the installed binary explicitly when available:

```bash
/nix/var/nix/profiles/default/bin/nix flake check
/nix/var/nix/profiles/default/bin/nix build .#theau-vps-bundle
```

- If a validation command fails, stop and document the exact command and error.
- Do not push to infrastructure after a failed local validation.
- Do not hide warnings that may affect future migration work.
- When the bundle is built, verify that the expected output exists and note the
  store path when relevant.

## Secrets Rules

- Tracked encrypted secrets currently live at
  `hosts/theau-vps/secrets.enc.yaml`.
- Cleartext secrets must remain ignored and local-only.
- Never commit:
  - `hosts/*/secrets.yaml`
  - `local-secrets/`
  - `~/.config/sops/age/keys.txt`
  - DuckDNS tokens
  - WireGuard private keys
  - WireGuard preshared keys
  - SSH private keys
  - SSH CA private keys
  - raw backup exports
- Public keys may be committed only when they are meant to be public inventory,
  such as `hosts/theau-vps/ssh-public-keys.json` or public WireGuard peer keys.
- Before any GitHub push, inspect the diff for accidental secret material.
- Before any infrastructure push, confirm that the deployment uses encrypted
  secrets and temporary decrypted files only.

## Infrastructure Push Rules

An infrastructure push means running a command that changes a live machine or a
public DNS/service state, including:

- `./deploy/push-generation.sh`
- `./deploy/rollback.sh`
- `./deploy/issue-certificate.sh`
- `./deploy/cutover-duckdns.sh`
- remote `ssh` commands that mutate `/etc`, `/var/lib`, `/opt`, systemd, Nix
  profiles, firewall rules, users, SSH access, certificates, or service state

Rules:

- Do not push to infrastructure unless the user explicitly asks for a live
  deploy, rollback, certificate issuance, DNS cutover, or remote mutation.
- Before an infrastructure push, summarize:
  - target host
  - command to run
  - expected services affected
  - rollback command or rollback path
  - validation commands to run after deployment
- Confirm local validation passes before pushing.
- Confirm the target is the intended host before pushing.
- Do not deploy if the working tree contains unrelated uncommitted changes that
  could affect the build, unless the user explicitly accepts that state.
- Do not run DuckDNS cutover without an explicit user request.
- Do not run rollback unless explicitly requested or as part of the existing
  deployment script's automatic failure path.
- After a live deploy, verify service health and report the exact checks run.
- If a live deploy fails, preserve rollback information and report the exact
  failure.

## GitHub Push Rules

A GitHub push means any command that publishes commits or tags to a remote, such
as:

- `git push`
- `git push --tags`
- pushing a branch through a tool or integration

Rules:

- Default workflow for this repository: after each completed change or phase,
  create a focused Git commit and push it to GitHub, unless the user explicitly
  asks not to push.
- Before pushing, run `git status --short`.
- Review the staged and unstaged diff before committing or pushing.
- Do not include secrets, local-only files, generated backups, decrypted
  material, or machine-specific private files.
- Do not push broken validation unless the user explicitly asks to publish a
  known failing state and the failure is documented.
- Prefer one focused commit per task or phase.
- Commit messages must describe the infrastructure intent, not just the file
  edits.
- If the push includes deployment-relevant changes, ensure the documentation and
  rollback notes are updated before pushing.

## Commit Rules

- Default workflow for this repository: commit every completed change or phase,
  then push the resulting commit to GitHub, unless the user explicitly asks not
  to commit or not to push.
- Before committing:
  - inspect `git status --short`
  - inspect the relevant diff
  - run relevant validation
  - confirm documentation is updated
- Do not stage unrelated user changes.
- Do not amend, rebase, reset, or rewrite history unless explicitly requested.
- Do not use destructive Git commands such as `git reset --hard` or
  `git checkout -- <path>` unless explicitly requested.

## Current VPS Bundle Rules

- The current VPS target is Ubuntu 24.04 with a Nix-built bundle.
- The bundle deployment workflow is part of production state and must remain
  intact until a later phase replaces it safely.
- Current service coverage includes:
  - OpenSSH
  - WireGuard
  - WGDashboard
  - Nginx
  - nftables
  - iperf3
  - certbot renewal
  - RustDesk OSS server
- Do not break:
  - `nix build .#theau-vps-bundle`
  - `deploy/push-generation.sh`
  - `deploy/activate-generation.sh`
  - `deploy/rollback.sh`
  - the `/opt/theau-vps/generations/<timestamp>` model
  - the `/opt/theau-vps/current` symlink model
- Any replacement for the Ubuntu activation model must first coexist with it or
  provide a tested rollback path.

## Final Response Rules

- Always state what changed.
- Always state what validation was run.
- If validation was not run, state why.
- If infrastructure was pushed, state the target, command, and post-deploy
  checks.
- If GitHub was pushed, state the branch and commit.
- Mention any remaining risk or manual follow-up that affects operation.
