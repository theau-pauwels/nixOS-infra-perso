# IONOS-VPS3 — Configuration OpenClaw

## Contexte

`IONOS-VPS3` (hostname: `openclaw-vps`) heberge OpenClaw, le bot Discord qui
remplace l'ancien `personal-secretary`. Ce host n'est **pas** gere par NixOS
— le deploiement est manuel (Node.js, npm, systemd --user).

IP publique : `87.106.38.127` (VPS IONOS)

## Fichiers

Tous les chemins sont relatifs a `/home/theau/`.

| Fichier local | Chemin sur le serveur | Role |
|---|---|---|
| `.openclaw/workspace/skills/*/SKILL.md` | `~/.openclaw/workspace/skills/` | Skills OpenClaw (personal-agenda, personal-mail-triage, personal-tasks, gog) |
| `.openclaw/workspace/MEMORY.md` | `~/.openclaw/workspace/MEMORY.md` | Memoire persistante de l'agent |
| `.openclaw/workspace/SOUL.md` | `~/.openclaw/workspace/SOUL.md` | Personnalite du bot |
| `.openclaw/workspace/IDENTITY.md` | `~/.openclaw/workspace/IDENTITY.md` | Identite de l'assistant |
| `.openclaw/workspace/USER.md` | `~/.openclaw/workspace/USER.md` | Infos sur l'utilisateur |
| `.openclaw/workspace/AGENTS.md` | `~/.openclaw/workspace/AGENTS.md` | Configuration des agents |
| `.openclaw/workspace/TOOLS.md` | `~/.openclaw/workspace/TOOLS.md` | Notes sur les outils locaux |
| `.openclaw/workspace/HEARTBEAT.md` | `~/.openclaw/workspace/HEARTBEAT.md` | Healthcheck |
| `.openclaw/workspace/calendar-context.md` | `~/.openclaw/workspace/calendar-context.md` | Contexte calendrier |
| `.openclaw/workspace/tasks/current.md` | `~/.openclaw/workspace/tasks/current.md` | Taches en cours |
| `.openclaw/cron/jobs.json` | `~/.openclaw/cron/jobs.json` | Cron jobs (daily/weekly summaries) |
| `.local/bin/my-agenda` | `~/.local/bin/my-agenda` | Script d'agenda (gog + ICS) |
| `.local/bin/my-ics-events` | `~/.local/bin/my-ics-events` | Parser ICS (Python) |
| `.config/openclaw/calendars/*.url` | `~/.config/openclaw/calendars/` | URLs des flux ICS UMONS |

## Fichiers NON commites (secrets)

Ces fichiers existent sur le serveur mais **ne sont pas** dans ce depot :

| Fichier | Contenu |
|---|---|
| `~/.openclaw/openclaw.json` | Config complete OpenClaw (tokens Discord, DeepSeek, OAuth) |
| `~/.config/gogcli/credentials.json` | OAuth client_id + client_secret Google |
| `~/.config/gogcli/keyring/` | Refresh token OAuth chiffre |
| `~/.config/gogcli/state/` | State gog (historyId, watch expiry) |
| `~/.bashrc` | `GOG_KEYRING_PASSWORD` et autres variables |
| `/etc/caddy/Caddyfile` | Configuration Caddy (domaine endpoint3.theau.net) |

## Deploiement

Pour deployer une modification depuis ce depot :

```bash
# Copier les fichiers
scp -r hosts/ionos-vps3/.openclaw theau@IONOS-VPS3:
scp -r hosts/ionos-vps3/.local theau@IONOS-VPS3:
scp -r hosts/ionos-vps3/.config theau@IONOS-VPS3:

# Ou en une commande
rsync -av hosts/ionos-vps3/ theau@IONOS-VPS3:/
```

Les skills sont reloades automatiquement par OpenClaw (hot reload).
Les scripts (`my-agenda`, `my-ics-events`) sont lus a chaque appel.

## Voir aussi

- `docs/implementation/openclaw-ionos-vps3.md` — Documentation complete de l'implementation
- `docs/openclaw-gmail-webhook.md` — Architecture du webhook Gmail
- `prompts/phases/phase-8.1-openclaw-gmail-webhook.md` — Phase tracking
