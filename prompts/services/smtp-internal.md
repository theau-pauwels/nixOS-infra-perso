# Service: Internal SMTP Server

## Objective
Provide internal mail relay for alerts and notifications.

## Tasks
- Create module `modules/services/smtp.nix`
- Configure Postfix
- Restrict to LAN/VPN

## Constraints
- No open relay

## Acceptance Criteria
- Emails sent successfully
