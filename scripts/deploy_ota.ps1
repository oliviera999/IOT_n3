# =============================================================================
# Script de deploiement OTA unifie - Projet n3 IoT
# =============================================================================
# Orchestre la publication OTA vers serveur/ota/ (depot n3_serveur).
# Tout passe par scripts/publish_ota.ps1 (n3pp, msp, cam, ffp5cs).
#
# Usage :
#   .\scripts\deploy_ota.ps1
#   .\scripts\deploy_ota.ps1 -IncludeFfp5cs -Build
#   .\scripts\deploy_ota.ps1 -Ffp5csOnly -Build
#   .\scripts\deploy_ota.ps1 -Targets "n3pp","msp" -DryRun
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
    [switch]$NoSign,
    [switch]$RequireSign,
    [switch]$SkipSubmoduleUpdate
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
if ((Get-Location).Path -ne $root) { Set-Location $root }

$ffp5Targets = @("ffp5-wroom-prod", "ffp5-wroom-beta", "ffp5-s3-prod", "ffp5-s3-test")

if ($Ffp5csOnly) {
    $Targets = $ffp5Targets
} elseif ($IncludeFfp5cs) {
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $merged = @()
    foreach ($t in @($Targets) + $ffp5Targets) {
        if ($seen.Add($t)) { $merged += $t }
    }
    $Targets = $merged
}

if (-not $DryRun -and -not $SkipSubmoduleUpdate) {
    Write-Host ""
    Write-Host "=== Sous-modules (init) ===" -ForegroundColor Cyan
    git submodule update --init firmwires serveur 2>$null
    if ($LASTEXITCODE -ne 0) { git submodule update --init }
}

if ($BuildFs -and -not $Build) {
    Write-Host "Info : -BuildFs sans -Build : pour ffp5cs, utiliser -Build (buildfs inclus pour envs avec FS)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Publication OTA unifiee (serveur/ota/) ===" -ForegroundColor Cyan
$publishArgs = @{
    Targets      = $Targets
    Build        = $Build
    SkipCommit   = $SkipCommit
    DryRun       = $DryRun
    SkipValidate = $SkipValidate
    NoSign       = $NoSign
    RequireSign  = $RequireSign
}
& (Join-Path $scriptDir "publish_ota.ps1") @publishArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur : publication OTA a echoue." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Deploiement OTA terminee." -ForegroundColor Green
