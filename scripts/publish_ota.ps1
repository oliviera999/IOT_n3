# =============================================================================
# Script de publication OTA distant - Projet n3 IoT
# =============================================================================
# Compile (optionnel), copie les firmware.bin vers serveur/ota/, met a jour les
# metadata.json, puis commit + push dans le depot serveur (sous-module).
#
# Cibles supportees :
#   n3pp      -> serveur/ota/n3pp/        (firmware serre, ESP32)
#   msp       -> serveur/ota/msp/         (firmware meteo, ESP32)
#   cam-msp1  -> serveur/ota/cam/msp1/    (camera meteo, ESP32-CAM)
#   cam-n3pp  -> serveur/ota/cam/n3pp/    (camera serre, ESP32-CAM)
#   cam-ffp3  -> serveur/ota/cam/ffp3/    (camera aquaponie, ESP32-CAM)
#
# Le firmware ffp5cs conserve son propre script (firmwires/ffp5cs/scripts/publish_ota.ps1).
#
# Prerequis : build deja effectue pour les cibles voulues, ou utiliser -Build.
# Executer depuis la racine du projet IOT_n3.
#
# Usage :
#   .\scripts\publish_ota.ps1
#   .\scripts\publish_ota.ps1 -Targets "n3pp","msp"
#   .\scripts\publish_ota.ps1 -Targets "cam-msp1","cam-n3pp","cam-ffp3"
#   .\scripts\publish_ota.ps1 -Build
#   .\scripts\publish_ota.ps1 -DryRun
# =============================================================================

param(
    [string[]]$Targets = @("n3pp", "msp", "cam-msp1", "cam-n3pp", "cam-ffp3"),
    [switch]$Build,
    [switch]$SkipCommit,
    [switch]$DryRun,
    [switch]$SkipValidate
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Racine IOT_n3 et initialisation submodule firmwires si besoin
# -----------------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
if ((Get-Location).Path -ne $root) { Set-Location $root }
if (-not (Test-Path "firmwires\n3pp4_2") -and (Test-Path ".gitmodules")) {
    $gm = Get-Content ".gitmodules" -Raw
    if ($gm -match 'submodule "firmwires"') {
        Write-Host "Initialisation du submodule firmwires (n3_firmwires)..." -ForegroundColor Gray
        git submodule update --init firmwires
    }
}

# -----------------------------------------------------------------------------
# Configuration des cibles
# -----------------------------------------------------------------------------
$TargetConfig = [ordered]@{
    "n3pp" = @{
        ProjectDir   = "firmwires\n3pp4_2"
        PioEnv       = "esp32dev"
        OtaDest      = "serveur\ota\n3pp"
        MetadataPath = "serveur\ota\n3pp\metadata.json"
        OtaUrl       = "http://iot.olution.info/ota/n3pp/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "msp" = @{
        ProjectDir   = "firmwires\msp2_5"
        PioEnv       = "esp32dev"
        OtaDest      = "serveur\ota\msp"
        MetadataPath = "serveur\ota\msp\metadata.json"
        OtaUrl       = "http://iot.olution.info/ota/msp/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "cam-msp1" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "msp1"
        OtaDest      = "serveur\ota\cam\msp1"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "http://iot.olution.info/ota/cam/msp1/firmware.bin"
        MetadataKey  = "msp1"
        AppMaxSize   = 1966080
    }
    "cam-n3pp" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "n3pp"
        OtaDest      = "serveur\ota\cam\n3pp"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "http://iot.olution.info/ota/cam/n3pp/firmware.bin"
        MetadataKey  = "n3pp"
        AppMaxSize   = 1966080
    }
    "cam-ffp3" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "ffp3"
        OtaDest      = "serveur\ota\cam\ffp3"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "http://iot.olution.info/ota/cam/ffp3/firmware.bin"
        MetadataKey  = "ffp3"
        AppMaxSize   = 1966080
    }
}

# -----------------------------------------------------------------------------
# Verifications initiales
# -----------------------------------------------------------------------------
if (-not (Test-Path "serveur")) {
    Write-Host "Erreur : executer depuis la racine du projet IOT_n3 (serveur/ doit exister)." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "firmwires")) {
    Write-Host "Erreur : firmwires/ absent. Lancez : git submodule update --init firmwires" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Extraction de version depuis le code source
# -----------------------------------------------------------------------------
function Get-FirmwareVersion {
    param([string]$TargetName, [hashtable]$Config)

    $projectDir = $Config.ProjectDir

    # n3pp / msp : version dans main.cpp
    if ($TargetName -eq "n3pp" -or $TargetName -eq "msp") {
        $mainCpp = Join-Path $projectDir "src\main.cpp"
        if (-not (Test-Path $mainCpp)) {
            Write-Host "  Erreur : $mainCpp introuvable" -ForegroundColor Red
            return $null
        }
        $content = Get-Content -Path $mainCpp -Raw
        if ($content -match 'String\s+version\s*=\s*"([^"]+)"') {
            return $Matches[1]
        }
        Write-Host "  Erreur : impossible d extraire la version depuis $mainCpp" -ForegroundColor Red
        return $null
    }

    # cam-* : version dans config.h, bloc #if defined(TARGET_xxx)
    if ($TargetName -like "cam-*") {
        $configH = Join-Path $projectDir "include\config.h"
        if (-not (Test-Path $configH)) {
            Write-Host "  Erreur : $configH introuvable" -ForegroundColor Red
            return $null
        }
        $content = Get-Content -Path $configH -Raw
        $targetDefine = switch ($TargetName) {
            "cam-msp1" { "TARGET_MSP1" }
            "cam-n3pp" { "TARGET_N3PP" }
            "cam-ffp3" { "TARGET_FFP3" }
        }
        if ($content -match "(?s)defined\($targetDefine\).*?FIRMWARE_VERSION\s+`"([^`"]+)`"") {
            return $Matches[1]
        }
        Write-Host "  Erreur : impossible d extraire FIRMWARE_VERSION pour $targetDefine" -ForegroundColor Red
        return $null
    }

    return $null
}

# -----------------------------------------------------------------------------
# Build optionnel
# -----------------------------------------------------------------------------
if ($Build) {
    Write-Host "" -NoNewline
    Write-Host "=== Compilation des cibles ===" -ForegroundColor Yellow
    $builtEnvs = @{}
    foreach ($targetName in $Targets) {
        $cfg = $TargetConfig[$targetName]
        if (-not $cfg) { continue }
        $key = "$($cfg.ProjectDir)|$($cfg.PioEnv)"
        if ($builtEnvs.ContainsKey($key)) { continue }

        Write-Host "  Compilation $targetName ($($cfg.ProjectDir) -e $($cfg.PioEnv))..." -ForegroundColor Gray
        Push-Location $cfg.ProjectDir
        try {
            pio run -e $cfg.PioEnv
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Erreur : build $targetName a echoue." -ForegroundColor Red
                exit 1
            }
        } finally {
            Pop-Location
        }
        $builtEnvs[$key] = $true
    }
    Write-Host "Compilation terminee." -ForegroundColor Green
    Write-Host ""
}

# -----------------------------------------------------------------------------
# Publication : copie des binaires + collecte des infos
# -----------------------------------------------------------------------------
Write-Host "=== Publication OTA ===" -ForegroundColor Cyan

$artifacts = @()

foreach ($targetName in $Targets) {
    $cfg = $TargetConfig[$targetName]
    if (-not $cfg) {
        Write-Host "  Avertissement : cible '$targetName' inconnue, ignoree." -ForegroundColor Yellow
        continue
    }

    Write-Host ""
    Write-Host "--- $targetName ---" -ForegroundColor Cyan

    # Localiser le firmware.bin compile
    $srcBin = Join-Path $cfg.ProjectDir ".pio\build\$($cfg.PioEnv)\firmware.bin"
    if (-not (Test-Path $srcBin)) {
        Write-Host "  Avertissement : $srcBin introuvable. Compilez d abord ou utilisez -Build." -ForegroundColor Yellow
        continue
    }

    # Extraire la version
    $version = Get-FirmwareVersion -TargetName $targetName -Config $cfg
    if (-not $version) {
        Write-Host "  Avertissement : version introuvable, cible ignoree." -ForegroundColor Yellow
        continue
    }
    Write-Host "  Version : $version" -ForegroundColor White

    # Creer le dossier de destination si necessaire
    $destDir = $cfg.OtaDest
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Write-Host "  Cree : $destDir" -ForegroundColor Gray
    }

    # Copier le binaire
    $destBin = Join-Path $destDir "firmware.bin"
    Copy-Item -Path $srcBin -Destination $destBin -Force
    $size = (Get-Item $destBin).Length
    $hash = (Get-FileHash -Path $destBin -Algorithm MD5).Hash.ToLowerInvariant()

    Write-Host "  Copie : $srcBin -> $destBin" -ForegroundColor Green
    Write-Host "  Taille : $size octets | MD5 : $hash" -ForegroundColor Gray

    # Validation taille
    if (-not $SkipValidate -and $size -gt $cfg.AppMaxSize) {
        Write-Host "  Erreur : taille firmware ($size) > partition app ($($cfg.AppMaxSize))" -ForegroundColor Red
        exit 1
    }

    $artifacts += @{
        TargetName   = $targetName
        Version      = $version
        Size         = $size
        Md5          = $hash
        MetadataPath = $cfg.MetadataPath
        MetadataKey  = $cfg.MetadataKey
        OtaUrl       = $cfg.OtaUrl
    }
}

if ($artifacts.Count -eq 0) {
    Write-Host ""
    Write-Host "Erreur : aucun binaire publie. Compilez les cibles ou verifiez -Targets." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Mise a jour des metadata.json
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Mise a jour metadata ===" -ForegroundColor Cyan

# Regrouper les artifacts par fichier metadata (les 3 cam partagent le meme)
$metaGroups = @{}
foreach ($a in $artifacts) {
    $path = $a.MetadataPath
    if (-not $metaGroups.ContainsKey($path)) {
        $metaGroups[$path] = @()
    }
    $metaGroups[$path] += $a
}

foreach ($metaPath in $metaGroups.Keys) {
    $group = $metaGroups[$metaPath]
    $firstArtifact = $group[0]

    if ($firstArtifact.MetadataKey) {
        # Format cam : JSON multi-cible
        $meta = $null
        if (Test-Path $metaPath) {
            try {
                $meta = Get-Content -Path $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            } catch {
                $meta = [PSCustomObject]@{}
            }
        } else {
            $meta = [PSCustomObject]@{}
        }

        foreach ($a in $group) {
            $entry = [PSCustomObject]@{
                version = $a.Version
                url     = $a.OtaUrl
                md5     = $a.Md5
            }
            $key = $a.MetadataKey
            if ($meta.PSObject.Properties[$key]) {
                $meta.$key = $entry
            } else {
                $meta | Add-Member -NotePropertyName $key -NotePropertyValue $entry -Force
            }
        }

        $json = $meta | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText((Join-Path $PWD $metaPath), $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  Mis a jour : $metaPath (format multi-cible)" -ForegroundColor Green
    }
    else {
        # Format simple
        foreach ($a in $group) {
            $meta = [PSCustomObject]@{
                version = $a.Version
                url     = $a.OtaUrl
                md5     = $a.Md5
            }
            $json = $meta | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText((Join-Path $PWD $a.MetadataPath), $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  Mis a jour : $($a.MetadataPath) (v$($a.Version))" -ForegroundColor Green
        }
    }
}

# -----------------------------------------------------------------------------
# Resume
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host ("-" * 70)
Write-Host ("{0,-12} {1,-8} {2,10} {3}" -f "Cible", "Version", "Taille", "Destination")
Write-Host ("-" * 70)
foreach ($a in $artifacts) {
    $dest = ($TargetConfig[$a.TargetName]).OtaDest
    Write-Host ("{0,-12} {1,-8} {2,10} {3}" -f $a.TargetName, $a.Version, "$($a.Size) o", $dest) -ForegroundColor White
}
Write-Host ("-" * 70)

# -----------------------------------------------------------------------------
# Git commit + push dans serveur (sous-module)
# -----------------------------------------------------------------------------
if ($SkipCommit -or $DryRun) {
    if ($DryRun) {
        Write-Host ""
        Write-Host "Dry run - fichiers modifies dans serveur/ota/ :" -ForegroundColor Gray
        Push-Location serveur
        git status --short ota/
        Pop-Location
    }
    Write-Host ""
    Write-Host "Termine (pas de commit)." -ForegroundColor Cyan
    exit 0
}

Write-Host ""
Write-Host "=== Commit serveur ===" -ForegroundColor Cyan
Push-Location serveur
try {
    git add ota/
    $status = git status --porcelain ota/
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "Aucun changement dans serveur/ota/, rien a committer." -ForegroundColor Gray
    } else {
        $versionList = ($artifacts | ForEach-Object { "$($_.TargetName)=$($_.Version)" }) -join ", "
        $commitMsg = "ota: publish $versionList"
        git commit -m $commitMsg
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : git commit serveur a echoue." -ForegroundColor Red
            exit 1
        }
        git push
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : git push serveur a echoue." -ForegroundColor Red
            exit 1
        }
        Write-Host "Commit et push serveur reussis." -ForegroundColor Green
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Rappel : le depot parent IOT_n3 pointe vers une nouvelle ref du sous-module serveur." -ForegroundColor Yellow
Write-Host "Pour versionner : git add serveur ; git commit -m 'update serveur ref (OTA)'" -ForegroundColor Gray
Write-Host ""
Write-Host "Publication OTA terminee." -ForegroundColor Cyan
