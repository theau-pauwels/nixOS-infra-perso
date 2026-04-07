#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
AGE_BIN_DEFAULT="${REPO_ROOT}/.tools/age/extracted/usr/bin/age"

if [[ -x "${AGE_BIN_DEFAULT}" ]]; then
  AGE_BIN="${AGE_BIN_DEFAULT}"
elif command -v age >/dev/null 2>&1; then
  AGE_BIN="$(command -v age)"
else
  echo "Could not find an age binary. Expected ${AGE_BIN_DEFAULT} or age in PATH." >&2
  exit 1
fi

"${SCRIPT_DIR}/harden-local-secrets.sh" >/dev/null

STAMP="$(date +%F-%H%M%S)"
OUTPUT_DIR="${REPO_ROOT}/local-secrets/archives"
OUTPUT_PATH="${OUTPUT_DIR}/plaintext-secret-vault-${STAMP}.tar.gz.age"

mkdir -p "${OUTPUT_DIR}"
chmod 700 "${OUTPUT_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PAYLOAD_DIR="${TMP_DIR}/payload"
mkdir -p "${PAYLOAD_DIR}/repo-local-secrets" "${PAYLOAD_DIR}/home-config-sops-age"

cp "${HOME}/.config/sops/age/keys.txt" "${PAYLOAD_DIR}/home-config-sops-age/keys.txt"

if compgen -G "${REPO_ROOT}/local-secrets/*" >/dev/null; then
  find "${REPO_ROOT}/local-secrets" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' path; do
    cp "${path}" "${PAYLOAD_DIR}/repo-local-secrets/"
  done
fi

if [[ -f "${REPO_ROOT}/local-secrets/theau-vps-ops.env" ]]; then
  cp "${REPO_ROOT}/local-secrets/theau-vps-ops.env" "${PAYLOAD_DIR}/repo-local-secrets/"
fi

cat > "${PAYLOAD_DIR}/MANIFEST.txt" <<EOF
Plaintext secret vault
Generated: $(date --iso-8601=seconds)
Repository: ${REPO_ROOT}

Contents:
$(cd "${PAYLOAD_DIR}" && find . -type f | sort)
EOF

(cd "${PAYLOAD_DIR}" && sha256sum $(find . -type f | sort) > SHA256SUMS)

ARCHIVE_PATH="${TMP_DIR}/plaintext-secret-vault-${STAMP}.tar.gz"
tar -C "${PAYLOAD_DIR}" -czf "${ARCHIVE_PATH}" .

echo "Creating passphrase-encrypted vault at ${OUTPUT_PATH}"
echo "age will prompt you for the vault passphrase."
"${AGE_BIN}" --passphrase -o "${OUTPUT_PATH}" "${ARCHIVE_PATH}"
chmod 600 "${OUTPUT_PATH}"

echo
echo "Vault created:"
echo "  ${OUTPUT_PATH}"
sha256sum "${OUTPUT_PATH}"
echo
echo "Decrypt later with:"
echo "  ${AGE_BIN} --decrypt -o /tmp/plaintext-secret-vault.tar.gz ${OUTPUT_PATH}"
