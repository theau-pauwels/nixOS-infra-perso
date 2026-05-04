"""Mail reader — Gmail via IMAP with App Password. Read-only, never marks as read."""
import email
import imaplib
import logging
import ssl
from datetime import datetime, timedelta
from email.header import decode_header
from email.utils import parsedate_to_datetime
from typing import Optional

logger = logging.getLogger(__name__)


class GmailIMAPReader:
    """Read-only Gmail access via IMAP + App Password."""

    def __init__(self, username: str, app_password: str, host: str = "imap.gmail.com", port: int = 993):
        if not username or not app_password:
            raise ValueError("GMAIL_USERNAME and GMAIL_APP_PASSWORD are required")
        self.username = username
        self.password = app_password
        self.host = host
        self.port = port

    def fetch_recent(self, max_results: int = 20, days: int = 3) -> list[dict]:
        """Fetch recent unread emails from inbox."""
        return self._fetch("UNSEEN", max_results, days)

    def fetch_important(self, max_results: int = 10, days: int = 5) -> list[dict]:
        """Fetch recent emails from inbox (both read and unread)."""
        return self._fetch("ALL", max_results, days)

    def _fetch(self, criteria: str, max_results: int, days: int) -> list[dict]:
        """Low-level IMAP fetch."""
        ctx = ssl.create_default_context()
        conn = imaplib.IMAP4_SSL(self.host, self.port, ssl_context=ctx)
        try:
            conn.login(self.username, self.password)
            conn.select("INBOX", readonly=True)  # read-only — never marks as read

            since = (datetime.now() - timedelta(days=days)).strftime("%d-%b-%Y")
            status, ids = conn.search(None, f"({criteria} SINCE {since})")
            if status != "OK":
                logger.error("IMAP search failed: %s", ids)
                return []

            ids_list = ids[0].split()
            if not ids_list:
                return []

            fetch_ids = ids_list[-max_results:]  # last N messages
            mails = []
            for mid in reversed(fetch_ids):
                try:
                    status, data = conn.fetch(mid, "(RFC822)")
                    if status != "OK" or not data or not data[0]:
                        continue
                    raw = data[0][1] if isinstance(data[0], tuple) else data[0]
                    msg = email.message_from_bytes(raw)
                    mail = _parse_email(msg, mid.decode())
                    if mail:
                        mails.append(mail)
                except Exception as e:
                    logger.warning("Failed to parse message %s: %s", mid, e)

            return mails
        finally:
            conn.logout()


def _parse_email(msg, msg_id: str) -> Optional[dict]:
    """Parse a raw email.message into a clean dict."""
    subject = _decode_header(msg.get("Subject", ""))
    from_addr = _decode_header(msg.get("From", ""))
    to_addr = _decode_header(msg.get("To", ""))
    date_raw = msg.get("Date", "")

    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    body = payload.decode("utf-8", errors="replace")
                    break
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            body = payload.decode("utf-8", errors="replace")

    snippet = body[:300].replace("\n", " ").strip() if body else ""

    # Truncate for LLM
    if len(body) > 3000:
        body = body[:3000] + "\n\n[... truncated]"

    is_important = "X-Priority: 1" in str(msg)  # rough heuristic

    return {
        "id": msg_id,
        "thread_id": msg.get("Message-ID", ""),
        "from": from_addr,
        "to": to_addr,
        "subject": subject or "(no subject)",
        "date": date_raw,
        "snippet": snippet,
        "body": body,
        "is_important": is_important,
    }


def _decode_header(value: str) -> str:
    """Decode RFC2047 encoded email headers."""
    parts = decode_header(value)
    result = ""
    for text, charset in parts:
        if isinstance(text, bytes):
            result += text.decode(charset or "utf-8", errors="replace")
        else:
            result += str(text)
    return result


def format_mail_summary(mails: list[dict]) -> str:
    """Format mails into Markdown summary."""
    if not mails:
        return "No new mails."
    lines = []
    for m in mails:
        dt = m["date"][:16] if m["date"] else "?"
        important = "🔴 " if m.get("is_important") else ""
        lines.append(f"### {important}{m['subject']}")
        lines.append(f"- From: {m['from']}")
        lines.append(f"- Date: {dt}")
        lines.append(f"- Summary: {m['snippet']}")
        lines.append("")
    return "\n".join(lines)


def mail_to_markdown(mails: list[dict], source: str = "gmail") -> str:
    """Convert mails to journal Markdown format."""
    today = datetime.now().strftime("%Y-%m-%d")
    lines = [f"## {today} — {source}", ""]
    for m in mails:
        lines.append(f"### {m['subject']}")
        lines.append(f"- Source: {source}")
        lines.append(f"- From: {m['from']}")
        lines.append(f"- Date: {m['date']}")
        lines.append(f"- Résumé: {m['snippet']}")
        lines.append(f"- Action recommandée: ")
        lines.append(f"- Deadline: ")
        lines.append(f"- Priorité: ")
        lines.append(f"- Brouillon nécessaire: non")
        lines.append("")
    return "\n".join(lines)
