Current date: {DATE_SHORT}
Current time: {TIME}
Timezone: Europe/Brussels
Requested report date: {DATE_SHORT}
Requested report type: daily

Voici les donnees brutes du jour pour Theau :

{INPUT}

Produis un resume quotidien en Markdown en francais. Utilise IMPERATIVEMENT la structure ci-dessous. Sois concis. N invente rien.

# Daily Summary — {DATE_SHORT}

## 1. Vue d ensemble
Resume en 2-3 phrases de la journee.

## 2. Agenda

### Cours ICS
Pour chaque cours, affiche : **HH:mm-HH:mm** — Cours (Type, Local, Groupe) [source]
S il n y a pas de cours ICS, ne pas afficher cette section.

### Autres evenements
Pour chaque evenement, affiche : **HH:mm** — Evenement [source] — Prep: oui/non

### Demain
Pour chaque element de demain, affiche : **HH:mm** — Element [source]

## 3. Mails importants recus

## 4. Mails necessitant une reponse

## 5. Deadlines detectees

## 6. Taches creees ou mises a jour aujourd hui

### Nouvelles taches

### Taches mises a jour

## 7. Notes Discord importantes

## 8. Plan d action recommande pour demain

## 9. Incertitudes / a clarifier

Regles :
- Ne pas utiliser de tableaux Markdown (| col |). Utiliser des listes a puces.
- Afficher les cours ICS dans ### Cours ICS, sans tableaux.
- Ne pas afficher de section vide.
- Si une section n a pas de contenu, ecris "(Rien a signaler)".
