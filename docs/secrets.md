# Secrets Workflow

## Goal

Keep deployable secrets encrypted in Git while avoiding cleartext material in the Nix store and in the repository history.

## Current files

- tracked: `hosts/theau-vps/secrets.enc.yaml`
- tracked: `hosts/nas-kot/secrets.enc.yaml`
- tracked: `hosts/mom-edge/secrets.enc.yaml`
- tracked: `hosts/dad-edge/secrets.enc.yaml`
- tracked: `.sops.yaml`
- tracked: `.sops.yaml.example`
- ignored: `hosts/theau-vps/secrets.yaml`
- ignored: `hosts/nas-kot/secrets.yaml`
- ignored: `local-secrets/`
- ignored: `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- ignored: `~/.config/sops/age/keys.txt`

## Current flow

1. keep any cleartext editable copy under `local-secrets/`
2. encrypt the relevant local cleartext file with `sops`
3. write the encrypted output to `hosts/<host>/secrets.enc.yaml`
4. keep `local-secrets/` ignored and permission-restricted
5. deploy with the encrypted secrets workflow only

## Encrypted content

The encrypted secrets currently contain:

- WireGuard server private key
- WireGuard peer private keys
- WireGuard preshared keys
- deploy SSH authorized keys
- WGDashboard admin password hash
- WGDashboard TOTP seed

`hosts/nas-kot/secrets.enc.yaml` is managed by `sops-nix` and contains:

- Restic repository password
- Restic repository location

The committed NAS file currently contains encrypted placeholder values only.
Replace them before production.

`hosts/mom-edge/secrets.enc.yaml` is managed by `sops-nix` and contains:

- Mom site WireGuard private key

The committed Mom file currently contains encrypted placeholder values only.
Replace them before production.

`hosts/dad-edge/secrets.enc.yaml` is managed by `sops-nix` and contains:

- Dad site WireGuard private key

The committed Dad file currently contains encrypted placeholder values only.
Replace them before production.

Phase 6.5 service modules introduce additional runtime secret paths. They are
documented placeholders only until the relevant host is enabled and wired to
`sops-nix` or another runtime secret mechanism:

- VPS SMTP relay:
  - `/run/secrets/gmail-smtp-app-password`
  - suggested SOPS key: `smtp/gmail-app-password`
- Forgejo:
  - `/run/secrets/forgejo-db-password` for non-sqlite database backends
  - `/run/secrets/forgejo-mailer-password` only if the internal SMTP relay later requires client auth
- Prowlarr and media automation:
  - `/run/secrets/prowlarr-api-key`
  - `/run/secrets/prowlarr-c411-username`
  - `/run/secrets/prowlarr-c411-password`
  - `/run/secrets/qbittorrent-webui-password`
- Coolify:
  - `/data/coolify/source/.env`
  - `/run/secrets/coolify-app-key`
  - `/run/secrets/coolify-db-password`
  - `/run/secrets/coolify-redis-password`
  - `/run/secrets/coolify-git-token`
  - `/run/secrets/dns-provider-token`

Do not commit the Coolify `.env`, tracker credentials, Gmail app password,
database passwords, deploy keys, OAuth tokens, or DNS provider tokens.

Trusted user SSH public keys do not need encryption. They live in:

- `hosts/theau-vps/ssh-public-keys.json`

## Local-only cleartext material

Cleartext secrets that need to persist locally for editing, recovery, or
bootstrap must live under `local-secrets/`. Do not keep persistent cleartext
secret files under `hosts/*/`.

These files must not be committed:

- `~/.config/sops/age/keys.txt`
- `local-secrets/`
- `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- any file containing a live `DUCKDNS_TOKEN`
- `hosts/theau-vps/secrets.yaml`
- `hosts/nas-kot/secrets.yaml`
- any raw backup from `backups/`

## Useful commands

Decrypt secrets locally:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./.tools/sops/sops-v3.12.2.linux.amd64 --decrypt hosts/theau-vps/secrets.enc.yaml
```

Re-encrypt after editing a temporary plaintext file:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./.tools/sops/sops-v3.12.2.linux.amd64 --encrypt \
  --filename-override hosts/theau-vps/secrets.enc.yaml \
  --input-type yaml \
  --output-type yaml \
  local-secrets/theau-vps.secrets.yaml > hosts/theau-vps/secrets.enc.yaml
```

Harden local permissions for ignored cleartext secrets:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./scripts/harden-local-secrets.sh
```

Create a passphrase-encrypted backup vault for local cleartext material:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./scripts/build-local-secret-vault.sh
```

This vault is designed to capture:

- `~/.config/sops/age/keys.txt`
- files stored directly under `local-secrets/`
- an optional ignored `local-secrets/theau-vps-ops.env` file if you decide to keep operational secrets there temporarily
