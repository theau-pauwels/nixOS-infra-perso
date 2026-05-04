#!/usr/bin/env python3
"""personal-secretary — entry point."""
import os
import sys
import logging
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.config import validate_config, DATA_DIR

# Ensure log dir exists
log_dir = DATA_DIR / "logs"
log_dir.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(str(log_dir / "service.log")),
    ],
)

logger = logging.getLogger("main")

# Validate config before starting
errors = validate_config()
if errors:
    for e in errors:
        logger.error("Config error: %s", e)
    if not os.environ.get("DISCORD_BOT_TOKEN"):
        logger.error("Missing DISCORD_BOT_TOKEN — cannot start")
        sys.exit(1)

logger.info("Starting personal-secretary (LLM: %s)", os.environ.get("LLM_PROVIDER", "deepseek"))

from app.bot import run_bot

if __name__ == "__main__":
    run_bot()
