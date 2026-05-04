# Personal Secretary

Discord bot serving as a personal assistant. Reads mails via IMAP, calendars
via ICS, notes via Discord, and produces AI-powered daily/weekly summaries using
DeepSeek.

## Architecture

```
Discord ──> personal-secretary (Python, systemd on IONOS-VPS)
               │
               ├──> DeepSeek API (summaries, extraction, refactoring)
               ├──> Gmail IMAP (mail reading, read-only)
               ├──> Google Calendar ICS / UMONS ICS (calendar)
               ├──> /var/lib/personal-secretary/journal/ (Markdown + Git)
               └──> Scheduler (daily 7:00, tomorrow 19:00, weekly Sun 18:00)
```

## Deployment

### Prerequisites

- Debian 13 (or any Linux) with Python 3.13+
- Discord bot token + guild ID
- DeepSeek API key

### Install

```bash
# Copy files
scp -r services/personal-secretary/ IONOS-VPS:/tmp/personal-secretary/

# On the server
sudo mkdir -p /var/lib/personal-secretary/{app,prompts,logs,state,journal/{daily,weekly,projects,sources,drafts}}
sudo cp -r /tmp/personal-secretary/app /var/lib/personal-secretary/
sudo cp /tmp/personal-secretary/main.py /var/lib/personal-secretary/
sudo cp -r /tmp/personal-secretary/prompts /var/lib/personal-secretary/
sudo chown -R theau:theau /var/lib/personal-secretary
sudo chmod 750 /var/lib/personal-secretary

# Python venv
python3 -m venv /var/lib/personal-secretary/venv
source /var/lib/personal-secretary/venv/bin/activate
pip install py-cord pytz GitPython google-api-python-client icalendar

# Secrets
sudo mkdir -p /etc/personal-secretary
sudo cp /tmp/personal-secretary/secrets.env.example /etc/personal-secretary/secrets.env
# Fill in /etc/personal-secretary/secrets.env with your keys
sudo chmod 600 /etc/personal-secretary/secrets.env

# Systemd
sudo cp /tmp/personal-secretary/personal-secretary.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now personal-secretary

# Init git journal
cd /var/lib/personal-secretary/journal
git init -b main
git config user.name "personal-secretary-bot"
git config user.email "personal-secretary-bot@ionos-vps.local"
touch inbox.md tasks.md deadlines.md mails.md
git add -A && git commit -m "init: personal-secretary journal"
```

### Secrets file

`/etc/personal-secretary/secrets.env`:

```env
# LLM (required)
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=sk-...
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL_SUMMARY=deepseek-chat
DEEPSEEK_MODEL_REASONING=deepseek-reasoner
DEEPSEEK_MODEL_DRAFTS=deepseek-chat

# Discord (required)
DISCORD_BOT_TOKEN=...
DISCORD_GUILD_ID=...
DISCORD_ALLOWED_USER_IDS=...     # comma-separated Discord user IDs

# Gmail IMAP (optional — for /daily mail reading)
GMAIL_USERNAME=...
GMAIL_APP_PASSWORD=...           # from https://myaccount.google.com/apppasswords

# ICS calendars (optional)
ICS_CALENDAR_PERSO=https://...
ICS_CALENDAR_UMONS=https://...
# Add more ICS_CALENDAR_<name> as needed
```

## Discord Commands

### Summaries

| Command | Description |
|---|---|
| `/daily` | Generate daily summary with mails, calendar, tasks, notes |
| `/tomorrow` | Preview tomorrow's schedule |
| `/weekly` | Generate weekly planning (7 days from today) |

### Notes

| Command | Description |
|---|---|
| `/note <text>` | Save a note to inbox |
| `/refactor` | Propose a compressed version of inbox.md |
| `/refactor review <comment>` | Revise proposal with mandatory directive |
| `/refactor accept` | Accept and apply the current proposal |

### Mail

| Command | Description |
|---|---|
| `/mails` | Show recent important mails |
| `/mail-feedback <id> <important\|ignore>` | Train the bot on mail importance |
| `/draft <context>` | Generate a mail draft |
| `/draft-reply <ref>` | Generate a reply draft |

### Projects

| Command | Description |
|---|---|
| `/project-create name:<n> temporary:<bool> deadline:<date>` | Create project + Discord channel |
| `/project-list` | List active projects |
| `/project-status name:<n>` | Show project details |
| `/project-close name:<n>` | Mark project completed |
| `/project-archive name:<n>` | Archive project |

### Tasks & Reminders

| Command | Description |
|---|---|
| `/tasks` | Show current tasks |
| `/deadlines` | Show upcoming deadlines |
| `/reminder <text> <when>` | Set a reminder (natural language, e.g., "demain 8h") |

### System

| Command | Description |
|---|---|
| `/status` | Show service health |
| `/help` | Show all commands |
| `/calendar` | Show upcoming events |
| `/process` | Process inbox notes into Markdown files |

## Auto-scheduler

| Time | Task |
|---|---|
| Every day 7:00 | `/daily` auto |
| Every day 19:00 | `/tomorrow` auto |
| Sunday 18:00 | `/weekly` auto |
| Every 30 min | Refactor inbox.md |

All times in Europe/Brussels.

## Discord Channels

Created automatically on first start:

| Channel | Purpose |
|---|---|
| `📥-inbox` | Auto-note: any message = note |
| `📋-daily` | Daily summaries |
| `📊-weekly` | Weekly summaries |
| `✅-tasks` | Extracted tasks |
| `⏰-deadlines` | Deadlines + reminders |
| `📧-mails` | Important mails |
| `✍️-drafts` | Mail drafts |
| `📅-calendar` | Upcoming events |
| `🔧-logs` | Service logs |
| `⚙️-admin` | Admin commands, refactor proposals |
| `📝-notes` | Quick notes (auto-saved) |

## Directory Structure

```
/var/lib/personal-secretary/
├── main.py              # Entry point
├── app/
│   ├── bot.py           # Discord bot + all slash commands
│   ├── channels.py      # Auto channel creation
│   ├── config.py        # Configuration from env vars
│   ├── calendar_reader.py  # ICS parser with timezone handling
│   ├── mail_reader.py   # Gmail IMAP reader
│   ├── mail_prefs.py    # Mail importance learning
│   ├── summaries.py     # Daily/weekly/tomorrow summary builders
│   ├── git_utils.py     # Journal Git operations
│   └── llm/
│       ├── base.py      # Abstract LLM provider
│       ├── deepseek.py  # DeepSeek API client
│       └── openai_compat.py  # OpenAI fallback
├── prompts/
│   ├── system.md        # System prompt
│   ├── daily.md         # Daily summary prompt
│   ├── weekly.md        # Weekly summary prompt
│   ├── tomorrow.md      # Tomorrow preview prompt
│   └── refactor_notes.md  # Notes refactoring prompt
├── journal/             # Git-tracked Markdown knowledge base
│   ├── inbox.md
│   ├── tasks.md
│   ├── deadlines.md
│   ├── mails.md
│   ├── daily/
│   ├── weekly/
│   ├── projects/
│   ├── drafts/
│   └── sources/
├── state/               # Runtime state (reminders, projects, preferences)
├── logs/                # Service logs
└── venv/                # Python virtualenv
```

## Rollback

```bash
# Stop service
sudo systemctl stop personal-secretary
# Restore journal from git
cd /var/lib/personal-secretary/journal
git log --oneline -5
git reset --hard <commit>
# Start
sudo systemctl start personal-secretary
```

## Security

- No public web interface — Discord only
- User authorization via `DISCORD_ALLOWED_USER_IDS`
- Never sends, deletes, archives, or marks mails as read
- Secrets in env file only, never committed
- Never exposes API keys in logs or LLM prompts
