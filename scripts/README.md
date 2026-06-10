# Inventaire des scripts – Racine IOT_n3

Scripts PowerShell à exécuter depuis la racine du dépôt (`IOT_n3/`), sauf indication contraire.

## Publication

| Script | Rôle |
|--------|------|
| `publish_ota.ps1` | Publie vers `serveur/ota/` : n3pp, msp, cam + cibles **ffp5-** (ffp5cs). Ex. `-Targets ffp5-wroom-prod,... -Build`. |
| `deploy_ota.ps1` | Orchestre `publish_ota.ps1` ; `-IncludeFfp5cs` ajoute les 4 cibles ffp5 ; `-Ffp5csOnly` = ffp5 uniquement. |
| `publish-cycle.ps1` | Cycle de publication serveur : incrémente VERSION, CHANGELOG, commit, push. Usage : `-Component serveur -Message "description"`. |
| `generate_ota_keys.ps1` | Génère la paire de clés ECDSA P-256 pour la signature OTA (sortie dans `scripts/ota_keys/`). |

> Journal de publication OTA : `scripts/ota-audit.jsonl` (une ligne par déploiement, cible + version). Clés OTA : `scripts/ota_keys/` (clé publique versionnée, clé privée **hors dépôt**).

### Déploiement OTA (détail)

- **Cibles racine** (n3pp, msp, cam-*) : `.\scripts\publish_ota.ps1` ou `.\scripts\deploy_ota.ps1`  
  → Binaires vers `serveur/ota/`, metadata SHA-256, signature ECDSA optionnelle. Après push, le CRON serveur déploie ; les ESP récupèrent la mise à jour via l’URL metadata.

- **FFP5CS** : `.\scripts\deploy_ota.ps1 -IncludeFfp5cs -Build` ou `.\scripts\publish_ota.ps1 -Targets ffp5-wroom-prod,... -Build` ; metadata racine `serveur/ota/metadata.json`, URLs **/ota/**. Voir `firmwires/ffp5cs/docs/technical/OTA_PUBLISH.md`.

- **Exemples** :  
  `.\scripts\deploy_ota.ps1 -Build`  
  `.\scripts\deploy_ota.ps1 -Targets "n3pp","msp" -DryRun`  
  `.\scripts\deploy_ota.ps1 -Ffp5csOnly -Build -BuildFs`

## Audit et vérification des pages

| Script | Rôle |
|--------|------|
| `audit-serveur-complet.ps1` | Audit exhaustif du serveur distant : pages, APIs, sécurité, logs. Rapport dans `docs/`. |
| `check-server-pages.ps1` | Vérifie les pages FFP3/MSP1/N3PP, galeries, APIs ; propose des correctifs. Rapport dans `scripts/reports/`. |
| `check-user-pages.ps1` | Vérification rapide de 8 pages utilisateur (home, aquaponie, galeries). |
| `audit-iot-pages.ps1` | *(Obsolète)* 3 pages hardcodées, variante curl. Préférer `check-server-pages.ps1`. |
| `audit-iot-pages-v2.ps1` | *(Obsolète)* Même 3 pages, variante Invoke-WebRequest. Préférer `check-server-pages.ps1`. |

## Déploiement

| Script | Rôle |
|--------|------|
| `deploy_ota.ps1` | Déploiement OTA : publie les firmwares vers `serveur/ota/` et optionnellement FFP5CS vers `ffp3/ota/`. Voir section « Déploiement OTA » ci-dessus. |
| `deploy-server.ps1` | Workflow : `git pull` serveur, commit+push serveur (et parent) si modifs, puis `DEPLOY_NOW.sh` dans `serveur/analyse-ffp3/`. Options : `-Message "..."`, `-NoPush`. À exécuter depuis la racine IOT_n3. Requiert Git Bash. **NB** : le script référence encore en dur l'ancien chemin `serveur/ffp3` (inexistant) — à corriger côté script. |

**Déploiement distant (FFP3) :** un déploiement SSH vers iot.olution.info (git fetch, composer, chmod) est possible via les scripts de `serveur/analyse-ffp3/`. En production, un CRON fait déjà `git pull` sur n3_serveur ; les scripts permettent un déploiement manuel ou une mise à jour des dépendances (composer, cache).

## Tests et diagnostic

| Script | Rôle |
|--------|------|
| `test-pages-curl.ps1` | Tests des pages via curl. |
| `test-highcharts-rendering.ps1` | Test du rendu des graphiques Highcharts. |
| `test-realtime-api.ps1` | Test de l’API temps réel. |
| `find-bugs.ps1` | Recherche de bugs dans le code. |
| `inspect-chart-data.ps1` | Inspection des données des graphiques. |

## Maintenance

| Script | Rôle |
|--------|------|
| `fix-di-cache-prod.ps1` | Vide le cache DI en production (option `-SkipDeploy`). |
| `fix-production-500-errors.ps1` | Correctifs pour erreurs 500 en production. |
| `clear-cursor-cache.ps1` | Vide le cache Cursor. |
| `clean-firmware-builds.ps1` | Nettoie les artefacts de build PlatformIO des firmwares (`.pio/`). |

## Git et submodules

| Script | Rôle |
|--------|------|
| `firmwires-list.ps1` | Liste les firmwares et leur état (lit `firmwires/firmwares.manifest.json`). |
| `fermer-pr-integrees.ps1` | Ferme les pull requests déjà intégrées (nettoyage GitHub). |

## Audit navigateur

| Chemin | Rôle |
|--------|------|
| `browser-audit/` | Package Node (Puppeteer) d'audit des pages rendues (graphiques, galeries). |

### Archive (scripts one-shot, migration effectuée)

Les scripts suivants sont dans `scripts/archive/`, conservés pour historique :

- `migrate-firmwires-to-submodule.ps1` — Migration firmwares → submodule
- `remove-ffp5cs-submodule-in-firmwires.ps1` — Migration ffp5cs
- `run-subtree-add-ffp5cs.ps1` — Opération subtree ffp5cs

## Debug (scroll)

| Script | Rôle |
|--------|------|
| `scroll-pages-debug.ps1` | Debug du scroll sur les pages. |
| `scroll-debug/` | Package Node pour le debug scroll. |

---

**Firmwares :** Voir [firmwires/README.md](../firmwires/README.md) pour les scripts de monitoring et workflow (monitor_Nmin, erase_flash_monitor, etc.).

**FFP5CS :** Inventaire détaillé dans [firmwires/ffp5cs/docs/INVENTAIRE_SCRIPTS_FFP5CS.md](../firmwires/ffp5cs/docs/INVENTAIRE_SCRIPTS_FFP5CS.md).
