# =============================================================================
# Liste des firmwares n3 IoT (depuis firmwires/firmwares.manifest.json)
# =============================================================================
# Affiche le registre des firmwares avec chemin, carte, lien serveur et
# version extraite du code si possible. Executer depuis la racine IOT_n3.
#
# Usage :
#   .\scripts\firmwires-list.ps1
#   .\scripts\firmwires-list.ps1 -WithVersion
#   .\scripts\firmwires-list.ps1 -Json
# =============================================================================

param(
    [switch]$WithVersion,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
$manifestPath = Join-Path $root "firmwires\firmwares.manifest.json"
$firmwiresRoot = Join-Path $root "firmwires"

# Initialiser le submodule firmwires si besoin (n3_firmwires)
if (-not (Test-Path $manifestPath) -and (Test-Path (Join-Path $root ".gitmodules"))) {
    $gm = Get-Content (Join-Path $root ".gitmodules") -Raw
    if ($gm -match 'submodule "firmwires"') {
        Write-Host "Initialisation du submodule firmwires (n3_firmwires)..." -ForegroundColor Gray
        Set-Location $root
        git submodule update --init firmwires
        Set-Location $scriptDir
    }
}
if (-not (Test-Path $manifestPath)) {
    Write-Host "Erreur : $manifestPath introuvable. Executer depuis la racine IOT_n3. Si firmwires est un submodule : git submodule update --init firmwires" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-VersionFromFile {
    param([string]$dir, [object]$versionSource)
    if (-not $versionSource) { return $null }
    $fullPath = Join-Path $firmwiresRoot (Join-Path $dir $versionSource.file)
    if (-not (Test-Path $fullPath)) {
        if ($versionSource.or) {
            $alt = Join-Path $firmwiresRoot (Join-Path $dir $versionSource.or)
            if (Test-Path $alt) {
                $c = Get-Content -Path $alt -Raw
                if ($c -match '(\d+\.\d+(\.\d+)?)') { return $Matches[1] }
            }
        }
        return $null
    }
    $content = Get-Content -Path $fullPath -Raw
    if ($versionSource.pattern -and $content -match $versionSource.pattern) {
        return $Matches[1]
    }
    if ($versionSource.define -and $content -match "$($versionSource.define)\s+`"([^`"]+)`"") {
        return $Matches[1]
    }
    return $null
}

$rows = @()
foreach ($fw in $manifest.firmwares) {
    $dir = Join-Path $firmwiresRoot $fw.path
    $exists = Test-Path $dir
    $version = $null
    if ($WithVersion -and $exists -and $fw.versionSource) {
        if ($fw.pioEnvs -and $fw.pioEnvs[0].versionDefine) {
            $first = $fw.pioEnvs[0]
            $vs = @{ file = $fw.versionSource.file; define = $first.versionDefine }
            $content = Get-Content -Path (Join-Path $dir $fw.versionSource.file) -Raw -ErrorAction SilentlyContinue
            if ($content -match "(?s)defined\($($first.versionDefine)\).*?FIRMWARE_VERSION\s+`"([^`"]+)`"") {
                $version = $Matches[1]
            }
        } else {
            $version = Get-VersionFromFile -dir $fw.path -versionSource $fw.versionSource
        }
    }
    $serveur = $fw.serveurFolder
    if (-not $serveur) { $serveur = "-" }
    $ota = if ($fw.otaTarget) { $fw.otaTarget } else { "-" }
    $sub = if ($fw.submodule) { "oui" } else { "-" }
    $rows += [PSCustomObject]@{
        Id       = $fw.id
        Path     = $fw.path
        Board    = $fw.board
        Serveur  = $serveur
        OtaCible = $ota
        Submodule = $sub
        Version  = $version
        Existe   = $exists
    }
}

if ($Json) {
    $rows | ConvertTo-Json -Depth 2
    exit 0
}

# Affichage tableau
$colId = 24
$colPath = 38
$colBoard = 14
$colServeur = 18
$colOta = 10
$colSub = 6
$colVer = 8
$fmt = "  {0,-$colId} {1,-$colPath} {2,-$colBoard} {3,-$colServeur} {4,-$colOta} {5,-$colSub} {6,-$colVer}"
Write-Host ""
Write-Host "Firmwares n3 IoT (source: firmwires/firmwares.manifest.json)" -ForegroundColor Cyan
Write-Host ("-" * 120)
Write-Host ($fmt -f "Id", "Path", "Board", "Serveur", "OTA", "Sub", "Version")
Write-Host ("-" * 120)
foreach ($r in $rows) {
    $ver = if ($r.Version) { $r.Version } else { "-" }
    if (-not $r.Existe) { $ver = "(absent)" }
    Write-Host ($fmt -f $r.Id, $r.Path, $r.Board, $r.Serveur, $r.OtaCible, $r.Submodule, $ver)
}
Write-Host ("-" * 120)
Write-Host ""
