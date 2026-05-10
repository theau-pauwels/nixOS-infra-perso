---
name: personal-agenda
description: personal agenda helper for théau. use when the user asks about planning, agenda, calendar, availability, free time, courses, umons schedule, cours ba3-ma1, iphone calendar, daily summaries, weekly summaries, deadlines, or schedule conflicts. always query narrow calendar windows instead of fetching the full academic calendar.
---

# Personal Agenda

Use this skill to answer questions about Théau's planning, calendars, courses, availability, free slots, daily agenda, weekly agenda, and UMONS schedule.

## Available helper command

On Théau's VPS, prefer this command:

```bash
/home/theau/.local/bin/my-agenda FROM TO
```

Example:

```bash
/home/theau/.local/bin/my-agenda 2026-05-05T00:00:00+02:00 2026-05-12T00:00:00+02:00
```

The command checks three calendars:

- Main Google Calendar: `theau.pauwels@gmail.com`
- iPhone calendar: `029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com`
- UMONS / Cours BA3-MA1 calendar: `msq0gfpodturbj0a7svn1hvjjd5hgjf7@import.calendar.google.com`

If `/home/theau/.local/bin/my-agenda` is missing, use the bundled helper template in `scripts/my-agenda` as the reference implementation and ask Théau to install it on the VPS.

## Critical rule: never fetch the full calendar by default

Do not parse the entire UMONS calendar unless the user explicitly asks for a long-term academic overview.

The UMONS calendar contains many events until the end of the academic year. Fetching everything is slow, noisy, and wastes context.

Always use the narrowest useful date range.

## Default date ranges

Use these ranges unless the user explicitly asks for another period.

### Today

For requests like:

- `mon planning aujourd'hui`
- `mes cours aujourd'hui`
- `qu'est-ce que j'ai aujourd'hui ?`

Query only today:

```bash
FROM="$(TZ=Europe/Brussels date -d 'today 00:00' '+%Y-%m-%dT%H:%M:%S%:z')"
TO="$(TZ=Europe/Brussels date -d 'tomorrow 00:00' '+%Y-%m-%dT%H:%M:%S%:z')"
/home/theau/.local/bin/my-agenda "$FROM" "$TO"
```

### Tomorrow

For requests like:

- `mon planning demain`
- `mes cours demain`
- `qu'est-ce que j'ai demain ?`

Query only tomorrow:

```bash
FROM="$(TZ=Europe/Brussels date -d 'tomorrow 00:00' '+%Y-%m-%dT%H:%M:%S%:z')"
TO="$(TZ=Europe/Brussels date -d 'tomorrow 00:00 +1 day' '+%Y-%m-%dT%H:%M:%S%:z')"
/home/theau/.local/bin/my-agenda "$FROM" "$TO"
```

### Next 7 days

For requests like:

- `mon planning`
- `mon planning cette semaine`
- `résume ma semaine`
- `qu'est-ce que j'ai dans les prochains jours ?`

Query the next 7 days:

```bash
FROM="$(TZ=Europe/Brussels date -d 'today 00:00' '+%Y-%m-%dT%H:%M:%S%:z')"
TO="$(TZ=Europe/Brussels date -d 'today 00:00 +7 days' '+%Y-%m-%dT%H:%M:%S%:z')"
/home/theau/.local/bin/my-agenda "$FROM" "$TO"
```

### Next 14 days

For requests like:

- `quand suis-je libre ?`
- `trouve-moi un créneau`
- `mes disponibilités`
- `quels sont mes créneaux libres ?`

Query at most the next 14 days:

```bash
FROM="$(TZ=Europe/Brussels date -d 'today 00:00' '+%Y-%m-%dT%H:%M:%S%:z')"
TO="$(TZ=Europe/Brussels date -d 'today 00:00 +14 days' '+%Y-%m-%dT%H:%M:%S%:z')"
/home/theau/.local/bin/my-agenda "$FROM" "$TO"
```

## Explicit date ranges

If the user gives a specific date range, use that range exactly.

Examples:

- `du 5 au 12 mai 2026`
- `la semaine prochaine`
- `pendant les examens`
- `en juin`

For broad requests like `tout le quadrimestre` or `jusqu'à la fin de l'année`, warn that the result may be long and prefer summarizing by week or by month.


## Default calendar for new events

When Theau asks to create an event, add it to the **iPhone** calendar by default
(029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com).

Use the gog CLI:

gog calendar create 029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com --summary "Titre" --start "ISO" --end "ISO" --account theau.pauwels@gmail.com

Only use another calendar if Theau explicitly says so.
Never create events in the UMONS calendar (read-only).

## Available calendars

The my-agenda script queries 5 calendar sources:

1. **Main Google Calendar** (theau.pauwels@gmail.com) — Google
2. **iPhone** (029342cfe6aa35acc532987b719017828f8bc81c9be7f599659e96a3f9e828a1@group.calendar.google.com) — Google
3. **Cours BA3-MA1** (msq0gfpodturbj0a7svn1hvjjd5hgjf7@import.calendar.google.com) — Google import
4. **Cours BA3-MA1 (ICS direct)** — ICS feed from ical.umons.ac.be (cours-ba3-ma1.url)
5. **Mails facultaires / Outlook UMONS** — ICS feed from outlook.office365.com (faculty-mail.url)

The ICS direct feed is more up-to-date than the Google Calendar import.
Both are included for redundancy.

## Calendar interpretation rules

- Use timezone `Europe/Brussels`.
- Treat `UMONS`, `Agenda UMONS`, `Cours BA3-MA1`, `cours`, and `horaire des cours` as the same UMONS calendar.
- Do not modify the UMONS calendar. It is read-only.
- Do not delete, edit, or create events unless the user explicitly asks and confirms.
- For the iPhone and main Google calendars, modifications require explicit confirmation.
- Do not ask the user for `GOG_KEYRING_PASSWORD` in chat. It must be configured in the VPS environment.
- If the command fails due to missing credentials or keyring access, report the error and suggest checking the service environment.

## Response style

### Discord formatting (CRITICAL)

**Never use Markdown tables in Discord messages.** Discord does not render
tables correctly. Always use bullet lists with this exact format:

```
📅 **Jour J** (date)
- 08:30-12:30 I-SECO-030 — Optimal Control (M. DEWASME)
- 13:30-15:30 I-SECO-030 — Optimal Control (M. DEWASME)
```

Rules:
- Use bullet points (-), never tables
- Each event on one line: `- HH:MM-HH:MM COURS — description`
- Group by day with bold date headers and 📅 emoji
- Mention start and end times for every event
- Keep course names readable, remove redundant teacher names after first mention
- Highlight conflicts or overlapping events with ⚠️
- If no events for a day, write `- Rien` or skip the day
- For availability requests, infer free slots between existing events
- Do not include raw event IDs
- For cron job delivery (daily/tomorrow summaries), keep the message under 2000 characters

### General

- Group events by day.
- For availability requests, infer free slots between existing events.
- Do not include raw event IDs unless the user asks for debugging.

## Preferred behavior

For a general planning request, use the 7-day range.

For an availability request, use the 14-day range.

For today or tomorrow, use only that single day.

For UMONS/course questions, never scan the full academic year unless explicitly requested.
