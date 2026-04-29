# Service: Internal SMTP Server via Gmail Relay

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- Services need to send alerts, logs, and notifications.
- Internal services should send mail through a controlled relay instead of each service managing SMTP credentials.
- The relay must never become an open relay.
- External delivery should use Gmail SMTP as the upstream relay.
- Secrets must be managed outside Git.

## This Service Implements

### Objective
Deploy an internal SMTP relay that accepts mail from trusted LAN/VPN services and forwards outgoing mail to external recipients through Gmail SMTP.

### Target Use Cases
- Monitoring alerts from Prometheus, Alertmanager, Uptime Kuma, or similar tools.
- Backup status notifications.
- Cron/systemd failure emails.
- Service notifications from self-hosted applications.
- Centralized SMTP configuration for internal services.

### Mail Flow

```text
internal services
  -> internal SMTP relay (Postfix)
  -> Gmail SMTP authenticated relay
  -> external recipients
```

### Recommended Implementation
Use Postfix as an internal relay with Gmail as `relayhost`.

Expected Gmail upstream settings:
- SMTP server: `smtp.gmail.com`
- Port: `587`
- TLS: STARTTLS
- Authentication: enabled
- Username: Gmail address or Google Workspace address
- Password: Google app password, not the normal account password

## Tasks

1. **Create service module**
   - `modules/services/smtp.nix`
   - Disabled by default.
   - Options:
     - enable
     - bind address
     - port
     - allowed networks
     - Gmail SMTP username
     - path to Gmail SMTP/app-password secret
     - sender address
     - optional canonical sender rewriting

2. **Configure Postfix as internal relay**
   - Listen only on trusted interfaces by default.
   - Allow relay only from explicitly trusted networks:
     - localhost
     - LAN subnet(s)
     - VPN subnet(s)
   - Set Gmail as upstream relayhost.
   - Enable SASL authentication.
   - Enable STARTTLS.
   - Configure sender canonical mapping if needed.

3. **Secret management**
   - Do not commit Gmail credentials.
   - Store the Gmail app password using the repository’s chosen secret mechanism, for example:
     - `sops-nix`
     - `agenix`
     - host-local secret file outside Git
   - The Nix module should consume a secret file path, not a literal password.

4. **Gmail account requirements**
   - Enable 2FA on the Gmail/Google account.
   - Generate an app password dedicated to SMTP relay usage.
   - Document that the normal Gmail password must not be used.
   - Prefer a dedicated mailbox such as `alerts@theau.net` or a dedicated Gmail account.

5. **Security hardening**
   - Must not accept unauthenticated relay from untrusted networks.
   - Must not listen publicly on WAN.
   - Firewall must restrict access to trusted networks.
   - Avoid exposing port 25 publicly.
   - Prefer submission port 587 internally if clients support it.
   - Consider rate limits to avoid accidental alert storms.

6. **Integration with services**
   - Document SMTP settings for internal services:
     - host
     - port
     - TLS mode
     - whether authentication is required internally
     - sender address
   - Include examples for:
     - Uptime Kuma
     - monitoring/alerting
     - systemd or cron notifications

7. **Logging and debugging**
   - Enable useful Postfix logs.
   - Document how to inspect mail queue.
   - Document common Gmail errors:
     - authentication failure
     - app password missing
     - STARTTLS failure
     - Gmail sending limits
     - rejected sender address

8. **Documentation**
   - `docs/implementation/smtp.md`
     - Architecture
     - Gmail relay configuration
     - Secret management
     - Security model
     - Client configuration examples
     - Troubleshooting

## Constraints
- MUST NOT be an open relay.
- MUST NOT expose SMTP publicly on WAN.
- MUST NOT commit Gmail password, app password, OAuth token, or any SMTP credential.
- MUST use a Gmail app password or equivalent secure Google-supported SMTP authentication method.
- External delivery is done through Gmail relay, not by direct MX delivery from the VPS.
- Local/offline delivery may be documented as optional, but it is not the primary mode for this service.

## Acceptance Criteria
- `modules/services/smtp.nix` exists and is valid Nix.
- Service is disabled by default.
- Postfix relays outgoing mail through Gmail SMTP over STARTTLS.
- Relay access is restricted to localhost/LAN/VPN.
- Gmail credentials are loaded from a secret file and are not present in Git.
- Documentation explains Gmail app password setup and troubleshooting.
- Test email to an external address is documented.

## Questions to Ask Before Starting
1. Which Gmail or Google Workspace account should be used as the relay sender?
2. Should internal clients authenticate to Postfix, or is IP-based LAN/VPN trust enough?
3. Which LAN/VPN subnets are allowed to use the relay?
4. Should all outgoing emails be rewritten to a single sender address such as `alerts@theau.net`?
5. Which secret mechanism should be used: `sops-nix`, `agenix`, or host-local secret file?
