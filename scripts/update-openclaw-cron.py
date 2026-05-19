#!/usr/bin/env python3
"""Update OpenClaw cron jobs for meal/diesel/news agent separation."""

import json
import time
import uuid

JOBS_PATH = "/root/.openclaw/cron/jobs.json"

with open(JOBS_PATH) as f:
    jobs = json.load(f)

# 1. Update Meal-prep to use meal agent
for j in jobs["jobs"]:
    if "Meal-prep" in j.get("name", ""):
        j["sessionTarget"] = "agent:meal"
        print(f"✓ meal: sessionTarget={j['sessionTarget']}")

    # 2. Update Resume de la journee - keep only agenda
    if "Resume de la journee" == j.get("name", ""):
        j["payload"]["message"] = (
            "Utilise le skill personal-agenda pour resumer mon planning du jour. "
            "Poste tout dans ce channel."
        )
        print(f"✓ daily: agenda only")

    # 3. Update existing diesel job (8:00) to use meal agent + meal channel
    if "Prix diesel" in j.get("name", ""):
        j["sessionTarget"] = "agent:meal"
        j["delivery"]["to"] = "channel:1504902914295074886"
        print(f"✓ diesel: agent=meal, channel=meal")

# 4. Create News cron job (daily at 7:15)
news_id = str(uuid.uuid4())
news_job = {
    "id": news_id,
    "name": "Resume des news",
    "enabled": True,
    "createdAtMs": int(time.time() * 1000),
    "schedule": {"kind": "cron", "expr": "15 7 * * *", "tz": "Europe/Brussels"},
    "sessionTarget": "agent:news",
    "wakeMode": "now",
    "payload": {
        "kind": "agentTurn",
        "message": (
            "Execute /opt/openclaw-news/venv/bin/python3 /opt/openclaw-news/daily_summary.py "
            "et poste le resultat complet dans ce channel. N'ajoute rien d'autre."
        ),
    },
    "delivery": {
        "mode": "announce",
        "channel": "discord",
        "to": "channel:1505268923334004948",
    },
    "state": {},
}

# Check if news job already exists
news_exists = any("news" in j.get("name", "").lower() for j in jobs["jobs"])
if news_exists:
    print("⚠ news job already exists, skipping creation")
else:
    jobs["jobs"].append(news_job)
    print(f"✓ news: created job {news_id}")

with open(JOBS_PATH, "w") as f:
    json.dump(jobs, f, indent=2)
    f.write("\n")
print("Done")
