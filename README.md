# nixOS-infra-perso

Personal infrastructure repository for the Ubuntu 24.04 + Nix deployment target.

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
- Nginx reverse proxy on `80` and later `443`
- nftables firewall
- iperf3
- certbot renewal timer

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
- the current certificate expires on `2026-07-05`

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
- `hostname` is `theau-vps`
- `timezone` is `Europe/Brussels`
- WireGuard, WGDashboard, Nginx, firewall, and iperf3 are active on `IONOS-VPS2`
- WGDashboard is reachable publicly at `https://theau-vps.duckdns.org`
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
