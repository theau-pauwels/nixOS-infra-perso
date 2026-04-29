# Service: Internal SMTP Server

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- Services need to send alerts, logs, and notifications.
- Internal services should not depend on external SMTP providers.
- Security is critical (no open relay).

## This Service Implements

### Objective
Deploy an internal SMTP relay for sending system alerts, monitoring notifications, and service emails.

### Target Use Cases
- Monitoring alerts (Prometheus, Uptime Kuma).
- System notifications (cron, failures).
- Service alerts (backup, VPN, etc.).

### Tasks

1. **Choose implementation**
   - Postfix (recommended lightweight relay).
   - Optional: msmtp for minimal setups.

2. **Create service module**
   - `modules/services/smtp.nix`
   - Disabled by default.
   - Options:
     - bind address
     - port
     - relay configuration
     - allowed networks

3. **Security configuration**
   - Restrict to:
     - localhost
     - LAN
     - VPN
   - Disable open relay.
   - Optional authentication.

4. **Optional external relay**
   - Allow forwarding via:
     - Gmail / SMTP provider
   - Use placeholders only.

5. **Integration with services**
   - Monitoring alerts
   - Backup notifications
   - System emails

6. **Logging and debugging**
   - Enable logs for mail delivery.
   - Document troubleshooting steps.

7. **Documentation**
   - `docs/implementation/smtp.md`
     - Architecture
     - Security model
     - Relay configuration
     - Troubleshooting

## Constraints
- MUST NOT be an open relay.
- No public exposure.
- No credentials in repo.
- Must work offline (local delivery).

## Acceptance Criteria
- Module builds successfully.
- Internal services can send emails.
- Relay is restricted to trusted networks.
- Documentation complete.

## Questions to Ask Before Starting
1. Internal-only emails or external delivery required?
2. Which services will send emails first?
3. Should authentication be required or IP-based trust enough?