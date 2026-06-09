<#
.SYNOPSIS
    Audit complet du serveur distant iot.olution.info.

.DESCRIPTION
    Verifie exhaustivement le serveur distant : pages web, APIs temps reel, endpoints firmware,
    redirections legacy, ressources statiques/OTA, logs serveur, securite (SSL, headers, fichiers
    sensibles) et performance. Genere un rapport Markdown et une sortie console coloree.
    A executer depuis la racine IOT_n3.

.PARAMETER BaseUrl
    URL de base du serveur (defaut : https://iot.olution.info).

.PARAMETER ReportDir
    Dossier de sortie du rapport (defaut : docs).

.PARAMETER LogLines
    Nombre de lignes d'erreur a inclure dans le rapport (defaut : 30).

.PARAMETER SkipSSL
    Ignorer la verification du certificat SSL.

.PARAMETER SkipSecurity
    Ignorer les tests de securite (headers, fichiers sensibles).

.EXAMPLE
    .\scripts\audit-serveur-complet.ps1

.EXAMPLE
    .\scripts\audit-serveur-complet.ps1 -BaseUrl http://localhost:8080 -SkipSSL
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://iot.olution.info',
    [string]$ReportDir = 'docs',
    [int]$LogLines = 30,
    [switch]$SkipSSL,
    [switch]$SkipSecurity
)

$ErrorActionPreference = 'Continue'

$root = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    (Get-Location).Path
}

$reportDirAbs = Join-Path $root $ReportDir
if (-not (Test-Path $reportDirAbs)) {
    New-Item -ItemType Directory -Path $reportDirAbs -Force | Out-Null
}

$baseUrlTrim = $BaseUrl.TrimEnd('/')
$timestamp = Get-Date -Format 'yyyy-MM-dd'
$timestampFull = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$reportPath = Join-Path $reportDirAbs "audit-serveur-complet-$timestamp.md"

# Version serveur (lue depuis le submodule, plus de valeur codee en dur)
$serveurVersionFile = Join-Path $root 'serveur/VERSION'
$serveurVersion = if (Test-Path $serveurVersionFile) {
    (Get-Content $serveurVersionFile -Raw).Trim()
} else {
    'inconnue (submodule serveur non initialise)'
}

# Compteurs globaux
$script:totalOk = 0
$script:totalWarn = 0
$script:totalErr = 0
$script:allTimings = [System.Collections.ArrayList]::new()

# ====================================================================
# Fonctions utilitaires
# ====================================================================

function Test-Url {
    param(
        [string]$Path,
        [string]$Method = 'GET',
        [int]$ExpectedCode = 200,
        [string]$Label = '',
        [switch]$NoRedirect,
        [switch]$CheckJson
    )
    $url = $baseUrlTrim + $Path
    $displayLabel = if ($Label) { $Label } else { $Path }
    Write-Host "  $Method $displayLabel ... " -NoNewline

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $code = 0
    $content = ''
    $headers = @{}
    $contentType = ''

    try {
        $params = @{
            Uri             = $url
            Method          = $Method
            UseBasicParsing = $true
            TimeoutSec      = 15
            ErrorAction     = 'Stop'
        }
        if ($NoRedirect) {
            $params['MaximumRedirection'] = 0
        }
        $resp = Invoke-WebRequest @params
        $code = $resp.StatusCode
        $content = $resp.Content
        $contentType = ($resp.Headers['Content-Type'] -join ', ')
        foreach ($h in $resp.Headers.Keys) {
            $headers[$h] = ($resp.Headers[$h] -join ', ')
        }
    } catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            try {
                $contentType = ($_.Exception.Response.Headers | Where-Object { $_.Key -eq 'Content-Type' } | Select-Object -First 1).Value -join ', '
            } catch {}
        }
    }
    $sw.Stop()
    $ms = $sw.ElapsedMilliseconds

    [void]$script:allTimings.Add([PSCustomObject]@{ Path = $Path; Ms = $ms })

    $status = 'OK'
    $isOk = $false

    if ($ExpectedCode -gt 0 -and $code -eq $ExpectedCode) {
        $status = 'OK'
        $isOk = $true
        $script:totalOk++
    } elseif ($ExpectedCode -gt 0 -and $code -ne $ExpectedCode) {
        $status = "Erreur (attendu $ExpectedCode)"
        $script:totalErr++
    } elseif ($code -ge 200 -and $code -lt 300) {
        $status = 'OK'
        $isOk = $true
        $script:totalOk++
    } elseif ($code -eq 301 -or $code -eq 302) {
        $status = 'Redirect'
        $script:totalWarn++
    } elseif ($code -ge 400) {
        $status = 'Erreur'
        $script:totalErr++
    } else {
        $status = 'Timeout/Inconnu'
        $script:totalWarn++
    }

    $jsonValid = $null
    if ($CheckJson -and $isOk -and $content) {
        try {
            $null = $content | ConvertFrom-Json
            $jsonValid = $true
        } catch {
            $jsonValid = $false
            $status = 'JSON invalide'
            $script:totalErr++
            $script:totalOk--
        }
    }

    $color = switch -Wildcard ($status) {
        'OK'         { 'Green' }
        'Redirect'   { 'Yellow' }
        'Timeout*'   { 'Yellow' }
        default      { 'Red' }
    }
    Write-Host "$code ${ms}ms " -NoNewline -ForegroundColor $color
    Write-Host $status -ForegroundColor $color

    return [PSCustomObject]@{
        Path        = $Path
        Url         = $url
        Method      = $Method
        HttpCode    = $code
        Expected    = $ExpectedCode
        Ms          = $ms
        Status      = $status
        ContentType = $contentType
        Content     = $content
        Headers     = $headers
        JsonValid   = $jsonValid
    }
}

function Format-ResultTable {
    param([array]$Results, [string]$ExtraCol = '')
    $md = "| Chemin | Code HTTP | Attendu | Temps (ms) | Statut |"
    if ($ExtraCol) { $md += " $ExtraCol |" }
    $md += "`n|--------|-----------|---------|------------|--------|"
    if ($ExtraCol) { $md += "------|" }
    $md += "`n"
    foreach ($r in $Results) {
        $md += "| ``$($r.Path)`` | $($r.HttpCode) | $($r.Expected) | $($r.Ms) | $($r.Status) |"
        if ($ExtraCol -eq 'JSON') {
            $jv = if ($null -eq $r.JsonValid) { '-' } elseif ($r.JsonValid) { 'Valide' } else { 'Invalide' }
            $md += " $jv |"
        }
        $md += "`n"
    }
    return $md
}

# ====================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  AUDIT COMPLET DU SERVEUR DISTANT" -ForegroundColor Cyan
Write-Host "  $BaseUrl" -ForegroundColor Cyan
Write-Host "  $timestampFull" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$mdSections = [System.Collections.ArrayList]::new()

# ====================================================================
# SECTION 1 — Pages web
# ====================================================================
Write-Host "[1/8] Pages web (GET, code 200 attendu)..." -ForegroundColor Yellow
Write-Host ""

$pagesPaths = @(
    '/',
    '/aquaponie',
    '/aquaponie-alt',
    '/aquaponie-description',
    '/aquaponie-test',
    '/aquaponie-alt-test',
    '/aquamobile',
    '/aquamobile-test',
    '/aquamobile-alt',
    '/aquamobile-alt-test',
    '/meteo',
    '/serre',
    '/login',
    '/gallery/msp1',
    '/gallery/n3pp',
    '/gallery/ffp3'
)

$pagesProtected = @(
    '/dashboard',
    '/dashboard-test',
    '/dashboard3',
    '/dashboard3-test',
    '/tide-stats',
    '/tide-stats-test',
    '/tide-stats3',
    '/tide-stats3-test',
    '/control',
    '/control-test',
    '/supervision',
    '/aquaponie-control',
    '/aquaponie-control-test',
    '/aquamobile-control',
    '/aquamobile-control-test',
    '/meteo-control',
    '/serre-control'
)

$pagesResults = [System.Collections.ArrayList]::new()
foreach ($p in $pagesPaths) {
    [void]$pagesResults.Add((Test-Url -Path $p -ExpectedCode 200))
}

Write-Host ""
Write-Host "  Pages protegees (200 ou 302 vers /login attendu)..." -ForegroundColor Gray
foreach ($p in $pagesProtected) {
    $r = Test-Url -Path $p -ExpectedCode 0 -NoRedirect
    # Page protegee : 200 (contenu) comme 301/302 (redirection vers /login) sont acceptables.
    if ($r.HttpCode -eq 301 -or $r.HttpCode -eq 302) {
        # Test-Url a comptabilise un avertissement : le reclasser en OK.
        $r.Status = 'OK'
        $script:totalWarn--
        $script:totalOk++
    } elseif ($r.HttpCode -eq 200) {
        # Deja comptabilise en OK par Test-Url : ne pas recompter.
        $r.Status = 'OK'
    }
    [void]$pagesResults.Add($r)
}

$pageMd = "## 1. Pages web`n`n"
$pageMd += Format-ResultTable -Results $pagesResults
[void]$mdSections.Add($pageMd)

# ====================================================================
# SECTION 2 — APIs temps reel
# ====================================================================
Write-Host ""
Write-Host "[2/8] APIs temps reel (GET, code 200, JSON valide)..." -ForegroundColor Yellow
Write-Host ""

$apiPaths = @(
    '/api/realtime/sensors/latest',
    '/api/realtime/outputs/state',
    '/api/realtime/system/health',
    '/api/health',
    '/api/realtime-test/sensors/latest',
    '/api/realtime-test/system/health',
    '/api/realtime3-test/system/health',
    '/api/realtime3/system/health',
    '/msp1/api/realtime/sensors/latest',
    '/msp1/api/realtime/system/health',
    '/msp1/api/outputs/state',
    '/n3pp/api/realtime/sensors/latest',
    '/n3pp/api/realtime/system/health',
    '/n3pp/api/outputs/state'
)

$apiResults = [System.Collections.ArrayList]::new()
foreach ($p in $apiPaths) {
    [void]$apiResults.Add((Test-Url -Path $p -ExpectedCode 200 -CheckJson))
}

$pingResult = Test-Url -Path '/ping' -ExpectedCode 200
if ($pingResult.Content -and $pingResult.Content.Trim() -ne 'OK') {
    $pingResult.Status = "Contenu inattendu: '$($pingResult.Content.Trim())'"
}
[void]$apiResults.Add($pingResult)

$apiMd = "## 2. APIs temps reel`n`n"
$apiMd += Format-ResultTable -Results $apiResults -ExtraCol 'JSON'
[void]$mdSections.Add($apiMd)

# ====================================================================
# SECTION 3 — Endpoints firmware
# ====================================================================
Write-Host ""
Write-Host "[3/8] Endpoints firmware (GET sur POST-only)..." -ForegroundColor Yellow
Write-Host ""

$fwPaths = @(
    @{ Path = '/post-data'; Expected = 405 },
    @{ Path = '/heartbeat'; Expected = 405 },
    @{ Path = '/post-ffp3-data.php'; Expected = 405 },
    @{ Path = '/msp1/msp1datas/post-msp1-data.php'; Expected = 405 },
    @{ Path = '/n3pp/n3ppdatas/post-n3pp-data.php'; Expected = 405 }
)

$fwResults = [System.Collections.ArrayList]::new()
foreach ($fw in $fwPaths) {
    [void]$fwResults.Add((Test-Url -Path $fw.Path -ExpectedCode $fw.Expected))
}

$fwMd = "## 3. Endpoints firmware (GET sur POST-only)`n`n"
$fwMd += "Ces endpoints n'acceptent que POST. Un GET doit retourner 405 (Method Not Allowed).`n`n"
$fwMd += Format-ResultTable -Results $fwResults
[void]$mdSections.Add($fwMd)

# ====================================================================
# SECTION 4 — Redirections legacy
# ====================================================================
Write-Host ""
Write-Host "[4/8] Redirections legacy (301 attendu)..." -ForegroundColor Yellow
Write-Host ""

$redirPaths = @(
    '/ffp3/',
    '/ffp3/dashboard',
    '/ffp3/aquaponie',
    '/ffp3-data',
    '/msp1/msp1control/',
    '/msp1/msp1control/index.php',
    '/n3pp/n3ppcontrol/',
    '/n3pp/n3ppcontrol/index.php',
    '/ffp3/heartbeat.php'
)

$redirResults = [System.Collections.ArrayList]::new()
foreach ($p in $redirPaths) {
    [void]$redirResults.Add((Test-Url -Path $p -ExpectedCode 301 -NoRedirect))
}

$redirMd = "## 4. Redirections legacy`n`n"
$redirMd += Format-ResultTable -Results $redirResults
[void]$mdSections.Add($redirMd)

# ====================================================================
# SECTION 5 — Ressources statiques et OTA
# ====================================================================
Write-Host ""
Write-Host "[5/8] Ressources statiques et OTA..." -ForegroundColor Yellow
Write-Host ""

$staticPaths = @(
    '/assets/css/main.css',
    '/assets/logo.png',
    '/manifest.json',
    '/robots.txt',
    '/favicon.ico',
    '/service-worker.js',
    '/ota/metadata.json'
)

$staticResults = [System.Collections.ArrayList]::new()
foreach ($p in $staticPaths) {
    [void]$staticResults.Add((Test-Url -Path $p -ExpectedCode 200))
}

$staticMd = "## 5. Ressources statiques et OTA`n`n"
$staticMd += Format-ResultTable -Results $staticResults
[void]$mdSections.Add($staticMd)

# ====================================================================
# SECTION 6 — Logs serveur
# ====================================================================
Write-Host ""
Write-Host "[6/8] Logs serveur (analyse)..." -ForegroundColor Yellow
Write-Host ""

$logCronUrl = $baseUrlTrim + '/public/cronlog.txt'
$logErrorUrl = $baseUrlTrim + '/public/error_log'

$cronContent = $null; $cronStatus = 0
$errorContent = $null; $errorStatus = 0

Write-Host "  Recuperation cronlog.txt ... " -NoNewline
try {
    $r = Invoke-WebRequest -Uri $logCronUrl -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    $cronStatus = $r.StatusCode; $cronContent = $r.Content
    Write-Host "$cronStatus OK" -ForegroundColor Green
} catch {
    $cronStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    Write-Host "$cronStatus Erreur" -ForegroundColor Red
}

Write-Host "  Recuperation error_log ... " -NoNewline
try {
    $r = Invoke-WebRequest -Uri $logErrorUrl -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    $errorStatus = $r.StatusCode; $errorContent = $r.Content
    Write-Host "$errorStatus OK" -ForegroundColor Green
} catch {
    $errorStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    Write-Host "$errorStatus Erreur" -ForegroundColor Red
}

$errorLogAnalysis = @{
    CountN3500 = 0; CountFatal = 0; Count404 = 0; TotalErrorLines = 0; LastLines = @()
    TopFiles = @{}
}
if ($errorContent) {
    $lines = $errorContent -split "`n"
    $errLines = $lines | Where-Object { $_ -match '\[n3 500\]|PHP Fatal|Fatal error|FFP3 404|n3-iot 404|\[ERROR\]' }
    $errorLogAnalysis.TotalErrorLines = @($errLines).Count
    $errorLogAnalysis.CountN3500 = @($lines | Where-Object { $_ -match '\[n3 500\]' }).Count
    $errorLogAnalysis.CountFatal = @($lines | Where-Object { $_ -match 'PHP Fatal|Fatal error' }).Count
    $errorLogAnalysis.Count404 = @($lines | Where-Object { $_ -match 'FFP3 404|n3-iot 404' }).Count
    $errorLogAnalysis.LastLines = @($errLines | Select-Object -Last $LogLines)

    foreach ($line in $errLines) {
        if ($line -match 'in\s+(/[^\s:]+):(\d+)') {
            $file = $Matches[1]
            if ($errorLogAnalysis.TopFiles.ContainsKey($file)) {
                $errorLogAnalysis.TopFiles[$file]++
            } else {
                $errorLogAnalysis.TopFiles[$file] = 1
            }
        }
    }
}

$cronLogAnalysis = @{
    CountError = 0; CountException = 0; CountInsert = 0; LastLines = @()
}
if ($cronContent) {
    $lines = $cronContent -split "`n"
    $cronErrLines = $lines | Where-Object { $_ -match '\[ERROR\]|Exception non gérée|Exception non geree|Erreur insertion' }
    $cronLogAnalysis.CountError = @($lines | Where-Object { $_ -match '\[ERROR\]' }).Count
    $cronLogAnalysis.CountException = @($lines | Where-Object { $_ -match 'Exception non gérée|Exception non geree' }).Count
    $cronLogAnalysis.CountInsert = @($lines | Where-Object { $_ -match 'Erreur insertion' }).Count
    $cronLogAnalysis.LastLines = @($cronErrLines | Select-Object -Last $LogLines)
}

Write-Host ""
Write-Host "  error_log: $($errorLogAnalysis.TotalErrorLines) lignes d'erreur, $($errorLogAnalysis.CountN3500) [n3 500], $($errorLogAnalysis.CountFatal) Fatal" -ForegroundColor $(if ($errorLogAnalysis.TotalErrorLines -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  cronlog: $($cronLogAnalysis.CountError) [ERROR], $($cronLogAnalysis.CountException) exceptions, $($cronLogAnalysis.CountInsert) erreurs insertion" -ForegroundColor $(if ($cronLogAnalysis.CountError -gt 0) { 'Yellow' } else { 'Green' })

$logMd = @"
## 6. Logs serveur

### Disponibilite

| Log | URL | Code HTTP |
|-----|-----|-----------|
| cronlog.txt | $logCronUrl | $cronStatus |
| error_log | $logErrorUrl | $errorStatus |

### Analyse error_log

| Metrique | Valeur |
|----------|--------|
| Total lignes d'erreur | $($errorLogAnalysis.TotalErrorLines) |
| Lignes ``[n3 500]`` | $($errorLogAnalysis.CountN3500) |
| PHP Fatal / Fatal error | $($errorLogAnalysis.CountFatal) |
| Lignes 404 (FFP3/n3-iot) | $($errorLogAnalysis.Count404) |

"@

if ($errorLogAnalysis.TopFiles.Count -gt 0) {
    $logMd += "**Fichiers les plus frequemment en erreur :**`n`n"
    $logMd += "| Fichier | Occurrences |`n|---------|-------------|`n"
    $sorted = $errorLogAnalysis.TopFiles.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
    foreach ($entry in $sorted) {
        $logMd += "| ``$($entry.Key)`` | $($entry.Value) |`n"
    }
    $logMd += "`n"
}

$logMd += @"
**Dernieres lignes error_log (max $LogLines) :**

``````
$($errorLogAnalysis.LastLines -join "`n")
``````

### Analyse cronlog.txt

| Metrique | Valeur |
|----------|--------|
| Lignes ``[ERROR]`` | $($cronLogAnalysis.CountError) |
| Exceptions non gerees | $($cronLogAnalysis.CountException) |
| Erreurs insertion | $($cronLogAnalysis.CountInsert) |

**Dernieres lignes cronlog (max $LogLines) :**

``````
$($cronLogAnalysis.LastLines -join "`n")
``````

"@

[void]$mdSections.Add($logMd)

# ====================================================================
# SECTION 7 — Securite
# ====================================================================
if (-not $SkipSecurity) {
    Write-Host ""
    Write-Host "[7/8] Securite..." -ForegroundColor Yellow
    Write-Host ""

    $secMd = "## 7. Securite`n`n"

    # 7a. SSL
    if (-not $SkipSSL -and $baseUrlTrim -match '^https://') {
        Write-Host "  Verification certificat SSL..." -ForegroundColor Gray
        $sslInfo = @{ Valid = $false; Issuer = ''; Expiry = ''; DaysLeft = 0; Subject = '' }
        try {
            $uri = [System.Uri]$baseUrlTrim
            $tcpClient = [System.Net.Sockets.TcpClient]::new($uri.Host, 443)
            $sslStream = [System.Net.Security.SslStream]::new($tcpClient.GetStream(), $false, { $true })
            $sslStream.AuthenticateAsClient($uri.Host)
            $cert = $sslStream.RemoteCertificate
            if ($cert) {
                $cert2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert)
                $sslInfo.Valid = ($cert2.NotAfter -gt (Get-Date))
                $sslInfo.Issuer = $cert2.Issuer
                $sslInfo.Subject = $cert2.Subject
                $sslInfo.Expiry = $cert2.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                $sslInfo.DaysLeft = [math]::Floor(($cert2.NotAfter - (Get-Date)).TotalDays)
            }
            $sslStream.Close()
            $tcpClient.Close()
        } catch {
            Write-Host "  Erreur SSL: $($_.Exception.Message)" -ForegroundColor Red
        }

        $sslColor = if ($sslInfo.DaysLeft -gt 30) { 'Green' } elseif ($sslInfo.DaysLeft -gt 7) { 'Yellow' } else { 'Red' }
        Write-Host "  SSL: $(if ($sslInfo.Valid) { 'Valide' } else { 'INVALIDE' }), expire le $($sslInfo.Expiry) ($($sslInfo.DaysLeft) jours)" -ForegroundColor $sslColor

        $secMd += @"
### Certificat SSL

| Propriete | Valeur |
|-----------|--------|
| Valide | $(if ($sslInfo.Valid) { 'Oui' } else { '**NON**' }) |
| Sujet | $($sslInfo.Subject) |
| Emetteur | $($sslInfo.Issuer) |
| Expiration | $($sslInfo.Expiry) |
| Jours restants | $($sslInfo.DaysLeft) |

"@
    } else {
        $secMd += "### Certificat SSL`n`nIgnore (``-SkipSSL`` ou URL non HTTPS).`n`n"
    }

    # 7b. Headers de securite
    Write-Host "  Verification headers de securite..." -ForegroundColor Gray
    $homeResult = $null
    foreach ($r in $pagesResults) {
        if ($r.Path -eq '/') { $homeResult = $r; break }
    }

    $secHeaders = @(
        'X-Content-Type-Options',
        'X-Frame-Options',
        'Strict-Transport-Security',
        'Content-Security-Policy',
        'X-XSS-Protection',
        'Referrer-Policy'
    )

    $secMd += "### Headers de securite (page d'accueil)`n`n"
    $secMd += "| Header | Present | Valeur |`n|--------|---------|--------|`n"

    $headersFound = 0
    foreach ($sh in $secHeaders) {
        $val = $null
        if ($homeResult -and $homeResult.Headers) {
            $val = $homeResult.Headers[$sh]
        }
        $present = if ($val) { 'Oui'; $headersFound++ } else { '**Non**' }
        $displayVal = if ($val) { $val } else { '-' }
        $secMd += "| $sh | $present | $displayVal |`n"
        $hColor = if ($val) { 'Green' } else { 'Yellow' }
        Write-Host "  $sh : $(if ($val) { $val } else { 'ABSENT' })" -ForegroundColor $hColor
    }
    $secMd += "`n"

    # 7c. Fichiers sensibles
    Write-Host ""
    Write-Host "  Verification fichiers sensibles exposes..." -ForegroundColor Gray
    $sensitivePaths = @(
        '/.env',
        '/.git/config',
        '/.git/HEAD',
        '/vendor/autoload.php',
        '/config/container.php',
        '/var/cache/',
        '/src/Config/Env.php',
        '/composer.json',
        '/composer.lock'
    )

    $sensitiveResults = [System.Collections.ArrayList]::new()
    foreach ($sp in $sensitivePaths) {
        $sr = Test-Url -Path $sp -ExpectedCode 0 -NoRedirect
        $accessible = ($sr.HttpCode -ge 200 -and $sr.HttpCode -lt 300)
        $srStatus = if ($accessible) { 'EXPOSE' } else { "Protege ($($sr.HttpCode))" }
        $sr | Add-Member -NotePropertyName 'Accessible' -NotePropertyValue $accessible -Force
        $sr | Add-Member -NotePropertyName 'SecurityStatus' -NotePropertyValue $srStatus -Force
        [void]$sensitiveResults.Add($sr)
        if ($accessible) {
            $script:totalErr++
            $script:totalOk--
        }
    }

    $secMd += "### Fichiers sensibles`n`n"
    $secMd += "| Chemin | Code HTTP | Statut |`n|--------|-----------|--------|`n"
    foreach ($sr in $sensitiveResults) {
        $icon = if ($sr.Accessible) { '**EXPOSE**' } else { 'Protege' }
        $secMd += "| ``$($sr.Path)`` | $($sr.HttpCode) | $icon |`n"
    }

    $exposedCount = @($sensitiveResults | Where-Object { $_.Accessible }).Count
    Write-Host ""
    if ($exposedCount -gt 0) {
        Write-Host "  ALERTE : $exposedCount fichier(s) sensible(s) expose(s) !" -ForegroundColor Red
    } else {
        Write-Host "  Aucun fichier sensible expose." -ForegroundColor Green
    }

    # 7d. error_log expose
    $errorLogExposed = ($errorStatus -eq 200)
    $secMd += "`n### Logs exposes`n`n"
    $secMd += "| Fichier | Accessible | Risque |`n|---------|-----------|--------|`n"
    $secMd += "| ``/public/error_log`` | $(if ($errorLogExposed) { 'Oui' } else { 'Non' }) | $(if ($errorLogExposed) { 'Moyen - contient traces PHP, chemins serveur' } else { '-' }) |`n"
    $secMd += "| ``/public/cronlog.txt`` | $(if ($cronStatus -eq 200) { 'Oui' } else { 'Non' }) | $(if ($cronStatus -eq 200) { 'Faible - log applicatif de diagnostic' } else { '-' }) |`n"

    [void]$mdSections.Add($secMd)
} else {
    Write-Host ""
    Write-Host "[7/8] Securite... IGNORE (-SkipSecurity)" -ForegroundColor Gray
    [void]$mdSections.Add("## 7. Securite`n`nIgnore (``-SkipSecurity``).`n")
}

# ====================================================================
# SECTION 8 — Performance
# ====================================================================
Write-Host ""
Write-Host "[8/8] Analyse performance..." -ForegroundColor Yellow
Write-Host ""

$timings = $script:allTimings | Where-Object { $_.Ms -gt 0 } | Sort-Object Ms
$count = $timings.Count
$perfMd = "## 8. Performance`n`n"

if ($count -gt 0) {
    $avgMs = [math]::Round(($timings | Measure-Object -Property Ms -Average).Average, 0)
    $minMs = ($timings | Measure-Object -Property Ms -Minimum).Minimum
    $maxMs = ($timings | Measure-Object -Property Ms -Maximum).Maximum
    $p95Index = [math]::Floor($count * 0.95)
    if ($p95Index -ge $count) { $p95Index = $count - 1 }
    $p95Ms = $timings[$p95Index].Ms

    $slowPages = @($timings | Where-Object { $_.Ms -gt 3000 })

    Write-Host "  Moyenne : ${avgMs}ms | Min : ${minMs}ms | Max : ${maxMs}ms | P95 : ${p95Ms}ms" -ForegroundColor Cyan
    Write-Host "  URLs testees : $count | Pages lentes (>3s) : $($slowPages.Count)" -ForegroundColor $(if ($slowPages.Count -gt 0) { 'Yellow' } else { 'Green' })

    $perfMd += @"
| Metrique | Valeur |
|----------|--------|
| URLs mesurees | $count |
| Moyenne | ${avgMs} ms |
| Minimum | ${minMs} ms |
| Maximum | ${maxMs} ms |
| P95 | ${p95Ms} ms |
| Pages lentes (> 3s) | $($slowPages.Count) |

"@

    if ($slowPages.Count -gt 0) {
        $perfMd += "### Pages lentes (> 3 secondes)`n`n"
        $perfMd += "| Chemin | Temps (ms) |`n|--------|------------|`n"
        foreach ($sp in ($slowPages | Sort-Object Ms -Descending)) {
            $perfMd += "| ``$($sp.Path)`` | $($sp.Ms) |`n"
        }
        $perfMd += "`n"
    }

    $perfMd += "### Top 10 pages les plus lentes`n`n"
    $perfMd += "| Chemin | Temps (ms) |`n|--------|------------|`n"
    $top10 = $timings | Sort-Object Ms -Descending | Select-Object -First 10
    foreach ($t in $top10) {
        $perfMd += "| ``$($t.Path)`` | $($t.Ms) |`n"
    }
} else {
    $perfMd += "Aucune donnee de performance collectee.`n"
}

[void]$mdSections.Add($perfMd)

# ====================================================================
# Resume executif et rapport
# ====================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  RESUME EXECUTIF" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  OK       : $($script:totalOk)" -ForegroundColor Green
Write-Host "  Avert.   : $($script:totalWarn)" -ForegroundColor Yellow
Write-Host "  Erreurs  : $($script:totalErr)" -ForegroundColor $(if ($script:totalErr -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

# Construction du rapport complet
$summaryMd = @"
# Audit complet du serveur distant

- **Date** : $timestampFull
- **Serveur** : $BaseUrl
- **Version serveur** : $serveurVersion

## Resume executif

| Metrique | Valeur |
|----------|--------|
| Tests OK | $($script:totalOk) |
| Avertissements | $($script:totalWarn) |
| Erreurs | $($script:totalErr) |
| Total tests | $($script:totalOk + $script:totalWarn + $script:totalErr) |

"@

$fullReport = $summaryMd + "`n" + ($mdSections -join "`n`n") + @"

---

## Recommandations

"@

$recommendations = [System.Collections.ArrayList]::new()

if ($script:totalErr -gt 0) {
    [void]$recommendations.Add("- **Corriger les erreurs HTTP** : $($script:totalErr) endpoint(s) retournent un code inattendu. Voir les sections detaillees ci-dessus.")
}
if ($errorLogAnalysis.CountN3500 -gt 0 -or $errorLogAnalysis.CountFatal -gt 0) {
    [void]$recommendations.Add("- **Analyser error_log** : $($errorLogAnalysis.CountN3500) erreurs [n3 500] et $($errorLogAnalysis.CountFatal) PHP Fatal detectees. Consulter les derniers fichiers en erreur.")
}
if ($cronLogAnalysis.CountError -gt 0) {
    [void]$recommendations.Add("- **Analyser cronlog** : $($cronLogAnalysis.CountError) lignes [ERROR] detectees.")
}
if (-not $SkipSecurity) {
    if ($exposedCount -gt 0) {
        [void]$recommendations.Add("- **CRITIQUE : Fichiers sensibles exposes** - $exposedCount fichier(s) accessible(s) publiquement. Configurer .htaccess ou le serveur web pour bloquer l acces.")
    }
    if ($headersFound -lt 4) {
        [void]$recommendations.Add("- **Ajouter des headers de securite** : seulement $headersFound/$($secHeaders.Count) headers presents. Ajouter au minimum ``X-Content-Type-Options``, ``X-Frame-Options``, ``Strict-Transport-Security``.")
    }
    if ($errorLogExposed) {
        [void]$recommendations.Add("- **Restreindre l'acces aux logs** : ``error_log`` est accessible publiquement et contient des chemins serveur et traces PHP.")
    }
}
if ($count -gt 0 -and $slowPages.Count -gt 0) {
    [void]$recommendations.Add("- **Optimiser les pages lentes** : $($slowPages.Count) page(s) au-dessus de 3 secondes.")
}

if ($recommendations.Count -eq 0) {
    $fullReport += "Aucune recommandation critique. Le serveur fonctionne correctement.`n"
} else {
    $fullReport += ($recommendations -join "`n") + "`n"
}

$fullReport += "`n---`n*Rapport genere par ``scripts/audit-serveur-complet.ps1``*`n"

[System.IO.File]::WriteAllText($reportPath, $fullReport, [System.Text.UTF8Encoding]::new($false))
Write-Host "Rapport enregistre : $reportPath" -ForegroundColor Green
Write-Host "Termine." -ForegroundColor Cyan
