# Phase 8.1 — OpenClaw Gmail Webhook (Implementation Pub/Sub + DeepSeek)

> **Host cible**: `IONOS-VPS3` (non-NixOS)
> **Date**: 2026-05-05

## Contexte

OpenClaw est le bot Discord qui remplace l'ancien `personal-secretary`.
Il tourne sur `IONOS-VPS3`.

Cette phase implemente le pipeline Gmail Pub/Sub -> DeepSeek -> Discord
`#📥-inbox`. Le script `openclaw-gmail-pubsub.py` tourne comme service
systemd sur IONOS-VPS3, recoit les notifications Pub/Sub en quasi temps
reel, classifie les mails avec DeepSeek, et notifie uniquement les mails
importants dans `#📥-inbox`.

## Architecture implementee

```
Gmail API users.watch -> Google Cloud Pub/Sub topic
                                    │
                            subscription (pull)
                                    │
                     openclaw-gmail-pubsub.py
                      (systemd service)
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
               Gmail API       DeepSeek API    Discord
               (fetch msg)     (classify)      (webhook)
```

- **Pub/Sub pull** uniquement (pas de polling IMAP/Gmail)
- **DeepSeek** (`deepseek-chat`) pour la classification
- **Fallback heuristique** si DeepSeek indisponible
- **Deduplication** par Message-ID + historyId
- **Renouvellement automatique** de la watch Gmail (tous les 6 jours)

## Fichiers produits

| Fichier | Role |
|---|---|
| `scripts/openclaw-gmail-pubsub.py` | Script principal (stdlib Python) |
| `docs/openclaw-gmail-webhook.md` | Documentation complete (mise a jour) |
| `.gitignore` | Patterns pour secrets OpenClaw/Gmail |
| `prompts/phases/phase-8.1-openclaw-gmail-webhook.md` | Ce fichier |

## Details du script

`scripts/openclaw-gmail-pubsub.py` (~500 lignes) :

- **TokenManager** : refresh OAuth 2.0 automatique
- **GmailAPI** : `users.watch`, `users.history.list`, `users.messages.get`
- **PubSubClient** : pull long-poll (30s timeout), acknowledge
- **classify_email** : appel DeepSeek avec retry (3 tentatives, backoff exponentiel)
- **_heuristic_classify** : fallback par mots-cles (francais + anglais)
- **send_discord_notification** : embed Discord formate (titre, champs, couleur)
- **State** : persistance de `historyId`, `watchExpiry`, `seenIds`
- **Signal handling** : SIGINT/SIGTERM -> shutdown gracieux

### Variables d'environnement requises

```
GMAIL_CLIENT_ID
GMAIL_CLIENT_SECRET
GMAIL_REFRESH_TOKEN
GMAIL_PUBSUB_TOPIC
GMAIL_PUBSUB_SUBSCRIPTION
DEEPSEEK_API_KEY
DISCORD_WEBHOOK_URL
STATE_DIR (defaut: /var/lib/openclaw/state)
LOG_LEVEL (defaut: info)
```

## Systemd

Unite : `openclaw-gmail-pubsub.service`

- User/Group : `openclaw`
- EnvironmentFile : `/run/secrets/openclaw.env`
- Restart : `on-failure` avec `RestartSec=10`
- Sandboxing : `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=yes`

Unite auxiliaire : `openclaw-secrets.service` (oneshot avant le main)
pour recreer `/run/secrets/openclaw.env` apres reboot a partir d'une
source persistante.

## Taches realisees

- [x] Script Python `openclaw-gmail-pubsub.py` (stdlib uniquement)
  - [x] OAuth 2.0 token management avec refresh automatique
  - [x] Gmail API : watch, history.list, messages.get
  - [x] Pub/Sub pull + acknowledge
  - [x] Classification DeepSeek avec retry (3 tentatives)
  - [x] Fallback heuristique (mots-cles FR/EN)
  - [x] Notification Discord (embed colore par categorie)
  - [x] Deduplication (gmail-seen-ids.json, garde 5000 IDs)
  - [x] Renouvellement auto de la watch Gmail (6 jours)
  - [x] Graceful shutdown (SIGINT/SIGTERM)
- [x] Documentation `docs/openclaw-gmail-webhook.md` :
  - [x] Architecture Pub/Sub uniquement (pas de polling)
  - [x] Prerequisites GCP (topic, subscription, IAM)
  - [x] Variables d'environnement (7 obligatoires + 2 optionnelles)
  - [x] Systemd service + secrets boot oneshot
  - [x] Tests (token, watch, Pub/Sub pull, bout en bout, classification, dedup)
  - [x] Troubleshooting (6 scenarios)
  - [x] Format de notification Discord (embed structure)
  - [x] Securite (principes, fichiers ignores, rotation, backups)
  - [x] Deploiement et arborescence cible
- [x] Mise a jour de `.gitignore`
- [x] Phase document cree

## Validation

```bash
git status --short
git diff --cached
nix flake check  # le depot Nix ne doit pas etre casse
python3 -c "import py_compile; py_compile.compile('scripts/openclaw-gmail-pubsub.py', doraise=True)"
```

## Prochaines phases

- **Phase 8.2** : Deploiement sur IONOS-VPS3 (scp, user, secrets, systemd, first run)
- **Phase 8.3** : Test OAuth + Pub/Sub de bout en bout, calibration DeepSeek
- **Phase 8.4** : Monitoring et alertes (healthcheck, downtime alerts)
- **Phase 8.5** : Webhook secondaire pour UMONS (si转发 change)

## Diagnostic et correction sur IONOS-VPS3 (2026-05-09)

### Probleme
Le mail de 1h47 UTC n'a pas ete delivre. gog a bien recu la notification
Pub/Sub a 01:48:11 UTC, mais le forward vers OpenClaw a echoue avec HTTP 400.

### Cause
`hooks.allowRequestSessionKey` etait absent de `/home/theau/.openclaw/openclaw.json`.
Le hook Gmail retournait :
```json
{"ok":false,"error":"sessionKey is disabled for externally supplied hook payload values; set hooks.allowRequestSessionKey=true to enable"}
```

### Correction
Ajout de `"allowRequestSessionKey": true` dans la section `hooks` du fichier
`/home/theau/.openclaw/openclaw.json`. Hot reload detecte et applique par
OpenClaw. Test curl confirme HTTP 200.

### Resultat
- `lastDeliveryStatus` dans le state gog passe de `"http_error"` a `"ok"`
- Le mail de test suivant est passe correctement
- Le mail de 1h47 UTC n'a pas ete rejoue (historyId deja avance)

## Notes

- IONOS-VPS3 n'est **pas** gere par Nix/NixOS. Le deploiement est manuel.
- Aucun secret dans ce depot (`.env`, `credentials.json`, `*.gog`, `openclaw.json` ignores).
- Le script Python `openclaw-gmail-pubsub.py` n'est pas deploye — OpenClaw
  natif (Node.js) et gog (Go) sont utilises en production.
- Le Pub/Sub remplace le polling IMAP - latence < 5s au lieu de 60-120s.
- DeepSeek remplace OpenAI (`deepseek-v4-flash` au lieu de `gpt-4.1-mini`).
