"""Discord channel auto-creation and state management."""
import json
import logging
import os
from pathlib import Path
from typing import Optional

import discord

from . import config

logger = logging.getLogger(__name__)

REQUIRED_CHANNELS = [
    "📥-inbox",
    "📋-daily",
    "📊-weekly",
    "✅-tasks",
    "⏰-deadlines",
    "📧-mails",
    "✍️-drafts",
    "📅-calendar",
    "🔧-logs",
    "⚙️-admin",
    "📝-notes",
]

# Map channel key → full channel name (with emoji)
CHANNEL_KEY_MAP = {
    "inbox": "📥-inbox",
    "daily": "📋-daily",
    "weekly": "📊-weekly",
    "tasks": "✅-tasks",
    "deadlines": "⏰-deadlines",
    "mails": "📧-mails",
    "drafts": "✍️-drafts",
    "calendar": "📅-calendar",
    "logs": "🔧-logs",
    "admin": "⚙️-admin",
    "notes": "📝-notes",
}

CHANNELS_FILE = config.STATE_DIR / "discord-channels.json"

def load_channel_state() -> Optional[dict]:
    if CHANNELS_FILE.exists():
        try:
            return json.loads(CHANNELS_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return None

def save_channel_state(state: dict):
    config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    CHANNELS_FILE.write_text(json.dumps(state, indent=2))

async def discover_or_create_channels(guild: discord.Guild) -> dict:
    if not config.DISCORD_AUTO_CREATE_CHANNELS:
        return await _validate_channel_ids(guild)

    category = await _find_or_create_category(guild, config.DISCORD_CATEGORY_NAME)
    channels = {}

    for name in REQUIRED_CHANNELS:
        channel = await _find_or_create_channel(guild, category, name)
        # Find the key from the name
        key = None
        for k, full_name in CHANNEL_KEY_MAP.items():
            if full_name == name:
                key = k
                break
        if key:
            channels[key] = {"id": str(channel.id), "name": name}

    state = {
        "guild_id": str(guild.id),
        "category_id": str(category.id),
        "category_name": config.DISCORD_CATEGORY_NAME,
        "channels": channels,
    }
    save_channel_state(state)
    return state

async def _find_or_create_category(guild: discord.Guild, name: str) -> discord.CategoryChannel:
    for ch in guild.categories:
        if ch.name == name:
            logger.info("Found existing category: %s", name)
            return ch
    cat = await guild.create_category(name)
    logger.info("Created category: %s", name)
    return cat

async def _find_or_create_channel(
    guild: discord.Guild, category: discord.CategoryChannel, name: str
) -> discord.TextChannel:
    for ch in category.text_channels:
        if ch.name == name:
            logger.info("Found existing channel: %s", name)
            return ch
    ch = await category.create_text_channel(name)
    logger.info("Created channel: %s", name)
    return ch

async def _validate_channel_ids(guild: discord.Guild) -> dict:
    env_map = {
        k: f"DISCORD_CHANNEL_{k.upper()}" for k in CHANNEL_KEY_MAP
    }
    channels = {}
    for key, env_var in env_map.items():
        ch_id = os.environ.get(env_var, "")
        if not ch_id:
            logger.error("Auto-create disabled and %s not set", env_var)
            raise RuntimeError(f"Missing channel env var: {env_var}")
        channels[key] = {"id": ch_id, "name": CHANNEL_KEY_MAP[key]}
    return {
        "guild_id": str(guild.id),
        "category_id": "",
        "category_name": "",
        "channels": channels,
    }
