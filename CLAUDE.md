# CLAUDE.md — IOT_n3

Dépôt parent de l'écosystème IoT n³ : il épingle deux sous-modules, `serveur/`
(→ `n3_serveur`) et `firmwires/` (→ `n3_firmwires`). Répondre en **français**.

@AGENTS.md

## Où ce dépôt s'inscrit

- **Projet Claude Code** : « n³ IoT » (dépôts `n3_firmwires`, `n3_serveur`, `IOT_n3`) ; ses
  instructions s'ajoutent à ce fichier.
- **Projets de chat claude.ai** : « N³ » (projet pédagogique, documentation) et « Pcb » (carte
  universelle n³, électronique).
- **Connecteur MCP `iot_olution`** : lecture de la prod iot.olution.info (mesures, santé, OTA).

## Règles

- Le code se modifie dans `n3_serveur` ou `n3_firmwires`, chacun avec son `CLAUDE.md`.
  Ici, on ne fait que **mettre à jour les pointeurs** des sous-modules, avec un message de
  commit qui dit ce qui change (`[projet] pointeur serveur → …`).
