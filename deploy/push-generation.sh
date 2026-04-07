#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

TARGET_HOST="${TARGET_HOST:-IONOS-VPS2-DEPLOY}"
SECRETS_FILE="${SECRETS_FILE:-hosts/theau-vps/secrets.enc.yaml}"
SOPS_BIN="${SOPS_BIN:-$REPO_ROOT/.tools/sops/sops-v3.12.2.linux.amd64}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Missing encrypted secrets file: $SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -x "$SOPS_BIN" ]]; then
  echo "Missing sops binary: $SOPS_BIN" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

bundle_path="$(nix build --no-link --print-out-paths .#theau-vps-bundle)"
generation_id="$(date +%Y%m%d%H%M%S)"
remote_generation="/opt/theau-vps/generations/$generation_id"
remote_secrets="/tmp/theau-vps-secrets.$generation_id.json"
remote_store="ssh://$TARGET_HOST?remote-program=sudo%20/nix/var/nix/profiles/default/bin/nix-store"

"$SOPS_BIN" -d --output-type json "$SECRETS_FILE" > "$tmpdir/secrets.json"
nix copy --to "$remote_store" "$bundle_path"
scp "$tmpdir/secrets.json" "$TARGET_HOST:$remote_secrets"

current_bundle="$(ssh "$TARGET_HOST" 'readlink -f /opt/theau-vps/current 2>/dev/null || true')"

ssh "$TARGET_HOST" "sudo mkdir -p /opt/theau-vps/generations && sudo ln -sfn '$bundle_path' '$remote_generation'"

if ssh "$TARGET_HOST" "sudo '$remote_generation/bin/activate-theau-vps-generation' --secrets-json '$remote_secrets'"; then
  ssh "$TARGET_HOST" "sudo ln -sfn '$remote_generation' /opt/theau-vps/current && sudo rm -f '$remote_secrets'"
  echo "Deployment succeeded: $remote_generation"
  exit 0
fi

echo "Deployment failed, attempting rollback" >&2
if [[ -n "$current_bundle" ]]; then
  ssh "$TARGET_HOST" "sudo '$current_bundle/bin/activate-theau-vps-generation' --secrets-json '$remote_secrets' || true"
fi
ssh "$TARGET_HOST" "sudo rm -f '$remote_secrets'"
exit 1
