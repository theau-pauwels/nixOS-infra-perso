from pathlib import Path
import sys


def replace_once(text, old, new):
    if old not in text:
        raise SystemExit(f"WGDashboard patch pattern not found: {old!r}")
    return text.replace(old, new, 1)


path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

text = replace_once(
    text,
    "from modules.NewConfigurationTemplates import NewConfigurationTemplates",
    "from modules.NewConfigurationTemplates import NewConfigurationTemplates\n"
    "from modules.DashboardTrustedAuth import is_trusted_admin_session, sync_trusted_admin_session",
)

text = replace_once(
    text,
    "        if token is None or token == \"\" or \"username\" not in session or session[\"username\"] != token:\n"
    "            return ResponseObject(False, \"Invalid authentication.\")",
    "        if is_trusted_admin_session():\n"
    "            return ResponseObject(True)\n"
    "        if token is None or token == \"\" or \"username\" not in session or session[\"username\"] != token:\n"
    "            return ResponseObject(False, \"Invalid authentication.\")",
)

api_accessed_line = "    DashboardConfig.APIAccessed = False    \n"
if api_accessed_line not in text:
    api_accessed_line = "    DashboardConfig.APIAccessed = False\n"
if api_accessed_line not in text:
    raise SystemExit("WGDashboard APIAccessed patch pattern not found")

text = text.replace(
    api_accessed_line,
    "    DashboardConfig.APIAccessed = False\n"
    "    trusted_auth_status, trusted_auth_message = sync_trusted_admin_session(request)\n"
    "    if not trusted_auth_status:\n"
    "        return ResponseObject(False, trusted_auth_message, status_code=403)\n"
    "\n",
    1,
)

path.write_text(text, encoding="utf-8")
