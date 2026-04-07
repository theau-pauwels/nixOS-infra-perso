#!/usr/bin/env bash
set -euo pipefail

DOMAIN_FQDN="${DOMAIN_FQDN:-theau-vps.duckdns.org}"
TARGET_IP="${TARGET_IP:-82.165.20.195}"
TIMEOUT_SEC="${TIMEOUT_SEC:-300}"

deadline=$((SECONDS + TIMEOUT_SEC))

while (( SECONDS < deadline )); do
  resolved_ip="$(getent ahostsv4 "$DOMAIN_FQDN" | awk '/STREAM/ {print $1; exit}')"
  if [[ "$resolved_ip" == "$TARGET_IP" ]]; then
    echo "DuckDNS propagation confirmed: ${DOMAIN_FQDN} -> ${resolved_ip}"
    exit 0
  fi

  echo "Waiting for ${DOMAIN_FQDN} -> ${TARGET_IP} (currently: ${resolved_ip:-unresolved})"
  sleep 10
done

echo "Timed out waiting for ${DOMAIN_FQDN} -> ${TARGET_IP}" >&2
exit 1
