#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def load_inventory(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def validate_public_key(public_key: str) -> None:
    prefixes = ("ssh-ed25519 ", "ssh-rsa ", "ecdsa-sha2-")
    if not public_key.startswith(prefixes):
        raise SystemExit(f"Unsupported SSH public key format: {public_key!r}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Register or update a trusted SSH public key in the host inventory."
    )
    parser.add_argument("--host-id", default="theau-vps", help="Host inventory to update.")
    parser.add_argument("--id", required=True, help="Stable identifier for the key entry.")
    parser.add_argument("--file", required=True, help="Path to the .pub file to register.")
    parser.add_argument(
        "--description",
        default="",
        help="Short human-readable description for this key.",
    )
    parser.add_argument(
        "--role",
        action="append",
        default=[],
        help="Role label to attach to the key entry. Repeat for multiple roles.",
    )
    args = parser.parse_args()

    key_path = Path(args.file).expanduser().resolve()
    public_key = key_path.read_text(encoding="utf-8").strip()
    validate_public_key(public_key)

    inventory_path = (
        Path(__file__).resolve().parent.parent
        / "hosts"
        / args.host_id
        / "ssh-public-keys.json"
    )
    inventory = load_inventory(inventory_path)

    entry = {
        "id": args.id,
        "description": args.description,
        "publicKey": public_key,
        "roles": args.role,
    }

    updated = False
    for index, current in enumerate(inventory):
        if current["id"] == args.id:
            inventory[index] = entry
            updated = True
            break

    if not updated:
        inventory.append(entry)

    inventory.sort(key=lambda item: item["id"])
    inventory_path.write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {inventory_path}")


if __name__ == "__main__":
    main()
