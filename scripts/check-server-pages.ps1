<#
.SYNOPSIS
    Verifie les pages en ligne sur le serveur distant et genere un rapport (URLs + analyse error_log et cronlog).

.DESCRIPTION
    En local : appelle le serveur iot.olution.info pour chaque URL definie, recupere les logs (cronlog.txt, error_log)
    via HTTP, les analyse et produit un rapport Markdown (et optionnellement JSON).
    A executer depuis la racine IOT_n3.

.PARAMETER BaseUrl
    URL de base du serveur (defaut : https://iot.olution.info).

.PARAMETER ReportDir
    Dossier de sortie des rapports (defaut : scripts/reports, relatif a la racine du depot).

.PARAMETER LogLines
    Nombre de lignes d'erreur a inclure dans le rapport (defaut : 20).

.PARAMETER ExportJson
    Si specifie, genere aussi un fichier JSON avec les memes donnees.

.EXAMPLE
    .\scripts\check-server-pages.ps1

.EXAMPLE
    .\scripts\check-server-pages.ps1 -ReportDir docs/rapports-serveur -LogLines 30 -ExportJson
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://iot.olution.info',
    [string]$ReportDir = 'scripts/reports',
    [int]$LogLines = 20,
    [switch]$ExportJson
)

$ErrorActionPreference = 'Stop'

# Racine du depot (parent du dossier scripts)
$root = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    (Get-Location).Path
}

$reportDirAbs = Join-Path $root $ReportDir
if (-not (Test-Path $reportDirAbs)) {
    New-Item -ItemType Directory -Path $reportDirAbs -Force | Out-Null
}

# Liste des URLs a verifier (chemins relatifs a BaseUrl)
$urlsToCheck = @(
    # FFP3 pages
    '/ffp3/',
    '/ffp3/dashboard',
    '/ffp3/aquaponie',
    '/ffp3/control',
    '/ffp3/tide-stats',
    '/ffp3/dashboard-test',
    '/ffp3/aquaponie-test',
    '/ffp3/control-test',
    # FFP3 API
    '/ffp3/api/outputs/state',
    '/ffp3/api/realtime/sensors/latest',
    '/ffp3/api/realtime/system/health',
    # MSP1 / N3PP pages
    '/msp1/msp1datas/msp1-data.php',
    '/n3pp/n3ppdatas/n3pp-data.php',
    # Galeries
    '/gallery/msp1',
    '/gallery/n3pp',
    '/gallery/ffp3',
    # Ressource
    '/ffp3/assets/css/main.css'
)

$baseUrlTrim = $BaseUrl.TrimEnd('/')
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
$reportPath = Join-Path $reportDirAbs "check-pages-$timestamp.md"
$jsonPath = if ($ExportJson) { Join-Path $reportDirAbs "check-pages-$timestamp.json" } else { $null }

Write-Host "Verification des pages et logs - $BaseUrl" -ForegroundColor Cyan
Write-Host "Rapport : $reportPath" -ForegroundColor Gray
Write-Host ""

# --- 1. Test des URLs
$results = [System.Collections.ArrayList]::new()
$okCount = 0
$warnCount = 0
$errCount = 0

foreach ($path in $urlsToCheck) {
    $url = $baseUrlTrim + $path
    Write-Host "  GET $path ... " -NoNewline
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
        $code = $resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        } else {
            $code = 0
        }
    }
    $sw.Stop()
    $ms = $sw.ElapsedMilliseconds

    $status = 'OK'
    if ($code -ge 200 -and $code -lt 300) {
        $okCount++
        $status = 'OK'
    } elseif ($code -eq 301 -or $code -eq 302) {
        $warnCount++
        $status = 'Redirect'
    } elseif ($code -ge 400) {
        $errCount++
        $status = 'Erreur'
    } else {
        $warnCount++
        $status = 'Avertissement'
    }

    $row = [PSCustomObject]@{
        Url      = $url
        Path     = $path
        Method   = 'GET'
        HttpCode = $code
        Ms       = $ms
        Status   = $status
    }
    [void]$results.Add($row)

    $color = switch ($status) {
        'OK'           { 'Green' }
        'Redirect'     { 'Yellow' }
        'Erreur'       { 'Red' }
        default        { 'Yellow' }
    }
    Write-Host "$code ${ms}ms " -NoNewline -ForegroundColor $color
    Write-Host $status -ForegroundColor $color
}

# --- 2. Recuperation et analyse des logs
Write-Host ""
Write-Host "Recuperation des logs..." -ForegroundColor Cyan

$logCronUrl = $baseUrlTrim + '/public/cronlog.txt'
$logErrorUrl = $baseUrlTrim + '/public/error_log'

$cronContent = $null
$cronStatus = $null
$errorContent = $null
$errorStatus = $null

try {
    $r = Invoke-WebRequest -Uri $logCronUrl -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $cronStatus = $r.StatusCode
    $cronContent = $r.Content
} catch {
    $cronStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
}

try {
    $r = Invoke-WebRequest -Uri $logErrorUrl -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $errorStatus = $r.StatusCode
    $errorContent = $r.Content
} catch {
    $errorStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
}

# Analyse error_log
$errorLogSummary = @{
    Available = ($errorStatus -eq 200)
    StatusCode = $errorStatus
    CountN3500 = 0
    CountFatal = 0
    Count404 = 0
    LastLines = @()
}
if ($errorContent) {
    $lines = $errorContent -split "`n"
    $errorLogSummary.CountN3500 = ($lines | Select-String -Pattern '\[n3 500\]' -AllMatches).Count
    $errorLogSummary.CountFatal = ($lines | Select-String -Pattern 'PHP Fatal|Fatal error' -AllMatches).Count
    $errorLogSummary.Count404 = ($lines | Select-String -Pattern 'FFP3 404|n3-iot 404' -AllMatches).Count
    $errorLines = $lines | Where-Object { $_ -match '\[n3 500\]|PHP Fatal|Fatal error|FFP3 404|n3-iot 404' }
    $errorLogSummary.LastLines = @($errorLines | Select-Object -Last $LogLines)
}

# Analyse cronlog
$cronLogSummary = @{
    Available = ($cronStatus -eq 200)
    StatusCode = $cronStatus
    CountError = 0
    CountException = 0
    CountInsert = 0
    LastLines = @()
}
if ($cronContent) {
    $lines = $cronContent -split "`n"
    $cronLogSummary.CountError = ($lines | Select-String -Pattern '\[ERROR\]' -AllMatches).Count
    $cronLogSummary.CountException = ($lines | Select-String -Pattern 'Exception non gérée|Exception non geree' -AllMatches).Count
    $cronLogSummary.CountInsert = ($lines | Select-String -Pattern 'Erreur insertion' -AllMatches).Count
    $cronErrorLines = $lines | Where-Object { $_ -match '\[ERROR\]|Exception non gérée|Exception non geree|Erreur insertion' }
    $cronLogSummary.LastLines = @($cronErrorLines | Select-Object -Last $LogLines)
}

# --- 3. Generation du rapport Markdown
$genTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$md = @"
# Rapport de verification des pages et logs

- **Date/heure** : $genTime
- **Serveur** : $BaseUrl
- **URLs testees** : $($results.Count)

## Resumé executif

| Metrique | Valeur |
|----------|--------|
| URLs OK | $okCount |
| URLs en redirection / avertissement | $warnCount |
| URLs en erreur | $errCount |
| error_log accessible | $(if ($errorLogSummary.Available) { 'Oui' } else { "Non ($($errorLogSummary.StatusCode))" }) |
| cronlog.txt accessible | $(if ($cronLogSummary.Available) { 'Oui' } else { "Non ($($cronLogSummary.StatusCode))" }) |

## Resultats par URL

| URL | Methode | Code HTTP | Temps (ms) | Statut |
|-----|---------|-----------|------------|--------|
"@ + "`n"

foreach ($row in $results) {
    $md += "| $($row.Url) | $($row.Method) | $($row.HttpCode) | $($row.Ms) | $($row.Status) |`n"
}

$md += @"

## Logs

### Disponibilite

| Log | URL | Code HTTP |
|-----|-----|-----------|
| cronlog.txt | $logCronUrl | $cronStatus |
| error_log | $logErrorUrl | $errorStatus |

### Résumé error_log

- Lignes \`[n3 500]\` : $($errorLogSummary.CountN3500)
- Lignes PHP Fatal : $($errorLogSummary.CountFatal)
- Lignes 404 (FFP3/n3-iot) : $($errorLogSummary.Count404)

**Dernières lignes pertinentes (max $LogLines) :**

``````
$(($errorLogSummary.LastLines -join "`n"))
``````

### Résumé cronlog.txt

- Lignes \`[ERROR]\` : $($cronLogSummary.CountError)
- Lignes \"Exception non gérée\" : $($cronLogSummary.CountException)
- Lignes \"Erreur insertion\" : $($cronLogSummary.CountInsert)

**Dernières lignes pertinentes (max $LogLines) :**

``````
$(($cronLogSummary.LastLines -join "`n"))
``````

---
*Rapport généré par scripts/check-server-pages.ps1*
"@

[System.IO.File]::WriteAllText($reportPath, $md, [System.Text.UTF8Encoding]::new($false))
Write-Host "Rapport enregistre : $reportPath" -ForegroundColor Green

# --- 4. Export JSON optionnel
if ($ExportJson) {
    $export = @{
        generatedAt = $genTime
        baseUrl      = $BaseUrl
        urlResults   = @($results)
        errorLog     = @{
            available  = $errorLogSummary.Available
            statusCode = $errorLogSummary.StatusCode
            countN3500 = $errorLogSummary.CountN3500
            countFatal = $errorLogSummary.CountFatal
            count404   = $errorLogSummary.Count404
            lastLines  = @($errorLogSummary.LastLines)
        }
        cronLog = @{
            available   = $cronLogSummary.Available
            statusCode = $cronLogSummary.StatusCode
            countError  = $cronLogSummary.CountError
            countException = $cronLogSummary.CountException
            countInsert = $cronLogSummary.CountInsert
            lastLines   = @($cronLogSummary.LastLines)
        }
        summary = @{
            ok   = $okCount
            warn = $warnCount
            err  = $errCount
        }
    }
    $export | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "JSON enregistre : $jsonPath" -ForegroundColor Green
}

# --- 5. Resumé console
Write-Host ""
Write-Host "Resume : $okCount OK, $warnCount avert., $errCount erreur(s)" -ForegroundColor $(if ($errCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Termine." -ForegroundColor Cyan
