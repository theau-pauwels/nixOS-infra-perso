# Secrets Workflow

## Goal

Keep deployable secrets encrypted in Git while avoiding cleartext material in the Nix store and in the repository history.

## Current files

- tracked: `hosts/theau-vps/secrets.enc.yaml`
- tracked: `.sops.yaml`
- tracked: `.sops.yaml.example`
- ignored: `hosts/theau-vps/secrets.yaml`
- ignored: `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- ignored: `~/.config/sops/age/keys.txt`

## Current flow

1. create a temporary plaintext `hosts/theau-vps/secrets.yaml`
2. encrypt it with `sops` into `hosts/theau-vps/secrets.enc.yaml`
3. delete the plaintext file immediately
4. deploy with `deploy/push-generation.sh`

## Encrypted content

The encrypted secrets currently contain:

- WireGuard server private key
- WireGuard peer private keys
- WireGuard preshared keys
- deploy SSH authorized keys
- WGDashboard admin password hash
- WGDashboard TOTP seed

## Local-only cleartext material

These files must not be committed:

- `~/.config/sops/age/keys.txt`
- `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- any file containing a live `DUCKDNS_TOKEN`
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
  hosts/theau-vps/secrets.yaml > hosts/theau-vps/secrets.enc.yaml
rm -f hosts/theau-vps/secrets.yaml
```
