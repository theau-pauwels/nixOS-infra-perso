# Internal SMTP Relay

## Architecture

The SMTP relay is a Postfix service declared by
`modules/services/smtp.nix`. It accepts mail from trusted LAN/VPN clients and
relays outbound delivery through Gmail SMTP submission.

```text
internal services -> Postfix on VPS/VPN -> smtp.gmail.com:587 -> recipients
```

The module writes the Gmail SASL map at runtime from a secret file. The Gmail
app password is never embedded in the Nix store.

## Host Placement

Planned placement is the future native NixOS VPS (`hosts/vps`). The VPS is the
VPN hub and is always reachable by remote services over WireGuard/Headscale.

The module is imported there but disabled by default:

```nix
personalInfra.services.smtp.enable = false;
```

## Network Exposure

Defaults are intentionally closed:

- listener: `loopback-only`
- internal port: `587/tcp`
- firewall: closed unless `openFirewall = true`
- trusted relay networks:
  - `127.0.0.0/8`
  - `10.224.10.0/24`
  - `10.224.20.0/24`
  - `10.8.0.0/24`
  - `100.64.0.0/10`

Do not bind to `all`, `0.0.0.0`, or `::` with an open firewall. The module
asserts against default-route trusted networks to avoid open relay mistakes.

## Secret Handling

Required runtime secret:

```text
/run/secrets/gmail-smtp-app-password
```

The file must contain a Gmail or Google Workspace app password. Do not use the
normal account password. The Gmail account must have 2FA enabled before an app
password can be generated.

Recommended SOPS key name once this is wired into a host:

```yaml
smtp/gmail-app-password: TODO_REPLACE_OUTSIDE_GIT
```

## Client Settings

Internal services should use:

- host: the VPS LAN/VPN address or internal DNS name
- port: `587`
- TLS to internal relay: none by default
- client authentication: none by default; relay is IP-trusted only
- sender: `alerts@example.invalid` until replaced

The relay itself uses STARTTLS to Gmail and authenticates with the app password.

## Backup Considerations

Postfix queue state is not a primary backup target. The only durable material is
configuration and the SOPS-managed Gmail app password. Back up:

- Nix configuration
- encrypted host secrets
- any operational runbook for Gmail account recovery

## Test Procedure

After enabling the service and provisioning the secret:

```bash
systemctl status postfix postfix-setup
postconf -n | grep -E 'relayhost|mynetworks|inet_interfaces|smtp_sasl'
printf 'Subject: SMTP relay test\n\nRelay test\n' | sendmail you@example.com
postqueue -p
journalctl -u postfix -n 100 --no-pager
```

From a trusted client network:

```bash
swaks --server smtp.infra.theau.local --port 587 \
  --from alerts@example.invalid --to you@example.com
```

From an untrusted network, relay attempts must be rejected.

## Rollback And Troubleshooting

Rollback by disabling the module and switching the host:

```nix
personalInfra.services.smtp.enable = false;
```

Common failures:

- missing secret file: `postfix-setup` fails before generating `sasl_passwd`
- Gmail auth failure: app password is wrong, revoked, or not an app password
- relay denied: client source is outside `allowedNetworks`
- Gmail sender rejected: set `senderAddress` to an address the Gmail account may send as
- queue stuck: inspect `postqueue -p` and flush with `postqueue -f` after fixing the root cause
