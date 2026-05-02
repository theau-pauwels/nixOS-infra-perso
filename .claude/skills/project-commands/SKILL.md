---
name: project-commands
description: Use when installing, testing, linting, building, running, deploying, rolling back, or validating this repository so the agent does not rediscover commands repeatedly.
---

# Project Commands

Run commands from the repository root: `/home/theau/Documents/vscode/NixOS-migration`.

This is a Nix flake infrastructure repository, not an npm project. There is no `package.json`, no `npm install`, and no app dev server.

For LLM in this workspace, prefix shell commands with `rtk`. If `rtk` cannot proxy a command shape, use `rtk proxy <command ...>`.

## Install / Dev Shell

Enter the Nix development shell:

```bash
rtk nix develop
```

If Nix is not installed locally, follow the Nix install commands in `README.md` under "Local prerequisites".

## Inspect

Show flake outputs:

```bash
rtk nix flake show
```

Show Git state:

```bash
rtk git status --short
```

List directories:

```bash
rtk ls -la
```

Read file excerpts:

```bash
rtk sed -n '1,220p' path/to/file
```

Search files and code:

```bash
rtk rg "pattern"
rtk rg --files
```

Use `find` through raw proxy when needed:

```bash
rtk proxy find . -maxdepth 3 -type f -print
```

## Format

Format Nix files with the flake formatter:

```bash
rtk nix fmt
```

## Test / Validate

Run the main repository validation:

```bash
rtk nix flake check
```

Build the primary production bundle without creating `result`:

```bash
rtk nix build --no-link --print-out-paths .#theau-vps-bundle
```

Build the primary production bundle with `result`:

```bash
rtk nix build .#theau-vps-bundle
rtk readlink -f result
```

Evaluate selected NixOS configuration values:

```bash
rtk nix eval .#nixosConfigurations.vps.config.services.headscale.settings.server_url
rtk nix eval .#nixosConfigurations.vps.config.services.authelia.instances.main.settings.access_control.rules
```

## Build Targets

Primary Ubuntu VPS bundle:

```bash
rtk nix build .#theau-vps-bundle
```

WGDashboard package:

```bash
rtk nix build .#wgdashboard
```

Future/native NixOS VPS artifact:

```bash
rtk nix build .#vps-native
```

Kot media artifacts:

```bash
rtk nix build .#jellyfin-kot
rtk nix build .#seedbox-kot
rtk nix build .#jellyseerr-kot
rtk nix build .#storage-kot
rtk nix build .#kot-media-stack
```

Site edge and NAS artifacts:

```bash
rtk nix build .#nas-kot
rtk nix build .#mom-edge
rtk nix build .#dad-edge
```

## Secrets

Use the repository-pinned SOPS binary for current VPS secrets:

```bash
rtk proxy ./.tools/sops/sops-v3.12.2.linux.amd64 --decrypt hosts/theau-vps/secrets.enc.yaml
```

Harden local secret file permissions:

```bash
rtk proxy ./scripts/harden-local-secrets.sh
```

Build the local secret backup vault:

```bash
rtk proxy ./scripts/build-local-secret-vault.sh
```

## Helper Scripts

Register or rotate a trusted SSH public key:

```bash
rtk proxy ./scripts/register-ssh-public-key.py \
  --host-id theau-vps \
  --id theau-desktop \
  --file ~/.ssh/id_ed25519_desktop.pub \
  --description "Desktop SSH key" \
  --role admin
```

Generate a WGDashboard password hash:

```bash
rtk proxy ./scripts/make-wgdashboard-password-hash.py
```

Import wg-easy data when doing migration work:

```bash
rtk proxy ./scripts/import-wg-easy.py --help
```

## Deploy

These commands mutate live infrastructure. Only run them when explicitly requested.

Deploy a new generation to the Ubuntu VPS:

```bash
rtk proxy env SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ./deploy/push-generation.sh
```

Override the target host or secrets file:

```bash
rtk proxy env TARGET_HOST=IONOS-VPS2-DEPLOY SECRETS_FILE=hosts/theau-vps/secrets.enc.yaml SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ./deploy/push-generation.sh
```

Rollback to the previous generation:

```bash
rtk proxy env SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ./deploy/rollback.sh
```

Rollback to a specific generation:

```bash
rtk proxy env SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ./deploy/rollback.sh /opt/theau-vps/generations/20260406225233
```

## Certificates and DNS

Issue or renew the DuckDNS certificate:

```bash
rtk proxy ./deploy/issue-certificate.sh
```

Issue or renew the `theau.net` service certificate:

```bash
rtk proxy ./deploy/issue-theau-net-services-certificate.sh
```

Cut over DuckDNS to the configured target:

```bash
rtk proxy env DUCKDNS_TOKEN="$DUCKDNS_TOKEN" ./deploy/cutover-duckdns.sh
rtk proxy ./deploy/wait-for-duckdns.sh
```

Immediate DuckDNS rollback to the old VPS IP:

```bash
rtk proxy env DUCKDNS_TOKEN="$DUCKDNS_TOKEN" TARGET_IP=87.106.38.127 ./deploy/cutover-duckdns.sh
rtk proxy ./deploy/wait-for-duckdns.sh
```

## Remote Verification

Check core VPS services:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'systemctl is-active ssh theau-vps-firewall.service theau-vps-wireguard.service theau-vps-nginx.service theau-vps-wgdashboard.service theau-vps-iperf3.service'
```

Check host identity and timezone:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'hostnamectl --static; timedatectl show -p Timezone --value'
```

Check local HTTP routing on the VPS:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'curl -fsSI -H "Host: theau-vps.duckdns.org" http://127.0.0.1/'
```

Check WGDashboard locally on the VPS:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'curl -fsS http://127.0.0.1:10086/ >/tmp/wgdashboard.html && head -n 5 /tmp/wgdashboard.html'
```

Check WireGuard listen port and peer count:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'sudo awk '\''/^ListenPort = /{print} /^# Name = /{count++; print} END{print "PEER_COUNT=" count}'\'' /etc/wireguard/wg0.conf'
```

Check RustDesk services:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'systemctl is-active theau-vps-rustdesk-hbbs.service theau-vps-rustdesk-hbbr.service'
```

Check public HTTPS endpoints from the local machine:

```bash
rtk curl -I https://theau-vps.duckdns.org
rtk curl -I https://wg.theau.net
rtk curl -I https://coolify.theau.net
rtk curl -I https://jellyfin.theau.net
rtk curl -I https://prowlarr.theau.net
rtk curl -I https://qbit.theau.net
rtk curl -I https://seer.theau.net
rtk curl -I https://users.theau.net
rtk curl -I https://authelia.theau.net
rtk curl -I https://file.theau.net
```

## Storage Operations

Check storage-kot:
```bash
rtk ssh -i ~/.ssh/theau-vps-deploy theau@10.1.10.124 'systemctl is-active samba-smbd filebrowser wg-quick-theau-vps'
```

Check FileBrowser:
```bash
rtk curl -sI http://10.8.0.23:8082/login
```

Check storage-kot shares:
```bash
rtk ssh -i ~/.ssh/theau-vps-deploy theau@10.1.10.124 'df -h /srv/nas; smbclient -N -L localhost 2>&1 | grep -i disk'
```

## Seedbox Operations

SSH to seedbox-kot:
```bash
rtk ssh -i ~/.ssh/theau-vps-deploy theau@10.1.10.123
```

Check seedbox containers:
```bash
rtk ssh -i ~/.ssh/theau-vps-deploy theau@10.1.10.123 'sudo podman ps --format "table {{.Names}} {{.Status}}"'
```

Check seedbox CIFS mount:
```bash
rtk ssh -i ~/.ssh/theau-vps-deploy theau@10.1.10.123 'mount | grep cifs; sudo podman exec seedbox-qbittorrent df -h /downloads'
```

## Jellyfin Operations

Check jellyfin CIFS mount:
```bash
rtk ssh -A IONOS-VPS2-DEPLOY 'ssh theau@10.8.0.21 "mount | grep cifs; ls /srv/jellyfin/media | head -5"'
```

## Legacy Jellyfin / Seedbox (docker-compose)

Inspect the seedbox compose file:

```bash
rtk ssh jellyfin_kot 'cd /opt/seedbox && sed -n "1,80p" docker-compose.yml'
```

Check seedbox containers (legacy):

```bash
rtk ssh jellyfin_kot 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
```

Check Gluetun logs:

```bash
rtk ssh jellyfin_kot 'docker logs --tail 80 gluetun 2>&1'
```

Inspect WireGuard state from the VPS bundle:

```bash
rtk ssh IONOS-VPS2-DEPLOY 'current=$(readlink -f /opt/theau-vps/current); sudo $current/share/theau-vps/wireguard-tools-package/bin/wg show wg0 dump'
```

Manual rollback of the Jellyfin VM VPN endpoint to the old VPS:

```bash
rtk ssh jellyfin_kot 'sudo sed -i "s/WIREGUARD_ENDPOINT_IP=82\.165\.20\.195/WIREGUARD_ENDPOINT_IP=87.106.38.127/" /opt/seedbox/docker-compose.yml && cd /opt/seedbox && sudo docker compose up -d gluetun qbittorrent'
```
