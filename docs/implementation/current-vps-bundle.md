# Current VPS Bundle Deployment

## Context

This document records the phase 0 baseline for the current `theau-vps`
deployment before the repository is evolved toward a broader multi-site Nix
infrastructure.

The current target is an Ubuntu 24.04 VPS, not a NixOS host. Nix is used to
build a reproducible deployment bundle locally. The deployment scripts then copy
that bundle into the target VPS Nix store and run an activation script that
writes Ubuntu configuration files and systemd units.

Current target facts:

- Target host alias: `IONOS-VPS2-DEPLOY`
- Target public IP: `82.165.20.195`
- Public domain: `theau-vps.duckdns.org`
- Hostname: `theau-vps`
- Admin user: `theau`
- Admin home: `/home/theau`
- Timezone: `Europe/Brussels`
- Public interface: `ens6`
- WireGuard interface: `wg0`
- WireGuard subnet: `10.8.0.0/24`

## Current Deployment Snapshot

As of 2026-04-30, `IONOS-VPS2-DEPLOY` is running:

- active bundle: `/nix/store/wxhrrifyxhc13qrxv5vxf4lmiazxyzyl-theau-vps-bundle`
- active generation: `/opt/theau-vps/generations/20260430134153`
- `theau-net-services` certificate expiry: 2026-07-29
- certificate SANs include `authelia.theau.net`, `coolify.theau.net`,
  `jellyfin.theau.net`, `prowlarr.theau.net`, `qbit.theau.net`,
  `seer.theau.net`, `users.theau.net`, and `wg.theau.net`

The deployed service edge behavior was verified from outside the VPS:

- `https://authelia.theau.net/`: Authelia login page, HTTP `200`
- `https://users.theau.net/`: Authelia redirect before LLDAP UI login
- `https://coolify.theau.net/`: Authelia redirect before Coolify
- `https://wg.theau.net/`: Authelia redirect before WGDashboard
- `https://jellyfin.theau.net/`: Authelia redirect before Jellyfin on
  `jellyfin-kot`
- `https://prowlarr.theau.net/`: Authelia redirect before Prowlarr
- `https://qbit.theau.net/`: Authelia redirect before qBittorrent on
  `seedbox-kot`
- `https://seer.theau.net/`: Authelia redirect before Seerr
- undeclared HTTPS hostnames: default `404`

## Repository Structure

Important files and directories at the phase 0 baseline:

- `flake.nix`: flake entrypoint. Imports `nixpkgs`, `flake-utils`, and the
  upstream WGDashboard source. Exposes the packages and dev shell.
- `flake.lock`: pinned dependency graph for the flake inputs.
- `README.md`: operational runbook for build, deploy, rollback, DuckDNS,
  HTTPS, RustDesk, SSH key inventory, and current status.
- `prompts/MASTER.md`: overall migration plan and infrastructure context.
- `prompts/phases/phase-0-preserve-vps-bundle.md`: phase 0 task definition.
- `hosts/theau-vps/default.nix`: host data model for the current VPS, including
  target host, domain, SSH, firewall, WireGuard, WGDashboard, iperf3, and
  RustDesk settings.
- `hosts/theau-vps/peers.nix`: public WireGuard peer inventory. It contains
  peer names, public keys, and allowed IPs only.
- `hosts/theau-vps/ssh-public-keys.json`: versioned trusted admin SSH public
  key inventory.
- `hosts/theau-vps/secrets.enc.yaml`: encrypted deployable secrets.
- `hosts/theau-vps/secrets.example.yaml`: schema example for deployable
  secrets.
- `hosts/theau-vps/README.md`: short host-local note for planned NixOS service
  coverage.
- `packages/bundle/default.nix`: builds the complete VPS deployment bundle.
  This is the central source for generated config files and systemd units.
- `packages/wgdashboard/default.nix`: packages WGDashboard 4.3.2 with a Python
  environment and local file overrides.
- `packages/wgdashboard/files/`: local WGDashboard override files copied into
  the package.
- `deploy/push-generation.sh`: builds, copies, transfers secrets, activates,
  and promotes a new generation on the Ubuntu target.
- `deploy/activate-generation.sh`: target-side activation script installed into
  the bundle as `bin/activate-theau-vps-generation`.
- `deploy/rollback.sh`: re-activates a previous generation and repoints
  `/opt/theau-vps/current`.
- `deploy/issue-certificate.sh`: runs certbot on the current remote generation
  to issue or renew the public certificate.
- `deploy/cutover-duckdns.sh`: updates the DuckDNS record using a local
  `DUCKDNS_TOKEN`.
- `deploy/wait-for-duckdns.sh`: waits until DuckDNS resolves to the expected
  target IP.
- `scripts/install-nix-ubuntu.sh`: bootstrap helper for installing Nix on an
  Ubuntu target.
- `scripts/register-ssh-public-key.py`: helper for maintaining the host SSH
  public key inventory.
- `scripts/make-wgdashboard-password-hash.py`: helper for generating the
  WGDashboard bcrypt password hash.
- `scripts/import-wg-easy.py`: migration helper for importing data from a
  previous wg-easy setup.
- `scripts/harden-local-secrets.sh`: hardens local permissions for ignored
  cleartext secret files.
- `scripts/build-local-secret-vault.sh`: creates a local encrypted backup vault
  for secret material that must stay out of Git.
- `docs/secrets.md`: current secrets workflow.
- `docs/ubuntu-nix-target.md`: short explanation of the Ubuntu plus Nix target
  model.
- `docs/migration-notes.md`: migration notes.

The working tree also contains ignored or local-only material such as
`local-secrets/`, `backups/`, `VPS_wg0-server/`, `.tools/`, and `ssh-config`.
Those paths are operational inputs or backups and must not be treated as new
declarative source for future phases without a separate audit.

## Flake Outputs

The flake is implemented with `flake-utils.lib.eachDefaultSystem`, so the same
output shape is defined for the default systems. On this machine,
`nix flake show` evaluated the active `x86_64-linux` outputs as:

- `packages.x86_64-linux.wgdashboard`: package `wgdashboard-4.3.2`
- `packages.x86_64-linux.theau-vps-bundle`: package `theau-vps-bundle`
- `packages.x86_64-linux.default`: alias to `theau-vps-bundle`
- `devShells.x86_64-linux.default`: development shell with age, git, jq,
  nixfmt, openssh, python3, rsync, sops, ssh-to-age, and yq-go
- `formatter.x86_64-linux`: `nixfmt-1.2.0`

`nix flake check` passed for `x86_64-linux`. It warned that
`nixfmt-rfc-style` is now the same as `pkgs.nixfmt`, and it omitted incompatible
systems unless `--all-systems` is used.

## Build Architecture

The bundle is built by `packages/bundle/default.nix`.

Inputs:

- `hostSpec`: imported from `hosts/theau-vps/default.nix`
- `wgdashboard`: built by `packages/wgdashboard/default.nix`
- selected packages from `nixpkgs`: nginx, certbot, nftables,
  wireguard-tools, iperf3, systemd, iproute2, openssh, python3, coreutils,
  procps, bash, gnused, and rustdesk-server

The derivation writes a store output named `theau-vps-bundle` with:

- `bin/activate-theau-vps-generation`
- helper scripts under `libexec/`
- generated host data under `share/theau-vps/`
- generated systemd unit files under `share/theau-vps/systemd/`
- generated Nginx configs under `share/theau-vps/nginx/`
- generated SSH, sysctl, nftables, and WGDashboard template files
- symlinks to the Nix packages needed by activation and runtime units

The build does not include cleartext secrets. Secret values are injected at
activation time from a decrypted JSON file transferred to the target.

## Bundle Contents Verified

The phase 0 build produced:

```text
/nix/store/k7xbmq97s063s4g4cx1ah9c532cz1xcn-theau-vps-bundle
```

Expected executable entries were present:

- `bin/activate-theau-vps-generation`
- `libexec/push-generation.sh`
- `libexec/rollback.sh`
- `libexec/issue-certificate.sh`

Expected generated configuration entries were present:

- `share/theau-vps/host-spec.json`
- `share/theau-vps/public-peers.json`
- `share/theau-vps/ssh/public-key-inventory.json`
- `share/theau-vps/ssh/60-theau-vps.conf`
- `share/theau-vps/sysctl.conf`
- `share/theau-vps/nftables.conf`
- `share/theau-vps/nginx/nginx.conf`
- `share/theau-vps/nginx/site-http.conf`
- `share/theau-vps/nginx/site-https.conf`
- `share/theau-vps/nginx/services-http.conf`
- `share/theau-vps/nginx/services-https.conf`
- `share/theau-vps/wg-dashboard.ini.template`

Expected systemd units were present:

- `theau-vps-firewall.service`
- `theau-vps-wireguard.service`
- `theau-vps-nginx.service`
- `theau-vps-wgdashboard.service`
- `theau-vps-authelia.service`
- `theau-vps-lldap.service`
- `theau-vps-prowlarr.service`
- `theau-vps-seerr.service`
- `theau-vps-certbot-renew.service`
- `theau-vps-certbot-renew.timer`
- `theau-vps-iperf3.service`
- `theau-vps-rustdesk-hbbs.service`
- `theau-vps-rustdesk-hbbr.service`

Expected package symlinks were present for WGDashboard, Nginx, certbot,
nftables, WireGuard tools, iperf3, systemd, iproute2, OpenSSH, Python,
coreutils, procps, bash, gnused, RustDesk server, Authelia, LLDAP, Prowlarr,
Seerr, and OpenSSL.

## Service Mapping

The current services are mapped to source files as follows:

| Service or concern | Source of desired state | Generated or installed files |
| --- | --- | --- |
| OpenSSH hardening and admin keys | `hosts/theau-vps/default.nix`, `hosts/theau-vps/ssh-public-keys.json`, encrypted deploy keys | `/etc/ssh/sshd_config.d/60-theau-vps.conf`, `/home/theau/.ssh/authorized_keys`, `/etc/theau-vps/ssh-public-keys.json` |
| WireGuard server | `hosts/theau-vps/default.nix`, `hosts/theau-vps/peers.nix`, encrypted WireGuard secrets | `/etc/wireguard/wg0.conf`, `theau-vps-wireguard.service` |
| WGDashboard | `hosts/theau-vps/default.nix`, `packages/wgdashboard/default.nix`, `packages/wgdashboard/files/*`, encrypted WGDashboard secrets | `/var/lib/wgdashboard/wg-dashboard.ini`, `/var/lib/wgdashboard/db/wgdashboard.db`, `theau-vps-wgdashboard.service` |
| Nginx reverse proxy | `packages/bundle/default.nix` generated config from `hostSpec` | `/etc/theau-vps/nginx/nginx.conf`, `/etc/theau-vps/nginx/sites-enabled/theau-vps.conf`, `theau-vps-nginx.service` |
| LLDAP | `hostSpec.serviceDomains`, generated runtime secrets | `/opt/theau-vps/state/lldap`, `theau-vps-lldap.service` |
| Authelia | `hostSpec.serviceDomains`, generated runtime secrets | `/opt/theau-vps/state/authelia`, `theau-vps-authelia.service` |
| Prowlarr | `hostSpec.serviceDomains`, generated runtime API key and config | `/var/lib/prowlarr`, `/opt/theau-vps/state/prowlarr`, `theau-vps-prowlarr.service` |
| Seerr | `hostSpec.serviceDomains`, generated runtime API key and environment | `/var/lib/seerr`, `/opt/theau-vps/state/seerr`, `theau-vps-seerr.service` |
| nftables firewall and NAT | `hostSpec.firewall`, `hostSpec.publicInterface`, `hostSpec.wireguard` | `/etc/theau-vps/nftables.conf`, `theau-vps-firewall.service` |
| sysctl forwarding and rp_filter | `packages/bundle/default.nix` | `/etc/sysctl.d/90-theau-vps.conf` |
| iperf3 | `hostSpec.iperf3` | `theau-vps-iperf3.service` |
| certbot renewal | `hostSpec.domain`, `hostSpec.acmeEmail`, bundle certbot package | `theau-vps-certbot-renew.service`, `theau-vps-certbot-renew.timer` |
| RustDesk OSS | `hostSpec.rustdesk`, `pkgs.rustdesk-server` | `/var/lib/rustdesk-server`, `theau-vps-rustdesk-hbbs.service`, `theau-vps-rustdesk-hbbr.service` |
| Host identity | `hostSpec.hostname`, `hostSpec.timezone` | `hostnamectl`, `timedatectl`, `/etc/hosts` update |

## Runtime Services

### WireGuard

The bundle generates a custom systemd oneshot unit named
`theau-vps-wireguard.service`. It requires `theau-vps-firewall.service` and
uses `wg-quick up /etc/wireguard/wg0.conf` to start the interface.

`/etc/wireguard/wg0.conf` is written during activation from:

- public peer metadata in `hosts/theau-vps/peers.nix`
- server and peer private material from the decrypted secrets JSON
- shared defaults in `hosts/theau-vps/default.nix`

### WGDashboard

WGDashboard is packaged from upstream version `v4.3.2`. The package wraps
Gunicorn and adds the Python dependencies required by WGDashboard.

The service runs as root with:

- working directory: the Nix store WGDashboard package
- configuration path: `/var/lib/wgdashboard`
- listen address: `127.0.0.1`
- listen port: `10086`

Activation writes `wg-dashboard.ini` from a template and injects the encrypted
admin password hash and TOTP seed. After WGDashboard starts, activation also
updates the SQLite database so peer data is present in the dashboard.

### Nginx

Nginx is run by `theau-vps-nginx.service` with a generated config under
`/etc/theau-vps/nginx/nginx.conf`.

Activation selects the site config dynamically:

- if `/etc/letsencrypt/live/theau-vps.duckdns.org/fullchain.pem` exists, it
  installs the HTTPS site config
- otherwise it installs the HTTP-only site config

Both modes keep the ACME webroot at `/var/lib/theau-vps/acme-challenge`.
The proxied app is WGDashboard on `127.0.0.1:10086`.

### Firewall

The nftables ruleset is generated by the bundle and installed to
`/etc/theau-vps/nftables.conf`.

Allowed public ports:

- TCP: `22`, `80`, `443`, `5201`, `21115`, `21116`, `21117`
- UDP: `51820`, `21116`

The ruleset drops inbound traffic by default, accepts loopback, established and
related traffic, ICMP, the listed public service ports, and permits forwarding
to and from `wg0`. It masquerades traffic from `10.8.0.0/24` out of `ens6`.

### iperf3

`theau-vps-iperf3.service` runs `iperf3 -s -p 5201`.

### Certbot

`theau-vps-certbot-renew.timer` triggers daily renewal at 03:17 with up to 30
minutes of randomized delay. The renewal service reloads Nginx after a
successful deploy hook.

Initial issuance is handled manually with `deploy/issue-certificate.sh`, which
runs certbot through the package symlink inside `/opt/theau-vps/current`.

The `theau.net` service certificate is issued separately with cert name
`theau-net-services`. Before issuing it, these DNS records must point to
`82.165.20.195`:

- `authelia.theau.net`
- `coolify.theau.net`
- `jellyfin.theau.net`
- `prowlarr.theau.net`
- `qbit.theau.net`
- `seer.theau.net`
- `users.theau.net`
- `wg.theau.net`

Use:

```bash
./deploy/issue-theau-net-services-certificate.sh
./deploy/push-generation.sh
```

### LLDAP And Authelia

LLDAP listens on `127.0.0.1:17170` for its web UI and `127.0.0.1:3890` for LDAP.
Authelia listens on `127.0.0.1:9091` and authenticates against LLDAP. The LLDAP
UI route can be gated by Authelia, but LLDAP still performs its own UI login
with LLDAP credentials.

Activation generates runtime-only secrets and a bootstrap user under
`/opt/theau-vps/state/lldap` and `/opt/theau-vps/state/authelia`. Credential
files are root-readable only:

```text
/opt/theau-vps/state/lldap/admin-credentials.txt
/opt/theau-vps/state/authelia/admin-credentials.txt
```

The bootstrap username is `theau`. Use `sudo cat` on IONOS-VPS2 to read the
generated passwords. Authelia currently uses its filesystem notifier, so
one-time verification codes are written to:

```text
/opt/theau-vps/state/authelia/notification.txt
```

Authelia authorization uses LLDAP groups:

- `users.theau.net`: `admins` at the edge, then LLDAP UI login
- `coolify.theau.net`: `paas-admins` or `admins`
- `jellyfin.theau.net`: `media-users`, `media-admins`, or `admins`
- `prowlarr.theau.net`: `media-admins` or `admins`
- `qbit.theau.net`: `media-admins` or `admins`
- `seer.theau.net`: `media-users`, `media-admins`, or `admins`
- `wg.theau.net`: `wg-admin`

Prowlarr binds to `127.0.0.1:9696` and is configured with
`AuthenticationMethod=External`; it relies on the Authelia/LLDAP edge gate.
Jellyfin is reached through the `jellyfin-kot` WireGuard peer at
`10.8.0.21:8096`. qBittorrent is reached through the `seedbox-kot` Gluetun peer
at `10.8.0.22:8080`; the qBittorrent config trusts only the VPS WireGuard address
for WebUI auth bypass, so public access is controlled by Authelia/LLDAP.
Seerr binds to `127.0.0.1:5055`; it does not have a generic Authelia/LLDAP
login backend in the packaged app, so WAN access is controlled by the
Authelia/LLDAP edge gate.

Coolify still uses its own internal user/team model after the Authelia gate.
The current deployed Coolify OAuth implementation does not provide LDAP/LLDAP or
generic Authelia OIDC user management.

WGDashboard internal authentication remains enabled. The packaged app is patched
to trust only local reverse-proxy `Remote-*` headers from Authelia; it creates an
admin session only when Authelia has authenticated the user and LLDAP group
membership includes `wg-admin`.

The main Nginx site also installs a `default_server` that returns 404 for
hostnames not declared in the VPS bundle.

### RustDesk OSS

RustDesk is split into:

- `theau-vps-rustdesk-hbbs.service` for the rendezvous server
- `theau-vps-rustdesk-hbbr.service` for the relay server

Both use the system user and group `rustdesk-server`. Activation creates the
account if needed. The unit pre-start logic creates or validates the persistent
keypair in `/var/lib/rustdesk-server`.

## Secrets Management

Tracked secret source:

- `hosts/theau-vps/secrets.enc.yaml`

Ignored cleartext or local-only material:

- `hosts/theau-vps/secrets.yaml`
- `local-secrets/theau-vps-wgdashboard-bootstrap.txt`
- `~/.config/sops/age/keys.txt`
- any local file containing `DUCKDNS_TOKEN`
- raw backups under `backups/`

The encrypted file contains:

- WireGuard server private key
- WireGuard peer private keys
- WireGuard preshared keys
- deployment SSH authorized keys
- WGDashboard admin password hash
- WGDashboard TOTP seed

Public SSH admin keys are not encrypted. They are versioned in
`hosts/theau-vps/ssh-public-keys.json`.

Deployment decrypts `hosts/theau-vps/secrets.enc.yaml` locally with sops, writes
a temporary JSON file, copies it to the target under `/tmp`, and passes its path
to `activate-theau-vps-generation`. The temporary local directory is removed on
exit. On successful activation, the remote temporary secrets file is deleted.
On deploy failure, rollback activation is attempted with the same temporary
remote secrets file, then it is deleted.

## Deployment Workflow

The normal deployment entrypoint is:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
./deploy/push-generation.sh
```

`deploy/push-generation.sh` performs these steps:

1. Checks that `hosts/theau-vps/secrets.enc.yaml` exists.
2. Checks that the configured sops binary exists and is executable.
3. Builds the bundle with `nix build --no-link --print-out-paths .#theau-vps-bundle`.
4. Creates a timestamp generation id.
5. Decrypts secrets to a temporary local JSON file.
6. Copies the bundle to the target Nix store with `nix copy`.
7. Copies the decrypted JSON secrets file to `/tmp` on the target.
8. Reads the previous `/opt/theau-vps/current` symlink, if present.
9. Creates `/opt/theau-vps/generations/<timestamp>` as a symlink to the store
   path.
10. Runs the generation activation script with `sudo`.
11. On success, repoints `/opt/theau-vps/current` to the new generation and
    removes remote temporary secrets.
12. On failure, attempts to activate the previous generation and removes remote
    temporary secrets.

The remote Nix copy target is:

```text
ssh://$TARGET_HOST?remote-program=sudo%20/nix/var/nix/profiles/default/bin/nix-store
```

This means the target must have Nix installed and accessible to root at
`/nix/var/nix/profiles/default/bin/nix-store`.

Default deployment variables:

- `TARGET_HOST=IONOS-VPS2-DEPLOY`
- `SECRETS_FILE=hosts/theau-vps/secrets.enc.yaml`
- `SOPS_BIN=$REPO_ROOT/.tools/sops/sops-v3.12.2.linux.amd64`

The Prowlarr and Seerr expansion makes the bundle closure large. The verified
local closure was about `2.0 GiB`, and `nix copy` can stay silent while it
transfers package store paths. If the command is interrupted before the final
bundle path is copied and before `/opt/theau-vps/current` is repointed, the
target keeps serving the previous generation. In that case, verify with:

```bash
ssh IONOS-VPS2-DEPLOY 'readlink -f /opt/theau-vps/current'
ssh IONOS-VPS2-DEPLOY 'systemctl is-active theau-vps-prowlarr.service theau-vps-seerr.service'
```

For the 2026-04-30 deployment, the Seerr store path was available in
`cache.nixos.org` and was substituted directly on the VPS. That reduced the
remote download to about `191.5 MiB` instead of pushing the local `1.4 GiB`
store path over SSH.

## Activation Behavior

The activation script is generated into the bundle as
`bin/activate-theau-vps-generation`. It requires:

```bash
activate-theau-vps-generation --secrets-json /path/to/secrets.json
```

Activation performs these operations on the Ubuntu target:

- Reads `host-spec.json`, `public-peers.json`, and the decrypted secrets JSON.
- Creates required directories under `/etc/theau-vps`, `/etc/wireguard`,
  `/var/lib/theau-vps`, `/var/lib/wgdashboard`, `/var/log/theau-vps/nginx`,
  `/var/cache/theau-vps/nginx`, and `/opt/theau-vps/state`.
- Creates the `rustdesk-server` system group and user if absent.
- Writes the SSH public key inventory to `/etc/theau-vps/ssh-public-keys.json`.
- Rewrites `/home/theau/.ssh/authorized_keys` from public admin keys plus
  encrypted deployment keys.
- Writes `/etc/wireguard/wg0.conf` from public peer data and encrypted private
  peer material.
- Writes `/var/lib/wgdashboard/wg-dashboard.ini`.
- Selects the Nginx HTTP or HTTPS site config based on certificate existence.
- Copies generated SSH, sysctl, nftables, Nginx, and systemd files into place.
- Sets the target hostname and timezone.
- Ensures `/etc/hosts` has a `127.0.1.1` entry for the configured hostname.
- Runs `sysctl --system`.
- Validates sshd config with `/usr/sbin/sshd -t`.
- Runs `systemctl daemon-reload`.
- Enables all managed services and the certbot timer.
- Restarts SSH, firewall, WireGuard, Nginx, iperf3, RustDesk, WGDashboard, and
  the certbot timer.
- Waits for the WGDashboard SQLite database, then upserts WireGuard peer data.
- Restarts WGDashboard once after the database upsert.

The activation script is imperative and target-mutating. It should be treated
as the current compatibility layer until a later phase replaces or supplements
it with native NixOS modules.

## Rollback Workflow

`deploy/rollback.sh` reuses the same encrypted secrets file and activation
mechanism.

If no generation path is provided, it selects the second newest entry under
`/opt/theau-vps/generations/`. If a path is provided, it activates that
generation directly.

Rollback then:

1. Decrypts secrets locally.
2. Copies temporary secrets JSON to the target.
3. Runs the selected generation activation script with `sudo`.
4. Repoints `/opt/theau-vps/current` to the selected generation.
5. Deletes the remote temporary secrets file.

## Build Verification

The shell used for this phase did not have `nix` in `PATH`:

```text
zsh:1: command not found: nix
```

The installed Nix binary was found at:

```text
/nix/var/nix/profiles/default/bin/nix
```

The verification was therefore run with the explicit binary path.

`nix flake check` result:

```text
all checks passed!
```

Notable warning:

```text
evaluation warning: nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead.
```

`nix build .#theau-vps-bundle --print-out-paths` result:

```text
/nix/store/k7xbmq97s063s4g4cx1ah9c532cz1xcn-theau-vps-bundle
```

The build succeeded and `result` resolves to the same store path.

## Phase 0 Status

Acceptance criteria:

- `nix build .#theau-vps-bundle` succeeds: yes, using
  `/nix/var/nix/profiles/default/bin/nix` because `nix` was not in `PATH`
- `docs/implementation/current-vps-bundle.md` exists: yes
- Repo structure documented in notes: yes
- Build output verified and expected bundle files present: yes

No code or deployment behavior was changed in this phase. The only repository
change is this implementation document.
