# =============================================================================
# Retirer le submodule ffp5cs dans n3_firmwires (dossier firmwires/)
# =============================================================================
# Dans le depot n3_firmwires, ffp5cs est encore un submodule. Ce script le
# supprime et integre le code ffp5cs comme dossier normal (git subtree),
# en conservant l'historique. Executer depuis la racine IOT_n3.
#
# Usage :
#   .\scripts\remove-ffp5cs-submodule-in-firmwires.ps1 -DryRun
#   .\scripts\remove-ffp5cs-submodule-in-firmwires.ps1
# =============================================================================

param([switch]$DryRun)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
$ffp5csUrl = "https://github.com/oliviera999/ffp5cs.git"

Push-Location $root
try {
    if (-not (Test-Path "firmwires\.git")) {
        Write-Host "Erreur : firmwires/ doit etre un clone (submodule n3_firmwires)." -ForegroundColor Red
        exit 1
    }

    $gm = Get-Content "firmwires\.gitmodules" -Raw -ErrorAction SilentlyContinue
    if (-not $gm -or $gm -notmatch 'submodule "ffp5cs"') {
        Write-Host "Le submodule ffp5cs n'est pas declare dans firmwires/.gitmodules. Rien a faire." -ForegroundColor Green
        exit 0
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Etapes (dans firmwires/) :" -ForegroundColor Yellow
        Write-Host "  1. git submodule deinit -f ffp5cs" -ForegroundColor Gray
        Write-Host "  2. git rm ffp5cs" -ForegroundColor Gray
        Write-Host "  3. git subtree add --prefix=ffp5cs $ffp5csUrl main" -ForegroundColor Gray
        Write-Host "  4. git add .gitmodules" -ForegroundColor Gray
        exit 0
    }

    Push-Location firmwires
    try {
        Write-Host "Desenregistrement du submodule ffp5cs..." -ForegroundColor Gray
        git submodule deinit -f ffp5cs 2>&1
        Write-Host "Suppression du submodule ffp5cs du suivi..." -ForegroundColor Gray
        git rm ffp5cs 2>&1
        Write-Host "Integration de ffp5cs en subtree (historique conserve)..." -ForegroundColor Gray
        git subtree add --prefix=ffp5cs $ffp5csUrl main 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : git subtree add a echoue. Verifiez la branche (main) et la connexion." -ForegroundColor Red
            exit 1
        }
        Write-Host "Termine. Pensez a : cd firmwires && git push" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}
