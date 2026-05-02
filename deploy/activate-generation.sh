#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: activate-theau-vps-generation --secrets-json /path/to/secrets.json
EOF
}

SECRETS_JSON=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secrets-json)
      SECRETS_JSON="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SECRETS_JSON" || ! -f "$SECRETS_JSON" ]]; then
  echo "A decrypted secrets JSON file is required." >&2
  exit 1
fi

BUNDLE_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
HOST_SPEC="$BUNDLE_ROOT/share/theau-vps/host-spec.json"
PUBLIC_PEERS="$BUNDLE_ROOT/share/theau-vps/public-peers.json"
export BUNDLE_ROOT HOST_SPEC PUBLIC_PEERS SECRETS_JSON

TARGET_USER="$(python3 - <<'PY'
import json, os
print(json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))["adminUser"])
PY
)"
TARGET_HOME="$(python3 - <<'PY'
import json, os
print(json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))["adminUserHome"])
PY
)"
TARGET_HOSTNAME="$(python3 - <<'PY'
import json, os
print(json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))["hostname"])
PY
)"
TARGET_TIMEZONE="$(python3 - <<'PY'
import json, os
print(json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))["timezone"])
PY
)"
DOMAIN="$(python3 - <<'PY'
import json, os
print(json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))["domain"])
PY
)"
SERVICE_CERT_NAME="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("certName", "theau-net-services"))
PY
)"
AUTHELIA_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("authelia", "authelia.theau.net"))
PY
)"
COOLIFY_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("coolify", "coolify.theau.net"))
PY
)"
FILE_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("file", "file.theau.net"))
PY
)"
JELLYFIN_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("jellyfin", "jellyfin.theau.net"))
PY
)"
PROWLARR_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("prowlarr", "prowlarr.theau.net"))
PY
)"
QBIT_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("qbit", "qbit.theau.net"))
PY
)"
SEER_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("seer", "seer.theau.net"))
PY
)"
WG_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("wg", "wg.theau.net"))
PY
)"
USERS_DOMAIN="$(python3 - <<'PY'
import json, os
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
print(host.get("serviceDomains", {}).get("users", "users.theau.net"))
PY
)"

install -d -m 0755 /etc/theau-vps /etc/theau-vps/nginx /etc/theau-vps/nginx/sites-enabled /etc/wireguard
install -d -m 0755 /var/lib/theau-vps /var/lib/theau-vps/acme-challenge /var/lib/wgdashboard /var/lib/wgdashboard/db /var/lib/wgdashboard/log /var/lib/wgdashboard/plugins
install -d -m 0755 /var/log/theau-vps/nginx /var/cache/theau-vps/nginx /opt/theau-vps/state

if ! getent group rustdesk-server >/dev/null; then
  groupadd --system rustdesk-server
fi

if ! id -u rustdesk-server >/dev/null 2>&1; then
  useradd --system --gid rustdesk-server --home-dir /var/lib/rustdesk-server --shell /usr/sbin/nologin --no-create-home rustdesk-server
fi

install -d -o rustdesk-server -g rustdesk-server -m 0750 /var/lib/rustdesk-server

if ! getent group authelia >/dev/null; then
  groupadd --system authelia
fi

if ! id -u authelia >/dev/null 2>&1; then
  useradd --system --gid authelia --home-dir /opt/theau-vps/state/authelia --shell /usr/sbin/nologin --no-create-home authelia
fi

if ! getent group lldap >/dev/null; then
  groupadd --system lldap
fi

if ! id -u lldap >/dev/null 2>&1; then
  useradd --system --gid lldap --home-dir /opt/theau-vps/state/lldap --shell /usr/sbin/nologin --no-create-home lldap
fi

if ! getent group prowlarr >/dev/null; then
  groupadd --system prowlarr
fi

if ! id -u prowlarr >/dev/null 2>&1; then
  useradd --system --gid prowlarr --home-dir /var/lib/prowlarr --shell /usr/sbin/nologin --no-create-home prowlarr
fi

if ! getent group seerr >/dev/null; then
  groupadd --system seerr
fi

if ! id -u seerr >/dev/null 2>&1; then
  useradd --system --gid seerr --home-dir /var/lib/seerr --shell /usr/sbin/nologin --no-create-home seerr
fi

install -d -o authelia -g authelia -m 0750 /opt/theau-vps/state/authelia
install -d -o authelia -g authelia -m 0750 /opt/theau-vps/state/authelia/assets
install -d -o lldap -g lldap -m 0750 /opt/theau-vps/state/lldap
install -d -o prowlarr -g prowlarr -m 0750 /opt/theau-vps/state/prowlarr /var/lib/prowlarr
install -d -o seerr -g seerr -m 0750 /opt/theau-vps/state/seerr /var/lib/seerr

AUTHELIA_STATE="/opt/theau-vps/state/authelia"
AUTHELIA_PASSWORD_FILE="$AUTHELIA_STATE/admin-password"
AUTHELIA_PASSWORD_HASH_FILE="$AUTHELIA_STATE/admin-password-hash"
AUTHELIA_CREDENTIALS_FILE="$AUTHELIA_STATE/admin-credentials.txt"
AUTHELIA_JWT_SECRET_FILE="$AUTHELIA_STATE/jwt-secret"
AUTHELIA_STORAGE_KEY_FILE="$AUTHELIA_STATE/storage-encryption-key"
AUTHELIA_LDAP_PASSWORD_FILE="$AUTHELIA_STATE/ldap-password"
LLDAP_STATE="/opt/theau-vps/state/lldap"
LLDAP_ADMIN_PASSWORD_FILE="$LLDAP_STATE/admin-password"
LLDAP_CREDENTIALS_FILE="$LLDAP_STATE/admin-credentials.txt"
LLDAP_JWT_SECRET_FILE="$LLDAP_STATE/jwt-secret"
LLDAP_SERVER_KEY_SEED_FILE="$LLDAP_STATE/server-key-seed"
LLDAP_CONFIG_FILE="$LLDAP_STATE/lldap_config.toml"
PROWLARR_STATE="/opt/theau-vps/state/prowlarr"
PROWLARR_API_KEY_FILE="$PROWLARR_STATE/api-key"
PROWLARR_CONFIG_FILE="/var/lib/prowlarr/config.xml"
SEERR_STATE="/opt/theau-vps/state/seerr"
SEERR_API_KEY_FILE="$SEERR_STATE/api-key"
SEERR_ENVIRONMENT_FILE="$SEERR_STATE/environment"

if [[ ! -s "$AUTHELIA_PASSWORD_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 24 > "$AUTHELIA_PASSWORD_FILE"
fi

if [[ ! -s "$AUTHELIA_JWT_SECRET_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 32 > "$AUTHELIA_JWT_SECRET_FILE"
fi

if [[ ! -s "$AUTHELIA_STORAGE_KEY_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 32 > "$AUTHELIA_STORAGE_KEY_FILE"
fi

if [[ ! -s "$LLDAP_ADMIN_PASSWORD_FILE" ]]; then
  install -o lldap -g lldap -m 0600 "$AUTHELIA_PASSWORD_FILE" "$LLDAP_ADMIN_PASSWORD_FILE"
fi

if [[ ! -s "$AUTHELIA_LDAP_PASSWORD_FILE" ]]; then
  install -o authelia -g authelia -m 0600 "$LLDAP_ADMIN_PASSWORD_FILE" "$AUTHELIA_LDAP_PASSWORD_FILE"
fi

if [[ ! -s "$LLDAP_JWT_SECRET_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 32 > "$LLDAP_JWT_SECRET_FILE"
fi

if [[ ! -s "$LLDAP_SERVER_KEY_SEED_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 32 > "$LLDAP_SERVER_KEY_SEED_FILE"
fi

if [[ ! -s "$PROWLARR_API_KEY_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 16 > "$PROWLARR_API_KEY_FILE"
fi

if [[ ! -s "$SEERR_API_KEY_FILE" ]]; then
  umask 077
  "$BUNDLE_ROOT/share/theau-vps/openssl-package/bin/openssl" rand -hex 16 > "$SEERR_API_KEY_FILE"
fi

if [[ ! -s "$AUTHELIA_PASSWORD_HASH_FILE" ]]; then
  password="$(cat "$AUTHELIA_PASSWORD_FILE")"
  "$BUNDLE_ROOT/share/theau-vps/authelia-package/bin/authelia" crypto hash generate argon2 --password "$password" \
    | sed -n 's/^Digest: //p' > "$AUTHELIA_PASSWORD_HASH_FILE"
fi

password="$(cat "$LLDAP_ADMIN_PASSWORD_FILE")"
jwt_secret="$(cat "$AUTHELIA_JWT_SECRET_FILE")"
storage_key="$(cat "$AUTHELIA_STORAGE_KEY_FILE")"
lldap_server_key_seed="$(cat "$LLDAP_SERVER_KEY_SEED_FILE")"
prowlarr_api_key="$(cat "$PROWLARR_API_KEY_FILE")"
seerr_api_key="$(cat "$SEERR_API_KEY_FILE")"

cat > "$AUTHELIA_CREDENTIALS_FILE" <<EOF
url: https://${AUTHELIA_DOMAIN}
username: theau
password: ${password}
EOF

cat > "$LLDAP_CREDENTIALS_FILE" <<EOF
url: https://${USERS_DOMAIN}
username: theau
password: ${password}
EOF

cat > "$LLDAP_CONFIG_FILE" <<EOF
ldap_host = "127.0.0.1"
ldap_port = 3890
http_host = "127.0.0.1"
http_port = 17170
http_url = "https://${USERS_DOMAIN}"
ldap_base_dn = "dc=theau,dc=net"
ldap_user_dn = "theau"
ldap_user_email = "theau.pauwels@gmail.com"
ldap_user_pass_file = "${LLDAP_ADMIN_PASSWORD_FILE}"
database_url = "sqlite://${LLDAP_STATE}/users.db?mode=rwc"
jwt_secret_file = "${LLDAP_JWT_SECRET_FILE}"
server_key_seed = "${lldap_server_key_seed}"
EOF

cat > "$PROWLARR_CONFIG_FILE" <<EOF
<Config>
  <LogLevel>info</LogLevel>
  <UrlBase></UrlBase>
  <Port>9696</Port>
  <BindAddress>127.0.0.1</BindAddress>
  <SslPort>6969</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <AuthenticationMethod>External</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>master</Branch>
  <ApiKey>${prowlarr_api_key}</ApiKey>
  <InstanceName>Prowlarr</InstanceName>
  <UpdateMechanism>External</UpdateMechanism>
</Config>
EOF

cat > "$SEERR_ENVIRONMENT_FILE" <<EOF
API_KEY=${seerr_api_key}
EOF

cat > "$AUTHELIA_STATE/configuration.yml" <<EOF
server:
  address: tcp://127.0.0.1:9091/
log:
  level: info
theme: dark
totp:
  issuer: theau.net
authentication_backend:
  ldap:
    implementation: lldap
    address: ldap://127.0.0.1:3890
    base_dn: dc=theau,dc=net
    additional_users_dn: ou=people
    additional_groups_dn: ou=groups
    user: uid=theau,ou=people,dc=theau,dc=net
access_control:
  default_policy: deny
  rules:
    - domain: ${AUTHELIA_DOMAIN}
      policy: one_factor
    - domain: ${USERS_DOMAIN}
      policy: two_factor
      subject:
        - group:admins
    - domain: ${COOLIFY_DOMAIN}
      policy: two_factor
      subject:
        - group:admins
        - group:paas-admins
    - domain: ${WG_DOMAIN}
      policy: two_factor
      subject:
        - group:wg-admin
    - domain: ${PROWLARR_DOMAIN}
      policy: two_factor
      subject:
        - group:admins
        - group:media-admins
    - domain: ${QBIT_DOMAIN}
      policy: one_factor
      subject:
        - group:admins
        - group:media-admins
        - group:media-users
    - domain: ${JELLYFIN_DOMAIN}
      policy: one_factor
      subject:
        - group:admins
        - group:media-admins
        - group:media-users
    - domain: ${FILE_DOMAIN}
      policy: one_factor
      subject:
        - group:admins
        - group:media-admins
        - group:media-users
    - domain: ${SEER_DOMAIN}
      policy: one_factor
      subject:
        - group:admins
        - group:media-admins
        - group:media-users
session:
  cookies:
    - domain: theau.net
      authelia_url: https://${AUTHELIA_DOMAIN}
      default_redirection_url: https://${USERS_DOMAIN}
storage:
  encryption_key: ${storage_key}
  local:
    path: ${AUTHELIA_STATE}/db.sqlite3
notifier:
  filesystem:
    filename: ${AUTHELIA_STATE}/notification.txt
identity_validation:
  reset_password:
    jwt_secret: ${jwt_secret}
EOF

chown authelia:authelia "$AUTHELIA_STATE/configuration.yml" "$AUTHELIA_JWT_SECRET_FILE" "$AUTHELIA_STORAGE_KEY_FILE" "$AUTHELIA_PASSWORD_FILE" "$AUTHELIA_PASSWORD_HASH_FILE" "$AUTHELIA_LDAP_PASSWORD_FILE"
chmod 0600 "$AUTHELIA_STATE/configuration.yml" "$AUTHELIA_JWT_SECRET_FILE" "$AUTHELIA_STORAGE_KEY_FILE" "$AUTHELIA_PASSWORD_FILE" "$AUTHELIA_PASSWORD_HASH_FILE" "$AUTHELIA_LDAP_PASSWORD_FILE"
chown lldap:lldap "$LLDAP_CONFIG_FILE" "$LLDAP_ADMIN_PASSWORD_FILE" "$LLDAP_JWT_SECRET_FILE" "$LLDAP_SERVER_KEY_SEED_FILE"
chmod 0600 "$LLDAP_CONFIG_FILE" "$LLDAP_ADMIN_PASSWORD_FILE" "$LLDAP_JWT_SECRET_FILE" "$LLDAP_SERVER_KEY_SEED_FILE"
chown prowlarr:prowlarr "$PROWLARR_API_KEY_FILE" "$PROWLARR_CONFIG_FILE"
chmod 0600 "$PROWLARR_API_KEY_FILE" "$PROWLARR_CONFIG_FILE"
chown seerr:seerr "$SEERR_API_KEY_FILE" "$SEERR_ENVIRONMENT_FILE"
chmod 0600 "$SEERR_API_KEY_FILE" "$SEERR_ENVIRONMENT_FILE"
chown root:root "$AUTHELIA_CREDENTIALS_FILE"
chmod 0600 "$AUTHELIA_CREDENTIALS_FILE"
chown root:root "$LLDAP_CREDENTIALS_FILE"
chmod 0600 "$LLDAP_CREDENTIALS_FILE"

python3 - <<'PY'
import json
import os
from pathlib import Path

bundle_root = Path(os.environ["BUNDLE_ROOT"])
host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
secrets = json.load(open(os.environ["SECRETS_JSON"], "r", encoding="utf-8"))
public_peers = json.load(open(os.environ["PUBLIC_PEERS"], "r", encoding="utf-8"))

keys = list(host["ssh"].get("managedAuthorizedKeys", []))
keys.extend(secrets.get("ssh", {}).get("deployAuthorizedKeys", []))
keys = list(dict.fromkeys(keys))

inventory_path = Path("/etc/theau-vps/ssh-public-keys.json")
inventory_path.write_text(json.dumps(host["ssh"].get("publicKeyInventory", []), indent=2) + "\n", encoding="utf-8")
inventory_path.chmod(0o644)

auth_keys_path = Path(host["adminUserHome"]) / ".ssh" / "authorized_keys"
auth_keys_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
auth_keys_path.write_text("\n".join(keys) + "\n", encoding="utf-8")
auth_keys_path.chmod(0o600)

peer_lookup = {
    entry["publicKey"]: entry
    for entry in secrets["wireguard"]["peers"]
}

wg_conf_lines = [
    "[Interface]",
    f"PrivateKey = {secrets['wireguard']['serverPrivateKey']}",
    f"Address = {host['wireguard']['address']}",
    f"ListenPort = {host['wireguard']['listenPort']}",
    "",
]

for peer in public_peers:
    secret_peer = peer_lookup[peer["publicKey"]]
    wg_conf_lines.extend(
        [
            f"# Name = {peer['name']}",
            "[Peer]",
            f"PublicKey = {peer['publicKey']}",
            f"PresharedKey = {secret_peer['presharedKey']}",
            f"AllowedIPs = {', '.join(peer['allowedIPs'])}",
            "",
        ]
    )

Path("/etc/wireguard/wg0.conf").write_text("\n".join(wg_conf_lines).rstrip() + "\n", encoding="utf-8")
Path("/etc/wireguard/wg0.conf").chmod(0o600)

template = (bundle_root / "share/theau-vps/wg-dashboard.ini.template").read_text(encoding="utf-8")
template = template.replace("@WGDASHBOARD_PASSWORD_HASH@", secrets["wgDashboard"]["adminPasswordHash"])
template = template.replace("@WGDASHBOARD_TOTP_KEY@", secrets["wgDashboard"]["totpKey"])
Path("/var/lib/wgdashboard/wg-dashboard.ini").write_text(template, encoding="utf-8")
Path("/var/lib/wgdashboard/wg-dashboard.ini").chmod(0o600)

https_conf = bundle_root / "share/theau-vps/nginx/site-https.conf"
http_conf = bundle_root / "share/theau-vps/nginx/site-http.conf"
cert_path = Path(f"/etc/letsencrypt/live/{host['domain']}/fullchain.pem")
selected = https_conf if cert_path.exists() else http_conf
Path("/etc/theau-vps/nginx/sites-enabled/theau-vps.conf").write_text(selected.read_text(encoding="utf-8"), encoding="utf-8")

service_https_conf = bundle_root / "share/theau-vps/nginx/services-https.conf"
service_http_conf = bundle_root / "share/theau-vps/nginx/services-http.conf"
service_domains = host.get("serviceDomains", {})
service_cert_name = service_domains.get("certName", "theau-net-services")
service_cert_path = Path(f"/etc/letsencrypt/live/{service_cert_name}/fullchain.pem")
selected_services = service_https_conf if service_cert_path.exists() else service_http_conf
Path("/etc/theau-vps/nginx/sites-enabled/theau-net-services.conf").write_text(selected_services.read_text(encoding="utf-8"), encoding="utf-8")
PY

cp "$BUNDLE_ROOT/share/theau-vps/ssh/60-theau-vps.conf" /etc/ssh/sshd_config.d/60-theau-vps.conf
cp "$BUNDLE_ROOT/share/theau-vps/sysctl.conf" /etc/sysctl.d/90-theau-vps.conf
cp "$BUNDLE_ROOT/share/theau-vps/nftables.conf" /etc/theau-vps/nftables.conf
cp "$BUNDLE_ROOT/share/theau-vps/nginx/nginx.conf" /etc/theau-vps/nginx/nginx.conf

cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-firewall.service" /etc/systemd/system/theau-vps-firewall.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-wireguard.service" /etc/systemd/system/theau-vps-wireguard.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-nginx.service" /etc/systemd/system/theau-vps-nginx.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-wgdashboard.service" /etc/systemd/system/theau-vps-wgdashboard.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-authelia.service" /etc/systemd/system/theau-vps-authelia.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-lldap.service" /etc/systemd/system/theau-vps-lldap.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-prowlarr.service" /etc/systemd/system/theau-vps-prowlarr.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-seerr.service" /etc/systemd/system/theau-vps-seerr.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-certbot-renew.service" /etc/systemd/system/theau-vps-certbot-renew.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-certbot-renew.timer" /etc/systemd/system/theau-vps-certbot-renew.timer
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-iperf3.service" /etc/systemd/system/theau-vps-iperf3.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-rustdesk-hbbs.service" /etc/systemd/system/theau-vps-rustdesk-hbbs.service
cp "$BUNDLE_ROOT/share/theau-vps/systemd/theau-vps-rustdesk-hbbr.service" /etc/systemd/system/theau-vps-rustdesk-hbbr.service

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh"
hostnamectl set-hostname "$TARGET_HOSTNAME"
timedatectl set-timezone "$TARGET_TIMEZONE"

python3 - <<'PY'
from pathlib import Path

hosts_path = Path("/etc/hosts")
hostname = Path("/etc/hostname").read_text(encoding="utf-8").strip()
lines = hosts_path.read_text(encoding="utf-8").splitlines()
updated = []
replaced = False

for line in lines:
    if line.strip().startswith("127.0.1.1"):
        if not replaced:
            updated.append(f"127.0.1.1\t{hostname}")
            replaced = True
        continue
    updated.append(line)

if not replaced:
    updated.append(f"127.0.1.1\t{hostname}")

hosts_path.write_text("\n".join(updated).rstrip() + "\n", encoding="utf-8")
PY

sysctl --system >/dev/null
/usr/sbin/sshd -t
systemctl daemon-reload
systemctl enable theau-vps-firewall.service theau-vps-wireguard.service theau-vps-nginx.service theau-vps-wgdashboard.service theau-vps-authelia.service theau-vps-lldap.service theau-vps-prowlarr.service theau-vps-seerr.service theau-vps-certbot-renew.timer theau-vps-iperf3.service theau-vps-rustdesk-hbbs.service theau-vps-rustdesk-hbbr.service >/dev/null
systemctl reset-failed theau-vps-firewall.service theau-vps-wireguard.service theau-vps-nginx.service theau-vps-wgdashboard.service theau-vps-authelia.service theau-vps-lldap.service theau-vps-prowlarr.service theau-vps-seerr.service theau-vps-certbot-renew.timer theau-vps-iperf3.service theau-vps-rustdesk-hbbs.service theau-vps-rustdesk-hbbr.service >/dev/null || true
systemctl restart ssh
systemctl restart theau-vps-firewall.service
systemctl restart theau-vps-wireguard.service
systemctl restart theau-vps-lldap.service

for _ in {1..30}; do
  if "$BUNDLE_ROOT/share/theau-vps/lldap-package/bin/lldap" healthcheck --config-file "$LLDAP_CONFIG_FILE" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
"$BUNDLE_ROOT/share/theau-vps/lldap-package/bin/lldap" healthcheck --config-file "$LLDAP_CONFIG_FILE" >/dev/null

lldap_password="$(cat "$LLDAP_ADMIN_PASSWORD_FILE")"
lldap_cli=(env "LLDAP_PASSWORD=$lldap_password" "$BUNDLE_ROOT/share/theau-vps/lldap-cli-package/bin/lldap-cli" -H http://127.0.0.1:17170 -D theau)
"${lldap_cli[@]}" group list >/dev/null
"${lldap_cli[@]}" user update set theau mail theau.pauwels@gmail.com >/dev/null

for group in admins infra-admins media-users media-admins git-users git-admins paas-users paas-admins wiki-users monitoring-users service-accounts wg-admin; do
  "${lldap_cli[@]}" group add "$group" >/dev/null 2>&1 || true
done

for group in admins infra-admins paas-admins git-admins media-admins monitoring-users wiki-users wg-admin; do
  "${lldap_cli[@]}" user group add theau "$group" >/dev/null 2>&1 || true
done

AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE="$AUTHELIA_LDAP_PASSWORD_FILE" \
  "$BUNDLE_ROOT/share/theau-vps/authelia-package/bin/authelia" config validate --config "$AUTHELIA_STATE/configuration.yml"
systemctl restart theau-vps-authelia.service
systemctl restart theau-vps-nginx.service
systemctl restart theau-vps-iperf3.service
systemctl restart theau-vps-rustdesk-hbbs.service
systemctl restart theau-vps-rustdesk-hbbr.service
systemctl restart theau-vps-prowlarr.service
systemctl restart theau-vps-seerr.service
systemctl restart theau-vps-wgdashboard.service
systemctl restart theau-vps-certbot-renew.timer

python3 - <<'PY'
import json
import os
import sqlite3
import time
from pathlib import Path

host = json.load(open(os.environ["HOST_SPEC"], "r", encoding="utf-8"))
secrets = json.load(open(os.environ["SECRETS_JSON"], "r", encoding="utf-8"))
public_peers = json.load(open(os.environ["PUBLIC_PEERS"], "r", encoding="utf-8"))
db_path = Path("/var/lib/wgdashboard/db/wgdashboard.db")

for _ in range(30):
    if db_path.exists():
        break
    time.sleep(1)

if not db_path.exists():
    raise SystemExit("WGDashboard database was not created after service start")

peer_lookup = {entry["publicKey"]: entry for entry in secrets["wireguard"]["peers"]}
conn = sqlite3.connect(db_path)
conn.execute('CREATE TABLE IF NOT EXISTS "DashboardAPIKeys" ("Key" TEXT PRIMARY KEY, "CreatedAt" DATETIME, "ExpiredAt" DATETIME)')

for peer in public_peers:
    secret_peer = peer_lookup[peer["publicKey"]]
    conn.execute(
        '''
        INSERT INTO "wg0" (
          id, private_key, DNS, endpoint_allowed_ip, name, total_receive, total_sent, total_data,
          endpoint, status, latest_handshake, allowed_ip, cumu_receive, cumu_sent, cumu_data,
          mtu, keepalive, remote_endpoint, preshared_key
        ) VALUES (?, ?, ?, ?, ?, 0, 0, 0, 'N/A', 'stopped', 'N/A', ?, 0, 0, 0, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          private_key = excluded.private_key,
          DNS = excluded.DNS,
          endpoint_allowed_ip = excluded.endpoint_allowed_ip,
          name = excluded.name,
          allowed_ip = excluded.allowed_ip,
          mtu = excluded.mtu,
          keepalive = excluded.keepalive,
          remote_endpoint = excluded.remote_endpoint,
          preshared_key = excluded.preshared_key
        ''',
        (
            peer["publicKey"],
            secret_peer["privateKey"],
            host["wireguard"]["peerDefaultDns"],
            ", ".join(host["wireguard"]["peerEndpointAllowedIps"]),
            peer["name"],
            ", ".join(peer["allowedIPs"]),
            host["wireguard"]["peerMtu"],
            host["wireguard"]["peerPersistentKeepalive"],
            host["domain"],
            secret_peer["presharedKey"],
        ),
    )

conn.commit()
conn.close()
PY

systemctl restart theau-vps-wgdashboard.service

echo "Activation completed for $DOMAIN"
