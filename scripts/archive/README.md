# Scripts archivés

Scripts et notes conservés pour historique. Ne sont plus maintenus ; ne pas utiliser en production.

## Migrations Git one-shot (déjà effectuées)

- `migrate-firmwires-to-submodule.ps1` — Migration firmwares → submodule n3_firmwires
- `remove-ffp5cs-submodule-in-firmwires.ps1` — Migration ffp5cs dans firmwires
- `run-subtree-add-ffp5cs.ps1` — Opération git subtree pour ffp5cs
- `README-subtree-ffp5cs.md` — Mode opératoire de l'intégration ffp5cs en subtree (migration terminée)
- `fermer-pr-integrees.ps1` — Fermeture en masse des PR #10–17 (plan 2026-05-30, commit `c2689f6`). Opération ponctuelle déjà réalisée.

## Audit de pages remplacés

- `audit-iot-pages.ps1` / `audit-iot-pages-v2.ps1` — Anciens audits sur 3 pages hardcodées (variantes curl et Invoke-WebRequest). Remplacés par `../check-server-pages.ps1` et `../audit-serveur-complet.ps1` (couverture complète + rapports).
- `inspect-chart-data.ps1` — Inspection des variables de données des graphiques par regex sur le HTML. Redondant avec `../test-highcharts-rendering.ps1` (smoke test statique) et surtout `../browser-audit/check-charts.js` (lecture réelle de `window.Highcharts` : nombre de séries et de points). Préférer ces deux-là.
