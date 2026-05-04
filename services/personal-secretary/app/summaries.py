"""Daily and weekly summary generation with live mail, calendar, and LLM."""
import os
from datetime import datetime, timedelta
from pathlib import Path


def _read_if_exists(path: Path) -> str:
    if path.exists():
        return path.read_text()
    return ""


def _env_dict():
    env = {}
    secrets_file = "/etc/personal-secretary/secrets.env"
    if os.path.exists(secrets_file):
        with open(secrets_file) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    env[k] = v.strip().strip('"')
    return env


def _fetch_mail_content(days: int = 3) -> str:
    env = _env_dict()
    username = env.get("GMAIL_USERNAME", "")
    password = env.get("GMAIL_APP_PASSWORD", "")
    if not username or not password:
        return "(Gmail not configured)"

    try:
        from .mail_reader import GmailIMAPReader, format_mail_summary
        reader = GmailIMAPReader(username=username, app_password=password)
        mails = reader.fetch_recent(max_results=10, days=days)
        result = format_mail_summary(mails)
        if len(result) > 3000:
            result = result[:3000] + "\n\n[... truncated]"
        return result
    except Exception as e:
        return f"(Mail fetch error: {e})"


def _fetch_calendar_content(days: int = 7) -> str:
    env = _env_dict()
    os.environ.update(env)
    try:
        from .calendar_reader import fetch_ics_calendars, format_calendar_summary
        cals = fetch_ics_calendars()
        return format_calendar_summary(cals, days=days)
    except Exception as e:
        return f"(Calendar fetch error: {e})"


def _llm_summarize(raw: str, task: str) -> str:
    """Use LLM to summarize raw content. Injects date/time into prompts."""
    env = _env_dict()
    os.environ.update(env)
    try:
        from .llm import get_provider
        provider = get_provider()
        prompt_dir = Path("/var/lib/personal-secretary/prompts")
        system_file = prompt_dir / "system.md"
        task_file = prompt_dir / f"{task}.md"

        system_prompt = system_file.read_text() if system_file.exists() else ""

        now = datetime.now()
        year, week, _ = now.isocalendar()
        tomorrow = now + timedelta(days=1)
        # Weekly: period is next Monday -> next Sunday
        if task == "weekly":
            start = now
            end = now + timedelta(days=7)
        else:
            start = now
            end = now + timedelta(days=6)

        date_vars = {
            "{DATE}": now.strftime("%A %d %B %Y"),
            "{DATE_SHORT}": now.strftime("%Y-%m-%d"),
            "{TIME}": now.strftime("%H:%M"),
            "{WEEK}": f"{year}-W{week:02d}",
            "{TOMORROW}": tomorrow.strftime("%Y-%m-%d"),
            "{PERIOD_START}": start.strftime("%Y-%m-%d"),
            "{PERIOD_END}": end.strftime("%Y-%m-%d"),
            "{INPUT}": raw,
        }

        task_prompt = raw
        if task_file.exists():
            task_prompt = task_file.read_text()
            for k, v in date_vars.items():
                task_prompt = task_prompt.replace(k, v)

        resp = provider.generate(prompt=task_prompt, system_prompt=system_prompt, task="summary")
        return resp.content
    except Exception as e:
        return f"{raw}\n\n(LLM unavailable - raw data shown: {e})"



_last_refactor = None

def refactor_notes():
    """Reorganize inbox.md into structured format using LLM (debounced: max 1 per 5 min)."""
    global _last_refactor
    now = datetime.now()
    if _last_refactor and (now - _last_refactor).total_seconds() < 300:
        return None
    _last_refactor = now

    from . import config
    inbox_path = config.JOURNAL_DIR / "inbox.md"
    notes_path = config.JOURNAL_DIR / "sources" / "discord-notes.md"

    inbox_content = inbox_path.read_text() if inbox_path.exists() else ""
    notes_content = notes_path.read_text() if notes_path.exists() else ""
    combined = f"Inbox:\n{inbox_content}\n\nArchive:\n{notes_content}"

    try:
        ai = _llm_summarize(combined, "refactor_notes")
    except Exception:
        ai = combined

    today = datetime.now().strftime("%Y-%m-%d")
    header = f"# Notes - refactored {today}\\n\\n"
    inbox_path.write_text(header + ai)
    notes_path.write_text(ai)
    return ai

def build_daily_summary():
    from . import config
    today = datetime.now().strftime("%Y-%m-%d")

    mails = _fetch_mail_content(days=2)
    calendar = _fetch_calendar_content(days=7)
    inbox = _read_if_exists(config.JOURNAL_DIR / "inbox.md")
    notes = _read_if_exists(config.JOURNAL_DIR / "sources" / "discord-notes.md")

    raw = f"""Mail (last 2 days):
{mails}

Calendar (next 7 days):
{calendar}

Discord notes / inbox:
{inbox if inbox else "(empty)"}

Discord notes archive:
{notes if notes else "(empty)"}
"""
    ai_summary = _llm_summarize(raw, "daily")

    summary = f"""# Daily Summary - {today}

{ai_summary}

---
Generated at {datetime.now().strftime('%H:%M')} by personal-secretary.
"""
    daily_dir = config.JOURNAL_DIR / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    (daily_dir / f"{today}.md").write_text(summary)
    return summary


def build_weekly_summary():
    from . import config
    now = datetime.now()
    year, week, _ = now.isocalendar()
    week_tag = f"{year}-W{week:02d}"

    mails = _fetch_mail_content(days=7)
    calendar = _fetch_calendar_content(days=14)

    raw = f"""Mail (last 7 days):
{mails}

Calendar (next 14 days):
{calendar}
"""
    ai_summary = _llm_summarize(raw, "weekly")

    summary = f"""# Weekly Planning - {week_tag}

{ai_summary}

---
Generated at {now.strftime('%H:%M')} by personal-secretary.
"""
    weekly_dir = config.JOURNAL_DIR / "weekly"
    weekly_dir.mkdir(parents=True, exist_ok=True)
    (weekly_dir / f"{week_tag}.md").write_text(summary)
    return summary


def build_tomorrow_summary():
    from . import config
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

    calendar = _fetch_calendar_content(days=2)
    tasks = _read_if_exists(config.JOURNAL_DIR / "tasks.md")[:500]
    deadlines = _read_if_exists(config.JOURNAL_DIR / "deadlines.md")[:500]

    raw = f"""Calendar (tomorrow and day after):
{calendar}

Tasks:
{tasks or "(none)"}

Deadlines:
{deadlines or "(none)"}
"""
    ai_summary = _llm_summarize(raw, "tomorrow")

    summary = f"""# Tomorrow Preview - {tomorrow}

{ai_summary}

---
Generated at {datetime.now().strftime('%H:%M')} by personal-secretary.
"""
    daily_dir = config.JOURNAL_DIR / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    (daily_dir / f"tomorrow-{tomorrow}.md").write_text(summary)
    return summary
