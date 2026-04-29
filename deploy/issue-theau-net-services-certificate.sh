#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

CERT_NAME=theau-net-services \
DOMAINS="authelia.theau.net coolify.theau.net wg.theau.net" \
  "$SCRIPT_DIR/issue-certificate.sh"
