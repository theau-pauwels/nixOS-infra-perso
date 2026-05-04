"""Main Discord bot with slash commands — py-cord flavor."""
import asyncio
import json
import logging
import os
import re
from datetime import datetime, timedelta
import pytz

BRUSSELS = pytz.timezone('Europe/Brussels')
from pathlib import Path

import discord
from discord.ext import commands, tasks
from discord.ui import Button, View

from . import config
from .channels import discover_or_create_channels, REQUIRED_CHANNELS
from .git_utils import init_journal, journal_commit, journal_status

logger = logging.getLogger(__name__)


class ReminderView(View):
    def __init__(self, reminder_text):
        super().__init__(timeout=None)
        self.reminder_text = reminder_text

    @discord.ui.button(label="Marquer comme fait", style=discord.ButtonStyle.success, custom_id="reminder_done")
    async def done_btn(self, button: Button, interaction: discord.Interaction):
        button.label = "Fait"
        button.style = discord.ButtonStyle.secondary
        button.disabled = True
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(f"Action terminee : {self.reminder_text}", ephemeral=True)


bot = commands.Bot(command_prefix="!", intents=discord.Intents.default())

_channel_state: dict = {}
_projects_state: dict = {}
_scheduled_daily_done: str = ""   # track last auto-daily date (7:00)
_scheduled_tomorrow_done: str = ""  # track last auto-tomorrow date (19:00)
_scheduled_weekly_done: str = ""  # track last auto-weekly date (Sun 18:00)

def _load_reminders() -> list:
    path = config.STATE_DIR / "reminders.json"
    if path.exists():
        try:
            return json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return []

def _save_reminders(reminders: list):
    config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    (config.STATE_DIR / "reminders.json").write_text(json.dumps(reminders, indent=2))


def is_authorized(ctx) -> bool:
    if not config.DISCORD_ALLOWED_USER_IDS:
        return True
    return str(ctx.author.id) in config.DISCORD_ALLOWED_USER_IDS


def get_channel(key: str) -> discord.TextChannel | None:
    ch_data = _channel_state.get("channels", {}).get(key, {})
    ch_id = ch_data.get("id")
    if ch_id:
        return bot.get_channel(int(ch_id))
    return None


def normalize_project_name(name: str) -> str:
    n = re.sub(r"[^a-z0-9-]", "-", name.lower().strip())
    n = re.sub(r"-+", "-", n)
    n = n.strip("-")
    if len(n) < 2:
        raise ValueError("Project name too short (min 2 chars)")
    if len(n) > 64:
        raise ValueError("Project name too long (max 64 chars)")
    if n in ("new", "list", "status", "close", "archive", "create", "test"):
        raise ValueError("Project name is a reserved word")
    return n


def load_projects_state() -> dict:
    path = config.STATE_DIR / "projects.json"
    if path.exists():
        try:
            return json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {"projects": {}, "active_limit": config.MAX_ACTIVE_PROJECTS}


def save_projects_state(state: dict):
    config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    (config.STATE_DIR / "projects.json").write_text(json.dumps(state, indent=2))


def journal_note(text: str, source: str = "Discord"):
    path = config.JOURNAL_DIR / "inbox.md"
    config.JOURNAL_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")
    with open(path, "a") as f:
        f.write(f"\n- {ts} — {source} — {text}\n")


async def post_summary(key: str, content: str):
    ch = get_channel(key)
    if ch and content.strip():
        sections = content.split("\n## ")
        sections[0] = sections[0].lstrip("# ").strip()
        buf = ""
        for i, sec in enumerate(sections):
            prefix = "## " if i > 0 else ""
            part = prefix + sec
            if len(buf) + len(part) + 1 > 1900 and buf:
                await ch.send(buf)
                buf = part
            else:
                buf = buf + "\n" + part if buf else part
        if buf:
            await ch.send(buf)


# ─── Self-waking scheduler ────────────────────────────────────────────────────


@tasks.loop(minutes=1)
async def scheduler_loop():
    """Check every minute if scheduled tasks should run."""
    now = datetime.now(BRUSSELS)
    today = now.strftime("%Y-%m-%d")
    weekday = now.weekday()
    hour = now.hour
    minute = now.minute

    global _scheduled_daily_done, _scheduled_tomorrow_done, _scheduled_weekly_done

    # Daily at 21:00 Europe/Brussels
    if hour == 21 and 0 <= minute < 5 and _scheduled_daily_done != today:
        _scheduled_daily_done = today
        logger.info("Auto-running daily summary at %s", now.strftime("%H:%M"))
        try:
            from .summaries import build_daily_summary
            summary = build_daily_summary()
            await post_summary("daily", summary)
            journal_commit(config.JOURNAL_DIR, f"daily: auto summary for {today}")
            await post_summary("logs", f"Daily summary auto-posted at {now.strftime('%H:%M')}")
        except Exception as e:
            logger.error("Auto daily failed: %s", e)
            await post_summary("logs", f"Auto daily error: {e}")

    # Weekly Sunday at 18:00
    if weekday == 6 and hour == 18 and 0 <= minute < 5 and _scheduled_weekly_done != today:
        _scheduled_weekly_done = today
        logger.info("Auto-running weekly summary")
        try:
            from .summaries import build_weekly_summary
            summary = build_weekly_summary()
            await post_summary("weekly", summary)
            journal_commit(config.JOURNAL_DIR, f"weekly: auto summary for {today}")
            await post_summary("logs", f"Weekly summary auto-posted at {now.strftime('%H:%M')}")
        except Exception as e:
            logger.error("Auto weekly failed: %s", e)
            await post_summary("logs", f"Auto weekly error: {e}")


# ─── Status & help ───────────────────────────────────────────────────────────


@bot.slash_command(name="status", description="Show service status")
async def cmd_status(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    git_st = journal_status(config.JOURNAL_DIR)
    msg = (
        f"**personal-secretary** — Running\n"
        f"LLM: {config.LLM_PROVIDER}\n"
        f"Auto daily: 7:00 | Auto tomorrow: 19:00 | Auto weekly: Sun 18:00\n"
        f"Git journal: {git_st}\n"
        f"Channels: {len(_channel_state.get('channels', {}))} configured"
    )
    await ctx.followup.send(msg, ephemeral=True)


@bot.slash_command(name="help", description="Show available commands")
async def cmd_help(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    cmds = [
        "**Available commands**",
        "/note <text>", "/daily", "/tomorrow", "/weekly",
        "/tasks", "/deadlines", "/mails", "/mail-feedback <id> <important|ignore>",
        "/calendar", "/draft <context>", "/draft-reply <ref>", "/process",
        "/project-create", "/project-list", "/project-status",
        "/project-close", "/project-archive",
        "/status", "/help",
    ]
    await ctx.followup.send("\n".join(cmds), ephemeral=True)


# ─── Core commands ───────────────────────────────────────────────────────────


@bot.slash_command(name="note", description="Add a note to inbox")
async def cmd_note(ctx, text: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    journal_note(text, source=f"Discord/{ctx.author.name}")
    ch = get_channel("notes")
    if ch:
        await ch.send(f"📝 **{ctx.author.name}**: {text}")
    await ctx.respond(f"Noted: {text[:100]}", ephemeral=True)


@bot.slash_command(name="daily", description="Generate daily summary now")
async def cmd_daily(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        from .summaries import build_daily_summary
        summary = build_daily_summary()
        await post_summary("daily", summary)
        journal_commit(config.JOURNAL_DIR, f"daily: update summary for {datetime.now().strftime('%Y-%m-%d')}")
        await ctx.followup.send("Daily summary generated.", ephemeral=True)
    except Exception as e:
        logger.error("Daily summary failed: %s", e)
        await post_summary("logs", f"Daily summary error: {e}")
        await ctx.followup.send("Daily summary failed — check logs.", ephemeral=True)


@bot.slash_command(name="weekly", description="Generate weekly summary now")
async def cmd_weekly(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        from .summaries import build_weekly_summary
        summary = build_weekly_summary()
        await post_summary("weekly", summary)
        journal_commit(config.JOURNAL_DIR, f"weekly: prepare week {datetime.now().strftime('%Y-W%W')}")
        await ctx.followup.send("Weekly summary generated.", ephemeral=True)
    except Exception as e:
        logger.error("Weekly summary failed: %s", e)
        await post_summary("logs", f"Weekly summary error: {e}")
        await ctx.followup.send("Weekly summary failed — check logs.", ephemeral=True)


@bot.slash_command(name="tasks", description="Show current tasks")
async def cmd_tasks(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    path = config.JOURNAL_DIR / "tasks.md"
    content = path.read_text()[:1900] if path.exists() else "No tasks yet."
    await ctx.followup.send(f"**Tasks**\n```md\n{content}\n```", ephemeral=True)


@bot.slash_command(name="deadlines", description="Show upcoming deadlines")
async def cmd_deadlines(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    path = config.JOURNAL_DIR / "deadlines.md"
    content = path.read_text()[:1900] if path.exists() else "No deadlines yet."
    await ctx.followup.send(f"**Deadlines**\n```md\n{content}\n```", ephemeral=True)


@bot.slash_command(name="mails", description="Summarize recent important mails")
async def cmd_mails(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    path = config.JOURNAL_DIR / "mails.md"
    content = path.read_text()[:1900] if path.exists() else "No mails processed yet."
    hint = "\n\nUse `/mail-feedback <id> <important|ignore>` to train me which mails matter."
    await ctx.followup.send(f"**Mails**\n```md\n{content}\n```{hint}", ephemeral=True)


@bot.slash_command(name="mail-feedback", description="Rate a mail: important or ignore")
async def cmd_mail_feedback(ctx, mail_id: str, label: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    label = label.lower().strip()
    if label not in ("important", "ignore"):
        await ctx.respond("Use: `important` or `ignore`", ephemeral=True)
        return
    from .mail_prefs import prefs
    prefs.feedback(mail_id, label)
    emoji = "⭐" if label == "important" else "\U0001f644"
    await ctx.respond(f"{emoji} Mail `{mail_id}` marked as **{label}**. I will learn from this.", ephemeral=True)


@bot.slash_command(name="calendar", description="Show upcoming events")
async def cmd_calendar(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    path = config.JOURNAL_DIR / "sources" / "calendar.md"
    content = path.read_text()[:1900] if path.exists() else "No calendar events synced yet."
    await ctx.followup.send(f"**Calendar**\n```md\n{content}\n```", ephemeral=True)


@bot.slash_command(name="draft", description="Generate a mail draft")
async def cmd_draft(ctx, context: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    draft = f"# Draft - {datetime.now().strftime('%Y-%m-%d')}\n\nContext: {context}\n\n---\n\n(Draft placeholder)\n"
    drafts_dir = config.JOURNAL_DIR / "drafts"
    drafts_dir.mkdir(parents=True, exist_ok=True)
    (drafts_dir / f"draft-{ts}.md").write_text(draft)
    await post_summary("drafts", draft)
    journal_commit(config.JOURNAL_DIR, f"draft: create draft-{ts}")
    await ctx.followup.send("Draft created.", ephemeral=True)


@bot.slash_command(name="draft-reply", description="Generate a reply draft")
async def cmd_draft_reply(ctx, ref: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    reply = f"# Reply Draft - {datetime.now().strftime('%Y-%m-%d')}\n\nReference: {ref}\n\n---\n\n(Reply placeholder)\n"
    drafts_dir = config.JOURNAL_DIR / "drafts"
    drafts_dir.mkdir(parents=True, exist_ok=True)
    (drafts_dir / f"reply-{ts}.md").write_text(reply)
    await post_summary("drafts", reply)
    journal_commit(config.JOURNAL_DIR, f"draft: create reply-{ts}")
    await ctx.followup.send("Reply draft created.", ephemeral=True)


@bot.slash_command(name="process", description="Process inbox notes")
async def cmd_process(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    inbox = config.JOURNAL_DIR / "inbox.md"
    if inbox.exists():
        notes = inbox.read_text()
        inbox.write_text("")
        journal_commit(config.JOURNAL_DIR, f"process: process inbox at {datetime.now().strftime('%Y-%m-%d')}")
        await ctx.followup.send(f"Inbox processed:\n```md\n{notes[:1500]}\n```", ephemeral=True)
    else:
        await ctx.followup.send("Inbox is empty.", ephemeral=True)


# ─── Project commands ────────────────────────────────────────────────────────



@bot.slash_command(name="reminder", description="Set a reminder. Date/time in natural language, e.g. demain 8h")
async def cmd_reminder(ctx, text: str, when: str = ""):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    if not when:
        when = text
    await ctx.defer(ephemeral=True)
    now = datetime.now(BRUSSELS)
    # Use LLM to parse natural language date
    try:
        from .llm import get_provider
        provider = get_provider()
        resp = provider.generate(
            prompt=f"Extract date+time from French text. Return only YYYY-MM-DD HH:MM. Now: {now.strftime('%Y-%m-%d')} {now.strftime('%H:%M')}. Text: {when}",
            task="extract"
        )
        parsed = resp.content.strip()
        # Validate format
        datetime.strptime(parsed, "%Y-%m-%d %H:%M")
        reminder_time = parsed
    except Exception:
        # Fallback: use simple heuristic
        reminder_time = now.strftime("%Y-%m-%d %H:%M")

    reminders = _load_reminders()
    reminders.append({
        "text": text,
        "time": reminder_time,
        "created_at": now.strftime("%Y-%m-%d %H:%M"),
        "user_id": str(ctx.author.id),
    })
    reminders.sort(key=lambda r: r["time"])
    _save_reminders(reminders)
    await ctx.followup.send(f"\u23F0 Reminder set: **{text}** at {reminder_time}", ephemeral=True)



def _load_proposal():
    p = config.STATE_DIR / "refactor_proposal.json"
    if p.exists():
        try:
            return json.loads(p.read_text())
        except:
            pass
    return {"original": "", "proposal": "", "reviews": []}

def _save_proposal(prop):
    config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    (config.STATE_DIR / "refactor_proposal.json").write_text(json.dumps(prop, indent=2, ensure_ascii=False))

def _build_refactor_proposal(comment=""):
    inbox = (config.JOURNAL_DIR / "inbox.md").read_text() if (config.JOURNAL_DIR / "inbox.md").exists() else ""
    if not inbox.strip():
        return None, "Inbox is empty."

    from .llm import get_provider
    provider = get_provider()
    prompt_file = config.PROMPTS_DIR / "refactor_notes.md"
    system = (config.PROMPTS_DIR / "system.md").read_text() if (config.PROMPTS_DIR / "system.md").exists() else ""
    task_prompt = prompt_file.read_text().replace("{INPUT}", inbox) if prompt_file.exists() else inbox

    if comment:
        task_prompt += "\n\nIMPORTANT - Instruction de revision OBLIGATOIRE a appliquer: " + comment + " Applique cette instruction sans discuter. Si on te demande de supprimer, SUPPRIME."

    resp = provider.generate(prompt=task_prompt, system_prompt=system, task="summary")
    prop = _load_proposal()
    prop["original"] = inbox
    prop["proposal"] = resp.content
    prop["reviews"].append(comment or "(initial proposal)")
    _save_proposal(prop)
    return resp.content, None
@bot.slash_command(name="refactor", description="Compress inbox to save tokens (no info loss)")
async def cmd_refactor(ctx, action: str = "", comment: str = ""):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)

    if action == "accept":
        prop = _load_proposal()
        if not prop.get("proposal"):
            await ctx.followup.send("No proposal to accept. Run /refactor first.", ephemeral=True)
            return
        (config.JOURNAL_DIR / "inbox.md").write_text(prop["proposal"])
        (config.JOURNAL_DIR / "sources" / "discord-notes.md").write_text(prop["proposal"])
        journal_commit(config.JOURNAL_DIR, "refactor: accept proposal")
        _save_proposal({"original": "", "proposal": "", "reviews": []})
        await ctx.followup.send("Proposal accepted. Inbox updated.", ephemeral=True)
        return

    if action == "review":
        if not comment:
            await ctx.followup.send("Use: /refactor review <your comment>", ephemeral=True)
            return
        proposal, err = _build_refactor_proposal(comment)
        if err:
            await ctx.followup.send(err, ephemeral=True)
            return
        await post_summary("admin", f"**Refactor proposal (reviewed)**\n{proposal}")
        await ctx.followup.send("Revised proposal posted in admin channel.", ephemeral=True)
        return

    # Default: generate new proposal
    proposal, err = _build_refactor_proposal()
    if err:
        await ctx.followup.send(err, ephemeral=True)
        return
    msg = "**Refactor proposal**\n" + proposal + "\n\nUse `/refactor review <comment>` to revise or `/refactor accept` to apply."
    await post_summary("admin", msg)
    await ctx.followup.send("Proposal posted in admin channel.", ephemeral=True)

@bot.slash_command(name="project-create", description="Create a project")
async def cmd_project_create(ctx, name: str, temporary: bool = True, deadline: str = ""):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        norm = normalize_project_name(name)
    except ValueError as e:
        await ctx.followup.send(str(e), ephemeral=True)
        return

    global _projects_state
    _projects_state = load_projects_state()
    projects = _projects_state.get("projects", {})

    if norm in projects and projects[norm]["status"] == "active":
        await ctx.followup.send(f"Project `{norm}` already exists.", ephemeral=True)
        return

    active = sum(1 for p in projects.values() if p.get("status") == "active")
    if active >= config.MAX_ACTIVE_PROJECTS:
        await ctx.followup.send(f"Max projects ({config.MAX_ACTIVE_PROJECTS}) reached.", ephemeral=True)
        return

    guild = ctx.guild
    proj_cat = next((c for c in guild.categories if c.name == config.DISCORD_CATEGORY_PROJECTS), None)
    if not proj_cat:
        proj_cat = await guild.create_category(config.DISCORD_CATEGORY_PROJECTS)

    ch_name = f"project-{norm}"
    existing = next((ch for ch in proj_cat.text_channels if ch.name == ch_name), None)
    if not existing:
        existing = await proj_cat.create_text_channel(ch_name)

    md_file = config.JOURNAL_DIR / "projects" / f"{norm}.md"
    md_file.parent.mkdir(parents=True, exist_ok=True)
    if not md_file.exists():
        md_file.write_text(f"# {name}\n\nCreated: {datetime.now().strftime('%Y-%m-%d')}\nStatus: active\nDeadline: {deadline or 'none'}\n\n## Tasks\n\n## Notes\n\n")

    projects[norm] = {
        "name": norm, "display_name": name, "channel_id": str(existing.id),
        "category_id": str(proj_cat.id),
        "markdown_file": str(md_file.relative_to(config.DATA_DIR)),
        "status": "active", "created_at": datetime.now().isoformat(),
        "closed_at": None, "archived_at": None,
        "deadline": deadline or None, "temporary": temporary,
    }
    _projects_state["projects"] = projects
    save_projects_state(_projects_state)

    await existing.send(f"**Project: {name}**\nStatus: active\nDeadline: {deadline or 'none'}\nMarkdown: `{md_file}`")
    journal_commit(config.JOURNAL_DIR, f"project: create {norm}")
    await ctx.followup.send(f"Project `{norm}` created -> {existing.mention}", ephemeral=True)


@bot.slash_command(name="project-list", description="List active projects")
async def cmd_project_list(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    global _projects_state
    _projects_state = load_projects_state()
    projects = _projects_state.get("projects", {})
    active = [(n, p) for n, p in projects.items() if p.get("status") == "active"]
    if not active:
        await ctx.followup.send("No active projects.", ephemeral=True)
        return
    lines = ["**Active projects**"]
    for n, p in sorted(active):
        dl = f" (deadline: {p['deadline']})" if p.get('deadline') else ""
        lines.append(f"- `{n}`{' [temp]' if p.get('temporary') else ''}{dl}")
    await ctx.followup.send("\n".join(lines), ephemeral=True)


@bot.slash_command(name="project-status", description="Show project details")
async def cmd_project_status(ctx, name: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    global _projects_state
    _projects_state = load_projects_state()
    try:
        norm = normalize_project_name(name)
    except ValueError:
        norm = name
    p = _projects_state.get("projects", {}).get(norm, {})
    if not p:
        await ctx.followup.send(f"Project `{norm}` not found.", ephemeral=True)
        return
    md_path = config.DATA_DIR / p.get("markdown_file", "")
    md_content = md_path.read_text()[:1000] if md_path.exists() else ""
    await ctx.followup.send(
        f"**{p.get('display_name', norm)}**\nStatus: {p.get('status')}\nDeadline: {p.get('deadline') or 'none'}\nChannel: <#{p.get('channel_id')}>\n```md\n{md_content}\n```",
        ephemeral=True)


@bot.slash_command(name="project-close", description="Mark project as completed")
async def cmd_project_close(ctx, name: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        norm = normalize_project_name(name)
    except ValueError:
        norm = name
    global _projects_state
    _projects_state = load_projects_state()
    p = _projects_state.get("projects", {}).get(norm)
    if not p:
        await ctx.followup.send(f"Project `{norm}` not found.", ephemeral=True)
        return
    p["status"] = "closed"
    p["closed_at"] = datetime.now().isoformat()

    guild = ctx.guild
    arch_cat = next((c for c in guild.categories if c.name == config.DISCORD_CATEGORY_ARCHIVED), None)
    if not arch_cat:
        arch_cat = await guild.create_category(config.DISCORD_CATEGORY_ARCHIVED)
    ch = guild.get_channel(int(p["channel_id"]))
    if ch:
        await ch.edit(category=arch_cat)
        await ch.send(f"Project **{p['display_name']}** completed.")
    save_projects_state(_projects_state)
    journal_commit(config.JOURNAL_DIR, f"project: close {norm}")
    await ctx.followup.send(f"Project `{norm}` closed.", ephemeral=True)


@bot.slash_command(name="project-archive", description="Archive project")
async def cmd_project_archive(ctx, name: str):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        norm = normalize_project_name(name)
    except ValueError:
        norm = name
    global _projects_state
    _projects_state = load_projects_state()
    p = _projects_state.get("projects", {}).get(norm)
    if not p:
        await ctx.followup.send(f"Project `{norm}` not found.", ephemeral=True)
        return
    if p["status"] not in ("closed", "active"):
        await ctx.followup.send("Close project first with /project-close.", ephemeral=True)
        return
    p["status"] = "archived"
    p["archived_at"] = datetime.now().isoformat()
    save_projects_state(_projects_state)
    journal_commit(config.JOURNAL_DIR, f"project: archive {norm}")
    await ctx.followup.send(f"Project `{norm}` archived.", ephemeral=True)


@bot.slash_command(name="tomorrow", description="Preview tomorrows schedule")
async def cmd_tomorrow_daily(ctx):
    if not is_authorized(ctx):
        await ctx.respond("Unauthorized.", ephemeral=True)
        return
    await ctx.defer(ephemeral=True)
    try:
        from .summaries import build_tomorrow_summary
        summary = build_tomorrow_summary()
        await post_summary("daily", summary)
        journal_commit(config.JOURNAL_DIR, "daily: update tomorrow preview")
        await ctx.followup.send("Tomorrow preview generated.", ephemeral=True)
    except Exception as e:
        logger.error("Tomorrow summary failed: %s", e)
        await post_summary("logs", f"Tomorrow summary error: {e}")
        await ctx.followup.send("Tomorrow summary failed — check logs.", ephemeral=True)


# ─── Bot lifecycle ───────────────────────────────────────────────────────────


@bot.event
async def on_message(message: discord.Message):
    if message.author == bot.user or message.author.bot:
        return
    ch_data = _channel_state.get("channels", {}).get("notes", {})
    notes_ch_id = ch_data.get("id")
    if notes_ch_id and str(message.channel.id) == notes_ch_id:
        if not message.content.startswith("/"):
            journal_note(message.content, source=f"Discord/{message.author.name}")
    await bot.process_commands(message)

@bot.event
async def on_ready():
    global _channel_state, _projects_state
    logger.info("Bot ready: %s", bot.user)

    guild = discord.utils.get(bot.guilds, id=int(config.DISCORD_GUILD_ID))
    if not guild:
        guilds = [f"{g.name} ({g.id})" for g in bot.guilds]
        logger.error("Guild %s not found. Available: %s", config.DISCORD_GUILD_ID, guilds)
        return

    try:
        _channel_state = await discover_or_create_channels(guild)
        logger.info("Channels synced, %s commands registered", len(bot.pending_application_commands))

        admin_ch = get_channel("admin")
        if admin_ch:
            await admin_ch.send(
                f"**personal-secretary** online\n"
                f"LLM: {config.LLM_PROVIDER}\n"
                f"Auto daily: 7:00 | Auto tomorrow: 19:00 | Auto weekly: Sun 18:00\n"
                f"Channels: {len(_channel_state.get('channels', {}))} configured"
            )
    except Exception as e:
        logger.error("Startup error: %s", e)

    _projects_state = load_projects_state()

    # Start the self-waking scheduler
    if not scheduler_loop.is_running():
        scheduler_loop.start()
        logger.info("Scheduler started")


def run_bot():
    init_journal(config.JOURNAL_DIR)
    bot.run(config.DISCORD_BOT_TOKEN)
