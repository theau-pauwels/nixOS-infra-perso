# OpenClaw — Implementation sur IONOS-VPS3

## Contexte

OpenClaw (v2026.5.4) est le bot Discord qui remplace l'ancien
`personal-secretary` (Phase 8). Il tourne sur `IONOS-VPS3`
(hostname: `openclaw-vps`, Ubuntu 24.04, non-NixOS).

Ce document decrit l'implementation reelle en production, pas
le script Python `openclaw-gmail-pubsub.py` du depot (qui est
une alternative standalone non deployee).

## Architecture

```text
Internet
  │
  │ HTTPS (Caddy, port 443)
  ▼
endpoint3.theau.net
  │
  ├── /gmail-pubsub* → localhost:8788 (gog)
  │     ▲ Google Cloud Pub/Sub push
  │
  └── /gateway* → localhost:18789 (OpenClaw gateway)
        ▲ Admin UI / API
```

### Processus

```
systemd --user (PID 1169)
  │
  ├── node openclaw gateway --port 18789          (PID 46680)
  │     │ port 18789 (loopback)
  │     │ plugins: discord, deepseek, duckduckgo
  │     │ hooks path: /hooks (dont /hooks/gmail)
  │
  └── node openclaw webhooks gmail run            (PID 46725)
        │
        └── openclaw-webhooks                     (PID 46734)
              │
              └── gog gmail watch serve            (PID 46754)
                    │ port 8788 (0.0.0.0)
                    │ path: /gmail-pubsub
                    │ hook → http://127.0.0.1:18789/hooks/gmail
```

### Flux d'un mail entrant

```
1. Gmail recoit un nouveau mail
2. Google Pub/Sub pousse vers https://endpoint3.theau.net/gmail-pubsub
3. Caddy proxy → localhost:8788 (gog)
4. gog verifie le token Pub/Sub, fetch le contenu via Gmail API
5. gog POST → http://127.0.0.1:18789/hooks/gmail
   Header: Authorization: Bearer <hook-token>
   Body: {source, account, historyId, messages: [{id, threadId, from, to,
          subject, date, snippet, body, labels}]}
6. OpenClaw gateway traite le hook, declenche le skill approprie
7. Le skill classifie le mail (via DeepSeek deepseek-v4-flash)
8. Si important/umons → notification Discord #📥-inbox
```

## Composants

### OpenClaw (Node.js)

- **Version** : 2026.5.4 (commit 325df3e)
- **Binaire** : `/home/theau/.npm-global/bin/openclaw`
- **Code** : `/home/theau/.npm-global/lib/node_modules/openclaw/dist/`
- **Config** : `/home/theau/.openclaw/openclaw.json`
- **Logs** : `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- **State** : `/home/theau/.openclaw/`
- **Plugin Discord** : `/home/theau/.openclaw/npm/node_modules/@openclaw/discord/`

### gog (Go)

- **Version** : v0.11.0
- **Binaire** : `/usr/local/bin/gog`
- **Source** : `/home/theau/gogcli/`
- **Config** : `/home/theau/.config/gogcli/config.json`
- **Credentials** : `/home/theau/.config/gogcli/credentials.json` (OAuth client_id + client_secret)
- **Keyring** : `/home/theau/.config/gogcli/keyring/` (refresh token chiffre)
- **Watch state** : `/home/theau/.config/gogcli/state/gmail-watch/theau_pauwels_gmail_com.json`

### Caddy

- **Config** : `/etc/caddy/Caddyfile`
- **Domaine** : `endpoint3.theau.net`
- **Ports** : 80, 443
- **Service** : `caddy.service` (systemd system)

## Configuration OpenClaw

Fichier : `/home/theau/.openclaw/openclaw.json`

Sections principales (sans secrets) :

```yaml
gateway:
  mode: local
  port: 18789
  bind: loopback
  auth:
    mode: token            # token fixe pour l'UI admin

agents:
  defaults:
    model:
      primary: deepseek/deepseek-v4-flash
    workspace: /home/theau/.openclaw/workspace

plugins:
  entries:
    deepseek:  { enabled: true }
    discord:   { enabled: true }
    duckduckgo: { enabled: true }

models:
  mode: merge
  providers:
    deepseek:
      baseUrl: https://api.deepseek.com
      api: openai-completions
      models:
        - deepseek-v4-flash (context: 1M, max_tokens: 384K)
        - deepseek-v4-pro   (context: 1M, max_tokens: 384K)
        - deepseek-chat

hooks:
  enabled: true
  path: /hooks
  token: "<hook-token>"    # auth entre gog et OpenClaw
  presets: [gmail]
  allowRequestSessionKey: true   # requis pour le hook gmail
  allowedSessionKeyPrefixes:
    - agent:
    - session:
    - hook:
  gmail:
    account: theau.pauwels@gmail.com
    label: INBOX
    topic: projects/goplaces-494720/topics/gog-gmail-watch
    subscription: gog-gmail-watch-push
    pushToken: "<pubsub-push-token>"
    includeBody: true
    maxBytes: 12000
    renewEveryMinutes: 720      # 12h
    serve:
      bind: 0.0.0.0
      port: 8788
      path: /gmail-pubsub

session:
  dmScope: per-channel-peer

tools:
  profile: coding
  web:
    search:
      provider: duckduckgo
      enabled: true
```

## Commandes

### Demarrage

Les processus sont lances manuellement (pas de systemd service) :

```bash
# Depuis une session utilisateur (theau)
export GOG_KEYRING_PASSWORD="<password>"
export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache

# Gateway principal
openclaw gateway --port 18789 &

# Webhook Gmail (lance gog en enfant)
openclaw webhooks gmail run \
  --account theau.pauwels@gmail.com \
  --bind 0.0.0.0 \
  --include-body \
  --max-bytes 12000 \
  --tailscale off &
```

En pratique, les processus sont geres par `systemd --user` et
persistent entre les deconnexions SSH.

### Arret

```bash
kill 46680   # openclaw gateway
kill 46725   # openclaw webhooks (tue aussi gog en cascade)
```

### Statut

```bash
ps -eo pid,user,cmd | grep -E "openclaw|gog" | grep -v grep
ss -tlnp | grep -E "8788|18789"
```

### Logs

```bash
# Logs OpenClaw (fichier)
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log

# Logs systemd --user (inclut gog)
journalctl --user -f | grep -E "openclaw|gog|hook|gmail"
```

### Test du hook Gmail

```bash
curl -s -X POST http://127.0.0.1:18789/hooks/gmail \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <hook-token>" \
  -d '{
    "source":"gmail",
    "account":"theau.pauwels@gmail.com",
    "historyId":"0",
    "messages":[{
      "id":"test",
      "threadId":"test",
      "from":"test@example.com",
      "subject":"Test",
      "snippet":"Test hook"
    }]
  }'
```

### Verification de l'etat gog

```bash
cat /home/theau/.config/gogcli/state/gmail-watch/theau_pauwels_gmail_com.json
# Verifier: lastDeliveryStatus = "ok"
```

## Google Cloud Platform

### Projet

- **Project ID** : `goplaces-494720`
- **Topic Pub/Sub** : `projects/goplaces-494720/topics/gog-gmail-watch`
- **Subscription** : `gog-gmail-watch-push` (type: push)
- **Push endpoint** : `https://endpoint3.theau.net/gmail-pubsub`

### APIs activees

- Gmail API
- Pub/Sub API

### OAuth 2.0

- Client ID / Client Secret : dans `/home/theau/.config/gogcli/credentials.json`
- Refresh token : dans le keyring file (`/home/theau/.config/gogcli/keyring/`)
- Scope Gmail : `https://www.googleapis.com/auth/gmail.readonly`
- Scope Pub/Sub : `https://www.googleapis.com/auth/pubsub`

## Workspace et Skills

### Repertoire

`/home/theau/.openclaw/workspace/`

### Skills installes

| Skill | Fichier | Usage |
|---|---|---|
| `personal-agenda` | `skills/personal-agenda/SKILL.md` | Agenda Google, iPhone, UMONS via `my-agenda` |
| `personal-mail-triage` | `skills/personal-mail-triage/SKILL.md` | Classification des mails Gmail, notification Discord `#📥-inbox` |
| `personal-tasks` | `skills/personal-tasks/SKILL.md` | Gestion des taches Discord `#✅-tasks` |
| `gog` | `skills/gog/SKILL.md` | CLI Google (Gmail, Calendar, Drive...) — requis par les autres skills |

> **Attention** : le skill `gog` (`skills/gog/SKILL.md`) est indispensable.
> Sans lui, tout appel a l'outil `gog` echoue avec :
> `[tools] read failed: ENOENT: no such file or directory, access '...gog/SKILL.md'`

### Fichiers du workspace

| Fichier | Role |
|---|---|
| `AGENTS.md` | Configuration des agents |
| `SOUL.md` | Personnalite du bot |
| `IDENTITY.md` | Identite de l'assistant |
| `USER.md` | Infos sur l'utilisateur (Theau) |
| `MEMORY.md` | Memoire persistante |
| `MEMORY.md` | Memoire persistante |
| `HEARTBEAT.md` | Healthcheck |
| `TOOLS.md` | Notes sur les outils locaux |
| `calendar-context.md` | Contexte calendrier |
| `memory/` | Souvenirs quotidiens (un `.md` par jour) |
| `tasks/` | Taches en cours |

### Cron jobs

Definis dans `/home/theau/.openclaw/cron/jobs.json` :

| Nom | Cron (Europe/Brussels) | Cible Discord |
|---|---|---|
| Resume de la journee | `0 7 * * *` (07:00) | channel:1500624381066350596 |
| Resume des taches | `10 7 * * *` (07:10) | — |
| Resume quotidien des taches | `10 7 * * *` (07:10) | `#✅-tasks` |
| Reminder: noms presidents cercles | `0 9 * * *` (09:00) | — |
| Resume de demain | `0 20 * * *` (20:00) | channel:1501277006812287018 |
| Resume semaine a venir | `0 21 * * 0` (dim. 21:00) | channel:1500624382609850528 |

## Discord

- **Bot** : OpenClaw, ID `1501239747585249430`
- **Guild** : Pixel's server, ID `1500615336687439912`
- **Canaux** :
  - `#📥-inbox` (ID: `1500624380286337185`) — notifications mail
  - `#✅-tasks` (ID: `1500624383515820143`) — taches actives
  - `#✅-task-done` (ID: `1501280239979069520`) — taches terminees
  - `#🔧-logs` (ID: `1500624388502978819`) — logs
- **Permissions** : View Channels, Send Messages, Read Message History

## Variables d'environnement

| Variable | Usage | Fichier |
|---|---|---|
| `GOG_KEYRING_PASSWORD` | Deverrouille le keyring gog | `~/.bashrc` |
| `NODE_COMPILE_CACHE` | Cache compilation Node | `~/.bashrc` |
| `OPENCLAW_NO_RESPAWN` | Empeche le respawn auto | `~/.bashrc` |

## Points de vigilance

### `allowRequestSessionKey`

**Obligatoire** pour le hook Gmail. Sans cette option, le hook retourne
HTTP 400 : `"sessionKey is disabled for externally supplied hook payload values"`.

Ajoute dans `openclaw.json` :
```json
"hooks": {
  "allowRequestSessionKey": true
}
```

### `GOG_KEYRING_PASSWORD`

Necessaire pour que gog puisse dechiffrer le refresh token stocke dans
le keyring file. Sans cette variable, gog echoue avec :
```
no TTY available for keyring file backend password prompt
```

Definie dans `~/.bashrc` (lue par le shell de l'utilisateur `theau`).

### Renouvellement de la watch Gmail

La watch Gmail expire apres 7 jours. OpenClaw (`renewEveryMinutes: 720`)
la renouvelle automatiquement toutes les 12h via gog.

### Historique Gmail

Le `historyId` est stocke dans le state gog. En cas de corruption ou
de mail manque, supprimer le fichier de state pour forcer une
resynchronisation complete :

```bash
rm /home/theau/.config/gogcli/state/gmail-watch/theau_pauwels_gmail_com.json
# Puis redemarrer openclaw webhooks gmail run
```

## Troubleshooting

### Le hook retourne HTTP 400

1. Verifier `allowRequestSessionKey: true` dans `openclaw.json`
2. Verifier que le preset `gmail` est dans `hooks.presets`
3. Verifier le token dans `Authorization: Bearer <hook-token>`

### gog ne demarre pas / erreur keyring

```bash
# Verifier que la variable est definie
echo $GOG_KEYRING_PASSWORD

# Tester gog manuellement
GOG_KEYRING_PASSWORD="<password>" gog gmail watch serve \
  --account theau.pauwels@gmail.com \
  --port 8789 \
  --path /test \
  --allow-no-hook
```

### Gmail API 403

- Verifier que la Gmail API est activee dans la console GCP
- Verifier que le refresh token est valide (pas revoque)
- Le refresh token expire si l'app OAuth est en mode "Testing"
  et que l'utilisateur n'est pas dans la liste des test users

### Pub/Sub ne pousse pas

- Verifier que la subscription est de type **push** avec l'URL
  `https://endpoint3.theau.net/gmail-pubsub`
- Verifier que le endpoint est accessible depuis Internet (Caddy,
  DNS, firewall)
- Verifier que la watch Gmail est active (dans le state gog)

### Doublons dans #📥-inbox

- gog deduplique par `historyId` et `pushMessageId`
- Si des doublons apparaissent, verifier que le state gog est
  accessible en ecriture

## Securite

### Secrets (jamais dans le depot Git)

| Secret | Emplacement |
|---|---|
| `DISCORD_BOT_TOKEN` | `/home/theau/.openclaw/openclaw.json` (channels.discord.token) |
| OAuth `client_id` / `client_secret` | `/home/theau/.config/gogcli/credentials.json` |
| OAuth refresh token | `/home/theau/.config/gogcli/keyring/` (chiffre) |
| `DEEPSEEK_API_KEY` | `/home/theau/.openclaw/openclaw.json` (models.providers.deepseek.apiKey) |
| Hook token | `/home/theau/.openclaw/openclaw.json` (hooks.token) |
| Pub/Sub push token | `/home/theau/.openclaw/openclaw.json` (hooks.gmail.pushToken) |
| `GOG_KEYRING_PASSWORD` | `~/.bashrc` (variable d'environnement) |

### Fichiers a ne jamais commiter

```
.openclaw/openclaw.json       # contient des tokens
.config/gogcli/credentials.json
.config/gogcli/keyring/
.config/gogcli/state/
/tmp/openclaw/
. npm-global/
```

### .gitignore

Les patterns suivants sont deja dans le `.gitignore` du depot :
```
*.env
*.env.*
credentials.json
*.gog
openclaw.env
```

## Mise a jour d'OpenClaw

```bash
npm update -g openclaw @openclaw/discord
# Puis redemarrer les processus
```

## Mise a jour de gog

```bash
cd /home/theau/gogcli
git pull
make build
sudo cp bin/gog /usr/local/bin/gog
```

## TODO

- [ ] Ajouter un systemd service pour le gateway OpenClaw
- [ ] Ajouter un systemd service pour le webhook Gmail
- [ ] Separer les secrets dans `/run/secrets/` au lieu de `openclaw.json`
- [ ] Ajouter un healthcheck periodique sur le hook Gmail
- [ ] Documenter le skill `personal-mail-triage` (non encore actif)
- [ ] Mettre en place un canal `#📥-inbox` automatise (creation au boot)
- [ ] Monitorer l'expiration de la watch Gmail
- [ ] Ajouter un failover : si Pub/Sub down, fallback polling Gmail API
