# =============================================================================
# Script de deploiement OTA unifie - Projet n3 IoT
# =============================================================================
# Orchestre la publication OTA des firmwares vers le serveur (iot.olution.info).
#
# Deux flux :
#   1) Cibles racine (n3pp, msp, cam-*) : publie vers serveur/ota/
#      -> utilise scripts/publish_ota.ps1
#   2) FFP5CS (wroom-prod, wroom-s3-*, etc.) : publie vers ffp3/ota/
#      -> utilise firmwires/ffp5cs/scripts/publish_ota.ps1
#
# Usage :
#   .\scripts\deploy_ota.ps1
#   .\scripts\deploy_ota.ps1 -IncludeFfp5cs
#   .\scripts\deploy_ota.ps1 -Targets "n3pp","msp" -Build
#   .\scripts\deploy_ota.ps1 -DryRun
#   .\scripts\deploy_ota.ps1 -Ffp5csOnly -Build -BuildFs
# =============================================================================

param(
    [string[]]$Targets = @("n3pp", "n3pp-test", "msp", "msp-test", "cam-msp1", "cam-n3pp", "cam-ffp3"),
    [switch]$IncludeFfp5cs,
    [switch]$Ffp5csOnly,
    [switch]$Build,
    [switch]$BuildFs,
    [switch]$SkipCommit,
    [switch]$DryRun,
    [switch]$SkipValidate,
    [switch]$NoSign
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
if ((Get-Location).Path -ne $root) { Set-Location $root }

# -----------------------------------------------------------------------------
# 1) Publication OTA racine (n3pp, msp, cam-*)
# -----------------------------------------------------------------------------
if (-not $Ffp5csOnly) {
    Write-Host ""
    Write-Host "=== Deploiement OTA racine (n3pp, msp, cam) ===" -ForegroundColor Cyan
    $publishArgs = @("-Targets") + $Targets
    if ($Build) { $publishArgs += "-Build" }
    if ($SkipCommit) { $publishArgs += "-SkipCommit" }
    if ($DryRun) { $publishArgs += "-DryRun" }
    if ($SkipValidate) { $publishArgs += "-SkipValidate" }
    if ($NoSign) { $publishArgs += "-NoSign" }

    & (Join-Path $scriptDir "publish_ota.ps1") @publishArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur : publication OTA racine a echoue." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# -----------------------------------------------------------------------------
# 2) Publication OTA FFP5CS (ffp3/ota/)
# -----------------------------------------------------------------------------
if ($IncludeFfp5cs -or $Ffp5csOnly) {
    $ffp5csDir = Join-Path $root "firmwires\ffp5cs"
    $ffp5csScript = Join-Path $ffp5csDir "scripts\publish_ota.ps1"
    if (-not (Test-Path $ffp5csScript)) {
        Write-Host "Erreur : script FFP5CS introuvable ($ffp5csScript)." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "=== Deploiement OTA FFP5CS (ffp3/ota/) ===" -ForegroundColor Cyan
    Push-Location $ffp5csDir
    try {
        $ffpArgs = @()
        if ($Build) { $ffpArgs += "-Build" }
        if ($BuildFs) { $ffpArgs += "-BuildFs" }
        if ($SkipCommit) { $ffpArgs += "-SkipCommit" }
        if ($DryRun) { $ffpArgs += "-DryRun" }
        if ($SkipValidate) { $ffpArgs += "-SkipValidate" }
        & $ffp5csScript @ffpArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : publication OTA FFP5CS a echoue." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Deploiement OTA terminee." -ForegroundColor Green
