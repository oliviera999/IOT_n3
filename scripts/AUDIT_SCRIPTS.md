# Audit du dossier `scripts/` — IOT_n3

- **Date** : 2026-06-09
- **Périmètre** : `scripts/` du dépôt parent IOT_n3 (scripts PowerShell, sous-projets Node, archive, configs).
- **Méthode** : revue de code statique, **vérifiée contre le submodule `serveur/` réel** (ref épinglée), puis validation syntaxique/statique des `.ps1` via **PowerShell 7.4.6** (parser `[Parser]::ParseFile`) et **PSScriptAnalyzer 1.25.0**.
- **Suivi** : commits `39ce321` (corrections P1–P4), `97ce5ee` (validation + variable morte), `34df8de` (fusion Node).

---

## 1. Synthèse

Le dossier est globalement de **bonne facture** : familles claires (publication OTA, audit/vérification de pages, déploiement, tests, maintenance, Git), `README` d'inventaire, dossier `archive/` documenté, `.gitignore` correct (clé privée OTA et `reports/` exclus). Quelques scripts étaient excellents (`publish_ota.ps1`, `audit-serveur-complet.ps1`, `check-server-pages.ps1`), d'autres obsolètes, redondants ou en contradiction factuelle avec la prod.

**Note globale : 7/10 avant correctifs → 8,5/10 après** (ménage, cohérence, validation outillée).

---

## 2. Notation par script (état final)

| Script | Utilité | État | Remarque |
|--------|:---:|:---:|--------|
| `publish_ota.ps1` | ⭐⭐⭐ | ✅ | Pièce maîtresse (SHA-256, ECDSA, anti-downgrade, audit log). Ajout `-RequireSign`. |
| `deploy_ota.ps1` | ⭐⭐⭐ | ✅ | Orchestrateur ; `-RequireSign` propagé. |
| `publish-cycle.ps1` | ⭐⭐⭐ | ✅ | Version+CHANGELOG+commit propre. |
| `audit-serveur-complet.ps1` | ⭐⭐⭐ | ✅ | 8 sections. Version lue depuis `serveur/VERSION` ; double-comptage corrigé. |
| `check-server-pages.ps1` | ⭐⭐⭐ | ✅ | Parse logs + propose des correctifs. Référence pour la vérif de pages. |
| `generate_ota_keys.ps1` | ⭐⭐⭐ | ✅ | openssl → fallback .NET. |
| `find-bugs.ps1` | ⭐⭐ | ✅ | Méta-script (sécurité + PHPUnit + pages + build). `tools/run-phpunit.php` confirmé présent. |
| `deploy-server.ps1` | ⭐⭐ | ✅ | Chemin ffp3 auto-détecté (`analyse-ffp3`) ; étape 4 best-effort ; variable morte retirée. |
| `clean-firmware-builds.ps1` | ⭐⭐ | ✅ | `-WhatIf` supporté. |
| `firmwires-list.ps1` | ⭐⭐ | ✅ | Lit le manifest. |
| `test-realtime-api.ps1` | ⭐⭐ | ✅ | Ciblé, auto-documenté. |
| `scroll-pages-debug.ps1` | ⭐⭐ | ✅ | Wrapper Node → `browser-audit/`. |
| `check-user-pages.ps1` | ⭐ | ✅ | **Bug corrigé** (dossier rapports créé) ; routes legacy → `/meteo`,`/serre`. |
| `test-pages-curl.ps1` | ⭐ | ✅ | Attentes 301 correctes (vérifié dans `public/index.php`). |
| `test-highcharts-rendering.ps1` | ⭐ | ✅ | Smoke test statique ; vérif réelle → `browser-audit/`. |
| `fix-di-cache-prod.ps1` | ⭐ | ✅ | Routes de vérif corrigées (301). |
| `fix-production-500-errors.ps1` | ⭐ | ✅ | Chemin SSH cache DI corrigé + alternative HTTP. |
| `clear-cursor-cache.ps1` | ⭐ | ⚠️ | Utilitaire dev générique, hors périmètre IoT (laissé). |
| `browser-audit/` (Node) | ⭐⭐⭐ | ✅ | Audits navigateur réels (charts + scroll). Projets Node fusionnés. |

**Archivés** (`scripts/archive/`) : `audit-iot-pages.ps1`, `audit-iot-pages-v2.ps1`, `inspect-chart-data.ps1`, `fermer-pr-integrees.ps1`, `README-subtree-ffp5cs.md` (+ les 3 migrations one-shot préexistantes).

---

## 3. Constats vérifiés contre le serveur réel

| # | Constat | Réalité (submodule `serveur`) | Traitement |
|---|---------|-------------------------------|-----------|
| 1 | `deploy-server.ps1` ciblait `serveur/ffp3/` | Inexistant ; le vrai chemin est `serveur/analyse-ffp3/` (seul `DEPLOY_NOW.sh`). Le script échouait **avant** le pull/push. | Auto-détection + étape 4 best-effort. |
| 2 | `audit-serveur-complet.ps1` : version `5.0.69` codée en dur | `serveur/VERSION` = **5.1.15**. | Lecture dynamique de `VERSION`. |
| 3 | `msp1-data.php` / `n3pp-data.php` attendus en 200 | **301** → `/meteo` / `/serre` (`public/index.php:428-436`). | `check-user-pages`, `fix-di-cache-prod` corrigés. |
| 4 | Deux chemins SSH de cache DI divergents | Réel : `var/cache/di/` sous la racine de déploiement (`/home4/oliviera/iot.olution.info/...`). | `fix-production-500-errors` corrigé + alternative HTTP (`clear-di-cache.php`). |
| 5 | Double-comptage des pages protégées (200) | Logique de compteur neutralisée (`$totalOk--;$totalOk++`). | Réécrite proprement. |

---

## 4. Actions réalisées

**P1 — Ménage** : archivage des obsolètes/one-shot ; correction du bug de création de `scripts/reports/` dans `check-user-pages.ps1` ; suppression d'une référence à un script archivé.

**P2 — Cohérence** (vérifiée contre `serveur/`) : chemin ffp3 auto-détecté ; version serveur dynamique ; chemin/cache DI réconcilié ; routes 301 alignées.

**P3 — Consolidation** : dépendance `highcharts` inutilisée retirée de `browser-audit` ; double-comptage corrigé ; **fusion des deux projets Node** `browser-audit` + `scroll-debug` (un seul `node_modules`, Playwright `^1.58.2`).

**P4 — Durcissement** : option **`-RequireSign`** sur `publish_ota.ps1` (échec si signature ECDSA indisponible/échouée pour n3pp/msp/cam), propagée via `deploy_ota.ps1`. Motivée par la régression visible dans `ota-audit.jsonl` (publications du 08/06 en `"signed":false`).

**Validation** : les **25 scripts `.ps1` parsent sans erreur** ; aucun diagnostic Error/Warning introduit par les modifications ; logique cross-platform (lecture `VERSION`) testée en isolation ; JS validés via `node --check`.

---

## 5. Non traité — décisions motivées

### Renommage des scripts OTA en kebab-case → **abandonné**

`publish_ota.ps1`, `deploy_ota.ps1`, `generate_ota_keys.ps1` sont en snake_case là où le reste est en kebab-case. **Ce n'est pas une incohérence à corriger** :

- `firmwires/ffp5cs/scripts/publish_ota.ps1` (submodule = dépôt séparé) appelle le script racine **par son nom exact** : `Test-Path .../scripts\publish_ota.ps1` puis `& .../scripts\publish_ota.ps1` (lignes 26 et 38). Le nom est donc un **contrat d'API inter-dépôts**.
- ~20 références dans la doc (README, RECOMMANDATIONS_IOT, `docs/AUDIT_OTA_SYSTEME.md`, etc.), dont des entrées **historiques** de CHANGELOG à ne pas réécrire.

Renommer casserait la délégation du submodule, ou imposerait un **shim permanent** au nom snake_case — ce qui annule le bénéfice cosmétique. **Recommandation : conserver les noms OTA tels quels.**

### `PSAvoidUsingWriteHost` (PSScriptAnalyzer) → laissé

Usage **intentionnel** : sortie console colorée propre à ces outils CLI interactifs. Migrer vers `Write-Information`/`Write-Output` changerait le comportement sans gain.

### `PSAvoidUsingBrokenHashAlgorithms` (MD5) → laissé

`Get-FileHash -Algorithm MD5` dans la branche **ffp5cs** : format OTA legacy documenté. Les autres cibles utilisent SHA-256 + signature ECDSA.

---

## 6. Recommandations résiduelles (à valider côté Windows/prod)

- Ces scripts ciblent **Windows/PowerShell** (chemins `\`, `pio`, réseau, prod) : la validation faite ici est syntaxique/statique. Un essai réel reste recommandé pour `publish_ota.ps1 -RequireSign` et l'auto-détection de `deploy-server.ps1`.
- **Restaurer la clé de signature OTA** sur la machine de build : `ota-audit.jsonl` montre des publications n3pp récentes non signées. Envisager `-RequireSign` par défaut dans le workflow de publication.
- `clear-cursor-cache.ps1` : utilitaire dev générique, candidat à un dépôt d'outils perso plutôt qu'au projet.

---

## 7. Annexe — méthodologie de validation

```powershell
# Parser (syntaxe, sans exécution)
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)

# Analyse statique
Invoke-ScriptAnalyzer -Path scripts/<file>.ps1 -Severity Error,Warning
```

`node --check <file>.js` pour les sous-projets Node ; `JSON.parse` pour `package.json` / `package-lock.json`.
