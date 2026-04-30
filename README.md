# nixOS-infra-perso

Personal infrastructure repository for the current Ubuntu 24.04 + Nix VPS
deployment target and the future multi-site declarative Nix infrastructure.

## Current state summary

The production path is still the legacy-compatible VPS bundle:

- Nix builds `.#theau-vps-bundle` locally.
- `deploy/push-generation.sh` copies the bundle to the Ubuntu VPS Nix store.
- `deploy/activate-generation.sh` writes configs and systemd units on Ubuntu.
- `/opt/theau-vps/current` points to the active generation.

Do not treat the new NixOS skeleton modules as active production config yet.

## Target architecture

The target architecture is documented in:

- [`docs/architecture.md`](/home/theau/Documents/vscode/NixOS-migration/docs/architecture.md)
- [`docs/addressing.md`](/home/theau/Documents/vscode/NixOS-migration/docs/addressing.md)
- [`docs/security-model.md`](/home/theau/Documents/vscode/NixOS-migration/docs/security-model.md)
- [`docs/migration-plan.md`](/home/theau/Documents/vscode/NixOS-migration/docs/migration-plan.md)
- [`docs/disaster-recovery.md`](/home/theau/Documents/vscode/NixOS-migration/docs/disaster-recovery.md)
- [`docs/implementation/current-vps-bundle.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/current-vps-bundle.md)
- [`docs/implementation/future-personal-ssh-access-platform.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/future-personal-ssh-access-platform.md)
- [`docs/implementation/jellyfin-kot-seedbox.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/jellyfin-kot-seedbox.md)
- [`docs/implementation/vps-headscale.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/vps-headscale.md)
- [`docs/implementation/vps-caddy.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/vps-caddy.md)
- [`docs/implementation/nas-kot-zfs.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/nas-kot-zfs.md)
- [`docs/implementation/mom-edge.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/mom-edge.md)
- [`docs/implementation/mom-nvr.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/mom-nvr.md)
- [`docs/implementation/dad-edge.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/dad-edge.md)
- [`docs/implementation/smtp.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/smtp.md)
- [`docs/implementation/git-selfhosted.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/git-selfhosted.md)
- [`docs/implementation/wiki-offline.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/wiki-offline.md)
- [`docs/implementation/prowlarr.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/prowlarr.md)
- [`docs/implementation/coolify-paas.md`](/home/theau/Documents/vscode/NixOS-migration/docs/implementation/coolify-paas.md)

## Production warning

The current VPS bundle is the legacy production path and must remain working
until a later phase replaces it with a tested rollback plan. Do not run
infrastructure deployment commands unless you intend to mutate the live VPS.

## Migration phase status

| Phase | Status | Notes |
| --- | --- | --- |
| Phase 0: preserve current VPS bundle | Complete | Current bundle documented and build verified |
| Phase 1: docs and skeleton modules | Complete | Adds target docs, disabled modules, and future host skeletons |
| Phase 2: Jellyfin Kot declarative | Complete | Adds initial Kot media NixOS host configs |
| Phase 2.5: Kot media split and SSO | Complete | Splits Jellyfin, Seedbox, and Jellyseerr VMs; adds identity provider skeleton |
| Phase 3: Headscale and Caddy | Complete | Enables native VPS Headscale, Caddy, LLDAP, and central Authelia authorization |
| Phase 4: NAS ZFS | Complete | Adds NAS Kot ZFS, LAN-only shares, Sanoid, Restic, and sops-nix secrets |
| Phase 5: Mom edge | Complete | Adds Mom site VPN edge, monitoring exporters, disabled Frigate module, and secrets skeleton |
| Phase 6: Dad edge | Complete | Adds outbound-only Dad WireGuard edge for Starlink CGNAT |
| Phase 6.5: self-hosted services | Complete | Adds disabled SMTP, Forgejo, Kiwix, Prowlarr, and Coolify modules with host imports and implementation docs |
| Phase 7: VPS NixOS native | Not started | Future work |

## Target model

- the OS stays Ubuntu 24.04 on the VPS
- Nix builds a reproducible deployment bundle locally
- `nix copy` pushes the bundle to the VPS store
- activation scripts install configs and `systemd` units on Ubuntu
- each deployment creates a generation under `/opt/theau-vps/generations/<timestamp>`
- `/opt/theau-vps/current` points to the active generation

## Current infrastructure

- source VPS: `IONOS-VPS`
  - public IP: `87.106.38.127`
  - current DuckDNS target for `theau-vps.duckdns.org`
  - current rollback host
- target VPS: `IONOS-VPS2-DEPLOY`
  - public IP: `82.165.20.195`
  - hostname target: `theau-vps`
  - timezone target: `Europe/Brussels`
- domain: `theau-vps.duckdns.org`
- admin user on target: `theau`
- WireGuard subnet: `10.8.0.0/24`
- WireGuard listen port: `51820/udp`
- iperf3 port: `5201/tcp`

## Managed services on the target

- native WireGuard via `wg-quick`
- WGDashboard behind local Gunicorn on `127.0.0.1:10086`
- RustDesk Server OSS with `hbbs` and `hbbr`
- Nginx reverse proxy on `80` and `443`
- LLDAP on `127.0.0.1:17170` with LDAP on `127.0.0.1:3890`
- Authelia on `127.0.0.1:9091`
- Prowlarr on `127.0.0.1:9696`
- Seerr on `127.0.0.1:5055`
- public vhosts for `authelia.theau.net`, `coolify.theau.net`,
  `prowlarr.theau.net`, `seer.theau.net`, `users.theau.net`, and
  `wg.theau.net`
- Authelia group policies backed by LLDAP (`wg-admin` for WGDashboard,
  `paas-admins` for Coolify, `media-admins` for Prowlarr, `media-users` for
  Seerr, `admins` for administration)
- a default Nginx vhost returning 404 for unlisted hostnames
- nftables firewall
- iperf3
- certbot renewal timer

## Disabled NixOS service modules

Phase 6.5 adds declarative modules for future self-hosted services. These are
imported into target NixOS hosts but disabled until intentionally enabled:

- SMTP Gmail relay on `hosts/vps`
- Forgejo self-hosted Git on `hosts/vps`
- Coolify PaaS on `hosts/vps`
- Kiwix offline wiki on `hosts/nas-kot`
- Prowlarr on `hosts/seedbox-kot`

## Safety rules

- do not commit raw backups
- do not commit live WireGuard exports
- do not commit local SSH client config
- do not commit cleartext secrets
- keep `~/.config/sops/age/keys.txt` backed up and private
- keep `local-secrets/` private and out of Git

## Important paths

- flake entrypoint: [`flake.nix`](/home/theau/Documents/vscode/NixOS-migration/flake.nix)
- target host spec: [`hosts/theau-vps/default.nix`](/home/theau/Documents/vscode/NixOS-migration/hosts/theau-vps/default.nix)
- encrypted deployable secrets: [`hosts/theau-vps/secrets.enc.yaml`](/home/theau/Documents/vscode/NixOS-migration/hosts/theau-vps/secrets.enc.yaml)
- bundle builder: [`packages/bundle/default.nix`](/home/theau/Documents/vscode/NixOS-migration/packages/bundle/default.nix)
- WGDashboard package: [`packages/wgdashboard/default.nix`](/home/theau/Documents/vscode/NixOS-migration/packages/wgdashboard/default.nix)
- activation script: [`deploy/activate-generation.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/activate-generation.sh)
- deploy script: [`deploy/push-generation.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/push-generation.sh)
- rollback script: [`deploy/rollback.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/rollback.sh)
- ACME issuance script: [`deploy/issue-certificate.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/issue-certificate.sh)
- DuckDNS cutover script: [`deploy/cutover-duckdns.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/cutover-duckdns.sh)
- DuckDNS propagation checker: [`deploy/wait-for-duckdns.sh`](/home/theau/Documents/vscode/NixOS-migration/deploy/wait-for-duckdns.sh)

## Local prerequisites

Install Nix in multi-user mode on the laptop:

```bash
bash <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
sudo sh -c 'printf "\nexperimental-features = nix-command flakes\n" >> /etc/nix/nix.conf'
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix --version
nix flake --help >/dev/null && echo FLAKES_OK
```

Create or verify the `age` key used by `sops`:

```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops ~/.config/sops/age
grep '^# public key:' ~/.config/sops/age/keys.txt
```

## Target VPS bootstrap

Install Nix on the Ubuntu target:

```bash
scp scripts/install-nix-ubuntu.sh IONOS-VPS2-DEPLOY:/tmp/install-nix-ubuntu.sh
ssh IONOS-VPS2-DEPLOY 'chmod 700 /tmp/install-nix-ubuntu.sh && bash /tmp/install-nix-ubuntu.sh'
ssh IONOS-VPS2-DEPLOY 'sudo sh -c '\''printf "\nexperimental-features = nix-command flakes\n" >> /etc/nix/nix.conf'\'''
ssh IONOS-VPS2-DEPLOY 'nix --version'
```

## Build and deploy

Build the deployment bundle locally:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
nix build .#theau-vps-bundle
readlink -f result
```

Push a generation to the target:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/push-generation.sh
```

Verify the deployed generation:

```bash
ssh IONOS-VPS2-DEPLOY 'systemctl is-active ssh theau-vps-firewall.service theau-vps-wireguard.service theau-vps-nginx.service theau-vps-wgdashboard.service theau-vps-iperf3.service'
ssh IONOS-VPS2-DEPLOY 'hostnamectl --static; timedatectl show -p Timezone --value'
ssh IONOS-VPS2-DEPLOY 'curl -fsSI -H "Host: theau-vps.duckdns.org" http://127.0.0.1/'
ssh IONOS-VPS2-DEPLOY 'curl -fsS http://127.0.0.1:10086/ >/tmp/wgdashboard.html && head -n 5 /tmp/wgdashboard.html'
ssh IONOS-VPS2-DEPLOY 'sudo awk '\''/^ListenPort = /{print} /^# Name = /{count++; print} END{print "PEER_COUNT=" count}'\'' /etc/wireguard/wg0.conf'
ssh IONOS-VPS2-DEPLOY 'systemctl is-active theau-vps-rustdesk-hbbs.service theau-vps-rustdesk-hbbr.service'
```

## Rollback

Rollback to the previous generation:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/rollback.sh
```

Rollback to a specific generation:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/rollback.sh /opt/theau-vps/generations/20260406225233
```

External rollback remains available after cutover, but the old VPS must be reached by its fixed IP:

```bash
ssh root@87.106.38.127 'hostnamectl --static; curl -fsS ifconfig.me; echo'
ssh IONOS-VPS2-DEPLOY 'hostnamectl --static; curl -fsS ifconfig.me; echo'
getent hosts theau-vps.duckdns.org
```

## DuckDNS cutover

The DuckDNS token was not found on `IONOS-VPS` during audit.

Checked and not found:

- `/opt/wireguard/docker-compose.yml`
- `/opt/reverse-proxy/docker-compose.yml`
- Docker container env for `wg-easy`
- Docker metadata under `/var/lib/docker`
- `/etc/environment`
- root environment variables
- `/root/.profile`
- `/root/.bashrc`
- `/root/.bash_history`
- `/root/README`
- cron entries under `/etc/cron.*` and root crontab
- `systemd` units and timers
- cloud-init paths under `/var/lib/cloud` and `/etc/cloud`
- root and user dotfiles under `/root` and `/home`

So the cutover script expects the token from your local environment.

Cut over DuckDNS to the new VPS:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export DUCKDNS_TOKEN='YOUR_DUCKDNS_TOKEN'
./deploy/cutover-duckdns.sh
./deploy/wait-for-duckdns.sh
```

Immediate DNS rollback to the old VPS:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export DUCKDNS_TOKEN='YOUR_DUCKDNS_TOKEN'
TARGET_IP=87.106.38.127 ./deploy/cutover-duckdns.sh
./deploy/wait-for-duckdns.sh
```

## HTTPS cutover

After DuckDNS points to `82.165.20.195`, issue the certificate and redeploy to switch Nginx to HTTPS mode:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./deploy/issue-certificate.sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/push-generation.sh
curl -I https://theau-vps.duckdns.org
```

Current production status:

- `theau-vps.duckdns.org` now resolves to `82.165.20.195`
- Nginx redirects HTTP to HTTPS
- Let's Encrypt is active for `theau-vps.duckdns.org`
- the DuckDNS certificate expires on `2026-07-05`

## theau.net service domains

The VPS bundle expects these DNS records before issuing the service
certificate:

```text
authelia.theau.net A 82.165.20.195
coolify.theau.net  A 82.165.20.195
prowlarr.theau.net A 82.165.20.195
seer.theau.net     A 82.165.20.195
users.theau.net    A 82.165.20.195
wg.theau.net       A 82.165.20.195
```

After DNS is live:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./deploy/issue-theau-net-services-certificate.sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/push-generation.sh
```

LLDAP and Authelia bootstrap credentials are generated on IONOS-VPS2 at:

```text
/opt/theau-vps/state/lldap/admin-credentials.txt
/opt/theau-vps/state/authelia/admin-credentials.txt
```

The bootstrap username is `theau`; the password is generated at activation
time and remains only on the VPS.

Authelia currently uses a filesystem notifier. One-time verification codes are
written on IONOS-VPS2 at:

```text
/opt/theau-vps/state/authelia/notification.txt
```

Current deployed edge behavior:

- `https://authelia.theau.net/` serves Authelia directly.
- `https://users.theau.net/` redirects to Authelia, then shows the LLDAP UI
  login.
- `https://coolify.theau.net/`, `https://wg.theau.net/`,
  `https://prowlarr.theau.net/`, and `https://seer.theau.net/` redirect to
  Authelia before reaching their upstream apps.
- undeclared HTTPS hostnames return `404`.

The `theau-net-services` certificate currently covers all six service domains
and expires on `2026-07-28`.

## RustDesk OSS

RustDesk Server OSS runs directly on `IONOS-VPS2` with a persistent keypair in `/var/lib/rustdesk-server`.

Required public ports:

- `21115/tcp`
- `21116/tcp`
- `21116/udp`
- `21117/tcp`

Intentionally not exposed publicly:

- `21118/tcp`
- `21119/tcp`

Client configuration:

- `ID Server`: `theau-vps.duckdns.org`
- `Relay Server`: `theau-vps.duckdns.org`
- `Key`: the content of `/var/lib/rustdesk-server/id_ed25519.pub`

Retrieve the current public key:

```bash
ssh IONOS-VPS2-DEPLOY 'sudo cat /var/lib/rustdesk-server/id_ed25519.pub'
```

## SSH public key inventory

Trusted user public keys are versioned per host in:

- [`hosts/theau-vps/ssh-public-keys.json`](/home/theau/Documents/vscode/NixOS-migration/hosts/theau-vps/ssh-public-keys.json)

Rotatable deployment automation keys stay encrypted in:

- [`hosts/theau-vps/secrets.enc.yaml`](/home/theau/Documents/vscode/NixOS-migration/hosts/theau-vps/secrets.enc.yaml)

Register or rotate a trusted machine key:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./scripts/register-ssh-public-key.py \
  --host-id theau-vps \
  --id theau-desktop \
  --file ~/.ssh/id_ed25519_desktop.pub \
  --description "Desktop SSH key" \
  --role admin
```

Redeploy after updating the inventory:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
nix build .#theau-vps-bundle
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/push-generation.sh
```

Inspect the deployed inventory and authorized keys on the VPS:

```bash
ssh IONOS-VPS2-DEPLOY 'sudo cat /etc/theau-vps/ssh-public-keys.json'
ssh IONOS-VPS2-DEPLOY 'sudo cat /home/theau/.ssh/authorized_keys'
```

Safety model:

- keep one stable break-glass admin key in the inventory
- rotate deployment keys through `hosts/theau-vps/secrets.enc.yaml`
- never sync private keys through the VPS
- if one machine is compromised, remove only its public key entry and redeploy

## Secrets workflow

Decrypt the host secrets:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./.tools/sops/sops-v3.12.2.linux.amd64 --decrypt hosts/theau-vps/secrets.enc.yaml
```

Files that must stay private:

- `~/.config/sops/age/keys.txt`
- `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- any local file containing `DUCKDNS_TOKEN`

Useful local hardening and backup commands:

```bash
cd /home/theau/Documents/vscode/NixOS-migration
./scripts/harden-local-secrets.sh
./scripts/build-local-secret-vault.sh
```

## Jellyfin VM seedbox

The Jellyfin VM stack lives on `jellyfin_kot` under `/opt/seedbox`.

Current target state:

- `gluetun` uses `WIREGUARD_ENDPOINT_IP=82.165.20.195`
- `qbittorrent` still uses `network_mode: "service:gluetun"`
- the peer `10.8.0.20/32` handshakes successfully on `theau-vps`

Useful commands:

```bash
ssh jellyfin_kot 'cd /opt/seedbox && sed -n "1,80p" docker-compose.yml'
ssh jellyfin_kot 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
ssh jellyfin_kot 'docker logs --tail 80 gluetun 2>&1'
ssh IONOS-VPS2-DEPLOY 'current=$(readlink -f /opt/theau-vps/current); sudo $current/share/theau-vps/wireguard-tools-package/bin/wg show wg0 dump'
```

Manual rollback to the old VPS endpoint if needed:

```bash
ssh jellyfin_kot 'sudo sed -i "s/WIREGUARD_ENDPOINT_IP=82\\.165\\.20\\.195/WIREGUARD_ENDPOINT_IP=87.106.38.127/" /opt/seedbox/docker-compose.yml && cd /opt/seedbox && sudo docker compose up -d gluetun qbittorrent'
```

## Current status

- target VPS deployment is active
- active generation is `/opt/theau-vps/generations/20260430010616`
- active bundle is `/nix/store/5hcbrdl1mm82nscm61kdzgci7m8y9b3f-theau-vps-bundle`
- `hostname` is `theau-vps`
- `timezone` is `Europe/Brussels`
- WireGuard, WGDashboard, Nginx, firewall, LLDAP, Authelia, Prowlarr, Seerr,
  and iperf3 are active on `IONOS-VPS2`
- WGDashboard is reachable at `https://wg.theau.net` behind Authelia
- Coolify is reachable at `https://coolify.theau.net` behind Authelia
- Prowlarr is reachable at `https://prowlarr.theau.net` behind Authelia
- Seerr is reachable at `https://seer.theau.net` behind Authelia
- LLDAP is reachable at `https://users.theau.net` behind Authelia, then uses
  LLDAP's own UI login
- Authelia default post-login fallback is `https://users.theau.net`
- DuckDNS now points to the new VPS at `82.165.20.195`
- HTTP returns `301` to HTTPS
- Jellyfin VM `gluetun` and `qbittorrent` now use the new WireGuard endpoint on `82.165.20.195`
- RustDesk OSS now runs on `IONOS-VPS2` with only the necessary public ports opened in `nftables`: `21115/tcp`, `21116/tcp+udp`, and `21117/tcp`
- `iperf3` remains exposed on `5201/tcp`
- RustDesk websocket ports `21118/tcp` and `21119/tcp` are intentionally listening locally but blocked by the firewall
- the old VPS remains a manual rollback host, but not via the old DuckDNS alias
- to reach the old VPS after cutover, use its fixed IP directly

Example old-VPS access after cutover:

```bash
ssh root@87.106.38.127
```
