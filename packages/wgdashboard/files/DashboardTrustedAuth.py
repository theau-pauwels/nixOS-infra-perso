import os
import re

from flask import session


def _truthy(value):
    return str(value).lower() in ("1", "true", "yes", "on")


def _groups(value):
    return {group for group in re.split(r"[\s,]+", value or "") if group}


def _allowed_remote_addr(request):
    allowed = {
        addr.strip()
        for addr in os.getenv(
            "WGDASHBOARD_TRUSTED_AUTH_ALLOWED_REMOTE_ADDRS",
            "127.0.0.1,::1",
        ).split(",")
        if addr.strip()
    }
    return not allowed or request.remote_addr in allowed


def trusted_auth_enabled():
    return _truthy(os.getenv("WGDASHBOARD_TRUSTED_AUTH", "false"))


def is_trusted_admin_session():
    return (
        trusted_auth_enabled()
        and session.get("role") == "admin"
        and session.get("SignInMethod") == "Authelia"
    )


def sync_trusted_admin_session(request):
    if not trusted_auth_enabled() or not _allowed_remote_addr(request):
        return True, None

    user = request.headers.get("Remote-User", "")
    if not user:
        return True, None

    required_group = os.getenv("WGDASHBOARD_TRUSTED_AUTH_REQUIRED_GROUP", "")
    user_groups = _groups(request.headers.get("Remote-Groups", ""))
    if required_group and required_group not in user_groups:
        session.clear()
        return False, f"Authelia user {user} is not in group {required_group}."

    session["role"] = "admin"
    session["username"] = f"authelia:{user}"
    session["AutheliaUser"] = user
    session["AutheliaGroups"] = sorted(user_groups)
    session["SignInMethod"] = "Authelia"
    session.permanent = True
    return True, None
