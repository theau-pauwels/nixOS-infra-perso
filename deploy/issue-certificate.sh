#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-IONOS-VPS2-DEPLOY}"
DOMAIN="${DOMAIN:-theau-vps.duckdns.org}"
DOMAINS="${DOMAINS:-$DOMAIN}"
CERT_NAME="${CERT_NAME:-$DOMAIN}"
EMAIL="${EMAIL:-theau.pauwels@gmail.com}"

current_bundle="$(ssh "$TARGET_HOST" 'readlink -f /opt/theau-vps/current 2>/dev/null || true')"
if [[ -z "$current_bundle" ]]; then
  echo "No current generation found on the target host." >&2
  exit 1
fi

domain_args=""
for domain in $DOMAINS; do
  domain_args="$domain_args -d '$domain'"
done

ssh "$TARGET_HOST" "sudo ${current_bundle}/share/theau-vps/certbot-package/bin/certbot certonly --webroot -w /var/lib/theau-vps/acme-challenge --cert-name '$CERT_NAME' $domain_args -m '$EMAIL' --agree-tos --non-interactive --keep-until-expiring"
echo "Certificate issued or already valid for $DOMAINS"
echo "Re-run deploy/activate to switch nginx to HTTPS mode."
