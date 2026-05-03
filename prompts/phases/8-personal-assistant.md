# Phase 8 — Personal Secretary

## Context

Add a lightweight personal secretary service (`personal-secretary`) on
`IONOS-VPS` (87.106.38.127, the old VPS after reinstall as NixOS).
It is a Discord bot that reads mails, calendar, and chat notes, maintains a
Markdown + Git knowledge base, and produces daily/weekly summaries via
OpenAI API. No local LLM, no Docker, no heavy platform.

## Target host

`IONOS-VPS` (87.106.38.127), freshly reinstalled with NixOS.
SSH key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKbbEgxgAKV7v3E0gbiMRJB5Ago1onGT953i8fz7xuNJ VPS-IONOS`

## Architecture

```
Discord ──> personal-secretary (Python, systemd)
               │
               ├──> OpenAI API (summaries, drafts, extraction)
               ├──> Gmail API / IMAP (mail reading, read-only)
               ├──> Google Calendar / CalDAV / ICS (calendar)
               ├──> /var/lib/personal-secretary/journal/ (Markdown + Git)
               └──> Systemd timers (daily 21:00, weekly Sun 18:00)
```

## Service name

- Service: `personal-secretary`
- System user/group: `personal-secretary`
- Data dir: `/var/lib/personal-secretary`
- Timezone: `Europe/Brussels`

## Directories

```
/var/lib/personal-secretary/
├── journal/          # Git-tracked Markdown knowledge base
│   ├── inbox.md
│   ├── tasks.md
│   ├── deadlines.md
│   ├── mails.md
│   ├── drafts/
│   ├── daily/
│   ├── weekly/
│   ├── projects/
│   │   ├── perso.md
│   │   ├── homelab.md
│   │   ├── cours.md
│   │   └── admin.md
│   └── sources/
│       ├── gmail-perso.md
│       ├── mag.md
│       ├── umons.md
│       ├── calendar.md
│       └── discord-notes.md
├── app/              # Python application code
├── prompts/          # LLM prompt templates
│   ├── system.md
│   ├── daily.md
│   ├── weekly.md
│   ├── extract_tasks.md
│   ├── extract_deadlines.md
│   ├── summarize_mails.md
│   ├── draft_mail.md
│   └── process_discord_notes.md
├── logs/             # Runtime logs (no secrets)
│   ├── service.log
│   ├── daily.log
│   ├── weekly.log
│   ├── mail.log
│   └── discord.log
└── state/            # Runtime state (tokens, last-check cursors)
```

## Discord bot

### Channel auto-creation

At startup, the bot connects to the Discord guild specified by `DISCORD_GUILD_ID`
and performs channel discovery/creation:

1. Find or create the category `DISCORD_CATEGORY_NAME` (default: `Personal Secretary`)
2. For each required channel, check if a channel with the expected name exists
   inside that category. If it exists, reuse it. If not, create it.
3. Never create duplicates — match by name + category
4. Store resolved channel IDs in `/var/lib/personal-secretary/state/discord-channels.json`
5. Post a confirmation message in `#secretary-admin` listing found/created channels
6. If `DISCORD_AUTO_CREATE_CHANNELS=false`, require all channel IDs to be provided
   via environment variables. Log an error and refuse to start if any are missing.
   Do not create any channels.

Bot requires these Discord permissions:
- View Channels
- Send Messages
- Read Message History
- Use Slash Commands
- Manage Channels

New variables:
```env
DISCORD_AUTO_CREATE_CHANNELS=true
DISCORD_CATEGORY_NAME=Personal Secretary
```

### Channels (prefix: `secretary-`)

All channels are created inside the `DISCORD_CATEGORY_NAME` category.

| Channel | Purpose |
|---|---|
| `#secretary-inbox` | Quick notes, raw capture |
| `#secretary-daily` | Auto daily summary |
| `#secretary-weekly` | Auto weekly summary |
| `#secretary-tasks` | Extracted tasks |
| `#secretary-deadlines` | Deadlines + reminders |
| `#secretary-mails` | Important mails |
| `#secretary-drafts` | Mail drafts (never sent) |
| `#secretary-calendar` | Upcoming events |
| `#secretary-logs` | Non-sensitive logs |
| `#secretary-admin` | Admin commands, status |

### Saved channel state

`/var/lib/personal-secretary/state/discord-channels.json`:
```json
{
  "guild_id": "...",
  "category_id": "...",
  "category_name": "Personal Secretary",
  "channels": {
    "inbox": {"id": "...", "name": "secretary-inbox"},
    "daily": {"id": "...", "name": "secretary-daily"},
    "weekly": {"id": "...", "name": "secretary-weekly"},
    "tasks": {"id": "...", "name": "secretary-tasks"},
    "deadlines": {"id": "...", "name": "secretary-deadlines"},
    "mails": {"id": "...", "name": "secretary-mails"},
    "drafts": {"id": "...", "name": "secretary-drafts"},
    "calendar": {"id": "...", "name": "secretary-calendar"},
    "logs": {"id": "...", "name": "secretary-logs"},
    "admin": {"id": "...", "name": "secretary-admin"}
  },
  "created_at": "2026-05-03T...",
  "updated_at": "2026-05-03T..."
}
```

This file is updated at each startup after channel discovery/creation.

### Commands

| Command | Action |
|---|---|
| `/note <text>` | Append to inbox.md |
| `/daily` | Generate daily summary now |
| `/weekly` | Generate weekly summary now |
| `/tasks` | Show current tasks |
| `/deadlines` | Show upcoming deadlines |
| `/mails` | Summarize recent important mails |
| `/draft <context>` | Generate mail draft |
| `/draft-reply <ref>` | Generate reply draft |
| `/calendar` | Show upcoming events |
| `/process` | Process inbox notes → update Markdown files |
| `/status` | Service health |
| `/help` | Show commands |

Only authorized Discord user IDs can use commands.

## Mail integration (read-only)

Three mail sources, configurable backends:

| Source | Default backend | Variables |
|---|---|---|
| Gmail perso | `gmail` | `GMAIL_PERSONAL_CLIENT_ID`, `GMAIL_PERSONAL_CLIENT_SECRET`, `GMAIL_PERSONAL_REFRESH_TOKEN` |
| Mag | `imap` | `MAG_IMAP_HOST`, `MAG_IMAP_PORT=993`, `MAG_IMAP_USERNAME`, `MAG_IMAP_PASSWORD` |
| UMONS | `imap` | `UMONS_IMAP_HOST`, `UMONS_IMAP_PORT=993`, `UMONS_IMAP_USERNAME`, `UMONS_IMAP_PASSWORD` |

Rules:
- Never send, delete, archive, or mark as read automatically
- Fetch recent unread mails
- Group by thread
- Deprioritize newsletters/spam/notifications
- Identify mails needing reply, containing deadlines, or high-priority
- Produce structured summaries in `journal/mails.md`
- Draft replies go to `journal/drafts/`

## Calendar integration

Configurable backend: `google`, `caldav`, `ics`, `none`

Variables: `CALENDAR_BACKEND`, `GOOGLE_CALENDAR_CLIENT_ID`, `GOOGLE_CALENDAR_CLIENT_SECRET`, `GOOGLE_CALENDAR_REFRESH_TOKEN`, `CALDAV_URL`, `CALDAV_USERNAME`, `CALDAV_PASSWORD`, `ICS_URL`

Behavior:
- Fetch today's events + next 7 days
- Detect deadlines and prep-needed events
- Integrate into daily/weekly summaries
- Post to `#secretary-calendar`

## Daily summary

- Time: every day at 21:00 Europe/Brussels
- Sources: all 3 mails + calendar + Discord notes + journal
- Output: `journal/daily/YYYY-MM-DD.md` + `#secretary-daily`

## Weekly summary

- Time: Sunday at 18:00 Europe/Brussels
- Sources: all daily sources + week's dailies + tasks + deadlines + drafts + active projects
- Output: `journal/weekly/YYYY-WXX.md` + `#secretary-weekly`

## Dynamic project management

The bot can create and manage temporary or permanent projects on demand.

### Commands

| Command | Action |
|---|---|
| `/project-create name:<nom> temporary:<true\|false> deadline:<date>` | Create project + Discord channel |
| `/project-list` | List active projects |
| `/project-status name:<nom>` | Show status, tasks, deadlines, recent notes |
| `/project-close name:<nom>` | Mark project completed, propose archival |
| `/project-archive name:<nom>` | Archive project after explicit confirmation |

### Behavior

1. On `/project-create`:
   - Normalize project name (lowercase, replace spaces/special chars with `-`, reject empty/too-long/ambiguous names)
   - Find or create the `Projects` Discord category
   - Create `#project-<normalized-name>` channel inside `Projects`
   - Never create duplicates — check existing channels by name + category
   - Create `/var/lib/personal-secretary/journal/projects/<normalized-name>.md`
   - Register project in `/var/lib/personal-secretary/state/projects.json`
   - Post welcome message in new channel with project name, deadline, and Markdown file path
   - Git commit: `project: create <normalized-name>`

2. On `/project-close`:
   - Mark project status as `closed` in `projects.json`
   - Move Discord channel to `Archived Projects` category (create if needed)
   - Post summary in `#secretary-admin`
   - Keep Markdown file intact as durable record
   - Git commit: `project: close <normalized-name>`

3. On `/project-archive`:
   - Require explicit confirmation from authorized user
   - Archive Discord channel (move to `Archived Projects`, set read-only)
   - Mark status as `archived` in `projects.json`
   - Never delete channel or file
   - Git commit: `project: archive <normalized-name>`

4. Active projects appear in daily and weekly summaries:
   - Recent activity (last messages/notes)
   - Pending tasks extracted from channel messages
   - Approaching deadlines (with 48h warning)

### State file

`/var/lib/personal-secretary/state/projects.json`:
```json
{
  "active_limit": 20,
  "projects": {
    "my-project": {
      "name": "my-project",
      "display_name": "My Project",
      "channel_id": "...",
      "category_id": "...",
      "markdown_file": "journal/projects/my-project.md",
      "status": "active",
      "created_at": "2026-05-03T...",
      "closed_at": null,
      "archived_at": null,
      "deadline": "2026-06-01",
      "temporary": true
    }
  }
}
```

### Variables

```env
MAX_ACTIVE_PROJECTS=20
DISCORD_CATEGORY_PROJECTS=Projects
DISCORD_CATEGORY_ARCHIVED=Archived Projects
```

### Security

- Only users in `DISCORD_ALLOWED_USER_IDS` can create, close, or archive projects
- Project names normalized: `[a-z0-9-]+`, max 64 chars, min 2 chars
- Refuse empty, too long, or ambiguous names
- Limit active projects via `MAX_ACTIVE_PROJECTS` (default 20)
- Never delete a channel or Markdown file without explicit confirmation
- Archived channels stay in `Archived Projects` category as read-only records
- Never expose Markdown file paths outside authorized users

## OpenAI

| Model | Purpose |
|---|---|
| `gpt-4.1-mini` | Daily summaries, classification, extraction, drafts |
| `gpt-4.1` | Complex synthesis (if needed) |

Rules: truncate long mails, no attachments, no secrets, limit prompt size, log approximate costs.

## NixOS module

```nix
services.personal-secretary = {
  enable = true;
  user = "personal-secretary";
  group = "personal-secretary";
  dataDir = "/var/lib/personal-secretary";
  timezone = "Europe/Brussels";
};
```

Systemd units:
- `personal-secretary.service` — Discord bot main process
- `personal-secretary-daily.service` + `.timer` — 21:00 daily
- `personal-secretary-weekly.service` + `.timer` — Sun 18:00 weekly
- `personal-secretary-deadlines.service` + `.timer` — deadline reminders

## Secrets

File: `/run/secrets/personal-secretary.env` (root-readable only, never committed)

Required variables: `OPENAI_API_KEY`, `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_ALLOWED_USER_IDS`, all 10 channel IDs, all mail/calendar backend variables.

## Git

- Track `journal/` directory
- Bot identity: `personal-secretary-bot <personal-secretary-bot@ionos-vps.local>`
- Auto-commit after daily/weekly/process
- Commit format: `daily: update summary for YYYY-MM-DD`, `weekly: prepare week YYYY-WXX`, `mail: add draft for <recipient>`, `tasks: update deadlines`
- Optional future: push to private remote

## Security

- No public web interface
- Discord auth gating (allowed user IDs only)
- No auto mail sending, deleting, archiving, or marking as read
- No root access for service
- No shell access
- Restrictive permissions on `/var/lib/personal-secretary`
- Secrets never in Markdown, logs, commits, or prompts to OpenAI

## Implementation order

1. **NixOS module skeleton** — `modules/services/personal-secretary.nix` with user, dirs, systemd service+timer stubs
2. **Python package** — `packages/personal-secretary/` with Discord bot + CLI entry points
3. **Host config** — `hosts/ionos-vps/default.nix` importing the module
4. **Secrets setup** — sops-nix or EnvironmentFile wiring
5. **Discord bot** — command handling, auth gating, channel routing
6. **Mail readers** — Gmail API + IMAP backends
7. **Calendar reader** — Google Calendar / CalDAV / ICS backends
8. **OpenAI integration** — prompt templates, daily/weekly/draft generation
9. **Git auto-commit** — post-processing hooks
10. **Timers** — daily 21:00, weekly Sun 18:00, deadlines check
11. **Documentation** — `docs/implementation/personal-secretary.md`

## Files to create

| File | Purpose |
|---|---|
| `modules/services/personal-secretary.nix` | NixOS module |
| `packages/personal-secretary/default.nix` | Nix package |
| `packages/personal-secretary/personal_secretary/` | Python package |
| `hosts/ionos-vps/` | Host config for old IONOS-VPS |
| `docs/implementation/personal-secretary.md` | Documentation |
| `prompts/llm/system.md` | System prompt |
| `prompts/llm/daily.md` | Daily summary prompt |
| `prompts/llm/weekly.md` | Weekly summary prompt |

## Validation

```bash
nix flake check
nix build .#nixosConfigurations.ionos-vps.config.system.build.toplevel
# SSH to IONOS-VPS, run /status, /note test, /daily
```

## Notes

- The old IONOS-VPS (87.106.38.127) will be reinstalled with NixOS before this phase starts.
- Phase starts AFTER reinstall, when the machine is reachable and NixOS is booted.
- No Docker — everything runs as native systemd services.
- `MAIL_SEND_AUTOMATICALLY=false` and `MAIL_CREATE_REMOTE_DRAFTS=false` are hard defaults.