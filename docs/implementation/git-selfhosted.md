# Self-Hosted Git Platform

## Architecture

The self-hosted Git service uses Forgejo through the NixOS
`services.forgejo` module, wrapped by `modules/services/git.nix`.

Forgejo was chosen over Gitea because it is the community-oriented fork,
stays lightweight, and has first-class NixOS module support on current
nixpkgs. Public registration is disabled by module assertion.

```text
browser -> Caddy HTTPS -> optional Authelia ForwardAuth -> Forgejo HTTP
git client -> Forgejo built-in SSH port
```

## Host Placement

Planned placement is the future native NixOS VPS (`hosts/vps`) because Git is a
small public-facing service and benefits from the VPS edge proxy.

The module is imported there but disabled by default:

```nix
personalInfra.services.git.enable = false;
```

If repository storage grows or CI runners are added, move runners and large
artifacts to Kot while keeping the web/SSH entrypoint on the VPS.

## Network Exposure

Defaults:

- Forgejo HTTP bind: `127.0.0.1:3000`
- Forgejo SSH: `2222/tcp`, firewall closed by default
- Caddy reverse proxy: optional
- Authelia ForwardAuth: enabled when the module-managed Caddy vhost is enabled
- public registration: disabled

For public HTTPS, enable `reverseProxy.enable = true` and point DNS for
`git.theau.net` at the VPS. For SSH clone/push access, explicitly open
`openSshFirewall = true` after confirming the port policy.

## Secret Handling

The module does not create an admin password. Bootstrap the first admin through
Forgejo's supported admin flow after deployment, then store any recovery
credential outside Git.

Optional runtime secrets:

```text
/run/secrets/forgejo-db-password
/run/secrets/forgejo-mailer-password
```

Use `database.passwordFile` for PostgreSQL/MySQL and `mailer.passwordFile` only
if the internal SMTP relay requires authentication.

## Backup Considerations

The module enables Forgejo dumps by default:

```text
/var/lib/forgejo/dump
```

Back up:

- `/var/lib/forgejo`
- Forgejo dump archives
- external database dump if using PostgreSQL/MySQL
- SSH host keys if the service uses a stable Git SSH identity
- encrypted secrets

Restic should include the Forgejo state directory and dump directory once the
service is enabled on a production host.

## Test Procedure

After enabling:

```bash
systemctl status forgejo forgejo-dump
curl -fsSI http://127.0.0.1:3000/
ss -ltnp | grep -E ':3000|:2222'
```

If Caddy is enabled:

```bash
curl -fsSI https://git.theau.net/
```

For SSH:

```bash
ssh -p 2222 git@git.theau.net
git clone ssh://git@git.theau.net:2222/OWNER/REPO.git
```

Confirm registration remains disabled from the web UI.

## Rollback And Troubleshooting

Rollback by disabling:

```nix
personalInfra.services.git.enable = false;
```

Keep `/var/lib/forgejo` intact during rollback. Do not remove repositories or
dumps unless a separate backup has been verified.

Common failures:

- web UI not reachable: check Caddy upstream and `HTTP_ADDR`
- SSH clone URLs wrong: check `sshPort`, firewall, and DNS
- database auth failure: verify `database.passwordFile` exists at runtime
- Authelia denies access: add a matching access-control rule or temporarily use VPN-only access
