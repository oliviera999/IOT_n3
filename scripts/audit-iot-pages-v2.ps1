# Script d'audit des pages IoT avec Invoke-WebRequest
# OBSOLETE : Preferer check-server-pages.ps1 ou audit-serveur-complet.ps1 (couverture complete).
# Date: 2026-03-09 | Alternative curl pour contourner timeouts

$pages = @(
    @{
        Name = "Page d'accueil"
        Url = "https://iot.olution.info/"
        ShortName = "home"
    },
    @{
        Name = "Aquaponie - Données"
        Url = "https://iot.olution.info/aquaponie"
        ShortName = "aquaponie"
    },
    @{
        Name = "Aquaponie - Description"
        Url = "https://iot.olution.info/aquaponie-description"
        ShortName = "aquaponie-description"
    }
)

Write-Host "`n=== AUDIT DES PAGES IOT (Invoke-WebRequest) ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Contexte: Cache DI vient d'être vidé`n" -ForegroundColor Gray

# Désactiver la vérification SSL si nécessaire (pour debug)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$results = @()
$tempDir = "$env:TEMP\iot_audit_v2_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

foreach ($page in $pages) {
    Write-Host "=" * 80 -ForegroundColor DarkGray
    Write-Host "TEST: $($page.Name)" -ForegroundColor Yellow
    Write-Host "URL: $($page.Url)" -ForegroundColor Gray
    Write-Host ""
    
    $outputFile = Join-Path $tempDir "$($page.ShortName).html"
    
    try {
        Write-Host "  Requête HTTP en cours..." -ForegroundColor Cyan
        
        $response = Invoke-WebRequest -Uri $page.Url -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        
        $statusCode = $response.StatusCode
        Write-Host "  ✓ Status HTTP: $statusCode" -ForegroundColor Green
        
        # Sauvegarder le contenu
        $htmlContent = $response.Content
        $htmlContent | Out-File -FilePath $outputFile -Encoding UTF8
        
        # Analyser le contenu
        Write-Host "  Analyse du contenu..." -ForegroundColor Cyan
        
        # Titre
        $titleMatch = [regex]::Match($htmlContent, '<title>([^<]+)</title>')
        $pageTitle = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { "NON TROUVÉ" }
        Write-Host "    Titre: '$pageTitle'" -ForegroundColor Gray
        
        # CSS
        $cssLinks = [regex]::Matches($htmlContent, '<link[^>]*href="([^"]*\.css[^"]*)"')
        $cssCount = $cssLinks.Count
        Write-Host "    Fichiers CSS: $cssCount détecté(s)" -ForegroundColor $(if ($cssCount -gt 0) { "Green" } else { "Yellow" })
        if ($cssCount -gt 0) {
            foreach ($css in $cssLinks | Select-Object -First 5) {
                Write-Host "      - $($css.Groups[1].Value)" -ForegroundColor DarkGray
            }
        }
        
        # Navigation
        $navPresent = $htmlContent -match '<nav[\s>]' -or $htmlContent -match 'class="[^"]*nav[^"]*"'
        Write-Host "    Navigation: $(if ($navPresent) { '✓ Présente' } else { '✗ Non détectée' })" -ForegroundColor $(if ($navPresent) { "Green" } else { "Red" })
        
        # Charts
        $chartsPresent = $htmlContent -match 'Chart\.js|<canvas|chartjs|chart-container'
        Write-Host "    Charts/Canvas: $(if ($chartsPresent) { '✓ Détecté' } else { '- Non détecté' })" -ForegroundColor $(if ($chartsPresent) { "Green" } else { "Gray" })
        
        # Erreurs PHP
        $phpErrors = [regex]::Matches($htmlContent, '(Fatal error|Warning:|Notice:|Parse error|Uncaught Exception)')
        $errorCount = $phpErrors.Count
        Write-Host "    Erreurs PHP visibles: $errorCount" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
        if ($errorCount -gt 0) {
            foreach ($error in $phpErrors | Select-Object -First 3) {
                $startIdx = [Math]::Max(0, $error.Index - 30)
                $length = [Math]::Min(150, $htmlContent.Length - $startIdx)
                $errorContext = $htmlContent.Substring($startIdx, $length) -replace '\s+', ' '
                Write-Host "      ! $errorContext" -ForegroundColor Red
            }
        }
        
        # Erreur 500 dans le contenu
        $has500Error = $htmlContent -match '500 Internal Server Error|HTTP 500'
        if ($has500Error) {
            Write-Host "    ⚠ ERREUR 500 détectée dans le contenu!" -ForegroundColor Red
        }
        
        # Taille
        $contentSize = $htmlContent.Length
        Write-Host "    Taille: $([Math]::Round($contentSize / 1024, 2)) Ko ($contentSize caractères)" -ForegroundColor Gray
        
        # Vérifier si le contenu est trop court (page d'erreur?)
        if ($contentSize -lt 500) {
            Write-Host "    ⚠ Contenu très court - possiblement une page d'erreur" -ForegroundColor Yellow
        }
        
        $results += [PSCustomObject]@{
            Page = $page.Name
            URL = $page.Url
            Status = $statusCode
            Titre = $pageTitle
            CSS = $cssCount
            Navigation = $navPresent
            Charts = $chartsPresent
            ErreursVisibles = $errorCount
            Erreur500 = $has500Error
            TailleKo = [Math]::Round($contentSize / 1024, 2)
            FichierHTML = $outputFile
        }
        
    } catch {
        Write-Host "  ✗ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
        
        # Essayer de capturer plus de détails
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "    Status Code: $statusCode" -ForegroundColor Red
        } else {
            $statusCode = "ERROR"
        }
        
        $results += [PSCustomObject]@{
            Page = $page.Name
            URL = $page.Url
            Status = $statusCode
            Titre = "ERREUR: $($_.Exception.Message)"
            CSS = 0
            Navigation = $false
            Charts = $false
            ErreursVisibles = 0
            Erreur500 = $false
            TailleKo = 0
            FichierHTML = ""
        }
    }
    
    Write-Host ""
}

# Résumé
Write-Host "=" * 80 -ForegroundColor DarkGray
Write-Host "`n=== RÉSUMÉ DE L'AUDIT ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Page, Status, Titre, CSS, Navigation, Charts, ErreursVisibles, Erreur500, TailleKo -AutoSize

Write-Host "`nFichiers HTML sauvegardés dans: $tempDir" -ForegroundColor Gray

# Analyse
$pagesOK = ($results | Where-Object { $_.Status -eq 200 }).Count
$pages500 = ($results | Where-Object { $_.Status -eq 500 -or $_.Erreur500 }).Count
$totalPages = $results.Count

Write-Host "`n=== ANALYSE GLOBALE ===" -ForegroundColor Cyan
Write-Host "Pages accessibles (200): $pagesOK / $totalPages" -ForegroundColor $(if ($pagesOK -eq $totalPages) { "Green" } else { "Red" })
Write-Host "Pages avec erreur 500: $pages500" -ForegroundColor $(if ($pages500 -eq 0) { "Green" } else { "Red" })
Write-Host "Pages avec erreurs PHP visibles: $(($results | Where-Object { $_.ErreursVisibles -gt 0 }).Count)" -ForegroundColor Gray

if ($pagesOK -eq $totalPages -and $pages500 -eq 0) {
    Write-Host "`n✓ AUDIT RÉUSSI: Toutes les pages sont accessibles." -ForegroundColor Green
} elseif ($pages500 -gt 0) {
    Write-Host "`n✗ AUDIT CRITIQUE: Erreurs 500 détectées!" -ForegroundColor Red
} else {
    Write-Host "`n⚠ AUDIT AVEC PROBLÈMES: Certaines pages nécessitent une attention." -ForegroundColor Yellow
}

Write-Host "`nFin de l'audit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Retourner le code de sortie approprié
if ($pages500 -gt 0) {
    exit 2  # Erreurs critiques
} elseif ($pagesOK -ne $totalPages) {
    exit 1  # Problèmes
} else {
    exit 0  # OK
}
