# OpenClaw Gmail Webhook — Mail Triage vers Discord

## Contexte

OpenClaw est le bot Discord qui remplace l'ancien `personal-secretary` (Phase 8).
Il tourne sur `IONOS-VPS3` et integre plusieurs skills, dont le tri de mails
Gmail.

L'objectif de ce webhook est de detecter rapidement les nouveaux mails Gmail,
de trier leur importance via DeepSeek, et de notifier uniquement les mails
importants dans le canal Discord `#📥-inbox`.

Les mails UMONS et facultaires sont transferes automatiquement vers la boite
Gmail personnelle. La detection se fait donc sur une seule source : Gmail.

## Architecture

```text
Gmail (boite perso)
  │
  │ Gmail API users.watch -> cree/enregistre une watch
  ▼
Google Cloud Pub/Sub (topic + subscription)
  │
  │ pull (long-poll) — near real-time
  ▼
scripts/openclaw-gmail-pubsub.py (systemd service sur IONOS-VPS3)
  │
  │ 1. recoit la notification Pub/Sub
  │ 2. fetch le message complet (Gmail API users.messages.get)
  │ 3. classifie via DeepSeek API (deepseek-chat)
  │    categories : important / umons / newsletter / admin / spam
  │ 4. dedoublonne par Message-ID + historyId
  │
  ▼
Discord #📥-inbox (webhook)
  │
  │ embed Discord formate :
  │   - objet, expediteur, date
  │   - categorie + score d'importance
  │   - resume FR (genere par DeepSeek)
  │   - action suggeree + deadline si applicable
  ▼
utilisateur (lecture + action)
```

### Pourquoi Pub/Sub uniquement (pas de polling)

- Le polling IMAP ou Gmail API `users.messages.list` introduit une latence
  (intervalle minimum de 60s recommande par Google).
- Pub/Sub pull livre les notifications en quasi temps reel (< 5s).
- La watch Gmail expire apres 7 jours ; le script la renouvelle automatiquement
  au bout de 6 jours.
- En cas d'echec de Pub/Sub, le script s'arrete et systemd le relance — il
  rattrape l'historique via `users.history.list`.

## Prerequis

### Sur IONOS-VPS3

- Python 3.10+ (stdlib uniquement — pas de pip requis).
- Systemd pour la supervision.
- Connectivite reseau sortante vers :
  - `gmail.googleapis.com` (API Gmail)
  - `pubsub.googleapis.com` (Google Cloud Pub/Sub)
  - `oauth2.googleapis.com` (refresh token OAuth)
  - `api.deepseek.com` (classification IA)
  - `discord.com` (webhook)

### Google Cloud Platform

- Projet GCP avec les API suivantes activees :
  - **Gmail API** : scope `https://www.googleapis.com/auth/gmail.readonly`
  - **Pub/Sub API** : pour recevoir les notifications
- Un topic Pub/Sub cree (ex: `projects/<project>/topics/gmail-notifications`).
- Un abonnement (subscription) **pull** cree sur ce topic
  (ex: `projects/<project>/subscriptions/gmail-notifications-sub`).
- Identifiants OAuth 2.0 (client ID, client secret) configures dans la
  console Google Cloud.
- Refresh token long-lived stocke hors depot.
- Le compte Gmail doit avoir la 2FA activee (prerequis OAuth).

### Permissions IAM

Le compte OAuth ou le service account doit avoir les roles :
- `roles/pubsub.subscriber` sur la subscription
- L'utilisateur Gmail doit avoir acces a sa propre boite (OAuth scope readonly)

### Serveur Discord

- Un webhook Discord configure pour le canal `#📥-inbox`.
- L'URL du webhook est de la forme :
  `https://discord.com/api/webhooks/<id>/<token>`

### DeepSeek

- Cle API DeepSeek (`deepseek-chat` model).
- Endpoint : `https://api.deepseek.com/v1/chat/completions`

## Variables d'environnement

Toutes les variables ci-dessous sont requises. Les valeurs reelles sont stockees
dans `/run/secrets/openclaw.env` (tmpfs, root-only).

| Variable | Description |
|---|---|
| `GMAIL_CLIENT_ID` | OAuth 2.0 client ID Google |
| `GMAIL_CLIENT_SECRET` | OAuth 2.0 client secret Google |
| `GMAIL_REFRESH_TOKEN` | OAuth 2.0 refresh token (long-lived) |
| `GMAIL_PUBSUB_TOPIC` | Topic Pub/Sub : `projects/<p>/topics/<t>` |
| `GMAIL_PUBSUB_SUBSCRIPTION` | Subscription Pub/Sub : `projects/<p>/subscriptions/<s>` |
| `DEEPSEEK_API_KEY` | Cle API DeepSeek |
| `DISCORD_WEBHOOK_URL` | URL du webhook Discord `#📥-inbox` |
| `STATE_DIR` | Repertoire state (defaut: `/var/lib/openclaw/state`) |
| `LOG_LEVEL` | `debug`, `info`, `warning`, `error` (defaut: `info`) |

## Fichiers

### Script principal

`scripts/openclaw-gmail-pubsub.py` dans ce depot.

Le script est concu pour fonctionner avec la stdlib Python uniquement
(aucune dependance pip). Il utilise `urllib` pour toutes les requetes HTTP.

### Fichiers d'etat runtime

```
/var/lib/openclaw/state/
├── gmail-history-id.txt     # Dernier historyId Gmail traite
├── gmail-watch-expiry.txt   # Timestamp d'expiration de la watch
└── gmail-seen-ids.json      # Message-IDs deja traites (dedup)
```

### Unite systemd

`/etc/systemd/system/openclaw-gmail-pubsub.service` :

```ini
[Unit]
Description=OpenClaw Gmail Pub/Sub Notifier
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
Group=openclaw
EnvironmentFile=/run/secrets/openclaw.env
ExecStart=/opt/openclaw/scripts/openclaw-gmail-pubsub.py
Restart=on-failure
RestartSec=10
WorkingDirectory=/var/lib/openclaw
StateDirectory=openclaw
LogsDirectory=openclaw

# Securite
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openclaw/state
ReadOnlyPaths=/run/secrets/openclaw.env

[Install]
WantedBy=multi-user.target
```

### Commandes utiles

```bash
# Demarrer / arreter / statut
systemctl start openclaw-gmail-pubsub
systemctl stop openclaw-gmail-pubsub
systemctl status openclaw-gmail-pubsub

# Activer au boot
systemctl enable openclaw-gmail-pubsub

# Voir les logs
journalctl -u openclaw-gmail-pubsub -f
journalctl -u openclaw-gmail-pubsub -n 100 --no-pager
```

## Classification DeepSeek

### Categories

| Categorie | Notifie ? | Description |
|---|---|---|
| `important` | **Oui** | Mails necessitant action/reponse, deadlines, examens, conversations personnelles |
| `umons` | **Oui** | Mails provenant de `@umons.ac.be` (faculte, cours) |
| `admin` | Seulement si score > 0.7 | Notifications systeme, alertes login, recus, confirmations |
| `newsletter` | Non | Listes de diffusion, promotions, news digests |
| `spam` | Non | Non sollicite, promotionnel, phishing |

### Fallback heuristique

Si DeepSeek est indisponible (erreur reseau, rate limit, ou cle API absente),
le script utilise une classification basee sur des regles :

- Adresse `@umons.ac.be` -> `umons`
- Mots-cles dans le sujet (`deadline`, `urgence`, `examen`, `rapport`...) -> `important`
- Mots-cles newsletter (`newsletter`, `digest`, `promo`...) ou `noreply` -> `newsletter`
- Mots-cles admin (`notification`, `login`, `facture`...) -> `admin`
- Defaut -> `important` (score 0.5)

## Format de notification Discord

Les notifications sont envoyees en tant qu'**embed** Discord :

```yaml
# Exemple d'embed
title: "🔴 [Examen] Convocation session de juin"
color: 0xFF4444  # rouge pour important, bleu pour umons
fields:
  - De: professeur@umons.ac.be
  - Categorie: umons (80%)
  - Resume: Convocation a l'examen de Mathematiques le 15 juin...
  - Action: Preparer l'examen, verifier l'horaire
  - Deadline: 15 juin 2026 14:00
footer: "📅 Mon, 12 May 2026 09:30:00 +0200"
```

Couleurs par categorie :
- `important` : rouge (`#FF4444`)
- `umons` : bleu (`#4499FF`)
- `admin` : gris (`#888888`)

## Tests

### Test du token OAuth Gmail

```bash
# Verifier que l'OAuth fonctionne (refresh token -> access token)
curl -s -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq -r .access_token
```

### Test de la watch Gmail

```bash
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq -r .access_token)

# Creer/enregistrer la watch
curl -s -X POST "https://gmail.googleapis.com/gmail/v1/users/me/watch" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"topicName\": \"$GMAIL_PUBSUB_TOPIC\", \"labelIds\": [\"INBOX\"]}" | jq .
```

### Test du Pub/Sub pull

```bash
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq -r .access_token)

# Pull des messages
curl -s -X POST "https://pubsub.googleapis.com/v1/${GMAIL_PUBSUB_SUBSCRIPTION}:pull" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"maxMessages": 5, "returnImmediately": true}' | jq .
```

### Test de bout en bout

1. Envoyer un mail test depuis une adresse externe vers la boite Gmail.
2. Verifier les logs du service :
   ```bash
   journalctl -u openclaw-gmail-pubsub -n 50 --no-pager
   ```
3. Le log doit montrer :
   - `Found 1 new message(s)`
   - `Classifying: <sujet> — <expediteur>`
   - `📬 Notifying: <sujet> (category=..., score=...%)`
4. Verifier l'apparition dans `#📥-inbox` sur Discord.

### Test de classification

1. Envoyer un mail avec `URGENT` dans l'objet -> doit apparaitre en `important`.
2. Envoyer un mail depuis une adresse `@umons.ac.be` -> doit apparaitre en `umons`.
3. Envoyer un mail depuis `newsletter@example.com` -> ne doit pas etre notifie.
4. Envoyer un mail avec `notification de securite` -> `admin`, notifie
   seulement si score > 0.7.

### Test de dedoublonnage

1. Envoyer un mail.
2. Attendre la notification dans `#📥-inbox`.
3. Redemarrer le service :
   ```bash
   systemctl restart openclaw-gmail-pubsub
   ```
4. Verifier que le meme mail n'apparait pas une seconde fois (le service
   utilise `gmail-seen-ids.json`).

## Troubleshooting

### Le service ne recoit pas les notifications

1. Verifier que le service tourne :
   ```bash
   systemctl status openclaw-gmail-pubsub
   ```
2. Verifier les logs :
   ```bash
   journalctl -u openclaw-gmail-pubsub -n 100 --no-pager
   ```
3. Verifier que le token OAuth est valide :
   ```bash
   # Tester manuellement (voir section Tests)
   ```
   Si le refresh token a expire ou est revoque, le regenerer via la console
   Google Cloud et mettre a jour `/run/secrets/openclaw.env`.

4. Verifier que la watch Gmail est active :
   ```bash
   ACCESS_TOKEN=...
   curl -s "https://gmail.googleapis.com/gmail/v1/users/me/profile" \
     -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
   ```
   La watch expire apres 7 jours. Le service la renouvelle automatiquement.

5. Verifier que Pub/Sub recoit bien les messages :
   - Aller dans la console GCP > Pub/Sub > Subscription.
   - Cliquer sur "View messages" et faire un pull manuel.
   - Si aucun message n'arrive, verifier que la watch Gmail est bien
     configuree avec le bon topic.

### Erreur "403 — Gmail API not enabled"

- Activer la Gmail API dans la console Google Cloud.
- Verifier que le scope OAuth inclut `https://www.googleapis.com/auth/gmail.readonly`.

### Erreur "403 — Pub/Sub API not enabled"

- Activer la Pub/Sub API dans la console Google Cloud.
- Verifier que le compte a le role `roles/pubsub.subscriber` sur la subscription.

### Erreur "401 — unauthorized" sur Pub/Sub

- Le refresh token OAuth fonctionne pour Gmail mais pas forcement pour Pub/Sub.
- Solution : ajouter le scope `https://www.googleapis.com/auth/pubsub` lors
  de la generation du refresh token, ou utiliser un service account JSON
  a la place du refresh token OAuth pour Pub/Sub.

### Doublons dans #📥-inbox

- Verifier que `gmail-seen-ids.json` est accessible en ecriture :
  ```bash
  ls -la /var/lib/openclaw/state/gmail-seen-ids.json
  ```
- Si le fichier est corrompu, le supprimer et redemarrer le service.

### DeepSeek retourne des erreurs

- Verifier la cle API :
  ```bash
  curl -s https://api.deepseek.com/v1/models \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" | jq .
  ```
- En cas de rate limit (429), le script reessaie automatiquement 3 fois
  avec backoff exponentiel.
- Si DeepSeek echoue completement, le fallback heuristique prend le relais.

## Securite des secrets

### Principes

- **Aucun secret** n'est present dans ce depot Git.
- Les secrets sont injectes via `/run/secrets/openclaw.env` (tmpfs, root-only).
- Le script Python lit les variables d'environnement uniquement.
- Les fichiers de state (`/var/lib/openclaw/state/`) ne contiennent
  aucun secret (historyId, timestamps, Message-IDs).

### Fichiers a ne jamais commiter

```
/run/secrets/openclaw.env
local-secrets/openclaw.env
*.env
credentials.json
*.gog
```

### Rotation des secrets

| Secret | Procedure |
|---|---|
| `GMAIL_REFRESH_TOKEN` | Rejouer le flow OAuth 2.0 -> nouveau refresh token |
| `DEEPSEEK_API_KEY` | DeepSeek Dashboard -> API Keys -> Create |
| `DISCORD_WEBHOOK_URL` | Discord -> Parametres du canal -> Integrations -> Webhooks |

Apres rotation, mettre a jour `/run/secrets/openclaw.env` et redemarrer :

```bash
systemctl restart openclaw-gmail-pubsub
```

### Backups

- Le script est dans ce depot Git (`scripts/openclaw-gmail-pubsub.py`).
- La configuration systemd est documentee ci-dessus.
- Le fichier de secrets `/run/secrets/openclaw.env` n'est **pas** sauvegarde
  automatiquement. Utiliser le vault chiffre local :
  ```bash
  ./scripts/build-local-secret-vault.sh
  ```
- Les fichiers de state dans `/var/lib/openclaw/state/` ne sont pas
  critiques (le service peut repartir de zero).

## Deploiement sur IONOS-VPS3

IONOS-VPS3 n'est **pas** gere par Nix/NixOS. Le deploiement est manuel :

1. Copier le script sur le serveur :
   ```bash
   scp scripts/openclaw-gmail-pubsub.py root@IONOS-VPS3:/opt/openclaw/scripts/
   ```
2. Creer l'utilisateur systeme :
   ```bash
   useradd -r -s /sbin/nologin -d /var/lib/openclaw -m openclaw
   ```
3. Creer le fichier de secrets :
   ```bash
   cat > /run/secrets/openclaw.env << 'EOF'
   GMAIL_CLIENT_ID=...
   GMAIL_CLIENT_SECRET=...
   GMAIL_REFRESH_TOKEN=...
   GMAIL_PUBSUB_TOPIC=projects/.../topics/...
   GMAIL_PUBSUB_SUBSCRIPTION=projects/.../subscriptions/...
   DEEPSEEK_API_KEY=sk-...
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/.../...
   EOF
   chmod 600 /run/secrets/openclaw.env
   ```
4. Installer l'unite systemd :
   ```bash
   cp openclaw-gmail-pubsub.service /etc/systemd/system/
   systemctl daemon-reload
   ```
5. Demarrer et activer :
   ```bash
   systemctl enable --now openclaw-gmail-pubsub
   systemctl status openclaw-gmail-pubsub
   ```

### Arborescence cible

```
/opt/openclaw/
└── scripts/
    └── openclaw-gmail-pubsub.py    # script de ce depot

/var/lib/openclaw/
└── state/
    ├── gmail-history-id.txt
    ├── gmail-watch-expiry.txt
    └── gmail-seen-ids.json

/run/secrets/
└── openclaw.env                    # secrets (tmpfs, root-only)

/etc/systemd/system/
└── openclaw-gmail-pubsub.service
```

### Script de boot pour recreer /run/secrets

`/run` est un tmpfs, donc le fichier `/run/secrets/openclaw.env` disparait
apres reboot. Solution : un oneshot systemd qui le recreer a partir d'un
fichier source securise ou d'un vault.

`/etc/systemd/system/openclaw-secrets.service` :

```ini
[Unit]
Description=Restore OpenClaw secrets file
Before=openclaw-gmail-pubsub.service

[Service]
Type=oneshot
ExecStart=/usr/bin/install -m 600 -o root -g root /etc/openclaw/secrets.env /run/secrets/openclaw.env
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

> **Attention** : cela suppose que `/etc/openclaw/secrets.env` existe avec
> les permissions `600`. A configurer manuellement.

## TODO

- [ ] Tester le flow OAuth complet depuis IONOS-VPS3.
- [ ] Documenter la procedure exacte de creation du refresh token Gmail
      (console Google Cloud -> OAuth 2.0 -> refresh token).
- [ ] Creer le topic et la subscription Pub/Sub dans la console GCP.
- [ ] Verifier que le compte OAuth a les droits `pubsub.subscriber`.
- [ ] Configurer le script de boot pour recreer `/run/secrets/openclaw.env`.
- [ ] Ajouter un healthcheck Discord facultatif (`/status`).
- [ ] Monitorer le service (alerte si downtime > 5 min).
