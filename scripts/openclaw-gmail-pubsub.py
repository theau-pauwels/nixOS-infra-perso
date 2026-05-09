#!/usr/bin/env python3
"""
Gmail Pub/Sub → DeepSeek Triage → Discord #📥-inbox

Architecture:
  1. Gmail API users.watch → Pub/Sub topic (one-time setup, auto-renewed)
  2. Pub/Sub pull subscription → detect new mail in near real-time
  3. Gmail API users.messages.get → fetch full message content
  4. DeepSeek API → classify importance (important / umons / newsletter / spam)
  5. Discord webhook → notify only important + umons mails to #📥-inbox

No polling fallback. Pub/Sub only, as intended.

Environment variables (all required unless noted):
  GMAIL_CLIENT_ID            OAuth 2.0 client ID
  GMAIL_CLIENT_SECRET        OAuth 2.0 client secret
  GMAIL_REFRESH_TOKEN        OAuth 2.0 refresh token (long-lived)
  GMAIL_PUBSUB_TOPIC         Full Pub/Sub topic: projects/<p>/topics/<t>
  GMAIL_PUBSUB_SUBSCRIPTION  Full subscription: projects/<p>/subscriptions/<s>
  DEEPSEEK_API_KEY           DeepSeek API key
  DISCORD_WEBHOOK_URL        Discord webhook URL for #📥-inbox
  STATE_DIR                  State directory (default: /var/lib/openclaw/state)
  LOG_LEVEL                  debug|info|warning|error (default: info)
"""

from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

logger = logging.getLogger("gmail-pubsub")

# ---------------------------------------------------------------------------
# Configuration from environment (no defaults for secrets)
# ---------------------------------------------------------------------------

GMAIL_CLIENT_ID = os.environ.get("GMAIL_CLIENT_ID", "")
GMAIL_CLIENT_SECRET = os.environ.get("GMAIL_CLIENT_SECRET", "")
GMAIL_REFRESH_TOKEN = os.environ.get("GMAIL_REFRESH_TOKEN", "")
GMAIL_PUBSUB_TOPIC = os.environ.get("GMAIL_PUBSUB_TOPIC", "")
GMAIL_PUBSUB_SUBSCRIPTION = os.environ.get("GMAIL_PUBSUB_SUBSCRIPTION", "")
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")
STATE_DIR = Path(os.environ.get("STATE_DIR", "/var/lib/openclaw/state"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "info").upper()

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

GMAIL_TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL_WATCH_URL = "https://gmail.googleapis.com/gmail/v1/users/me/watch"
GMAIL_HISTORY_URL = "https://gmail.googleapis.com/gmail/v1/users/me/history"
GMAIL_MESSAGE_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
PUBSUB_PULL_URL = f"https://pubsub.googleapis.com/v1/{GMAIL_PUBSUB_SUBSCRIPTION}:pull"
PUBSUB_ACK_URL = (
    f"https://pubsub.googleapis.com/v1/{GMAIL_PUBSUB_SUBSCRIPTION}:acknowledge"
)

DEEPSEEK_CHAT_URL = "https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_MODEL = "deepseek-chat"

WATCH_RENEWAL_DAYS = 6  # renew watch before 7-day expiry
PUBSUB_PULL_TIMEOUT = 30  # long-poll timeout in seconds
PUBSUB_MAX_MESSAGES = 10
DISCORD_MAX_LENGTH = 2000
HTTP_TIMEOUT = 30

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _http_json(
    method: str,
    url: str,
    body: Optional[dict] = None,
    headers: Optional[dict] = None,
    timeout: int = HTTP_TIMEOUT,
) -> dict:
    """Make an HTTP request and return parsed JSON."""
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        err_body = ""
        try:
            err_body = e.read().decode()[:500]
        except Exception:
            pass
        raise RuntimeError(f"HTTP {e.code} {url}: {err_body}") from e


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# OAuth 2.0 token management
# ---------------------------------------------------------------------------


class TokenManager:
    """Manages OAuth 2.0 access tokens for Gmail API."""

    def __init__(self, client_id: str, client_secret: str, refresh_token: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token
        self._access_token: Optional[str] = None
        self._expires_at: float = 0.0

    def get_token(self) -> str:
        """Return a valid access token, refreshing if needed."""
        if self._access_token and time.time() < self._expires_at - 60:
            return self._access_token
        self._refresh()
        return self._access_token  # type: ignore[return-value]

    def _refresh(self) -> None:
        logger.info("Refreshing OAuth access token")
        resp = _http_json(
            "POST",
            GMAIL_TOKEN_URL,
            body={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "refresh_token": self.refresh_token,
                "grant_type": "refresh_token",
            },
        )
        self._access_token = resp.get("access_token")
        if not self._access_token:
            raise RuntimeError(f"OAuth token refresh failed: {json.dumps(resp)}")
        expires_in = resp.get("expires_in", 3600)
        self._expires_at = time.time() + expires_in
        logger.info("Access token refreshed, expires in %ss", expires_in)


# ---------------------------------------------------------------------------
# Gmail API
# ---------------------------------------------------------------------------


class GmailAPI:
    """Minimal Gmail API client for watch + fetch."""

    def __init__(self, token_manager: TokenManager):
        self.tm = token_manager

    def _auth_headers(self) -> dict:
        return {"Authorization": f"Bearer {self.tm.get_token()}"}

    def setup_watch(self) -> dict:
        """Call users.watch to register/renew the Pub/Sub watch."""
        logger.info("Setting up Gmail watch on topic %s", GMAIL_PUBSUB_TOPIC)
        resp = _http_json(
            "POST",
            GMAIL_WATCH_URL,
            body={
                "topicName": GMAIL_PUBSUB_TOPIC,
                "labelIds": ["INBOX"],
            },
            headers=self._auth_headers(),
        )
        history_id = resp.get("historyId", "unknown")
        expiry = resp.get("expiration", "unknown")
        logger.info("Watch established — historyId=%s, expires=%s", history_id, expiry)
        return resp

    def get_history(self, history_id: str) -> list[dict]:
        """Fetch history changes since a given historyId."""
        logger.info("Fetching history since %s", history_id)
        resp = _http_json(
            "GET",
            f"{GMAIL_HISTORY_URL}?startHistoryId={history_id}",
            headers=self._auth_headers(),
        )
        return resp.get("history", [])

    def get_message(self, msg_id: str) -> dict:
        """Fetch a full message by ID (full format)."""
        logger.debug("Fetching message %s", msg_id)
        return _http_json(
            "GET",
            f"{GMAIL_MESSAGE_URL}/{msg_id}?format=full",
            headers=self._auth_headers(),
        )

    def get_message_minimal(self, msg_id: str) -> dict:
        """Fetch minimal message metadata by ID."""
        return _http_json(
            "GET",
            f"{GMAIL_MESSAGE_URL}/{msg_id}?format=minimal&fields=id,threadId,labelIds,payload/headers",
            headers=self._auth_headers(),
        )


# ---------------------------------------------------------------------------
# Gmail message parsing
# ---------------------------------------------------------------------------


def _get_header(headers: list[dict], name: str) -> str:
    """Extract a header value from a Gmail API headers list."""
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def _decode_body(payload: dict) -> str:
    """Recursively decode a Gmail message body from the payload."""
    if payload.get("mimeType") == "text/plain":
        data = payload.get("body", {}).get("data", "")
        if data:
            import base64

            return base64.urlsafe_b64decode(data + "===").decode(
                "utf-8", errors="replace"
            )
    parts = payload.get("parts", [])
    for part in parts:
        result = _decode_body(part)
        if result:
            return result
    # fallback: try top-level body
    data = payload.get("body", {}).get("data", "")
    if data:
        import base64

        return base64.urlsafe_b64decode(data + "===").decode("utf-8", errors="replace")
    return ""


def parse_message(full_msg: dict) -> dict:
    """Parse a Gmail API full message into a clean dict."""
    msg_id = full_msg.get("id", "")
    thread_id = full_msg.get("threadId", "")
    payload = full_msg.get("payload", {})
    headers = payload.get("headers", [])

    subject = _get_header(headers, "Subject")
    from_addr = _get_header(headers, "From")
    to_addr = _get_header(headers, "To")
    date_str = _get_header(headers, "Date")
    body = _decode_body(payload)

    snippet = full_msg.get("snippet", "")
    if not snippet and body:
        snippet = body[:200].replace("\n", " ").strip()

    return {
        "id": msg_id,
        "thread_id": thread_id,
        "from": from_addr,
        "to": to_addr,
        "subject": subject or "(no subject)",
        "date": date_str,
        "snippet": snippet,
        "body": body[:4000] if body else snippet,  # truncate for LLM
    }


# ---------------------------------------------------------------------------
# Pub/Sub pull client
# ---------------------------------------------------------------------------


class PubSubClient:
    """Pull messages from a Google Cloud Pub/Sub subscription."""

    def __init__(self, token_manager: TokenManager):
        self.tm = token_manager
        self.subscription = GMAIL_PUBSUB_SUBSCRIPTION
        self.pull_url = f"https://pubsub.googleapis.com/v1/{self.subscription}:pull"
        # ack_url built per-message from ack_id; base used for batched ack
        self.ack_base = (
            f"https://pubsub.googleapis.com/v1/{self.subscription}:acknowledge"
        )

    def pull(
        self,
        max_messages: int = PUBSUB_MAX_MESSAGES,
        timeout: int = PUBSUB_PULL_TIMEOUT,
    ) -> list[dict]:
        """Pull messages from the subscription (long-poll)."""
        logger.debug("Pulling Pub/Sub (max=%s, timeout=%ss)", max_messages, timeout)
        try:
            resp = _http_json(
                "POST",
                self.pull_url,
                body={
                    "maxMessages": max_messages,
                    "returnImmediately": False,
                },
                headers={"Authorization": f"Bearer {self.tm.get_token()}"},
                timeout=timeout + 10,
            )
            return resp.get("receivedMessages", [])
        except RuntimeError:
            logger.exception("Pub/Sub pull error")
            return []

    def ack(self, ack_ids: list[str]) -> None:
        """Acknowledge messages so they are not redelivered."""
        if not ack_ids:
            return
        logger.debug("Acking %s message(s)", len(ack_ids))
        try:
            _http_json(
                "POST",
                self.ack_base,
                body={"ackIds": ack_ids},
                headers={"Authorization": f"Bearer {self.tm.get_token()}"},
            )
        except RuntimeError:
            logger.exception("Pub/Sub ack error")


# ---------------------------------------------------------------------------
# DeepSeek triage
# ---------------------------------------------------------------------------


TRIAGE_SYSTEM_PROMPT = """You are a personal email triage assistant. Your job is to classify incoming emails.

Output ONLY a JSON object with these fields:
{
  "category": "important" | "umons" | "newsletter" | "admin" | "spam",
  "importance_score": 0.0 to 1.0,
  "summary_fr": "one-line French summary of the email",
  "action_needed": true | false,
  "action_description_fr": "what action is expected (or empty string if none)",
  "deadline": "deadline date/time if any (or empty string)",
  "sender_type": "human" | "system" | "noreply" | "listserv" | "unknown"
}

Classification rules:
- "important": mails requiring action/reply, deadlines, exams, administrative decisions, personal conversations
- "umons": mails from @umons.ac.be addresses (faculty, courses)
- "newsletter": mailing lists, promotional, news digests
- "admin": system notifications, login alerts, receipts, confirmations
- "spam": unsolicited, promotional, phishing

UMONS mails are ALWAYS notified. Newsletters and spam are NEVER notified.
Admin mails are notified only if importance_score > 0.7.
"""


def classify_email(mail: dict) -> dict:
    """Classify an email using DeepSeek API. Returns structured triage dict."""
    if not DEEPSEEK_API_KEY:
        logger.warning("DEEPSEEK_API_KEY not set — using heuristic classification")
        return _heuristic_classify(mail)

    user_prompt = f"""Email:
From: {mail["from"]}
Subject: {mail["subject"]}
Date: {mail["date"]}
Body (truncated):
{mail["body"][:2000]}
"""

    body = json.dumps(
        {
            "model": DEEPSEEK_MODEL,
            "messages": [
                {"role": "system", "content": TRIAGE_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": 500,
            "temperature": 0.1,
        }
    ).encode("utf-8")

    for attempt in range(1, 4):
        try:
            req = urllib.request.Request(DEEPSEEK_CHAT_URL, data=body, method="POST")
            req.add_header("Content-Type", "application/json")
            req.add_header("Authorization", f"Bearer {DEEPSEEK_API_KEY}")
            req.add_header("Accept", "application/json")

            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
                content = (
                    data.get("choices", [{}])[0].get("message", {}).get("content", "{}")
                )
                # Extract JSON from the response
                return _parse_classification(content, mail)

        except urllib.error.HTTPError as e:
            logger.error("DeepSeek HTTP %s (attempt %s/3)", e.code, attempt)
            if e.code == 429:
                time.sleep(2**attempt)
                continue
            if attempt < 3 and 500 <= e.code < 600:
                time.sleep(2**attempt)
                continue
            break
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            logger.error("DeepSeek network error (attempt %s/3): %s", attempt, e)
            if attempt < 3:
                time.sleep(2**attempt)
                continue
            break

    logger.warning("DeepSeek classification failed, falling back to heuristics")
    return _heuristic_classify(mail)


def _parse_classification(raw: str, mail: dict) -> dict:
    """Parse the DeepSeek JSON response, with fallback to heuristics."""
    try:
        # Handle markdown code blocks
        raw = raw.strip()
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1]
            if raw.endswith("```"):
                raw = raw[:-3]
            raw = raw.strip()
        if raw.startswith("json"):
            raw = raw[4:].strip()
        result = json.loads(raw)
        return {
            "category": result.get("category", "important"),
            "importance_score": float(result.get("importance_score", 0.5)),
            "summary_fr": result.get("summary_fr", mail["snippet"]),
            "action_needed": bool(result.get("action_needed", False)),
            "action_description_fr": result.get("action_description_fr", ""),
            "deadline": result.get("deadline", ""),
            "sender_type": result.get("sender_type", "unknown"),
        }
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        logger.warning("Failed to parse DeepSeek response: %s", e)
        return _heuristic_classify(mail)


def _heuristic_classify(mail: dict) -> dict:
    """Rule-based classification fallback when DeepSeek is unavailable."""
    subject = mail.get("subject", "").lower()
    from_addr = mail.get("from", "").lower()

    # UMONS detection
    if "@umons.ac.be" in from_addr:
        return {
            "category": "umons",
            "importance_score": 0.8,
            "summary_fr": mail.get("snippet", ""),
            "action_needed": True,
            "action_description_fr": "Vérifier le mail UMONS",
            "deadline": "",
            "sender_type": "human",
        }

    # Important keywords
    important_kw = [
        "deadline",
        "urgence",
        "urgent",
        "action requise",
        "examen",
        "rapport",
        "important",
        "rappel",
        "échéance",
        "convocation",
    ]
    if any(kw in subject for kw in important_kw):
        return {
            "category": "important",
            "importance_score": 0.8,
            "summary_fr": mail.get("snippet", ""),
            "action_needed": True,
            "action_description_fr": "Action probablement requise",
            "deadline": "",
            "sender_type": "unknown",
        }

    # Newsletter detection
    newsletter_kw = [
        "newsletter",
        "news",
        "digest",
        "weekly",
        "bulletin",
        "offre",
        "promo",
        "soldes",
        "découvrez",
        "abonnement",
    ]
    if any(kw in subject for kw in newsletter_kw) or "noreply" in from_addr:
        return {
            "category": "newsletter",
            "importance_score": 0.1,
            "summary_fr": mail.get("snippet", ""),
            "action_needed": False,
            "action_description_fr": "",
            "deadline": "",
            "sender_type": "listserv" if "noreply" in from_addr else "unknown",
        }

    # System/admin detection
    admin_kw = [
        "notification",
        "alerte",
        "security",
        "login",
        "connexion",
        "password",
        "reset",
        "confirm",
        "receipt",
        "facture",
        "paiement",
    ]
    if any(kw in subject for kw in admin_kw):
        return {
            "category": "admin",
            "importance_score": 0.3,
            "summary_fr": mail.get("snippet", ""),
            "action_needed": False,
            "action_description_fr": "",
            "deadline": "",
            "sender_type": "system",
        }

    # Default: moderate importance
    return {
        "category": "important",
        "importance_score": 0.5,
        "summary_fr": mail.get("snippet", ""),
        "action_needed": False,
        "action_description_fr": "",
        "deadline": "",
        "sender_type": "unknown",
    }


def should_notify(classification: dict) -> bool:
    """Decide whether to send a Discord notification based on classification."""
    category = classification.get("category", "")
    score = classification.get("importance_score", 0.0)

    # Always notify
    if category in ("important", "umons"):
        return True
    # Admin only if high importance
    if category == "admin" and score > 0.7:
        return True
    # Never notify
    return False


# ---------------------------------------------------------------------------
# Discord notification
# ---------------------------------------------------------------------------


def send_discord_notification(mail: dict, classification: dict) -> bool:
    """Send a formatted notification to the Discord webhook."""
    if not DISCORD_WEBHOOK_URL:
        logger.info("DISCORD_WEBHOOK_URL not set — skipping notification")
        return False

    category = classification.get("category", "important")
    score = classification.get("importance_score", 0.0)
    summary = classification.get("summary_fr", mail.get("snippet", ""))
    action = classification.get("action_description_fr", "")
    deadline = classification.get("deadline", "")

    # Category emoji
    emoji_map = {
        "important": "🔴",
        "umons": "🎓",
        "admin": "⚙️",
        "newsletter": "📰",
        "spam": "🗑️",
    }
    emoji = emoji_map.get(category, "📧")

    # Build Discord embed
    subject = mail.get("subject", "(no subject)")
    from_addr = mail.get("from", "")
    date_str = mail.get("date", "")[:25]

    embed = {
        "title": f"{emoji} {subject}",
        "color": 0xFF4444
        if category == "important"
        else 0x4499FF
        if category == "umons"
        else 0x888888,
        "fields": [
            {"name": "De", "value": from_addr or "?", "inline": True},
            {"name": "Catégorie", "value": f"{category} ({score:.0%})", "inline": True},
            {
                "name": "Résumé",
                "value": summary[:1000] or "(pas de contenu)",
                "inline": False,
            },
        ],
        "footer": {"text": f"📅 {date_str}"},
    }

    if action:
        embed["fields"].append(
            {"name": "⚠️ Action", "value": action[:1000], "inline": False}
        )
    if deadline:
        embed["fields"].append(
            {"name": "⏰ Deadline", "value": deadline, "inline": False}
        )

    payload = json.dumps({"embeds": [embed]}).encode("utf-8")

    try:
        req = urllib.request.Request(DISCORD_WEBHOOK_URL, data=payload, method="POST")
        req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 204:
                logger.info("Discord notification sent: %s", subject)
                return True
            logger.warning("Discord webhook returned HTTP %s", resp.status)
            return False
    except Exception as e:
        logger.error("Failed to send Discord notification: %s", e)
        return False


# ---------------------------------------------------------------------------
# State persistence (historyId cursor)
# ---------------------------------------------------------------------------


def load_history_id() -> str:
    """Load the last seen historyId from state file."""
    state_file = STATE_DIR / "gmail-history-id.txt"
    if state_file.exists():
        hid = state_file.read_text().strip()
        logger.debug("Loaded historyId=%s", hid)
        return hid
    logger.info("No existing historyId found — will start fresh watch")
    return ""


def save_history_id(history_id: str) -> None:
    """Save the current historyId to state file."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file = STATE_DIR / "gmail-history-id.txt"
    state_file.write_text(history_id)
    logger.debug("Saved historyId=%s", history_id)


def load_watch_expiry() -> float:
    """Load the watch expiration timestamp."""
    state_file = STATE_DIR / "gmail-watch-expiry.txt"
    if state_file.exists():
        try:
            return float(state_file.read_text().strip())
        except ValueError:
            pass
    return 0.0


def save_watch_expiry(expiry_epoch: float) -> None:
    """Save the watch expiration timestamp."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file = STATE_DIR / "gmail-watch-expiry.txt"
    state_file.write_text(str(int(expiry_epoch)))


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------


def load_seen_ids() -> set[str]:
    """Load set of already-processed message IDs."""
    state_file = STATE_DIR / "gmail-seen-ids.json"
    if state_file.exists():
        try:
            return set(json.loads(state_file.read_text()))
        except (json.JSONDecodeError, ValueError):
            pass
    return set()


def save_seen_ids(seen: set[str]) -> None:
    """Save set of processed message IDs (keep last 5000)."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    ids_list = list(seen)[-5000:]
    state_file = STATE_DIR / "gmail-seen-ids.json"
    state_file.write_text(json.dumps(ids_list))


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------


_shutdown = False


def _on_signal(signum, frame):
    global _shutdown
    logger.info("Received signal %s, shutting down", signum)
    _shutdown = True


def validate_env() -> list[str]:
    """Validate required environment variables. Returns list of missing vars."""
    required = {
        "GMAIL_CLIENT_ID": GMAIL_CLIENT_ID,
        "GMAIL_CLIENT_SECRET": GMAIL_CLIENT_SECRET,
        "GMAIL_REFRESH_TOKEN": GMAIL_REFRESH_TOKEN,
        "GMAIL_PUBSUB_TOPIC": GMAIL_PUBSUB_TOPIC,
        "GMAIL_PUBSUB_SUBSCRIPTION": GMAIL_PUBSUB_SUBSCRIPTION,
        "DEEPSEEK_API_KEY": DEEPSEEK_API_KEY,
        "DISCORD_WEBHOOK_URL": DISCORD_WEBHOOK_URL,
    }
    return [name for name, value in required.items() if not value]


def process_new_messages(gmail: GmailAPI, seen_ids: set[str]) -> set[str]:
    """Fetch history changes, process new messages, return updated seen_ids."""
    history_id = load_history_id()
    if not history_id:
        # First run: set up watch and grab current historyId
        watch_resp = gmail.setup_watch()
        history_id = str(watch_resp.get("historyId", ""))
        if history_id:
            save_history_id(history_id)
        expiry = watch_resp.get("expiration")
        if expiry:
            expiry_epoch = int(
                datetime.fromisoformat(expiry.replace("Z", "+00:00")).timestamp()
            )
            save_watch_expiry(expiry_epoch)
        return seen_ids

    # Fetch history
    try:
        history_entries = gmail.get_history(history_id)
    except RuntimeError:
        logger.exception("Failed to fetch history — will retry")
        return seen_ids

    new_messages_ids: list[str] = []
    for entry in history_entries:
        for msg_added in entry.get("messagesAdded", []):
            msg = msg_added.get("message", {})
            msg_id = msg.get("id", "")
            if msg_id and msg_id not in seen_ids:
                new_messages_ids.append(msg_id)

    if not new_messages_ids:
        # Update historyId even if no new messages
        if history_entries:
            latest = history_entries[-1].get("id", "")
            if latest:
                save_history_id(latest)
        return seen_ids

    logger.info("Found %s new message(s)", len(new_messages_ids))
    new_seen = set(seen_ids)

    for msg_id in new_messages_ids:
        if _shutdown:
            break
        try:
            full_msg = gmail.get_message(msg_id)
            mail = parse_message(full_msg)
        except RuntimeError:
            logger.exception("Failed to fetch message %s", msg_id)
            continue

        logger.info("Classifying: %s — %s", mail["subject"], mail["from"])
        classification = classify_email(mail)

        if should_notify(classification):
            logger.info(
                "📬 Notifying: %s (category=%s, score=%.0f%%)",
                mail["subject"],
                classification["category"],
                classification["importance_score"] * 100,
            )
            send_discord_notification(mail, classification)
        else:
            logger.info(
                "🔇 Skipped: %s (category=%s, score=%.0f%%)",
                mail["subject"],
                classification["category"],
                classification["importance_score"] * 100,
            )

        new_seen.add(msg_id)

    # Update state
    if history_entries:
        latest = history_entries[-1].get("id", "")
        if latest:
            save_history_id(latest)
    save_seen_ids(new_seen)

    return new_seen


def check_and_renew_watch(gmail: GmailAPI) -> None:
    """Renew the Gmail watch if it's about to expire."""
    expiry = load_watch_expiry()
    now = time.time()
    renew_threshold = now + (WATCH_RENEWAL_DAYS * 86400)

    if expiry == 0 or now > expiry - 3600:
        logger.info("Watch expired or near expiry — renewing")
        watch_resp = gmail.setup_watch()
        new_history_id = str(watch_resp.get("historyId", ""))
        if new_history_id:
            save_history_id(new_history_id)
        new_expiry = watch_resp.get("expiration")
        if new_expiry:
            expiry_epoch = int(
                datetime.fromisoformat(new_expiry.replace("Z", "+00:00")).timestamp()
            )
            save_watch_expiry(expiry_epoch)
    elif expiry < renew_threshold:
        logger.info(
            "Watch expires soon (%s) — renewing early",
            datetime.fromtimestamp(expiry).isoformat(),
        )
        watch_resp = gmail.setup_watch()
        new_expiry = watch_resp.get("expiration")
        if new_expiry:
            expiry_epoch = int(
                datetime.fromisoformat(new_expiry.replace("Z", "+00:00")).timestamp()
            )
            save_watch_expiry(expiry_epoch)


def run() -> int:
    """Main loop: pull Pub/Sub, process messages, repeat."""
    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)

    logging.basicConfig(
        level=getattr(logging, LOG_LEVEL, logging.INFO),
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    )

    missing = validate_env()
    if missing:
        logger.error("Missing environment variables: %s", ", ".join(missing))
        return 1

    logger.info("Starting Gmail Pub/Sub notifier")
    logger.info("  Pub/Sub topic: %s", GMAIL_PUBSUB_TOPIC)
    logger.info("  Pub/Sub subscription: %s", GMAIL_PUBSUB_SUBSCRIPTION)
    logger.info("  State dir: %s", STATE_DIR)

    token_manager = TokenManager(
        GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN
    )
    gmail = GmailAPI(token_manager)
    pubsub = PubSubClient(token_manager)

    seen_ids = load_seen_ids()
    logger.info("Loaded %s previously seen message IDs", len(seen_ids))

    # Initial watch setup
    check_and_renew_watch(gmail)

    consecutive_errors = 0

    while not _shutdown:
        try:
            # Renew watch if needed
            check_and_renew_watch(gmail)

            # Pull Pub/Sub messages
            messages = pubsub.pull(max_messages=PUBSUB_MAX_MESSAGES, timeout=30)
            ack_ids = []

            if messages:
                for msg in messages:
                    ack_id = msg.get("ackId", "")
                    if ack_id:
                        ack_ids.append(ack_id)

                # Process new messages via Gmail history
                seen_ids = process_new_messages(gmail, seen_ids)

                # Acknowledge Pub/Sub messages
                if ack_ids:
                    pubsub.ack(ack_ids)

                consecutive_errors = 0
            else:
                # No messages — normal idle
                logger.debug("No Pub/Sub messages in this pull window")
                consecutive_errors = 0

        except RuntimeError as e:
            consecutive_errors += 1
            logger.error(
                "Error in main loop (consecutive=%s): %s", consecutive_errors, e
            )
            if consecutive_errors > 10:
                logger.critical("Too many consecutive errors, exiting")
                return 1
            time.sleep(min(consecutive_errors * 5, 60))
        except Exception:
            logger.exception("Unexpected error in main loop")
            consecutive_errors += 1
            if consecutive_errors > 10:
                logger.critical("Too many consecutive errors, exiting")
                return 1
            time.sleep(min(consecutive_errors * 5, 60))

    logger.info("Shutdown complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
