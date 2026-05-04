"""Git operations on the journal directory."""
import subprocess
from pathlib import Path
from datetime import datetime

def _git(cmd: list, cwd: Path):
    """Run a git command, return success boolean."""
    try:
        subprocess.run(["git"] + cmd, cwd=cwd, check=True,
                       capture_output=True, text=True)
        return True
    except subprocess.CalledProcessError:
        return False

def init_journal(journal_dir: Path) -> bool:
    """Initialize git in journal directory if not already a repo."""
    if (journal_dir / ".git").exists():
        return True
    _git(["init", "-b", "main"], journal_dir)
    _git(["config", "user.name", "personal-secretary-bot"], journal_dir)
    _git(["config", "user.email", "personal-secretary-bot@ionos-vps.local"], journal_dir)
    return True

def journal_commit(journal_dir: Path, message: str) -> bool:
    """Stage all changes in journal and commit."""
    if not (journal_dir / ".git").exists():
        return False
    _git(["add", "-A"], journal_dir)
    return _git(["commit", "-m", message, "--allow-empty"], journal_dir)

def journal_status(journal_dir: Path) -> str:
    """Get git status for journal directory."""
    try:
        result = subprocess.run(["git", "-C", str(journal_dir), "status", "--short"],
                                capture_output=True, text=True)
        return result.stdout.strip() or "(no changes)"
    except subprocess.CalledProcessError:
        return "(git error)"
