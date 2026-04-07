#!/usr/bin/env python3
from __future__ import annotations

import getpass
import sys

try:
    import bcrypt
except ImportError as exc:
    print("bcrypt is required. Run this from the flake devShell or install python3-bcrypt first.", file=sys.stderr)
    raise SystemExit(1) from exc


password = getpass.getpass("WGDashboard admin password: ")
confirm = getpass.getpass("Confirm password: ")
if password != confirm:
    print("Passwords do not match.", file=sys.stderr)
    raise SystemExit(1)

print(bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8"))
