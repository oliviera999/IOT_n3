<#
.SYNOPSIS
    Scroll des pages IoT et capture les erreurs console, screenshots et debug.

.DESCRIPTION
    Lance un navigateur headless (Playwright) pour chaque page du serveur IoT,
    scrolle jusqu'en bas (declenche lazy-load, jquery.scrollex/scrolly),
    capture les messages de la console (erreurs, warnings) et genere des screenshots.
    Produit un rapport Markdown dans scripts/reports/.

.PARAMETER BaseUrl
    URL de base du serveur (defaut : https://iot.olution.info).

.PARAMETER Headed
    Affiche le navigateur au lieu du mode headless (pour debug visuel).

.PARAMETER NoScreenshots
    Desactive la capture des screenshots (plus rapide).

.EXAMPLE
    .\scripts\scroll-pages-debug.ps1

.EXAMPLE
    .\scripts\scroll-pages-debug.ps1 -BaseUrl http://localhost:8080 -Headed

.EXAMPLE
    .\scripts\scroll-pages-debug.ps1 -NoScreenshots
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://iot.olution.info',
    [switch]$Headed,
    [switch]$NoScreenshots
)

$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    (Get-Location).Path
}

$scrollDebugDir = Join-Path $root 'scripts\scroll-debug'

if (-not (Test-Path $scrollDebugDir)) {
    Write-Host "Erreur: Le dossier scripts/scroll-debug est introuvable." -ForegroundColor Red
    exit 1
}

# Verifier Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host "Node.js est requis pour ce script." -ForegroundColor Red
    Write-Host "Installez Node.js depuis https://nodejs.org puis relancez." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative sans Node: utilisez les scripts d'audit HTTP existants:" -ForegroundColor Gray
    Write-Host "  .\scripts\check-server-pages.ps1" -ForegroundColor Gray
    Write-Host "  .\scripts\audit-serveur-complet.ps1" -ForegroundColor Gray
    exit 1
}

# npm install si besoin (Playwright + navigateurs)
$nodeModules = Join-Path $scrollDebugDir 'node_modules'
$playwrightPath = Join-Path $nodeModules 'playwright'

if (-not (Test-Path $playwrightPath)) {
    Write-Host "Installation des dependances (Playwright)..." -ForegroundColor Cyan
    Push-Location $scrollDebugDir
    try {
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur lors de npm install" -ForegroundColor Red
            exit 1
        }
        Write-Host "Installation des navigateurs Playwright (Chromium)..." -ForegroundColor Cyan
        npx playwright install chromium
    } finally {
        Pop-Location
    }
}

# Construction des arguments pour le script Node
$nodeArgs = @('--baseUrl', $BaseUrl)
if ($Headed) { $nodeArgs += '--headed' }
if ($NoScreenshots) { $nodeArgs += '--no-screenshots' }

Write-Host ""
$scriptPath = Join-Path $scrollDebugDir 'scroll-pages-debug.js'
& node $scriptPath @nodeArgs
exit $LASTEXITCODE
