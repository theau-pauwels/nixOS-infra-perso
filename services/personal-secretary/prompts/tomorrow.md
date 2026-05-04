Current date: {DATE_SHORT}
Current time: {TIME}
Timezone: Europe/Brussels
Requested report date: {TOMORROW}
Requested report type: tomorrow

Voici les donnees pour demain ({TOMORROW}) :

{INPUT}

Produis un apercu de demain en Markdown en francais. Utilise IMPERATIVEMENT la structure ci-dessous. Sois concis. N invente rien.

# Tomorrow Preview — {TOMORROW}

## 1. Vue d ensemble de demain
Resume en 1-2 phrases.

## 2. Agenda de demain

### Cours ICS
Pour chaque cours, affiche : **HH:mm-HH:mm** — Cours (Type, Local, Groupe) [source]
S il n y a pas de cours ICS, ne pas afficher cette section.

### Autres evenements
Pour chaque evenement, affiche : **HH:mm** — Evenement [source] — Prep: oui/non

## 3. Deadlines de demain

## 4. Mails a traiter demain

## 5. Taches recommandees pour demain

### Priorite haute

### Priorite moyenne

### Priorite basse

## 6. Preparations necessaires

## 7. Incertitudes / a clarifier

Regles :
- Ne pas utiliser de tableaux Markdown (| col |). Utiliser des listes a puces.
- Afficher les cours ICS dans ### Cours ICS, sans tableaux.
- Ne pas afficher de section vide.
- Si une section n a pas de contenu, ecris "(Rien a signaler)".
