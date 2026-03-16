# =============================================================================
# Migration : firmwires -> submodule n3_firmwires (Option B)
# =============================================================================
# Remplace le dossier firmwires (et le submodule firmwires/ffp5cs) par un
# unique submodule pointant vers n3_firmwires.
#
# PREREQUIS : Le depot n3_firmwires existe sur GitHub et contient deja tout
# le contenu de firmwires (n3pp4_2, msp2_5, uploadphotosserver*, ffp5cs, ratata,
# LVGL_Widgets, firmwares.manifest.json, etc.). ffp5cs doit etre un dossier
# normal dans n3_firmwires (pas un submodule).
#
# Executer depuis la racine IOT_n3. En cas de doute, lancer d'abord avec -DryRun.
#
# Usage :
#   .\scripts\migrate-firmwires-to-submodule.ps1 -DryRun
#   .\scripts\migrate-firmwires-to-submodule.ps1
#   .\scripts\migrate-firmwires-to-submodule.ps1 -Force
# =============================================================================

param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$N3_FIRMWIRES_URL = "https://github.com/oliviera999/n3_firmwires.git"

# Racine IOT_n3 (depuis scripts/)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
Push-Location $root

try {
    if (-not (Test-Path ".git")) {
        Write-Host "Erreur : executer depuis la racine du depot IOT_n3 (pas de .git ici)." -ForegroundColor Red
        exit 1
    }

    $gitmodules = Get-Content ".gitmodules" -Raw -ErrorAction SilentlyContinue
    $hasFfp5cs = $gitmodules -and $gitmodules -match "firmwires/ffp5cs"
    $hasFirmwiresSub = $gitmodules -and $gitmodules -match 'submodule "firmwires"'

    if ($hasFirmwiresSub) {
        Write-Host "Le dossier firmwires est deja un submodule (n3_firmwires). Rien a faire." -ForegroundColor Green
        exit 0
    }

    Write-Host "Migration firmwires -> submodule n3_firmwires" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Host "[DRY RUN] Etapes qui seraient executees :" -ForegroundColor Yellow
        if ($hasFfp5cs) {
            Write-Host "  1. git submodule deinit -f firmwires/ffp5cs" -ForegroundColor Gray
            Write-Host "  2. git rm firmwires/ffp5cs" -ForegroundColor Gray
        }
        Write-Host "  3. git rm -r firmwires" -ForegroundColor Gray
        Write-Host "  4. git submodule add $N3_FIRMWIRES_URL firmwires" -ForegroundColor Gray
        Write-Host "  5. git add .gitmodules" -ForegroundColor Gray
        Write-Host "  6. git commit -m '[projet] firmwires en submodule n3_firmwires'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Assurez-vous que n3_firmwires contient tout le contenu de firmwires avant de lancer sans -DryRun." -ForegroundColor Yellow
        exit 0
    }

    if (-not $Force) {
        Write-Host "Cette operation va SUPPRIMER le dossier firmwires local et le remplacer par le submodule." -ForegroundColor Yellow
        Write-Host "Verifiez que n3_firmwires sur GitHub contient bien tout le code (n3pp4_2, msp2_5, ffp5cs, etc.)." -ForegroundColor Yellow
        $r = Read-Host "Continuer ? (o/N)"
        if ($r -ne "o" -and $r -ne "O") {
            Write-Host "Annule." -ForegroundColor Gray
            exit 0
        }
    }

    # 1. Desenregistrer ffp5cs si present
    if ($hasFfp5cs) {
        Write-Host "Desenregistrement du submodule firmwires/ffp5cs..." -ForegroundColor Gray
        git submodule deinit -f firmwires/ffp5cs
        git rm firmwires/ffp5cs
    }

    # 2. Supprimer firmwires du suivi (supprime le dossier)
    Write-Host "Suppression du dossier firmwires du suivi Git..." -ForegroundColor Gray
    git rm -r firmwires

    # 3. Ajouter le submodule n3_firmwires
    Write-Host "Ajout du submodule n3_firmwires..." -ForegroundColor Gray
    git submodule add $N3_FIRMWIRES_URL firmwires

    git add .gitmodules
    Write-Host "Commit..." -ForegroundColor Gray
    git commit -m "[projet] firmwires en submodule n3_firmwires"

    Write-Host ""
    Write-Host "Migration terminee. Pensez a : git push origin master" -ForegroundColor Green
    Write-Host "Et dans firmwires : git submodule update --init firmwires (sur les clones existants)." -ForegroundColor Gray
} finally {
    Pop-Location
}
