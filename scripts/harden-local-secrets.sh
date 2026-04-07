#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${REPO_ROOT}/local-secrets"
chmod 700 "${REPO_ROOT}/local-secrets"

find "${REPO_ROOT}/local-secrets" -type d -exec chmod 700 {} +
find "${REPO_ROOT}/local-secrets" -type f -exec chmod 600 {} +

if [[ -d "${HOME}/.config/sops" ]]; then
  chmod 700 "${HOME}/.config/sops"
fi

if [[ -d "${HOME}/.config/sops/age" ]]; then
  chmod 700 "${HOME}/.config/sops/age"
fi

if [[ -f "${HOME}/.config/sops/age/keys.txt" ]]; then
  chmod 600 "${HOME}/.config/sops/age/keys.txt"
fi

echo "Local cleartext secrets permissions hardened."
