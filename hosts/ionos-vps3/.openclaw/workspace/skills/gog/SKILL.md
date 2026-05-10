---
name: gog
description: Google CLI for Gmail/Calendar/Chat/Classroom/Drive/Contacts/Tasks/Sheets/Docs/Slides/People/Forms/Apps. Use for any Google account interaction. All operations for theau.pauwels@gmail.com.
---

# gog — Google CLI

Use gog to interact with Google services from the command line.

## Available accounts

- theau.pauwels@gmail.com (default)

## Available calendars

| Calendrier | Calendar ID | Read/Write |
|---|---|---|
| Google principal | theau.pauwels@gmail.com | Read + Write |
| iPhone | 029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com | Read + Write |
| UMONS / Cours BA3-MA1 | msq0gfpodturbj0a7svn1hvjjd5hgjf7@import.calendar.google.com | Read-only |

## Default calendar for new events

Tout nouvel evenement doit etre cree dans le calendrier iPhone
(029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com),
sauf instruction contraire explicite de l utilisateur.

Ne jamais creer d evenement dans le calendrier UMONS (read-only).

## Common commands

### Gmail (read-only)

gog gmail search 'query' --account theau.pauwels@gmail.com
gog gmail get message-id --account theau.pauwels@gmail.com
gog gmail list --max-results 5 --account theau.pauwels@gmail.com

### Calendar (read)

gog calendar list --max-results 10 --account theau.pauwels@gmail.com
gog calendar list --from 2026-05-09 --to 2026-05-16 --account theau.pauwels@gmail.com

### Calendar (write — iPhone par defaut)

gog calendar create 029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com --summary 'Titre' --start '2026-05-12T14:00:00+02:00' --end '2026-05-12T15:00:00+02:00' --account theau.pauwels@gmail.com

## Environment

- GOG_KEYRING_PASSWORD must be set
- Binary: /usr/local/bin/gog
- Config: /home/theau/.config/gogcli/

## Notes

- UMONS calendar is read-only — never write to it
- Default calendar for new events is iPhone
- Exception: if user explicitly asks for another calendar, use that one
- Never expose keyring password or OAuth credentials
