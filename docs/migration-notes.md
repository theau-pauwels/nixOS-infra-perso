# Migration Notes

## Source host

- Old VPS remains the rollback host until DNS and WireGuard cutover are validated

## Target host

- Fresh VPS will become `theau-vps` on NixOS

## Git policy

- Store configuration in Git
- Keep sensitive backups outside Git
- Store deployable secrets in encrypted form only
