# browser-audit — audits navigateur des pages IoT (Playwright)

Projet Node unique regroupant les audits qui nécessitent un **vrai navigateur** (exécution du JavaScript de page), là où les scripts PowerShell ne font qu'une analyse HTML statique.

## Prérequis

- Node.js 18+ (https://nodejs.org)
- Accès réseau au serveur cible (prod ou local)

## Installation

```bash
cd scripts/browser-audit
npm install
npx playwright install chromium
```

## Outils

### 1. `check-charts.js` — rendu Highcharts

Charge chaque page, lit `window.Highcharts.charts` (nombre de séries, points de données),
capture les erreurs console et requêtes échouées, génère des screenshots.

```bash
npm run audit:charts                 # baseUrl par défaut (http://127.0.0.1:8093)
npm run audit:charts:prod            # https://iot.olution.info
node check-charts.js --baseUrl http://localhost:8082
```

- **Rapport** : `scripts/browser-audit/report.json`
- **Captures** : `scripts/browser-audit/screenshots/`

### 2. `scroll-pages-debug.js` — scroll, console, screenshots

Scrolle chaque page jusqu'en bas (déclenche lazy-load, scrollex), capture les messages
console (erreurs/warnings) et génère des screenshots (haut, milieu, bas). Produit un
rapport Markdown.

```bash
npm run scroll-debug                 # prod par défaut
npm run scroll-debug:prod
node scroll-pages-debug.js --baseUrl http://localhost:8080
node scroll-pages-debug.js --headed --no-screenshots
```

Wrapper PowerShell (installe les dépendances au besoin, depuis la racine IOT_n3) :

```powershell
.\scripts\scroll-pages-debug.ps1
.\scripts\scroll-pages-debug.ps1 -BaseUrl http://localhost:8080 -Headed
.\scripts\scroll-pages-debug.ps1 -NoScreenshots
```

- **Rapport** : `scripts/reports/scroll-debug-YYYY-MM-DDTHH-mm-ss.md`
- **Screenshots** : `scripts/reports/screenshots/<timestamp>/`

## Note

Ce dossier a fusionné l'ancien projet `scripts/scroll-debug/` (mai 2026) pour n'avoir
qu'un seul `node_modules` et une seule version de Playwright.
