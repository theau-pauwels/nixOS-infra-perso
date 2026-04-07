#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("VPS_wg0-server/wg0.json")
    if not source.exists():
      print(f"Missing wg-easy JSON export: {source}", file=sys.stderr)
      return 1

    data = json.loads(source.read_text(encoding="utf-8"))

    print("ssh:")
    print("  deployAuthorizedKeys: []")
    print("")
    print("wireguard:")
    print(f"  serverPrivateKey: {json.dumps(data['server']['privateKey'])}")
    print("  peers:")
    for client in data["clients"].values():
        print(f"    - publicKey: {json.dumps(client['publicKey'])}")
        print(f"      privateKey: {json.dumps(client['privateKey'])}")
        print(f"      presharedKey: {json.dumps(client['preSharedKey'])}")
    print("")
    print("wgDashboard:")
    print('  adminPasswordHash: "$2b$12$replace-me-with-a-bcrypt-hash"')
    print('  totpKey: "REPLACEWITHBASE32TOTPKEY"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
