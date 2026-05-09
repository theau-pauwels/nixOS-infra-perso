# Phase 8.1 — OpenClaw Gmail Webhook (Documentation & Config)

> **Parent phase**: Phase 8 — Personal Secretary (remplacé par OpenClaw)
> **Host cible**: `IONOS-VPS3` (non-NixOS)
> **Date**: 2026-05-05

## Contexte

OpenClaw est le bot Discord qui remplace l'ancien `personal-secretary`.
Il tourne sur `IONOS-VPS3` et intègre plusieurs skills.

Cette phase documente le webhook Gmail → OpenClaw → triage → Discord
`#📥-inbox`. Aucune implémentation de code n'est faite dans cette phase :
elle est purement documentaire et préparatoire.

Le skill `personal-mail-triage` existe dans OpenClaw et doit être configuré
pour classifier les mails Gmail (important / UMONS / newsletter / spam) et
notifier uniquement les mails importants dans `#📥-inbox`.

## Ce que cette phase couvre

1. Documentation de l'architecture Gmail → OpenClaw → Discord.
2. Documentation des prérequis, variables d'environnement, et flux de secrets.
3. Templates de configuration systemd et OpenClaw (sans secrets).
4. Mise à jour de `.gitignore` pour les patterns de secrets Gmail/OpenClaw.
5. Procédures de test et troubleshooting.

## Ce que cette phase ne couvre PAS

- L'implémentation du code OpenClaw ou du skill `personal-mail-triage`.
- L'installation effective sur IONOS-VPS3.
- La création du refresh token Gmail (documenté mais à faire hors repo).
- Le déploiement (push to infra) — phase séparée.

## Fichiers produits

| Fichier | Rôle |
|---|---|
| `docs/openclaw-gmail-webhook.md` | Documentation complète |
| `.gitignore` | Patterns mis à jour pour les secrets OpenClaw/Gmail |
| `prompts/phases/phase-8.1-openclaw-gmail-webhook.md` | Ce fichier |

## Tâches réalisées

- [x] Inspecter le dépôt existant.
- [x] Créer `docs/openclaw-gmail-webhook.md` :
  - [x] Architecture Gmail → gog → OpenClaw → Discord `#📥-inbox`.
  - [x] Prérequis (IONOS-VPS3, compte Google, Discord, gog).
  - [x] Variables d'environnement (sans valeurs).
  - [x] Templates de configuration (`config.yaml`, `personal-mail-triage.yaml`).
  - [x] Unités systemd (`openclaw.service`, `openclaw-mail-check.service` + `.timer`).
  - [x] Tests (token Gmail, watch, bout en bout, classification).
  - [x] Troubleshooting (auth, watch, canal Discord, doublons).
  - [x] Sécurité des secrets (principes, fichiers ignorés, rotation, backups).
  - [x] Déploiement non-Nix sur IONOS-VPS3.
  - [x] Section TODO pour les étapes suivantes.
- [x] Mettre à jour `.gitignore` (patterns `*.env`, `credentials.json`, `*.gog`, `openclaw.env`).
- [x] Commit et push des changements.

## Validation

```bash
git status --short
git diff --staged
nix flake check  # le dépôt Nix ne doit pas être cassé
```

## Prochaines phases

- **Phase 8.2** : Installation effective sur IONOS-VPS3 (binaire, config, systemd, utilisateur).
- **Phase 8.3** : Configuration OAuth Gmail et premier test de bout en bout.
- **Phase 8.4** : Calibration du skill `personal-mail-triage` (catégories, seuils, notifications).
- **Phase 8.5** : Monitoring et alertes (logs, healthcheck Discord, uptime).

## Notes

- IONOS-VPS3 n'est **pas** géré par Nix/NixOS. Le déploiement est manuel
  (scp, ssh, systemctl).
- Les secrets (`DISCORD_BOT_TOKEN`, `GMAIL_REFRESH_TOKEN`, `OPENAI_API_KEY`,
  etc.) ne sont **jamais** dans ce dépôt.
- Le fichier `local-secrets/openclaw.env` peut être utilisé pour stocker les
  secrets localement, avec `chmod 600`.
- Le pattern `*.env` ajouté dans `.gitignore` protège tous les fichiers `.env`
  du dépôt.
