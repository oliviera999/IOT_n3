<#
.SYNOPSIS
    Script de recherche de bugs — lance tests, vérifications de sécurité et optionnellement build firmwares / pages distantes.

.DESCRIPTION
    À exécuter depuis la racine IOT_n3. Effectue :
    - Vérifications de sécurité (secrets potentiels, fichiers sensibles versionnés)
    - Tests PHPUnit du serveur
    - Optionnel : vérification des pages distantes (check-server-pages.ps1)
    - Optionnel : compilation des firmwares principaux (détection d'erreurs de build)

.PARAMETER ServerTests
    Lance les tests PHPUnit du serveur (défaut : vrai).

.PARAMETER Security
    Lance les vérifications de sécurité (secrets dans le code, .gitignore) (défaut : vrai).

.PARAMETER Pages
    Lance la vérification des pages distantes (check-server-pages.ps1). Nécessite accès réseau.

.PARAMETER Firmwares
    Compile les firmwares listés (n3pp4_2, msp2_5, ffp5cs) pour détecter les erreurs de build. Plus long.

.PARAMETER ReportDir
    Dossier des rapports (pour -Pages). Défaut : scripts/reports.

.EXAMPLE
    .\scripts\find-bugs.ps1

.EXAMPLE
    .\scripts\find-bugs.ps1 -Pages -Firmwares
#>

[CmdletBinding()]
param(
    [switch]$ServerTests = $true,
    [switch]$Security = $true,
    [switch]$Pages,
    [switch]$Firmwares,
    [string]$ReportDir = 'scripts/reports'
)

$ErrorActionPreference = 'Continue'

$root = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    (Get-Location).Path
}

$issues = [System.Collections.ArrayList]::new()
$warnings = [System.Collections.ArrayList]::new()
$okItems = [System.Collections.ArrayList]::new()

function Add-Issue { param([string]$Msg) [void]$issues.Add($Msg) }
function Add-Warning { param([string]$Msg) [void]$warnings.Add($Msg) }
function Add-Ok { param([string]$Msg) [void]$okItems.Add($Msg) }

Write-Host ''
Write-Host '=== Recherche de bugs - IOT_n3 ===' -ForegroundColor Cyan
Write-Host ('Racine : ' + $root) -ForegroundColor Gray
Write-Host ''

# --- 1. Vérifications de sécurité
if ($Security) {
    Write-Host '[1/4] Securite (secrets, .gitignore)...' -ForegroundColor Yellow

    # Fichiers sensibles ne doivent pas être versionnés (vérifier dans dépôt racine et submodule firmwires)
    $trackedSensitive = @()
    foreach ($repo in @($root, (Join-Path $root 'firmwires'))) {
        if (-not (Test-Path (Join-Path $repo '.git'))) { continue }
        $listed = git -C $repo ls-files 2>$null
        foreach ($line in ($listed -split "`n")) {
            $line = ($line -replace "`r", '').Trim()
            if (-not $line) { continue }
            $name = $line -replace '.*[/\\]', ''
            if ($name -in @('credentials.h', 'secrets.h', 'config_private.h') -or $line -match '\.env$') {
                $rel = if ($repo -eq $root) { $line } else { 'firmwires/' + ($line -replace '\\', '/') }
                $trackedSensitive += $rel
            }
        }
    }
    if ($trackedSensitive.Count -gt 0) {
        Add-Issue ("Fichiers sensibles versionnes (a retirer du depot) : " + ($trackedSensitive -join ', '))
    } else {
        Add-Ok 'Aucun fichier sensible (credentials.h, .env, etc.) non versionne'
    }

    # Recherche de secrets en dur dans le code source (hors vendor / managed_components)
    $searchDirs = @(
        (Join-Path $root 'firmwires\n3pp4_2'),
        (Join-Path $root 'firmwires\msp2_5'),
        (Join-Path $root 'firmwires\ffp5cs\src'),
        (Join-Path $root 'firmwires\ffp5cs\include'),
        (Join-Path $root 'firmwires\archive\uploadphotosserver_msp1'),
        (Join-Path $root 'firmwires\archive\uploadphotosserver_n3pp_1_6_deppsleep'),
        (Join-Path $root 'firmwires\archive\uploadphotosserver_ffp3_1_5_deppsleep')
    )
    $suspicious = @()
    foreach ($dir in $searchDirs) {
        if (-not (Test-Path $dir)) { continue }
        $files = Get-ChildItem -Path $dir -Include '*.cpp','*.h','*.ino' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'managed_components|vendor' }
        foreach ($f in $files) {
            $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            # Éviter les faux positifs : credentials.h est justement le bon endroit
            if ($f.Name -eq 'credentials.h' -or $f.Name -eq 'credentials.h.example') { continue }
            # Motifs regex (concatenation pour eviter parsing des accolades en PowerShell)
            $b = [char]123 + '4,' + [char]125   # {4,}
            $b8 = [char]123 + '8,' + [char]125 # {8,}
            $patWifi = 'WIFI_PASSWORD\s*=\s*".' + $b + '"'
            $patApi = 'API_KEY\s*=\s*".' + $b8 + '"'
            $patCred = '#include\s*credentials'
            if ($content -match $patWifi -and $content -notmatch $patCred) {
                $suspicious += ($f.FullName.Replace($root, '') + ' : possible mot de passe WiFi en dur')
            }
            if ($content -match $patApi -and $content -notmatch $patCred) {
                $suspicious += ($f.FullName.Replace($root, '') + ' : possible cle API en dur')
            }
        }
    }
    if ($suspicious.Count -gt 0) {
        foreach ($s in $suspicious) { Add-Warning $s }
    } else {
        Add-Ok 'Aucun secret evident en dur dans les sources (hors credentials.h)'
    }

    Write-Host '  Securite : termine' -ForegroundColor Gray
    Write-Host ''
}

# --- 2. Tests PHPUnit serveur
if ($ServerTests) {
    Write-Host '[2/4] Tests PHPUnit (serveur)...' -ForegroundColor Yellow
    $serveurPath = Join-Path $root 'serveur'
    if (-not (Test-Path (Join-Path $serveurPath 'vendor'))) {
        Add-Warning 'serveur/vendor absent - executer : cd serveur ; composer install'
        Write-Host '  Composer install requis' -ForegroundColor Yellow
    } else {
        Push-Location $serveurPath
        try {
            $out = & php tools/run-phpunit.php 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                Add-Ok "PHPUnit : tous les tests passent"
                Write-Host '  OK' -ForegroundColor Green
            } else {
                Add-Issue "PHPUnit : des tests ont echoue (exit $exit)"
                Write-Host $out -ForegroundColor Red
                Write-Host '  ECHEC' -ForegroundColor Red
            }
        } finally {
            Pop-Location
        }
    }
    Write-Host ''
}

# --- 3. Vérification des pages distantes
if ($Pages) {
    Write-Host '[3/4] Verification des pages distantes...' -ForegroundColor Yellow
    $checkScript = Join-Path $root 'scripts\check-server-pages.ps1'
    if (Test-Path $checkScript) {
        & $checkScript -ReportDir $ReportDir
        Add-Ok "Rapport pages généré dans $ReportDir"
    } else {
        Add-Warning "Script check-server-pages.ps1 introuvable"
    }
    Write-Host ''
} else {
    Write-Host '[3/4] Pages distantes : ignore (utilisez -Pages pour lancer)' -ForegroundColor Gray
    Write-Host ''
}

# --- 4. Build firmwares
if ($Firmwares) {
    Write-Host '[4/4] Compilation des firmwares...' -ForegroundColor Yellow
    $firmwiresRoot = Join-Path $root 'firmwires'
    $envs = @(
        @{ Project = 'n3pp4_2'; Env = 'esp32dev' }
        @{ Project = 'msp2_5'; Env = 'esp32dev' }
        @{ Project = 'ffp5cs'; Env = 'wroom-test' }
    )
    foreach ($e in $envs) {
        $projDir = Join-Path $firmwiresRoot $e.Project
        if (-not (Test-Path $projDir)) {
            Add-Warning "Firmware $($e.Project) non trouve - ignore"
            continue
        }
        Push-Location $projDir
        try {
            $buildOut = & pio run -e $e.Env 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-Ok "Build $($e.Project) ($($e.Env)) : OK"
                Write-Host "  $($e.Project) : OK" -ForegroundColor Green
            } else {
                Add-Issue "Build $($e.Project) ($($e.Env)) : echec"
                Write-Host $buildOut -ForegroundColor Red
                Write-Host "  $($e.Project) : ECHEC" -ForegroundColor Red
            }
        } catch {
            Add-Issue "Build $($e.Project) : exception - $($_.Exception.Message)"
            Write-Host "  $($e.Project) : erreur" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    }
    Write-Host ''
} else {
    Write-Host '[4/4] Build firmwares : ignore (utilisez -Firmwares pour lancer)' -ForegroundColor Gray
    Write-Host ''
}

# --- Résumé final
Write-Host '=== Resume ===' -ForegroundColor Cyan
foreach ($o in $okItems) {
    Write-Host ('  [OK] ' + $o) -ForegroundColor Green
}
foreach ($w in $warnings) {
    Write-Host ('  [!!] ' + $w) -ForegroundColor Yellow
}
foreach ($i in $issues) {
    Write-Host ('  [XX] ' + $i) -ForegroundColor Red
}

$hasErrors = $issues.Count -gt 0
$hasWarnings = $warnings.Count -gt 0
Write-Host ''
if ($hasErrors) {
    Write-Host 'Resultat : des problemes ont ete detectes.' -ForegroundColor Red
    exit 1
}
if ($hasWarnings) {
    $msgWarn = 'Resultat : OK avec avertissements.'
    Write-Host $msgWarn -ForegroundColor Yellow
    exit 0
}
$msgOk = 'Resultat : tout est OK.'
Write-Host $msgOk -ForegroundColor Green
exit 0
