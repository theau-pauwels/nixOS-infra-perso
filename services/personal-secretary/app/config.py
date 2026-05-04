"""Configuration from environment variables."""
import os
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

DATA_DIR = Path(os.environ.get("PERSONAL_SECRETARY_DATA_DIR", "/var/lib/personal-secretary"))
JOURNAL_DIR = DATA_DIR / "journal"
STATE_DIR = DATA_DIR / "state"
LOGS_DIR = DATA_DIR / "logs"
PROMPTS_DIR = DATA_DIR / "prompts"

# Discord
DISCORD_BOT_TOKEN = os.environ.get("DISCORD_BOT_TOKEN", "")
DISCORD_GUILD_ID = os.environ.get("DISCORD_GUILD_ID", "")
DISCORD_ALLOWED_USER_IDS = [u.strip() for u in os.environ.get("DISCORD_ALLOWED_USER_IDS", "").split(",") if u.strip()]
DISCORD_AUTO_CREATE_CHANNELS = os.environ.get("DISCORD_AUTO_CREATE_CHANNELS", "true").lower() == "true"
DISCORD_CATEGORY_NAME = os.environ.get("DISCORD_CATEGORY_NAME", "Personal Secretary")
DISCORD_CATEGORY_PROJECTS = os.environ.get("DISCORD_CATEGORY_PROJECTS", "Projects")
DISCORD_CATEGORY_ARCHIVED = os.environ.get("DISCORD_CATEGORY_ARCHIVED", "Archived Projects")
MAX_ACTIVE_PROJECTS = int(os.environ.get("MAX_ACTIVE_PROJECTS", "20"))

TIMEZONE = os.environ.get("TZ", "Europe/Brussels")

# Mail
MAIL_CREATE_REMOTE_DRAFTS = os.environ.get("MAIL_CREATE_REMOTE_DRAFTS", "false").lower() == "true"
MAIL_SEND_AUTOMATICALLY = os.environ.get("MAIL_SEND_AUTOMATICALLY", "false").lower() == "true"

# LLM
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "deepseek").lower()

# DeepSeek
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
DEEPSEEK_BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
DEEPSEEK_MODEL_SUMMARY = os.environ.get("DEEPSEEK_MODEL_SUMMARY", "deepseek-chat")
DEEPSEEK_MODEL_REASONING = os.environ.get("DEEPSEEK_MODEL_REASONING", "deepseek-reasoner")
DEEPSEEK_MODEL_DRAFTS = os.environ.get("DEEPSEEK_MODEL_DRAFTS", "deepseek-chat")

# OpenAI (fallback)
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL_SUMMARY = os.environ.get("OPENAI_MODEL_SUMMARY", "gpt-4.1-mini")
OPENAI_MODEL_REASONING = os.environ.get("OPENAI_MODEL_REASONING", "gpt-4.1")
OPENAI_MODEL_DRAFTS = os.environ.get("OPENAI_MODEL_DRAFTS", "gpt-4.1-mini")

LLM_MAX_INPUT_CHARS = int(os.environ.get("LLM_MAX_INPUT_CHARS", "60000"))
LLM_TIMEOUT_SECONDS = int(os.environ.get("LLM_TIMEOUT_SECONDS", "60"))
LLM_RETRY_COUNT = int(os.environ.get("LLM_RETRY_COUNT", "3"))


def validate_config():
    """Validate required config. Returns list of error messages."""
    errors = []
    if not DISCORD_BOT_TOKEN:
        errors.append("DISCORD_BOT_TOKEN is not set")
    if not DISCORD_GUILD_ID:
        errors.append("DISCORD_GUILD_ID is not set")

    if LLM_PROVIDER == "deepseek" and not DEEPSEEK_API_KEY:
        errors.append("LLM_PROVIDER=deepseek requires DEEPSEEK_API_KEY")
    elif LLM_PROVIDER == "openai" and not OPENAI_API_KEY:
        errors.append("LLM_PROVIDER=openai requires OPENAI_API_KEY")
    elif LLM_PROVIDER not in ("deepseek", "openai"):
        errors.append(f"Unknown LLM_PROVIDER: {LLM_PROVIDER} (use deepseek or openai)")

    if errors:
        logger.error("Config validation errors: %s", "; ".join(errors))
    return errors


# Journal Git
JOURNAL_GIT_REMOTE = os.environ.get("JOURNAL_GIT_REMOTE", "")
JOURNAL_GIT_PUSH = os.environ.get("JOURNAL_GIT_PUSH", "false").lower() == "true"

# Mail - Gmail
def gmail_config():
    return {
        "client_id": os.environ.get("GMAIL_PERSONAL_CLIENT_ID", ""),
        "client_secret": os.environ.get("GMAIL_PERSONAL_CLIENT_SECRET", ""),
        "refresh_token": os.environ.get("GMAIL_PERSONAL_REFRESH_TOKEN", ""),
    }

# Calendar - ICS URLs
def ics_calendars() -> dict[str, str]:
    """Return all ICS_CALENDAR_* env vars as {name: url} dict."""
    cals = {}
    for key, value in os.environ.items():
        if key.startswith("ICS_CALENDAR_") and value.strip():
            name = key.replace("ICS_CALENDAR_", "").lower()
            cals[name] = value.strip()
    return cals
