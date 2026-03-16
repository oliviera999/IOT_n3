# Scroll et debug des pages IoT

Script Node.js (Playwright) pour parcourir les pages du serveur IoT en scrollant et capturer les erreurs console, warnings et screenshots.

## Prérequis

- Node.js 18+ (https://nodejs.org)
- Accès réseau au serveur cible (prod ou local)

## Installation

```powershell
cd scripts/scroll-debug
npm install
npx playwright install chromium
```

Ou depuis la racine IOT_n3, lancer une fois le script PowerShell qui installe automatiquement :

```powershell
.\scripts\scroll-pages-debug.ps1
```

## Usage

### Via PowerShell (depuis racine IOT_n3)

```powershell
# Prod (défaut)
.\scripts\scroll-pages-debug.ps1

# Serveur local
.\scripts\scroll-pages-debug.ps1 -BaseUrl http://localhost:8080

# Navigateur visible (debug visuel)
.\scripts\scroll-pages-debug.ps1 -Headed

# Sans screenshots (plus rapide)
.\scripts\scroll-pages-debug.ps1 -NoScreenshots
```

### Via Node directement

```bash
cd scripts/scroll-debug
node scroll-pages-debug.js
node scroll-pages-debug.js --baseUrl http://localhost:8080
node scroll-pages-debug.js --headed --no-screenshots
```

## Sortie

- **Rapport** : `scripts/reports/scroll-debug-YYYY-MM-DDTHH-mm-ss.md`
- **Screenshots** : `scripts/reports/screenshots/<timestamp>/` (top, mid, bottom par page)

## Pages testées

Accueil, Aquaponie, Météo, Serre, Galeries (MSP1, N3PP, FFP3), FFP3 Aquaponie, FFP3 Dashboard.
