"""Mail preference learning — learns which mails are important from user feedback."""
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

logger = logging.getLogger(__name__)

PREFS_FILE = Path("/var/lib/personal-secretary/state/mail-preferences.json")


class MailPreferences:
    """Learned preferences about which mails are important / not important."""

    def __init__(self):
        self._data = self._load()

    def _load(self) -> dict:
        if PREFS_FILE.exists():
            try:
                return json.loads(PREFS_FILE.read_text())
            except (json.JSONDecodeError, OSError):
                pass
        return {
            "important_senders": {},     # {sender: count}
            "ignored_senders": {},       # {sender: count}
            "important_domains": {},     # {domain: count}
            "ignored_domains": {},       # {domain: count}
            "important_keywords": {},    # {keyword: count}
            "ignored_keywords": {},      # {keyword: count}
            "feedback_log": [],          # [{mail_id, sender, subject, label, ts}]
        }

    def _save(self):
        PREFS_FILE.parent.mkdir(parents=True, exist_ok=True)
        PREFS_FILE.write_text(json.dumps(self._data, indent=2))

    def feedback(self, mail_id: str, label: str, sender: str = "", subject: str = ""):
        """Record feedback: label = 'important' or 'ignore'."""
        cat = "important_senders" if label == "important" else "ignored_senders"
        dom_cat = "important_domains" if label == "important" else "ignored_domains"
        kw_cat = "important_keywords" if label == "important" else "ignored_keywords"

        # Extract sender email
        email_match = re.search(r'[\w.+-]+@[\w-]+\.[\w.-]+', sender)
        email_addr = email_match.group(0) if email_match else sender.lower().strip()
        domain = email_addr.split("@")[-1] if "@" in email_addr else ""

        if email_addr:
            self._data[cat][email_addr] = self._data[cat].get(email_addr, 0) + 1
        if domain:
            self._data[dom_cat][domain] = self._data[dom_cat].get(domain, 0) + 1

        # Extract keywords from subject
        if subject:
            words = re.findall(r'\w{4,}', subject.lower())
            for w in words:
                if w not in ("re fwd"):
                    self._data[kw_cat][w] = self._data[kw_cat].get(w, 0) + 1

        self._data["feedback_log"].append({
            "mail_id": mail_id,
            "sender": email_addr,
            "subject": subject[:200] if subject else "",
            "label": label,
            "ts": datetime.now().isoformat(),
        })

        # Keep log manageable
        if len(self._data["feedback_log"]) > 200:
            self._data["feedback_log"] = self._data["feedback_log"][-200:]

        self._save()
        logger.info("Feedback recorded: %s -> %s (%s)", mail_id, label, email_addr)

    def score_mail(self, sender: str, subject: str) -> int:
        """Score a mail: positive = important, negative = not important. Range ~ -10 to +10."""
        score = 0
        email_match = re.search(r'[\w.+-]+@[\w-]+\.[\w.-]+', sender)
        email_addr = email_match.group(0) if email_match else sender.lower().strip()
        domain = email_addr.split("@")[-1] if "@" in email_addr else ""

        # Sender signals
        imp_s = self._data["important_senders"].get(email_addr, 0)
        ign_s = self._data["ignored_senders"].get(email_addr, 0)
        score += min(imp_s, 5)  # cap at +5
        score -= min(ign_s, 5)  # cap at -5

        # Domain signals
        imp_d = self._data["important_domains"].get(domain, 0)
        ign_d = self._data["ignored_domains"].get(domain, 0)
        score += min(imp_d, 3)
        score -= min(ign_d, 3)

        # Keyword signals
        if subject:
            words = set(re.findall(r'\w{4,}', subject.lower()))
            for w in words:
                score += min(self._data["important_keywords"].get(w, 0), 2)
                score -= min(self._data["ignored_keywords"].get(w, 0), 2)

        return max(-10, min(10, score))

    def get_context_for_llm(self) -> str:
        """Generate a short context string for the LLM about learned preferences."""
        lines = []
        imp_senders = sorted(self._data["important_senders"].items(),
                             key=lambda x: x[1], reverse=True)[:5]
        ign_senders = sorted(self._data["ignored_senders"].items(),
                             key=lambda x: x[1], reverse=True)[:5]

        if imp_senders:
            lines.append("Important senders (learned): " +
                         ", ".join(f"{s} ({c}x)" for s, c in imp_senders))
        if ign_senders:
            lines.append("Ignored senders (learned): " +
                         ", ".join(f"{s} ({c}x)" for s, c in ign_senders))
        return "\n".join(lines) if lines else ""


# Singleton
prefs = MailPreferences()
