<#
.SYNOPSIS
    Verifie les pages du serveur distant (prod), genere le rapport en local et propose des correctifs avant validation.

.DESCRIPTION
    Cible par defaut la PROD distante (https://iot.olution.info). Le script s'execute en local, envoie les requetes
    vers le serveur distant, recupere les logs (cronlog.txt, error_log) via HTTP et genere le rapport sur la machine
    locale. En presence d'erreurs (URLs 4xx/5xx, erreurs dans les logs), une section "Correctifs proposes" liste des
    actions precises et fonctionnelles a valider puis appliquer manuellement (aucune modification automatique).
    A executer depuis la racine IOT_n3.

.PARAMETER BaseUrl
    URL de base du serveur (defaut : https://iot.olution.info pour prod).

.PARAMETER ReportDir
    Dossier de sortie des rapports en local (defaut : scripts/reports).

.PARAMETER LogLines
    Nombre de lignes d'erreur a inclure dans le rapport (defaut : 20).

.PARAMETER ExportJson
    Si specifie, genere aussi un fichier JSON avec les memes donnees.

.PARAMETER NoCorrectifs
    Ne pas generer la section "Correctifs proposes" dans le rapport.

.EXAMPLE
    .\scripts\check-server-pages.ps1

.EXAMPLE
    .\scripts\check-server-pages.ps1 -ReportDir docs/rapports-serveur -LogLines 30 -ExportJson

.EXAMPLE
    .\scripts\check-server-pages.ps1 -BaseUrl http://localhost:8080
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://iot.olution.info',
    [string]$ReportDir = 'scripts/reports',
    [int]$LogLines = 20,
    [switch]$ExportJson,
    [switch]$NoCorrectifs
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

# --- 2b. Construction des correctifs proposes (sans les appliquer)
$correctifs = [System.Collections.ArrayList]::new()
if (-not $NoCorrectifs) {
    # Correctifs pour URLs en erreur
    foreach ($row in $results) {
        if ($row.HttpCode -eq 404) {
            $pathNorm = $row.Path.TrimEnd('/')
            $suggestion = "URL $($row.Url) retourne 404. "
            if ($pathNorm -match '\.php$') {
                $suggestion += "Verifier que le fichier existe sous serveur/public ou qu'une route Slim equivale dans serveur/public/index.php (groupes /msp1, /n3pp, /ffp3). Verifier aussi .htaccess si le script est servi par Apache."
            } else {
                $suggestion += "Verifier que la route est definie dans serveur/public/index.php (rechercher '" + ($pathNorm -replace '^/ffp3', '') + "' ou le chemin sans prefixe /ffp3). Pour les assets (CSS/JS), verifier le chemin sous serveur/public/assets/."
            }
            [void]$correctifs.Add([PSCustomObject]@{ Type = 'URL_404'; Source = $row.Path; Correctif = $suggestion; Fichier = 'serveur/public/index.php'; Ligne = $null })
        }
        elseif ($row.HttpCode -ge 500) {
            [void]$correctifs.Add([PSCustomObject]@{
                Type     = 'URL_5xx'
                Source   = $row.Path
                Correctif = "URL $($row.Url) retourne $($row.HttpCode). Consulter error_log (voir section Logs ci-dessous) pour la ligne [n3 500] ou PHP Fatal associee, puis corriger le fichier et la ligne indiques."
                Fichier  = $null
                Ligne    = $null
            })
        }
        elseif ($row.HttpCode -ge 400 -and $row.HttpCode -lt 500) {
            [void]$correctifs.Add([PSCustomObject]@{
                Type     = 'URL_4xx'
                Source   = $row.Path
                Correctif = "URL $($row.Url) retourne $($row.HttpCode). Verifier authentification (route protegee ?), parametres attendus (GET/POST) et serveur/public/index.php (middleware auth, publicPaths/protectedPaths)."
                Fichier  = 'serveur/public/index.php'
                Ligne    = $null
            })
        }
    }

    # Parser error_log : [n3 500] ... Exception: message in /path/file.php:123
    $patternN3500 = '\[n3 500\].*?—\s*(\S+):\s*(.+?)\s+in\s+(.+?):(\d+)'
    $patternFatal = 'Fatal error:\s*(.+?)\s+in\s+(.+?)\s+on\s+line\s+(\d+)'
    $patternFatal2 = 'PHP Fatal error:\s*(.+?)\s+in\s+(.+?)\s+on\s+line\s+(\d+)'
    foreach ($line in $errorLogSummary.LastLines) {
        if ($line -match $patternN3500) {
            $exClass = $Matches[1]; $msg = $Matches[2].Trim(); $file = $Matches[3]; $lineNum = $Matches[4]
            $fileLocal = $file -replace '^.*[/\\](templates|src|public)[/\\]', 'serveur/$1/'
            [void]$correctifs.Add([PSCustomObject]@{
                Type     = 'error_log_500'
                Source   = $line
                Correctif = "Exception $exClass : $msg. Fichier (cote serveur) : $file ligne $lineNum. En local : ouvrir $fileLocal vers la ligne $lineNum, corriger selon le message (template manquant, variable indefinie, colonne BDD, etc.)."
                Fichier  = $fileLocal
                Ligne    = [int]$lineNum
            })
        }
        elseif ($line -match $patternFatal -or $line -match $patternFatal2) {
            $msg = $Matches[1]; $file = $Matches[2]; $lineNum = $Matches[3]
            $fileLocal = $file -replace '^.*[/\\](templates|src|public)[/\\]', 'serveur/$1/'
            [void]$correctifs.Add([PSCustomObject]@{
                Type     = 'error_log_fatal'
                Source   = $line
                Correctif = "PHP Fatal : $msg. Fichier : $file ligne $lineNum. En local : $fileLocal ligne $lineNum. Corriger la syntaxe, la classe manquante ou l'appel incorrect."
                Fichier  = $fileLocal
                Ligne    = [int]$lineNum
            })
        }
        elseif ($line -match 'FFP3 404|n3-iot 404') {
            [void]$correctifs.Add([PSCustomObject]@{
                Type     = 'error_log_404'
                Source   = $line
                Correctif = "Requete vers route inexistante (loggee dans error_log). Extraire METHOD et URI de la ligne, puis ajouter la route dans serveur/public/index.php ou le fichier .php correspondant."
                Fichier  = 'serveur/public/index.php'
                Ligne    = $null
            })
        }
    }

    # Parser cronlog : Exception / Erreur insertion (fichier:ligne si present)
    $patternCronFile = 'in\s+(.+?):(\d+)|in\s+(.+?)\s+line\s+(\d+)'
    foreach ($line in $cronLogSummary.LastLines) {
        $suggestion = $null
        if ($line -match 'Erreur insertion') {
            $suggestion = "Erreur insertion (cronlog). Souvent liee a une colonne BDD manquante ou un type invalide. Verifier le schema des tables (ffp3Data, ffp3Outputs, etc.) et le code d'insertion dans les Repository (serveur/src/). Comparer avec TableConfig et les migrations."
        }
        elseif ($line -match 'Exception non gérée|Exception non geree') {
            if ($line -match $patternCronFile) {
                $f = if ($Matches[1]) { $Matches[1] } else { $Matches[3] }
                $l = if ($Matches[2]) { $Matches[2] } else { $Matches[4] }
                $fLocal = $f -replace '^.*[/\\](templates|src|public)[/\\]', 'serveur/$1/'
                $suggestion = "Exception dans cronlog. Fichier : $f ligne $l. En local : $fLocal ligne $l. Corriger l'exception (donnees, BDD, fichier manquant)."
            } else {
                $suggestion = "Exception non geree (cronlog). Consulter la ligne complete ci-dessus pour le message et la pile d'appels, puis identifier le fichier et la ligne dans le depot serveur/."
            }
        }
        if ($suggestion) {
            [void]$correctifs.Add([PSCustomObject]@{ Type = 'cronlog'; Source = $line; Correctif = $suggestion; Fichier = $null; Ligne = $null })
        }
    }

    # Deduplication par (Type, Fichier, Ligne) pour eviter doublons
    $seen = @{}
    $correctifsUniques = [System.Collections.ArrayList]::new()
    foreach ($c in $correctifs) {
        $key = "$($c.Type)|$($c.Fichier)|$($c.Ligne)"
        if (-not $seen[$key]) {
            $seen[$key] = $true
            [void]$correctifsUniques.Add($c)
        }
    }
    $correctifs = $correctifsUniques
}

# --- 2c. Section Correctifs (texte pour le rapport)
$correctifsSection = ''
if (-not $NoCorrectifs -and $correctifs.Count -gt 0) {
    $correctifsSection = @"

## Correctifs proposes (a valider puis appliquer manuellement)

Les actions suivantes sont suggerees en fonction des erreurs detectees. **Aucune modification n'est appliquee automatiquement.** Valider chaque point, appliquer les correctifs dans le depot local, tester (ex. php -S + check-server-pages -BaseUrl http://localhost:8080), puis redéployer en prod et relancer ce script pour verifier.

| # | Type | Fichier/Ligne | Action proposee |
|---|------|----------------|-----------------|
"@
    $i = 1
    foreach ($c in $correctifs) {
        $fic = if ($c.Fichier) { $c.Fichier } else { '-' }
        $lig = if ($c.Ligne) { $c.Ligne } else { '-' }
        $action = ($c.Correctif -replace '\|', '\|' -replace "`r?`n", ' ').Trim()
        $correctifsSection += "| $i | $($c.Type) | ${fic} : ${lig} | $action |`n"
        $i++
    }
    $correctifsSection += "`n**Validation :** appliquer manuellement les correctifs souhaites, tester en local, deployer, puis relancer ce script.`n"
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

```
$(($errorLogSummary.LastLines -join "`n"))
```

### Résumé cronlog.txt

- Lignes \`[ERROR]\` : $($cronLogSummary.CountError)
- Lignes \"Exception non gérée\" : $($cronLogSummary.CountException)
- Lignes \"Erreur insertion\" : $($cronLogSummary.CountInsert)

**Dernières lignes pertinentes (max $LogLines) :**

```
$(($cronLogSummary.LastLines -join "`n"))
```
$correctifsSection
---
*Rapport généré par scripts/check-server-pages.ps1*
"@

[System.IO.File]::WriteAllText($reportPath, $md, [System.Text.UTF8Encoding]::new($false))
Write-Host "Rapport enregistre : $reportPath" -ForegroundColor Green

# --- 5. Export JSON optionnel
if ($ExportJson) {
    $correctifsExport = @($correctifs | ForEach-Object { [PSCustomObject]@{ Type = $_.Type; Source = $_.Source; Correctif = $_.Correctif; Fichier = $_.Fichier; Ligne = $_.Ligne } })
    $export = @{
        generatedAt = $genTime
        baseUrl      = $BaseUrl
        urlResults   = @($results)
        correctifs   = $correctifsExport
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

# --- 6. Resumé console
Write-Host ""
Write-Host "Resume : $okCount OK, $warnCount avert., $errCount erreur(s)" -ForegroundColor $(if ($errCount -gt 0) { 'Red' } else { 'Green' })
if (-not $NoCorrectifs -and $correctifs.Count -gt 0) {
    Write-Host "Correctifs proposes : $($correctifs.Count) (voir rapport, section Correctifs proposes)" -ForegroundColor Yellow
}
Write-Host "Termine." -ForegroundColor Cyan
