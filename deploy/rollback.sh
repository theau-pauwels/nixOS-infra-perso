#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

TARGET_HOST="${TARGET_HOST:-IONOS-VPS2-DEPLOY}"
SECRETS_FILE="${SECRETS_FILE:-hosts/theau-vps/secrets.enc.yaml}"
GENERATION_PATH="${1:-}"
SOPS_BIN="${SOPS_BIN:-$REPO_ROOT/.tools/sops/sops-v3.12.2.linux.amd64}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Missing encrypted secrets file: $SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -x "$SOPS_BIN" ]]; then
  echo "Missing sops binary: $SOPS_BIN" >&2
  exit 1
fi

if [[ -z "$GENERATION_PATH" ]]; then
  GENERATION_PATH="$(ssh "$TARGET_HOST" 'ls -1dt /opt/theau-vps/generations/* 2>/dev/null | sed -n "2p"')"
fi

if [[ -z "$GENERATION_PATH" ]]; then
  echo "No previous generation available on the target host." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

remote_secrets="/tmp/theau-vps-rollback.$$.json"
"$SOPS_BIN" -d --output-type json "$SECRETS_FILE" > "$tmpdir/secrets.json"
scp "$tmpdir/secrets.json" "$TARGET_HOST:$remote_secrets"
ssh "$TARGET_HOST" "sudo '$GENERATION_PATH/bin/activate-theau-vps-generation' --secrets-json '$remote_secrets' && sudo ln -sfn '$GENERATION_PATH' /opt/theau-vps/current && sudo rm -f '$remote_secrets'"

echo "Rollback succeeded: $GENERATION_PATH"
