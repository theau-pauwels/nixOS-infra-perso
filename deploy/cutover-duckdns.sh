#!/usr/bin/env bash
set -euo pipefail

DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN:-theau-vps}"
TARGET_IP="${TARGET_IP:-82.165.20.195}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN:?Set DUCKDNS_TOKEN in your environment before running this script.}"

response="$(
  curl -fsSL "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${TARGET_IP}&verbose=true"
)"

if [[ "${response}" != OK* ]]; then
  echo "DuckDNS update failed: ${response}" >&2
  exit 1
fi

echo "DuckDNS update accepted for ${DUCKDNS_SUBDOMAIN}.duckdns.org -> ${TARGET_IP}"
echo "Verify propagation with: ./deploy/wait-for-duckdns.sh"
