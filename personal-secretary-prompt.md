# Prompt pour agent/Codex — `personal-secretary` sur NixOS / IONOS-VPS

## Choix par défaut à appliquer

- OS cible : NixOS sur `IONOS-VPS`
- Type de service : orchestrateur léger, pas une plateforme lourde
- Langage recommandé : Python
- Déploiement : module NixOS + systemd
- Conteneurisation : pas de Docker sauf justification forte
- Interface utilisateur : Discord bot
- Source de vérité : Markdown + Git local sur le VPS
- IA : OpenAI API
- Modèle local : interdit
- Daily summary : tous les jours à 21h00, timezone `Europe/Brussels`
- Weekly summary : dimanche à 18h00, timezone `Europe/Brussels`
- Mails : lecture seule au départ
- Brouillons : Markdown local au départ
- Envoi automatique de mails : interdit
- Secrets : utiliser la méthode de secrets déjà présente dans la stack ; sinon prévoir `sops-nix`, `agenix`, ou un `EnvironmentFile` root-only

Ne commence pas par installer une solution lourde existante comme OpenClaw complet, n8n, Dify, Matrix ou autre. L’objectif est d’implémenter un orchestrateur minimal, robuste, auditable et intégré à NixOS.

---

# Objectif

Ajouter à ma stack NixOS sur `IONOS-VPS` un service léger nommé `personal-secretary`, jouant le rôle de secrétaire personnel disponible 24/7.

Le service doit fonctionner comme un orchestrateur léger :

- pas de modèle IA local ;
- appels à l’API OpenAI pour les tâches de résumé, extraction, priorisation et rédaction ;
- stockage local durable en Markdown versionné ;
- interface principale via Discord ;
- intégration avec mes boîtes mail, mon calendrier et les notes envoyées dans Discord.

Le VPS est contraint en ressources. L’implémentation doit donc être sobre, robuste et adaptée à un petit VPS.

---

# Contexte infra

Le service doit être intégré proprement dans ma stack NixOS existante sur `IONOS-VPS`.

Contraintes :

- déploiement déclaratif via NixOS ;
- service systemd géré par NixOS ;
- secrets séparés de la configuration publique ;
- pas de Docker sauf justification forte ;
- pas de stack lourde type OpenClaw, n8n, Dify ou Matrix ;
- pas de LLM local ;
- OpenAI API pour les tâches lourdes ;
- Discord comme interface de chat et de notification ;
- Markdown + Git comme source de vérité.

---

# Nom du service

```text
personal-secretary
```

Nom utilisateur système :

```text
personal-secretary
```

Répertoire principal :

```text
/var/lib/personal-secretary
```

Structure attendue :

```text
/var/lib/personal-secretary/
├── journal/
│   ├── inbox.md
│   ├── tasks.md
│   ├── deadlines.md
│   ├── mails.md
│   ├── drafts/
│   ├── daily/
│   ├── weekly/
│   ├── projects/
│   │   ├── perso.md
│   │   ├── homelab.md
│   │   ├── cours.md
│   │   └── admin.md
│   └── sources/
│       ├── gmail-perso.md
│       ├── mag.md
│       ├── umons.md
│       ├── calendar.md
│       └── discord-notes.md
├── app/
├── prompts/
├── logs/
└── state/
```

Le dossier `journal/` doit être versionné avec Git.

Identité Git du bot :

```text
name  = personal-secretary-bot
email = personal-secretary-bot@ionos-vps.local
```

Chaque modification automatique importante doit être commitée avec un message clair, par exemple :

```text
daily: update summary for 2026-05-03
weekly: prepare week 2026-W19
mail: add draft for Thierry Dutoit
tasks: update deadlines
```

---

# Fonctionnalités principales

Le secrétaire personnel doit :

1. Lire mes mails depuis plusieurs sources :
   - Gmail personnel ;
   - boîte mail Mag ;
   - boîte mail UMONS.

2. Lire mon calendrier :
   - Google Calendar, CalDAV, ICS ou autre backend configurable.

3. Lire les notes envoyées depuis Discord :
   - notes rapides ;
   - tâches ;
   - idées ;
   - deadlines ;
   - demandes de brouillons ;
   - informations à retenir pour le résumé daily/weekly.

4. Maintenir une source de vérité en Markdown :
   - tâches ;
   - deadlines ;
   - notes brutes ;
   - résumés quotidiens ;
   - résumés hebdomadaires ;
   - mails à traiter ;
   - brouillons de mails ;
   - décisions importantes ;
   - historique exploitable.

5. Produire automatiquement :
   - un résumé daily ;
   - un résumé weekly le dimanche soir ;
   - une liste de deadlines ;
   - une liste de mails à envoyer ou auxquels répondre ;
   - des brouillons de mails ;
   - des rappels dans Discord.

6. Poster les informations dans Discord dans des salons dédiés.

---

# Discord

Créer ou documenter les salons Discord utiles.

Serveur cible :

```text
TODO: nom ou ID du serveur Discord
```

Créer/utiliser les salons suivants :

```text
#secretary-inbox
#secretary-daily
#secretary-weekly
#secretary-tasks
#secretary-deadlines
#secretary-mails
#secretary-drafts
#secretary-calendar
#secretary-logs
#secretary-admin
```

Rôle de chaque salon :

```text
#secretary-inbox
Notes rapides envoyées depuis le téléphone. Tout message ou commande utile peut être capturé ici.

#secretary-daily
Résumé quotidien automatique.

#secretary-weekly
Résumé hebdomadaire automatique, envoyé le dimanche soir.

#secretary-tasks
Tâches extraites depuis les mails, le calendrier et les notes Discord.

#secretary-deadlines
Deadlines détectées et rappels associés.

#secretary-mails
Mails importants, mails à traiter, relances à faire.

#secretary-drafts
Brouillons de mails générés, jamais envoyés automatiquement.

#secretary-calendar
Résumé des événements à venir.

#secretary-logs
Logs non sensibles, erreurs techniques, état des jobs.

#secretary-admin
Commandes d’administration, statut, configuration, tests.
```

Le bot Discord doit supporter au minimum les commandes suivantes :

```text
/note <texte>
Ajoute une note horodatée dans inbox.md.

/daily
Génère immédiatement un résumé quotidien.

/weekly
Génère immédiatement un résumé hebdomadaire.

/tasks
Affiche les tâches actuelles.

/deadlines
Affiche les deadlines à venir.

/mails
Résume les mails importants récents.

/draft <contexte>
Génère un brouillon de mail à partir du contexte fourni.

/draft-reply <mail_id ou référence>
Génère une réponse à un mail précis, sans l’envoyer.

/calendar
Affiche les événements à venir.

/process
Traite les notes brutes de l’inbox Discord et met à jour les fichiers Markdown.

/status
Affiche l’état du service, sans exposer les secrets.

/help
Affiche les commandes disponibles.
```

Important :

- le bot doit refuser les commandes venant d’utilisateurs non autorisés ;
- l’ID Discord autorisé doit être configurable ;
- ne jamais publier de secret dans Discord ;
- ne pas poster de contenu mail complet si un résumé suffit ;
- les erreurs détaillées doivent rester dans les logs locaux si elles contiennent des données sensibles.

---

# Mails

Sources mail à intégrer :

```text
GMAIL_PERSONAL
MAG_MAIL
UMONS_MAIL
```

Prévoir une configuration flexible par backend :

```text
MAIL_BACKEND_GMAIL_PERSONAL=gmail|imap
MAIL_BACKEND_MAG=imap|gmail|graph
MAIL_BACKEND_UMONS=imap|graph
```

Variables génériques possibles :

```env
# Gmail perso
GMAIL_PERSONAL_BACKEND=gmail
GMAIL_PERSONAL_CLIENT_ID=
GMAIL_PERSONAL_CLIENT_SECRET=
GMAIL_PERSONAL_REFRESH_TOKEN=

# Mag
MAG_MAIL_BACKEND=imap
MAG_IMAP_HOST=
MAG_IMAP_PORT=993
MAG_IMAP_USERNAME=
MAG_IMAP_PASSWORD=
MAG_IMAP_FOLDER=INBOX

# UMONS
UMONS_MAIL_BACKEND=imap
UMONS_IMAP_HOST=
UMONS_IMAP_PORT=993
UMONS_IMAP_USERNAME=
UMONS_IMAP_PASSWORD=
UMONS_IMAP_FOLDER=INBOX
```

Comportement mail :

- récupérer les mails récents ;
- récupérer les mails non lus ;
- grouper autant que possible par thread ;
- ignorer ou déprioriser newsletters, publicités, notifications automatiques et spams ;
- identifier les mails demandant une réponse ;
- identifier les mails contenant une deadline ;
- identifier les mails importants administratifs, scolaires, professionnels ou liés au homelab ;
- produire un résumé clair ;
- extraire les tâches ;
- créer des brouillons de réponse si demandé ;
- ne jamais envoyer de mail automatiquement ;
- ne jamais supprimer de mail ;
- ne jamais archiver de mail automatiquement ;
- ne jamais marquer comme lu automatiquement au début.

Structure Markdown pour les mails :

```text
journal/mails.md
journal/drafts/
journal/sources/gmail-perso.md
journal/sources/mag.md
journal/sources/umons.md
```

Exemple d’entrée dans `mails.md` :

```md
## 2026-05-03

### Mail important

- Source: UMONS
- From: ...
- Subject: ...
- Date: ...
- Résumé:
- Action recommandée:
- Deadline:
- Priorité: haute/moyenne/basse
- Brouillon nécessaire: oui/non
```

Les identifiants de mails utilisés dans Discord doivent être des références internes non sensibles, par exemple :

```text
mail-20260503-001
```

---

# Brouillons de mails

Le service doit pouvoir écrire des brouillons.

Au départ, cela signifie :

1. Générer un brouillon en Markdown dans :

```text
/var/lib/personal-secretary/journal/drafts/
```

2. Poster le brouillon dans `#secretary-drafts`.

3. Optionnellement, si le backend le permet et si la configuration l’autorise, créer un vrai brouillon dans Gmail ou Outlook.

Variable de sécurité :

```env
MAIL_CREATE_REMOTE_DRAFTS=false
MAIL_SEND_AUTOMATICALLY=false
```

Valeurs par défaut :

```text
MAIL_CREATE_REMOTE_DRAFTS=false
MAIL_SEND_AUTOMATICALLY=false
```

L’envoi automatique de mails doit rester désactivé.

Un brouillon Markdown doit contenir :

```md
# Draft - YYYY-MM-DD - destinataire

Source:
Destinataire:
Objet:
Contexte:
Priorité:
Deadline:
Statut: draft/local

---

Bonjour,

...

Bien à vous,
Theau
```

---

# Calendrier

Prévoir un backend calendrier configurable :

```text
CALENDAR_BACKEND=google|caldav|ics|none
```

Variables possibles :

```env
CALENDAR_BACKEND=
GOOGLE_CALENDAR_CLIENT_ID=
GOOGLE_CALENDAR_CLIENT_SECRET=
GOOGLE_CALENDAR_REFRESH_TOKEN=
CALDAV_URL=
CALDAV_USERNAME=
CALDAV_PASSWORD=
ICS_URL=
```

Comportement calendrier :

- récupérer les événements du jour ;
- récupérer les événements des 7 prochains jours ;
- détecter les deadlines ;
- détecter les événements nécessitant préparation ;
- intégrer les événements dans les résumés daily et weekly ;
- poster les événements importants dans `#secretary-calendar`.

---

# Notes Discord

Les notes envoyées dans `#secretary-inbox` ou via `/note` doivent être ajoutées à :

```text
journal/inbox.md
journal/sources/discord-notes.md
```

Format :

```md
- YYYY-MM-DD HH:mm — Discord — <auteur> — <contenu>
```

Le service doit ensuite pouvoir traiter ces notes et mettre à jour :

```text
tasks.md
deadlines.md
daily/YYYY-MM-DD.md
weekly/YYYY-WXX.md
projects/*.md
```

---

# Résumé daily

Horaire automatique :

```text
Tous les jours à 21:00 Europe/Brussels
```

Le résumé daily doit utiliser :

- mails Gmail perso ;
- mails Mag ;
- mails UMONS ;
- calendrier ;
- notes Discord ;
- journal Markdown ;
- tâches existantes ;
- deadlines existantes.

Sortie dans :

```text
journal/daily/YYYY-MM-DD.md
Discord: #secretary-daily
```

Contenu attendu :

```md
# Daily summary - YYYY-MM-DD

## Vue d’ensemble

## Agenda du jour / demain

## Mails importants

## Mails à répondre

## Brouillons proposés

## Tâches créées aujourd’hui

## Tâches toujours ouvertes

## Deadlines proches

## Notes importantes du chat

## Points de blocage

## Plan d’action recommandé
```

Le résumé doit être concis, actionnable et priorisé.

---

# Résumé weekly

Horaire automatique :

```text
Dimanche à 18:00 Europe/Brussels
```

Le résumé weekly doit préparer la semaine qui arrive.

Sources :

- mails Gmail perso ;
- mails Mag ;
- mails UMONS ;
- calendrier des 7 à 14 prochains jours ;
- notes Discord de la semaine ;
- tâches ouvertes ;
- deadlines ;
- drafts non envoyés ;
- journal daily de la semaine écoulée.

Sortie dans :

```text
journal/weekly/YYYY-WXX.md
Discord: #secretary-weekly
```

Contenu attendu :

```md
# Weekly planning - YYYY-WXX

## Résumé exécutif

## Événements importants de la semaine

## Deadlines

## Tâches prioritaires

## Mails à envoyer

## Mails à répondre

## Brouillons à valider

## Relances à faire

## Risques / blocages

## Plan d’action par jour

## Notes utiles issues du chat
```

---

# Rappels de deadlines

Le service doit maintenir :

```text
journal/deadlines.md
```

Format recommandé :

```md
# Deadlines

## À venir

- [ ] YYYY-MM-DD — Description
  - Source:
  - Priorité:
  - Rappel:
  - Statut:
```

Rappels Discord :

- rappel quotidien des deadlines proches ;
- rappel renforcé si deadline dans moins de 48 h ;
- rappel dans `#secretary-deadlines`.

Comportement :

- ne pas inventer de deadline ;
- toujours citer la source interne : mail, calendrier, note Discord ou tâche Markdown ;
- si la date est ambiguë, marquer comme `à clarifier`.

---

# OpenAI

Utiliser l’API OpenAI.

Variables :

```env
OPENAI_API_KEY=
OPENAI_MODEL_SUMMARY=gpt-4.1-mini
OPENAI_MODEL_REASONING=gpt-4.1
OPENAI_MODEL_DRAFTS=gpt-4.1-mini
```

Règles :

- utiliser le modèle léger pour daily, classification et extraction ;
- utiliser le modèle plus fort seulement pour synthèses complexes si nécessaire ;
- tronquer intelligemment les longs mails ;
- éviter d’envoyer des pièces jointes ;
- limiter la taille des prompts ;
- ne pas envoyer de secrets à OpenAI ;
- ne pas envoyer plus de contenu mail que nécessaire ;
- journaliser les coûts approximatifs si possible.

---

# Prompts internes

Créer des prompts séparés dans :

```text
/var/lib/personal-secretary/prompts/
```

Fichiers attendus :

```text
system.md
daily.md
weekly.md
extract_tasks.md
extract_deadlines.md
summarize_mails.md
draft_mail.md
process_discord_notes.md
```

Le prompt système doit imposer :

```md
Tu es le secrétaire personnel de Theau.

Tu dois aider à organiser ses mails, son calendrier, ses notes Discord, ses tâches, ses deadlines et ses brouillons de mails.

Tu dois être fiable, concis, structuré et prudent.

Règles absolues :
- ne jamais envoyer de mail automatiquement ;
- ne jamais supprimer d’information utilisateur ;
- ne jamais inventer de tâche, deadline ou mail ;
- toujours distinguer ce qui est certain de ce qui est à clarifier ;
- préserver une trace Markdown ;
- produire des sorties actionnables ;
- ne pas exposer de secrets ;
- signaler les informations manquantes ;
- privilégier les résumés utiles plutôt que les longs dumps de contenu.
```

---

# NixOS

Implémenter cela proprement dans la stack NixOS.

Créer un module NixOS ou ajouter une configuration équivalente :

```nix
services.personal-secretary.enable = true;
```

Paramètres souhaités :

```nix
services.personal-secretary = {
  enable = true;
  user = "personal-secretary";
  group = "personal-secretary";
  dataDir = "/var/lib/personal-secretary";
  timezone = "Europe/Brussels";
};
```

Le module doit créer :

- utilisateur système ;
- groupe système ;
- répertoires nécessaires ;
- service systemd principal ;
- timers systemd daily/weekly/deadlines ;
- variables d’environnement depuis un fichier secret ;
- permissions restrictives.

Unités systemd attendues :

```text
personal-secretary.service
personal-secretary-daily.service
personal-secretary-daily.timer
personal-secretary-weekly.service
personal-secretary-weekly.timer
personal-secretary-deadlines.service
personal-secretary-deadlines.timer
```

Le service principal doit lancer le bot Discord.

Les timers doivent appeler des commandes CLI du service, par exemple :

```text
personal-secretary daily
personal-secretary weekly
personal-secretary deadlines
```

---

# Secrets

Ne pas mettre les secrets dans le repo Nix.

Utiliser la méthode déjà présente dans ma stack si elle existe.

Sinon prévoir une intégration compatible avec :

```text
sops-nix
agenix
fichier EnvironmentFile root-only
```

Fichier d’environnement attendu :

```text
/run/secrets/personal-secretary.env
```

ou fallback :

```text
/etc/personal-secretary/secrets.env
```

Permissions :

- lisible uniquement par root et/ou l’utilisateur `personal-secretary` ;
- jamais committé ;
- jamais affiché dans les logs.

Variables minimales :

```env
OPENAI_API_KEY=

DISCORD_BOT_TOKEN=
DISCORD_GUILD_ID=
DISCORD_ALLOWED_USER_IDS=
DISCORD_CHANNEL_INBOX=
DISCORD_CHANNEL_DAILY=
DISCORD_CHANNEL_WEEKLY=
DISCORD_CHANNEL_TASKS=
DISCORD_CHANNEL_DEADLINES=
DISCORD_CHANNEL_MAILS=
DISCORD_CHANNEL_DRAFTS=
DISCORD_CHANNEL_CALENDAR=
DISCORD_CHANNEL_LOGS=
DISCORD_CHANNEL_ADMIN=

GMAIL_PERSONAL_BACKEND=
GMAIL_PERSONAL_CLIENT_ID=
GMAIL_PERSONAL_CLIENT_SECRET=
GMAIL_PERSONAL_REFRESH_TOKEN=

MAG_MAIL_BACKEND=
MAG_IMAP_HOST=
MAG_IMAP_PORT=
MAG_IMAP_USERNAME=
MAG_IMAP_PASSWORD=

UMONS_MAIL_BACKEND=
UMONS_IMAP_HOST=
UMONS_IMAP_PORT=
UMONS_IMAP_USERNAME=
UMONS_IMAP_PASSWORD=

CALENDAR_BACKEND=
GOOGLE_CALENDAR_CLIENT_ID=
GOOGLE_CALENDAR_CLIENT_SECRET=
GOOGLE_CALENDAR_REFRESH_TOKEN=
CALDAV_URL=
CALDAV_USERNAME=
CALDAV_PASSWORD=
ICS_URL=
```

---

# Sécurité

Règles obligatoires :

- ne pas exposer d’interface web publique ;
- Discord doit être l’interface principale ;
- limiter les utilisateurs Discord autorisés ;
- ne pas stocker les secrets dans Markdown ;
- ne pas envoyer automatiquement de mails ;
- ne pas supprimer ou archiver automatiquement des mails ;
- ne pas marquer les mails comme lus automatiquement au début ;
- ne pas donner d’accès root au service ;
- ne pas donner d’accès shell arbitraire ;
- ne pas monter de secrets système inutiles ;
- logs sans contenu sensible complet ;
- permissions restrictives sur `/var/lib/personal-secretary`.

---

# Git et versioning

Le dossier suivant doit être versionné :

```text
/var/lib/personal-secretary/journal
```

Initialiser Git si absent.

Faire un commit initial avec les fichiers de base.

Après chaque traitement daily/weekly/process important :

- vérifier les changements ;
- commit automatique ;
- message clair ;
- ne jamais commit de secrets.

Option future :

- push vers un repo privé Forgejo/Gitea/GitHub si configuré.

Variables optionnelles :

```env
JOURNAL_GIT_REMOTE=
JOURNAL_GIT_PUSH=false
```

---

# Fichiers Markdown initiaux

Créer les fichiers suivants s’ils n’existent pas :

```text
inbox.md
tasks.md
deadlines.md
mails.md
sources/gmail-perso.md
sources/mag.md
sources/umons.md
sources/calendar.md
sources/discord-notes.md
projects/perso.md
projects/homelab.md
projects/cours.md
projects/admin.md
```

Créer les dossiers :

```text
daily/
weekly/
drafts/
```

---

# Logging

Logs attendus :

```text
/var/lib/personal-secretary/logs/service.log
/var/lib/personal-secretary/logs/daily.log
/var/lib/personal-secretary/logs/weekly.log
/var/lib/personal-secretary/logs/mail.log
/var/lib/personal-secretary/logs/discord.log
```

Les logs ne doivent pas contenir :

- tokens ;
- mots de passe ;
- contenu complet des mails si inutile ;
- prompts complets avec données sensibles.

---

# Tests

Ajouter une procédure de test complète.

Tests attendus :

1. Vérifier que le service NixOS s’active.
2. Vérifier que l’utilisateur `personal-secretary` existe.
3. Vérifier que les dossiers sont créés avec les bonnes permissions.
4. Vérifier que le bot Discord démarre.
5. Vérifier que `/status` fonctionne.
6. Vérifier que `/note test` écrit dans `inbox.md`.
7. Vérifier que `/daily` génère un résumé.
8. Vérifier que `/weekly` génère un résumé.
9. Vérifier que la récupération Gmail perso fonctionne.
10. Vérifier que la récupération Mag fonctionne.
11. Vérifier que la récupération UMONS fonctionne.
12. Vérifier que le calendrier est lu.
13. Vérifier qu’un brouillon Markdown peut être généré.
14. Vérifier qu’aucun mail n’est envoyé automatiquement.
15. Vérifier qu’un commit Git est créé après modification.
16. Vérifier que les secrets ne sont pas committés.
17. Vérifier que les logs ne contiennent pas de secrets.

---

# Documentation attendue

Produire ou mettre à jour une documentation avec :

- architecture ;
- installation NixOS ;
- configuration des secrets ;
- configuration Discord ;
- création des salons Discord ;
- configuration des accès mails ;
- configuration calendrier ;
- commandes disponibles ;
- fonctionnement des résumés daily/weekly ;
- stratégie de sécurité ;
- stratégie de backup ;
- procédure de restauration ;
- procédure de debug.

---

# Résultat final attendu

À la fin, ma stack NixOS sur `IONOS-VPS` doit contenir un service `personal-secretary` fiable, léger et sécurisé.

Il doit me servir de secrétaire personnel 24/7 via Discord, capable de :

- lire mes mails Gmail perso, Mag et UMONS ;
- lire mon calendrier ;
- lire mes notes Discord ;
- maintenir une source de vérité Markdown versionnée ;
- produire un résumé quotidien ;
- produire un résumé hebdomadaire le dimanche soir ;
- extraire les tâches ;
- rappeler les deadlines ;
- générer des brouillons de mails ;
- poster les informations dans les salons Discord adaptés ;
- ne jamais envoyer de mails automatiquement sans validation explicite.
