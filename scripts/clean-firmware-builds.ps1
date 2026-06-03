# =============================================================================
# Nettoyage des artefacts de build firmware (PlatformIO) — projet IOT_n3
# =============================================================================
# Supprime les dossiers .pio (build + libdeps) dans chaque projet firmwires connu,
# et optionnellement les sorties redirigees sous C:\pio-builds\<slug> ainsi que
# l'ancien miroir C:\ffp5cs_build.
#
# Usage (depuis la racine IOT_n3) :
#   .\scripts\clean-firmware-builds.ps1 -WhatIf
#   .\scripts\clean-firmware-builds.ps1
#   .\scripts\clean-firmware-builds.ps1 -SyncPioBuilds
#   .\scripts\clean-firmware-builds.ps1 -IncludePioBuildsRoot -IncludeLegacyFfp5Mirror
#
# Variables :
#   N3_PIO_BUILD_ROOT — si defini, aussi nettoyer cette racine (sous-dossiers slug connus)
# =============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$IncludePioBuildsRoot,
    [switch]$SyncPioBuilds,
    [switch]$IncludeLegacyFfp5Mirror
)

if ($SyncPioBuilds) {
    $IncludePioBuildsRoot = $true
}

$ErrorActionPreference = "Stop"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
$firmwires = Join-Path $root "firmwires"

if (-not (Test-Path -LiteralPath $firmwires)) {
    Write-Host "Erreur : firmwires/ introuvable (racine : $root)." -ForegroundColor Red
    exit 1
}

$helpers = Join-Path $firmwires "scripts\Get-PioBuildHelpers.ps1"
if (Test-Path -LiteralPath $helpers) {
    . $helpers
}

# Projets : chemins relatifs a firmwires/ (dossiers optionnels si submodule partiel)
$relativeProjects = @(
    "ffp5cs",
    "n3pp",
    "msp",
    "uploadphotosserver",
    "LVGL_Widgets",
    "ratata",
    "ffp5cs\test psram s3",
    "ffp5cs\test psram s3 2"
)

function Remove-TreeIfExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ($PSCmdlet.ShouldProcess($Path, "Supprimer repertoire")) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Host "  Supprime : $Path" -ForegroundColor Green
    }
}

Write-Host "=== Nettoyage builds firmware ===" -ForegroundColor Cyan
Write-Host "Racine : $root" -ForegroundColor Gray

foreach ($rel in $relativeProjects) {
    $proj = Join-Path $firmwires $rel
    if (-not (Test-Path -LiteralPath $proj)) {
        Write-Host "[skip] Absent : $rel" -ForegroundColor DarkGray
        continue
    }
    $pio = Join-Path $proj ".pio"
    if (Test-Path -LiteralPath $pio) {
        Write-Host "--- $rel : .pio/ ---" -ForegroundColor Yellow
        Remove-TreeIfExists -Path $pio
    } else {
        Write-Host "[ok] Pas de .pio : $rel" -ForegroundColor Gray
    }
}

if ($IncludePioBuildsRoot -or $env:N3_PIO_BUILD_ROOT) {
    $pioRoot = if ($env:N3_PIO_BUILD_ROOT -and $env:N3_PIO_BUILD_ROOT.Trim()) {
        $env:N3_PIO_BUILD_ROOT.Trim()
    } else {
        "C:\pio-builds"
    }
    Write-Host "--- Racine redirection : $pioRoot ---" -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $pioRoot)) {
        Write-Host "  (inexistant)" -ForegroundColor Gray
    } else {
        foreach ($rel in $relativeProjects) {
            $proj = Join-Path $firmwires $rel
            if (-not (Test-Path -LiteralPath $proj)) { continue }
            if (Get-Command Get-N3PioProjectSlug -ErrorAction SilentlyContinue) {
                $slug = Get-N3PioProjectSlug -ProjectRoot $proj
            } else {
                $slug = ((Split-Path -Leaf $proj) -split '\s+') -join '-'
            }
            $slugDir = Join-Path $pioRoot $slug
            Remove-TreeIfExists -Path $slugDir
        }
    }
}

if ($IncludeLegacyFfp5Mirror) {
    $legacy = "C:\ffp5cs_build"
    Write-Host "--- Ancien miroir : $legacy ---" -ForegroundColor Yellow
    Remove-TreeIfExists -Path $legacy
}

Write-Host "=== Termine ===" -ForegroundColor Cyan
