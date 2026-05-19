---
name: diesel-price
description: Affiche les prix du diesel autour de Mons. S active sur /diesel, "prix diesel", "diesel pas cher", "ou faire le plein".
---

# Prix Diesel

Utilise ce skill quand l utilisateur demande /diesel, "prix diesel", "diesel pas cher", "ou faire le plein", "quel est le prix du diesel".

## Action

Execute la commande et poste le resultat :

```bash
python3 /root/.local/bin/carbu-diesel-scraper.py
```

Ne modifie RIEN. Poste la sortie telle quelle.

## Cron

Le cron "Prix diesel quotidien" (8:00) execute automatiquement ce skill.

---

## Implementation

- **Trigger** : /diesel, "prix diesel", "diesel pas cher", "ou faire le plein"
- **Script** : ~/.local/bin/carbu-diesel-scraper.py (Python, scrape carbu.com)
- **Sources** : Mons (7000), Thulin (7350), Honnelles (7387)
- **Cout agent** : minimal — juste exec + post, pas d analyse
