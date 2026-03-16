# =============================================================================
# Script de publication OTA distant - Projet n3 IoT
# =============================================================================
# Compile (optionnel), copie les firmware.bin vers serveur/ota/, met a jour les
# metadata.json, puis commit + push dans le depot serveur (sous-module).
#
# Securite Phase 1 :
#   - URLs HTTPS
#   - Hash SHA-256 (remplace MD5)
#   - Signature ECDSA P-256 du binaire (optionnel, active via -SignKey)
#   - Champ min_version pour protection anti-downgrade
#   - Log d'audit dans scripts/ota-audit.jsonl
#
# Cibles supportees :
#   n3pp      -> serveur/ota/n3pp/        (firmware serre, ESP32 prod)
#   n3pp-test -> serveur/ota/n3pp-test/   (firmware serre test, env esp32dev_test)
#   msp       -> serveur/ota/msp/         (firmware meteo, ESP32 prod)
#   msp-test  -> serveur/ota/msp-test/    (firmware meteo test, env esp32dev_test)
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
#   .\scripts\publish_ota.ps1 -Build -SignKey scripts\ota_keys\ota_signing_key.pem
#   .\scripts\publish_ota.ps1 -DryRun
# =============================================================================

param(
    [string[]]$Targets = @("n3pp", "n3pp-test", "msp", "msp-test", "cam-msp1", "cam-n3pp", "cam-ffp3"),
    [switch]$Build,
    [switch]$SkipCommit,
    [switch]$DryRun,
    [switch]$SkipValidate,
    [switch]$NoSign,         # Ne pas signer (ignore la cle par defaut)
    [string]$SignKey = ""    # Chemin vers la cle privee ECDSA PEM (defaut : scripts\ota_keys\ota_signing_key.pem)
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
        OtaUrl       = "https://iot.olution.info/ota/n3pp/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "n3pp-test" = @{
        ProjectDir   = "firmwires\n3pp4_2"
        PioEnv       = "esp32dev_test"
        OtaDest      = "serveur\ota\n3pp-test"
        MetadataPath = "serveur\ota\n3pp-test\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/n3pp-test/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "msp" = @{
        ProjectDir   = "firmwires\msp2_5"
        PioEnv       = "esp32dev"
        OtaDest      = "serveur\ota\msp"
        MetadataPath = "serveur\ota\msp\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/msp/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "msp-test" = @{
        ProjectDir   = "firmwires\msp2_5"
        PioEnv       = "esp32dev_test"
        OtaDest      = "serveur\ota\msp-test"
        MetadataPath = "serveur\ota\msp-test\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/msp-test/firmware.bin"
        MetadataKey  = $null
        AppMaxSize   = 1966080
    }
    "cam-msp1" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "msp1"
        OtaDest      = "serveur\ota\cam\msp1"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/cam/msp1/firmware.bin"
        MetadataKey  = "msp1"
        AppMaxSize   = 1966080
    }
    "cam-n3pp" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "n3pp"
        OtaDest      = "serveur\ota\cam\n3pp"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/cam/n3pp/firmware.bin"
        MetadataKey  = "n3pp"
        AppMaxSize   = 1966080
    }
    "cam-ffp3" = @{
        ProjectDir   = "firmwires\uploadphotosserver"
        PioEnv       = "ffp3"
        OtaDest      = "serveur\ota\cam\ffp3"
        MetadataPath = "serveur\ota\cam\metadata.json"
        OtaUrl       = "https://iot.olution.info/ota/cam/ffp3/firmware.bin"
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

# Verification de la cle de signature
# Chemin par defaut partage par tous les firmwares cible (n3_ota_pubkey.h)
$defaultSignKey = Join-Path $root "scripts\ota_keys\ota_signing_key.pem"
if ($SignKey -eq "") {
    $SignKey = $defaultSignKey
}

$signingEnabled = $false
if ($NoSign) {
    Write-Host "Info : publication sans signature ECDSA (-NoSign)." -ForegroundColor Gray
} elseif ($SignKey -ne "" -and (Test-Path $SignKey)) {
    $signingEnabled = $true
    Write-Host "Signature ECDSA activee : $SignKey" -ForegroundColor Green
} elseif ($SignKey -ne "") {
    # Cle demandee mais absente : generation auto si chemin par defaut (premiere utilisation)
    $isDefaultPath = ($SignKey -eq $defaultSignKey -or $SignKey -like "*ota_keys\ota_signing_key.pem")
    if ($isDefaultPath) {
        Write-Host "Cle de signature absente — generation via generate_ota_keys.ps1 (premiere utilisation)..." -ForegroundColor Yellow
        & (Join-Path $scriptDir "generate_ota_keys.ps1") -OutDir "scripts\ota_keys"
        if (Test-Path $SignKey) {
            $signingEnabled = $true
            Write-Host "  Cles generees. Signature ECDSA activee." -ForegroundColor Green
        } else {
            Write-Host "Erreur : generation des cles a echoue." -ForegroundColor Red
            exit 1
        }
        if ($Build) {
            Write-Host "  Utilisez -Build pour recompiler les firmwares avec la nouvelle cle publique." -ForegroundColor Cyan
        }
    } else {
        Write-Host "Avertissement : cle de signature introuvable ($SignKey) — publication sans signature ECDSA." -ForegroundColor Yellow
    }
}
if (-not $signingEnabled -and $SignKey -eq $defaultSignKey) {
    Write-Host "Info : publication sans signature ECDSA (cle absente, utiliser -SignKey pour forcer la generation)." -ForegroundColor Gray
} elseif (-not $signingEnabled) {
    Write-Host "Info : publication sans signature ECDSA." -ForegroundColor Gray
}

# -----------------------------------------------------------------------------
# Extraction de version depuis le code source
# -----------------------------------------------------------------------------
function Get-FirmwareVersion {
    param([string]$TargetName, [hashtable]$Config)

    $projectDir = $Config.ProjectDir

    # n3pp / msp / n3pp-test / msp-test : version dans main.cpp (meme source, env different pour *-test)
    if ($TargetName -eq "n3pp" -or $TargetName -eq "msp" -or $TargetName -eq "n3pp-test" -or $TargetName -eq "msp-test") {
        $mainCpp = Join-Path $projectDir "src\main.cpp"
        if (-not (Test-Path $mainCpp)) {
            Write-Host "  Erreur : $mainCpp introuvable" -ForegroundColor Red
            return $null
        }
        $content = Get-Content -Path $mainCpp -Raw
        if ($content -match 'String\s+version\s*=\s*"([^"]+)"') {
            return $Matches[1]
        }
        # Fallback : FIRMWARE_VERSION dans le config header
        $configH = Join-Path $projectDir "include\n3pp_config.h"
        if (-not (Test-Path $configH)) {
            $configH = Join-Path $projectDir "include\msp_config.h"
        }
        if (Test-Path $configH) {
            $configContent = Get-Content -Path $configH -Raw
            if ($configContent -match 'FIRMWARE_VERSION\s+"([^"]+)"') {
                return $Matches[1]
            }
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
        # Version commune a toutes les cibles cam
        if ($content -match 'FIRMWARE_VERSION\s+"([^"]+)"') {
            return $Matches[1]
        }
        Write-Host "  Erreur : impossible d extraire FIRMWARE_VERSION dans $configH" -ForegroundColor Red
        return $null
    }

    return $null
}

# -----------------------------------------------------------------------------
# Signature ECDSA P-256 du binaire
# -----------------------------------------------------------------------------
function Invoke-OtaSign {
    param(
        [string]$BinaryPath,
        [string]$PrivateKeyPath
    )

    if (-not $PrivateKeyPath -or -not (Test-Path $PrivateKeyPath)) {
        return $null
    }

    # Tentative via openssl (prefere : compatible avec mbedTLS DER sur ESP32)
    $opensslCmd = Get-Command "openssl" -ErrorAction SilentlyContinue
    if ($opensslCmd) {
        $tempSig = [System.IO.Path]::GetTempFileName()
        try {
            & openssl dgst -sha256 -sign $PrivateKeyPath -outform DER -out $tempSig $BinaryPath 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempSig)) {
                $sigBytes = [System.IO.File]::ReadAllBytes($tempSig)
                if ($sigBytes.Length -gt 0) {
                    return [Convert]::ToBase64String($sigBytes)
                }
            }
        } finally {
            Remove-Item $tempSig -ErrorAction SilentlyContinue
        }
        Write-Host "  Avertissement : openssl dgst a echoue, tentative .NET..." -ForegroundColor Yellow
    }

    # Fallback : .NET ECDsa (requiert .NET 6+ pour ImportFromPem + DSASignatureFormat)
    try {
        $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        $ecdsa.ImportFromPem((Get-Content $PrivateKeyPath -Raw))
        $firmwareBytes = [System.IO.File]::ReadAllBytes($BinaryPath)
        $sigBytes = $ecdsa.SignData(
            $firmwareBytes,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.DSASignatureFormat]::Rfc3279DerSequence
        )
        $ecdsa.Dispose()
        return [Convert]::ToBase64String($sigBytes)
    } catch {
        Write-Host "  Avertissement : signature .NET echouee : $_" -ForegroundColor Yellow
        return $null
    }
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
# Publication : copie des binaires + calcul SHA-256 + signature ECDSA
# -----------------------------------------------------------------------------
Write-Host "=== Publication OTA (HTTPS + SHA-256) ===" -ForegroundColor Cyan

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

    # Validation taille
    if (-not $SkipValidate -and $size -gt $cfg.AppMaxSize) {
        Write-Host "  Erreur : taille firmware ($size) > partition app ($($cfg.AppMaxSize))" -ForegroundColor Red
        exit 1
    }

    # Calcul SHA-256 (remplace MD5)
    $sha256 = (Get-FileHash -Path $destBin -Algorithm SHA256).Hash.ToLowerInvariant()

    Write-Host "  Copie  : $srcBin -> $destBin" -ForegroundColor Green
    Write-Host "  Taille : $size octets" -ForegroundColor Gray
    Write-Host "  SHA-256: $sha256" -ForegroundColor Gray

    # Signature ECDSA P-256 (optionnelle)
    $signature = $null
    if ($signingEnabled) {
        $signature = Invoke-OtaSign -BinaryPath $destBin -PrivateKeyPath $SignKey
        if ($signature) {
            Write-Host "  Signature ECDSA : OK ($(($signature.Length)) chars base64)" -ForegroundColor Green
        } else {
            Write-Host "  Avertissement : signature ECDSA echouee, publication sans signature." -ForegroundColor Yellow
        }
    }

    $artifacts += @{
        TargetName   = $targetName
        Version      = $version
        Size         = $size
        Sha256       = $sha256
        Signature    = $signature
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
Write-Host "=== Mise a jour metadata (HTTPS + SHA-256 + min_version) ===" -ForegroundColor Cyan

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
                version     = $a.Version
                min_version = $a.Version
                url         = $a.OtaUrl
                sha256      = $a.Sha256
            }
            if ($a.Signature) {
                $entry | Add-Member -NotePropertyName "signature" -NotePropertyValue $a.Signature -Force
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
        # Format simple (n3pp, msp)
        foreach ($a in $group) {
            $meta = [PSCustomObject]@{
                version     = $a.Version
                min_version = $a.Version
                url         = $a.OtaUrl
                sha256      = $a.Sha256
            }
            if ($a.Signature) {
                $meta | Add-Member -NotePropertyName "signature" -NotePropertyValue $a.Signature -Force
            }
            $json = $meta | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText((Join-Path $PWD $a.MetadataPath), $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  Mis a jour : $($a.MetadataPath) (v$($a.Version))" -ForegroundColor Green
        }
    }
}

# -----------------------------------------------------------------------------
# Log d'audit
# -----------------------------------------------------------------------------
$auditLog = "scripts\ota-audit.jsonl"
foreach ($a in $artifacts) {
    $auditEntry = [PSCustomObject]@{
        timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        target      = $a.TargetName
        version     = $a.Version
        sha256      = $a.Sha256
        signed      = ($null -ne $a.Signature)
        dry_run     = $DryRun.IsPresent
        deployer    = $env:USERNAME
    } | ConvertTo-Json -Compress
    Add-Content -Path $auditLog -Value $auditEntry -Encoding UTF8
}
Write-Host ""
Write-Host "  Log d audit : $auditLog" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# Resume
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host ("-" * 80)
Write-Host ("{0,-12} {1,-8} {2,10} {3,-8} {4}" -f "Cible", "Version", "Taille", "Signe", "SHA-256")
Write-Host ("-" * 80)
foreach ($a in $artifacts) {
    $signed = if ($a.Signature) { "oui" } else { "non" }
    $sha256Short = $a.Sha256.Substring(0, 16) + "..."
    Write-Host ("{0,-12} {1,-8} {2,10} {3,-8} {4}" -f `
        $a.TargetName, $a.Version, "$($a.Size) o", $signed, $sha256Short) -ForegroundColor White
}
Write-Host ("-" * 80)

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
$serveurCommitted = $false
$versionList = ($artifacts | ForEach-Object { "$($_.TargetName)=$($_.Version)" }) -join ", "
Push-Location serveur
try {
    git add ota/
    $status = git status --porcelain ota/
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "Aucun changement dans serveur/ota/, rien a committer." -ForegroundColor Gray
    } else {
        $signedTargets = ($artifacts | Where-Object { $_.Signature } | ForEach-Object { $_.TargetName }) -join ","
        $commitMsg = "ota: publish $versionList [sha256]"
        if ($signedTargets) { $commitMsg += " [signed:$signedTargets]" }
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
        $serveurCommitted = $true
    }
} finally {
    Pop-Location
}

# Commit du depot parent : enregistrer la nouvelle ref du sous-module serveur
if ($serveurCommitted) {
    Write-Host ""
    Write-Host "=== Commit depot parent (ref serveur) ===" -ForegroundColor Cyan
    git add serveur
    $parentStatus = git status --porcelain serveur
    if (-not [string]::IsNullOrWhiteSpace($parentStatus)) {
        git commit -m "ota: update ref serveur (publish $versionList)"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur : git commit depot parent a echoue." -ForegroundColor Red
            exit 1
        }
        Write-Host "Commit depot parent reussi (ref serveur mise a jour)." -ForegroundColor Green
    } else {
        Write-Host "Aucun changement de ref serveur, rien a committer dans le depot parent." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Publication OTA terminee." -ForegroundColor Cyan
