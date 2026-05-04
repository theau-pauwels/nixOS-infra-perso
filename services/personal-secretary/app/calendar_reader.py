"""Calendar reader — ICS backend reading multiple URLs."""
import logging
import os
import urllib.request
from datetime import datetime, timedelta, timezone
import pytz

BRUSSELS_TZ = pytz.timezone("Europe/Brussels")

logger = logging.getLogger(__name__)


def fetch_ics_calendars() -> dict[str, list[dict]]:
    calendars = {}
    for key, value in sorted(os.environ.items()):
        if key.startswith("ICS_CALENDAR_") and value and isinstance(value, str) and value.strip():
            name = key.replace("ICS_CALENDAR_", "").lower()
            url = value.strip().strip('"')
            try:
                events = _fetch_ics(url)
                calendars[name] = events
                logger.info("Fetched ICS calendar %s: %d events", name, len(events))
            except Exception as e:
                logger.error("Failed ICS calendar %s: %s", name, e)
    return calendars


def _fetch_ics(url: str) -> list[dict]:
    req = urllib.request.Request(url, headers={"User-Agent": "personal-secretary/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8", errors="replace")
    if not isinstance(raw, str):
        return []

    events = []
    current = {}
    in_vevent = False
    for line in raw.split("\n"):
        line = line.rstrip("\r")
        if line.startswith("BEGIN:VEVENT"):
            in_vevent = True
            current = {}
        elif line.startswith("END:VEVENT"):
            in_vevent = False
            if current.get("summary"):
                events.append(current)
            current = {}
        elif in_vevent:
            for prefix in ("DTSTART", "DTEND", "SUMMARY", "DESCRIPTION", "LOCATION", "UID"):
                if line.startswith(prefix + ":") or line.startswith(prefix + ";"):
                    value = line.split(":", 1)[1] if ":" in line else ""
                    value = value.replace("\\,", ",").replace("\\n", "\n")
                    current[prefix.lower()] = value
                    break
    return events


def _parse_dt(value: str) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    v = value.strip()
    is_utc = v.endswith("Z")
    for fmt in ("%Y%m%dT%H%M%S", "%Y%m%dT%H%M%SZ", "%Y%m%d"):
        try:
            dt = datetime.strptime(v, fmt)
            if is_utc or fmt.endswith("Z"):
                dt = dt.replace(tzinfo=timezone.utc).astimezone(BRUSSELS_TZ)
            return dt.replace(tzinfo=None)
        except ValueError:
            continue
    if len(v) >= 8:
        try:
            return datetime.strptime(v[:8], "%Y%m%d")
        except ValueError:
            pass
    return None


def format_calendar_summary(calendars: dict[str, list[dict]], days: int = 7) -> str:
    now = datetime.now()
    cutoff = now + timedelta(days=days)

    lines = [f"# Upcoming events ({now.strftime('%Y-%m-%d')} to {cutoff.strftime('%Y-%m-%d')})", ""]
    total = 0

    for cal_name, events in calendars.items():
        upcoming = []
        for ev in events:
            dt = _parse_dt(ev.get("dtstart", ""))
            if dt is not None and now <= dt <= cutoff:
                upcoming.append((dt, ev))

        upcoming.sort(key=lambda x: x[0])

        if upcoming:
            lines.append(f"## {cal_name}")
            for dt, ev in upcoming:
                summary = ev.get("summary", "?")[:80]
                loc = f" @ {ev['location']}" if ev.get("location") else ""
                end_dt = _parse_dt(ev.get("dtend", ""))
                end_str = f"-{end_dt.strftime('%H:%M')}" if end_dt else ""
                lines.append(f"- **{dt.strftime('%a %d %b %H:%M')}{end_str}** — {summary}{loc}")
                total += 1
            lines.append("")

    if total == 0:
        lines.append("No upcoming events.")
    return "\n".join(lines)
