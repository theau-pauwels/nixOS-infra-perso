# OpenClaw Gmail Webhook — Mail Triage vers Discord

## Contexte

OpenClaw est le bot Discord qui remplace l'ancien `personal-secretary` (Phase 8).
Il tourne sur `IONOS-VPS3` et intègre plusieurs skills, dont le tri de mails
Gmail.

L'objectif de ce webhook est de détecter rapidement les nouveaux mails Gmail,
de trier leur importance via le skill `personal-mail-triage`, et de notifier
uniquement les mails importants dans le canal Discord `#📥-inbox`.

Les mails UMONS et facultaires sont transférés automatiquement vers la boîte
Gmail personnelle. La détection se fait donc sur une seule source : Gmail.

## Architecture

```text
Gmail (boîte perso)
  │
  │ push notification (Pub/Sub ou watch Gmail API)
  ▼
gog (Gmail OAuth Gateway)
  │
  │ token OAuth, polling ou watch
  ▼
OpenClaw (bot Discord sur IONOS-VPS3)
  │
  │ skill: personal-mail-triage
  │   - classification (important / newsletter / spam / UMONS / admin)
  │   - extraction des deadlines, relances, actions requises
  │   - dédoublonnage par Message-ID
  ▼
Discord #📥-inbox
  │
  │ notification formatée :
  │   - objet
  │   - expéditeur
  │   - priorité
  │   - extrait ou résumé court
  │   - action suggérée si applicable
  ▼
utilisateur (lecture + action)
```

## Prérequis

### Sur IONOS-VPS3

- OpenClaw installé et fonctionnel (binaire ou package Nix).
- Systemd pour la supervision.
- Connectivité réseau sortante vers :
  - `gmail.googleapis.com` (API Gmail)
  - `discord.com` (API Discord)
  - `oauth2.googleapis.com` (token OAuth si géré par gog)

### Compte Google / Gmail

- Gmail API activée dans la console Google Cloud.
- Identifiants OAuth 2.0 (client ID, client secret) avec le scope
  `https://www.googleapis.com/auth/gmail.readonly`.
- Refresh token stocké hors du dépôt (voir Sécurité).
- L'account Gmail doit avoir la 2FA activée (prérequis pour OAuth ou app password).

### Serveur Discord

- Un bot Discord avec les permissions :
  - View Channels
  - Send Messages
  - Read Message History
  - Use Slash Commands
- Canal `#📥-inbox` existant (ou créé automatiquement par OpenClaw).
- ID du serveur (guild ID) connu.

### gog (Gmail OAuth Gateway)

Outil CLI utilisé par OpenClaw pour s'authentifier à l'API Gmail via OAuth 2.0.
Il gère :
- Le stockage local du refresh token (fichier keyring ou fichier token).
- Le renouvellement automatique des access tokens.
- L'accès read-only à la boîte Gmail (list, get, watch).

## Variables d'environnement

Toutes les variables ci-dessous doivent être fournies à OpenClaw **sans valeur**
dans ce dépôt. Les valeurs réelles sont stockées dans un fichier `EnvironmentFile`
protégé ou dans `/run/secrets/`.

| Variable | Description | Sensible |
|---|---|---|
| `DISCORD_BOT_TOKEN` | Token du bot Discord | Oui |
| `DISCORD_GUILD_ID` | ID du serveur Discord | Non (semi-public) |
| `DISCORD_INBOX_CHANNEL_ID` | ID du canal `#📥-inbox` | Non |
| `GMAIL_CLIENT_ID` | OAuth 2.0 client ID Google | Oui |
| `GMAIL_CLIENT_SECRET` | OAuth 2.0 client secret Google | Oui |
| `GMAIL_REFRESH_TOKEN` | OAuth 2.0 refresh token Gmail | Oui |
| `GOG_KEYRING_PASSWORD` | Mot de passe du keyring gog local | Oui |
| `OPENAI_API_KEY` | Clé API OpenAI (pour le tri) | Oui |
| `OPENCLAW_DATA_DIR` | Répertoire de données OpenClaw | Non |
| `OPENCLAW_LOG_LEVEL` | Niveau de log (info, debug) | Non |

## Fichiers de configuration

### Emplacement

```
/etc/openclaw/
├── config.yaml          # Configuration principale OpenClaw
├── skills/
│   └── personal-mail-triage.yaml  # Configuration du skill mail
└── state/
    └── mail-cursor.json  # Dernier Message-ID traité (état runtime)
```

### Template `config.yaml`

```yaml
# /etc/openclaw/config.yaml — template sans secrets
discord:
  token: "${DISCORD_BOT_TOKEN}"
  guild_id: "${DISCORD_GUILD_ID}"

gmail:
  provider: "gog"
  client_id: "${GMAIL_CLIENT_ID}"
  client_secret: "${GMAIL_CLIENT_SECRET}"
  refresh_token: "${GMAIL_REFRESH_TOKEN}"
  poll_interval_seconds: 60
  watch_enabled: true

skills:
  personal-mail-triage:
    enabled: true
    inbox_channel_id: "${DISCORD_INBOX_CHANNEL_ID}"
    model: "gpt-4.1-mini"
    max_tokens_per_mail: 500
    categories:
      important:
        keywords: ["deadline", "urgence", "action requise", "rapport", "examen"]
        notify: true
      umons:
        from_patterns: ["@umons.ac.be"]
        notify: true
      admin:
        from_patterns: ["noreply@", "notification@"]
        notify: false
      newsletter:
        from_patterns: ["newsletter@", "news@"]
        notify: false
      spam:
        score_threshold: 0.3
        notify: false

logging:
  level: "${OPENCLAW_LOG_LEVEL:-info}"
  dir: "/var/log/openclaw"
```

## Commandes systemd

### Unité de service

`/etc/systemd/system/openclaw.service` :

```ini
[Unit]
Description=OpenClaw Discord Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
Group=openclaw
EnvironmentFile=/run/secrets/openclaw.env
ExecStart=/opt/openclaw/bin/openclaw run --config /etc/openclaw/config.yaml
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/openclaw
StateDirectory=openclaw
LogsDirectory=openclaw

[Install]
WantedBy=multi-user.target
```

### Timer de vérification mail (si pas de watch Gmail)

`/etc/systemd/system/openclaw-mail-check.service` :

```ini
[Unit]
Description=OpenClaw — Vérification périodique des mails Gmail
After=network-online.target

[Service]
Type=oneshot
User=openclaw
Group=openclaw
EnvironmentFile=/run/secrets/openclaw.env
ExecStart=/opt/openclaw/bin/openclaw mail-check
```

`/etc/systemd/system/openclaw-mail-check.timer` :

```ini
[Unit]
Description=OpenClaw — Timer de vérification des mails (toutes les 2 min)

[Timer]
OnBootSec=30
OnUnitActiveSec=120
AccuracySec=10

[Install]
WantedBy=timers.target
```

### Commandes utiles

```bash
# Démarrer / arrêter / statut
systemctl start openclaw
systemctl stop openclaw
systemctl status openclaw

# Activer le timer de vérification mail
systemctl enable --now openclaw-mail-check.timer

# Voir les logs
journalctl -u openclaw -f
journalctl -u openclaw-mail-check -f

# Vérifier les timers
systemctl list-timers openclaw-*
```

## Tests

### Test local du token Gmail

```bash
# Via gog : vérifier que l'authentification fonctionne
gog auth test --provider gmail

# Lister les 5 derniers messages (read-only)
gog mail list --max-results 5
```

### Test du webhook Gmail (watch)

```bash
# Vérifier que la watch Gmail est active
gog mail watch status

# Forcer une vérification manuelle
/opt/openclaw/bin/openclaw mail-check
```

### Test de bout en bout

1. Envoyer un mail test vers la boîte Gmail personnelle.
2. Vérifier les logs OpenClaw :
   ```bash
   journalctl -u openclaw -n 50 --no-pager | grep -i mail
   ```
3. Vérifier l'apparition dans `#📥-inbox` sur Discord.
4. Vérifier le dédoublonnage en renvoyant le même mail.

### Test de classification

1. Envoyer un mail avec `URGENT` dans l'objet → doit apparaître dans la catégorie `important`.
2. Envoyer un mail depuis une adresse `@umons.ac.be` → doit apparaître en `umons`.
3. Envoyer un mail depuis `newsletter@example.com` → ne doit pas être notifié.

## Troubleshooting

### Le bot ne reçoit pas les nouveaux mails

1. Vérifier que le service OpenClaw tourne :
   ```bash
   systemctl status openclaw
   ```
2. Vérifier les logs :
   ```bash
   journalctl -u openclaw -n 100 --no-pager
   ```
3. Vérifier que le token OAuth est valide :
   ```bash
   gog auth test
   ```
   Si le refresh token a expiré ou est révoqué, le regénérer via la console
   Google Cloud et mettre à jour `GMAIL_REFRESH_TOKEN` dans le fichier de secrets.

4. Vérifier que la watch Gmail est active :
   ```bash
   gog mail watch status
   ```
   La watch expire après 7 jours. OpenClaw doit la renouveler automatiquement.
   Si ce n'est pas le cas, redémarrer le service.

### Erreur d'authentification Gmail

- Cause fréquente : refresh token expiré ou révoqué.
- Solution : regénérer le refresh token (OAuth playground ou flow applicatif).
- Vérifier que l'application Google Cloud n'est pas en mode "Testing" avec
  un quota dépassé. Passer en "Production" ou ajouter l'utilisateur comme
  test user.

### Erreur gog keyring

- `GOG_KEYRING_PASSWORD` est nécessaire pour déverrouiller le fichier keyring
  local de gog.
- Si le mot de passe est perdu, supprimer le keyring (`/var/lib/openclaw/.gog/`)
  et refaire le flow OAuth complet.

### Le canal Discord n'existe pas

- Vérifier que `DISCORD_INBOX_CHANNEL_ID` est correct.
- Si OpenClaw gère l'auto-création de canaux, vérifier que le bot a la
  permission `Manage Channels`.
- Vérifier les logs pour des erreurs 404 ou 403 sur l'API Discord.

### Doublons dans #📥-inbox

- Vérifier que `mail-cursor.json` est accessible en écriture :
  ```bash
  ls -la /var/lib/openclaw/state/mail-cursor.json
  ```
- Si le fichier est corrompu, le supprimer et redémarrer le service.
  Le bot repartira du dernier message non traité.

## Sécurité des secrets

### Principes

- **Aucun secret** n'est présent dans ce dépôt Git.
- Les secrets transitent uniquement via :
  - `/run/secrets/openclaw.env` (fichier temporaire, monté en tmpfs).
  - Le fichier keyring local de `gog` (protégé par `GOG_KEYRING_PASSWORD`).
- Les fichiers de configuration dans `/etc/openclaw/` utilisent des
  variables d'environnement (`${VAR}`) et ne contiennent pas de secrets
  en clair.

### Fichiers à ne jamais commiter

```
/run/secrets/openclaw.env
/var/lib/openclaw/.gog/keyring
/etc/openclaw/config.yaml (si contient des secrets en dur)
~/.config/gog/credentials.json
local-secrets/openclaw.env
```

### Rotation des secrets

| Secret | Procédure de rotation |
|---|---|
| `DISCORD_BOT_TOKEN` | Discord Developer Portal → Bot → Reset Token |
| `GMAIL_REFRESH_TOKEN` | Rejouer le flow OAuth 2.0 → nouveau refresh token |
| `GOG_KEYRING_PASSWORD` | Regénérer via `gog keyring init` |
| `OPENAI_API_KEY` | OpenAI Dashboard → API Keys → Create |

Après rotation, mettre à jour le fichier de secrets sur IONOS-VPS3 et
redémarrer le service :

```bash
systemctl restart openclaw
```

### Backups

- La configuration Nix et les fichiers de template sont dans ce dépôt Git.
- Le fichier de secrets `/run/secrets/openclaw.env` n'est **pas** sauvegardé
  automatiquement. Utiliser le vault chiffré local pour le stocker :
  ```bash
  ./scripts/build-local-secret-vault.sh
  ```
- Le state (`mail-cursor.json`) est dans `/var/lib/openclaw/state/`. Il peut
  être sauvegardé mais n'est pas critique (le bot peut repartir de zéro).

## Déploiement sur IONOS-VPS3

IONOS-VPS3 n'est **pas** géré par Nix/NixOS. Le déploiement se fait de manière
classique :

1. Installer le binaire OpenClaw dans `/opt/openclaw/bin/`.
2. Copier les fichiers de configuration dans `/etc/openclaw/`.
3. Copier les unités systemd dans `/etc/systemd/system/`.
4. Créer l'utilisateur système `openclaw`.
5. Placer le fichier de secrets dans `/run/secrets/openclaw.env`.
6. Activer et démarrer les services.

### Arborescence cible

```
/opt/openclaw/
└── bin/
    └── openclaw          # binaire

/etc/openclaw/
├── config.yaml
└── skills/
    └── personal-mail-triage.yaml

/var/lib/openclaw/
├── .gog/                  # keyring gog (protégé)
└── state/
    └── mail-cursor.json

/var/log/openclaw/         # logs

/run/secrets/
└── openclaw.env           # secrets (tmpfs, root-only)
```

## TODO

- [ ] Tester le flow OAuth complet depuis IONOS-VPS3.
- [ ] Documenter la procédure exacte de création du refresh token Gmail
      (console Google Cloud → OAuth 2.0 → refresh token).
- [ ] Vérifier que `#📥-inbox` est créé automatiquement par OpenClaw ou
      documenter la création manuelle.
- [ ] Ajouter le canal `#📥-inbox` à la configuration Discord du bot.
- [ ] Vérifier la persistance de `/run/secrets/openclaw.env` après reboot
      (tmpfs → recréer via script au boot ou utiliser `/etc/` avec permissions 600).
