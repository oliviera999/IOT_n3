# =============================================================================
# Script de deploiement OTA unifie - Projet n3 IoT
# =============================================================================
# Orchestre la publication OTA des firmwares vers le serveur (iot.olution.info).
#
# Flux complet (sans -DryRun / -SkipCommit) :
#   0) Sous-modules : git submodule update --init --recursive (+ ffp5cs/ffp3 si FFP5CS).
#   1) Cibles racine (n3pp, msp, cam-*) : publie vers serveur/ota/, commit+push serveur + parent.
#      -> scripts/publish_ota.ps1
#   2) FFP5CS : publie vers ffp3/ota/ (depot ffp3), commit+push firmwires (ref ffp3),
#      sync ffp3/ota -> serveur/ota, commit+push serveur, puis commit+push parent (refs serveur + firmwires).
#      -> firmwires/ffp5cs/scripts/publish_ota.ps1
#   L'OTA est alors disponible sur iot.olution.info (CRON pull n3_serveur).
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
    [switch]$NoSign,
    [switch]$SkipSubmoduleUpdate
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
if ((Get-Location).Path -ne $root) { Set-Location $root }

# -----------------------------------------------------------------------------
# 0) Sous-modules a jour (pour que ffp3/ota, serveur/ota existent)
# -----------------------------------------------------------------------------
if (-not $DryRun -and -not $SkipSubmoduleUpdate) {
    Write-Host ""
    Write-Host "=== Sous-modules (init + update) ===" -ForegroundColor Cyan
    # Premier niveau uniquement (evite echec si sous-module recursif invalide dans serveur)
    # Attention : reinitialise firmwires/serveur sur la ref enregistree dans le parent (ecrase commits locaux non pousses).
    git submodule update --init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur : git submodule update a echoue." -ForegroundColor Red
        exit 1
    }
    if ($IncludeFfp5cs -or $Ffp5csOnly) {
        $ffp5csDir = Join-Path $root "firmwires\ffp5cs"
        if (Test-Path (Join-Path $ffp5csDir ".gitmodules")) {
            Push-Location $ffp5csDir
            git submodule update --init
            Pop-Location
        }
    }
}
elseif (-not $DryRun -and $SkipSubmoduleUpdate) {
    Write-Host ""
    Write-Host "=== Sous-modules : ignore (-SkipSubmoduleUpdate) ===" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 1) Publication OTA racine (n3pp, msp, cam-*)
# -----------------------------------------------------------------------------
if (-not $Ffp5csOnly) {
    Write-Host ""
    Write-Host "=== Deploiement OTA racine (n3pp, msp, cam) ===" -ForegroundColor Cyan
    $publishArgs = @{
        Targets     = $Targets
        Build      = $Build
        SkipCommit = $SkipCommit
        DryRun     = $DryRun
        SkipValidate = $SkipValidate
        NoSign     = $NoSign
    }
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
        $ffpArgs = @{
            Build       = $Build
            BuildFs     = $BuildFs
            SkipCommit  = $SkipCommit
            DryRun      = $DryRun
            SkipValidate = $SkipValidate
        }
        & $ffp5csScript @ffpArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : publication OTA FFP5CS a echoue." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
    # Enregistrer la ref ffp3 dans le depot firmwires (sous-module ffp5cs/ffp3)
    $firmwiresDir = Join-Path $root "firmwires"
    $serveurCommitted = $false
    $firmwiresCommitted = $false
    if (-not $SkipCommit -and -not $DryRun -and (Test-Path (Join-Path $firmwiresDir ".git"))) {
        Push-Location $firmwiresDir
        $ffp3Status = git status --porcelain ffp5cs/ffp3
        if ($ffp3Status) {
            git add ffp5cs/ffp3
            git commit -m "[ffp5cs] chore: update ffp3 ref (OTA)"
            if ($LASTEXITCODE -eq 0) {
                git push
                $firmwiresCommitted = ($LASTEXITCODE -eq 0)
                Write-Host "  Commit + push firmwires (ref ffp3) OK." -ForegroundColor Gray
            }
        }
        Pop-Location
    }
    # Sync ffp3/ota -> serveur/ota pour que le serveur (iot.olution.info) serve /ffp3/ota/*
    $ffp3Ota = Join-Path $ffp5csDir "ffp3\ota"
    $serveurOta = Join-Path $root "serveur\ota"
    if (Test-Path $ffp3Ota) {
        Write-Host ""
        Write-Host "=== Sync OTA FFP5CS vers serveur/ota ===" -ForegroundColor Cyan
        if (-not $DryRun) {
            Copy-Item (Join-Path $ffp3Ota "metadata.json") $serveurOta -Force
            @("esp32-wroom", "esp32-wroom-beta", "esp32-s3", "esp32-s3-test") | ForEach-Object {
                $d = Join-Path $serveurOta $_
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
                $srcDir = Join-Path $ffp3Ota $_
                if (Test-Path $srcDir) {
                    Copy-Item (Join-Path $srcDir "*") $d -Recurse -Force
                }
            }
            Write-Host "  Copie ffp3/ota -> serveur/ota OK." -ForegroundColor Gray
        }
        # Commit + push serveur si changements et pas SkipCommit/DryRun
        if (-not $SkipCommit -and -not $DryRun -and (Test-Path (Join-Path $root "serveur\.git"))) {
            Push-Location (Join-Path $root "serveur")
            $status = git status --porcelain ota/
            if ($status) {
                git add ota/
                git commit -m "[serveur] ota: sync FFP5CS (metadata + esp32-*)"
                git push
                $serveurCommitted = ($LASTEXITCODE -eq 0)
                Write-Host "  Commit + push serveur (ota) OK." -ForegroundColor Gray
            }
            Pop-Location
        }
    }
    # Commit + push depot parent (refs serveur et/ou firmwires)
    if ((-not $SkipCommit -and -not $DryRun) -and ($serveurCommitted -or $firmwiresCommitted)) {
        Write-Host ""
        Write-Host "=== Commit depot parent (refs sous-modules) ===" -ForegroundColor Cyan
        if ($serveurCommitted) { git add serveur }
        if ($firmwiresCommitted) { git add firmwires }
        $parentStatus = git status --porcelain
        if ($parentStatus) {
            git commit -m "[projet] ref serveur/firmwires (OTA FFP5CS)"
            git push
            Write-Host "  Commit + push depot parent OK." -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Deploiement OTA terminee." -ForegroundColor Green
