# Script d'audit des pages IoT après clear du cache DI
# OBSOLETE : Preferer check-server-pages.ps1 ou audit-serveur-complet.ps1 (couverture complete).
# Date: 2026-03-09 | Pages: home, aquaponie data, aquaponie description

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

Write-Host "`n=== AUDIT DES PAGES IOT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Contexte: Cache DI vient d'être vidé`n" -ForegroundColor Gray

$results = @()
$tempDir = "$env:TEMP\iot_audit_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

foreach ($page in $pages) {
    Write-Host "=" * 80 -ForegroundColor DarkGray
    Write-Host "TEST: $($page.Name)" -ForegroundColor Yellow
    Write-Host "URL: $($page.Url)" -ForegroundColor Gray
    Write-Host ""
    
    $outputFile = Join-Path $tempDir "$($page.ShortName).html"
    $headerFile = Join-Path $tempDir "$($page.ShortName)_headers.txt"
    
    try {
        # 1. Récupérer les headers
        Write-Host "  [1/3] Récupération des headers..." -ForegroundColor Cyan
        $headerResponse = curl -I -s -L --max-time 30 $page.Url 2>&1
        $headerResponse | Out-File -FilePath $headerFile -Encoding UTF8
        
        # Parser le status code
        $statusLine = ($headerResponse | Select-String -Pattern "HTTP/[\d\.]+ (\d{3})" | Select-Object -First 1)
        if ($statusLine) {
            $statusCode = $statusLine.Matches.Groups[1].Value
            Write-Host "    Status HTTP: $statusCode" -ForegroundColor $(if ($statusCode -eq "200") { "Green" } elseif ($statusCode -eq "500") { "Red" } else { "Yellow" })
        } else {
            $statusCode = "UNKNOWN"
            Write-Host "    Status HTTP: INCONNU (timeout ou erreur réseau)" -ForegroundColor Red
        }
        
        # 2. Récupérer le contenu HTML
        Write-Host "  [2/3] Téléchargement du contenu HTML..." -ForegroundColor Cyan
        $htmlContent = curl -s -L --max-time 30 $page.Url 2>&1
        $htmlContent | Out-File -FilePath $outputFile -Encoding UTF8
        
        # 3. Analyser le contenu
        Write-Host "  [3/3] Analyse du contenu..." -ForegroundColor Cyan
        
        # Extraire le titre
        $titleMatch = [regex]::Match($htmlContent, '<title>([^<]+)</title>')
        $pageTitle = if ($titleMatch.Success) { $titleMatch.Groups[1].Value } else { "NON TROUVÉ" }
        Write-Host "    Titre: $pageTitle" -ForegroundColor Gray
        
        # Vérifier le CSS
        $cssLinks = [regex]::Matches($htmlContent, '<link[^>]*href="([^"]*\.css[^"]*)"')
        $cssCount = $cssLinks.Count
        Write-Host "    Fichiers CSS: $cssCount détecté(s)" -ForegroundColor Gray
        if ($cssCount -gt 0) {
            foreach ($css in $cssLinks | Select-Object -First 3) {
                Write-Host "      - $($css.Groups[1].Value)" -ForegroundColor DarkGray
            }
        }
        
        # Vérifier la navigation
        $navPresent = $htmlContent -match '<nav[\s>]' -or $htmlContent -match 'class="[^"]*nav'
        Write-Host "    Navigation: $(if ($navPresent) { '✓ Présente' } else { '✗ Non détectée' })" -ForegroundColor $(if ($navPresent) { "Green" } else { "Red" })
        
        # Vérifier les charts (Chart.js, canvas)
        $chartsPresent = $htmlContent -match 'Chart\.js|<canvas|chartjs'
        Write-Host "    Charts/Canvas: $(if ($chartsPresent) { '✓ Détecté' } else { '- Non détecté' })" -ForegroundColor $(if ($chartsPresent) { "Green" } else { "Gray" })
        
        # Vérifier les erreurs PHP visibles
        $phpErrors = [regex]::Matches($htmlContent, '(Fatal error|Warning|Notice|Parse error|Uncaught)')
        $errorCount = $phpErrors.Count
        Write-Host "    Erreurs PHP visibles: $errorCount" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
        if ($errorCount -gt 0) {
            foreach ($error in $phpErrors | Select-Object -First 3) {
                $errorContext = $htmlContent.Substring([Math]::Max(0, $error.Index - 50), [Math]::Min(100, $htmlContent.Length - [Math]::Max(0, $error.Index - 50)))
                Write-Host "      - $($error.Value): $($errorContext -replace '\s+', ' ')" -ForegroundColor Red
            }
        }
        
        # Vérifier les éléments cassés
        $brokenElements = [regex]::Matches($htmlContent, '(404|Not Found|File not found|undefined)')
        $brokenCount = $brokenElements.Count
        Write-Host "    Éléments potentiellement cassés: $brokenCount mention(s)" -ForegroundColor $(if ($brokenCount -eq 0) { "Green" } else { "Yellow" })
        
        # Taille du contenu
        $contentSize = $htmlContent.Length
        Write-Host "    Taille du contenu: $contentSize caractères" -ForegroundColor Gray
        
        $results += [PSCustomObject]@{
            Page = $page.Name
            URL = $page.Url
            Status = $statusCode
            Titre = $pageTitle
            CSS = $cssCount
            Navigation = $navPresent
            Charts = $chartsPresent
            ErreursVisibles = $errorCount
            TailleContenu = $contentSize
            FichierHTML = $outputFile
        }
        
    } catch {
        Write-Host "  ✗ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Page = $page.Name
            URL = $page.Url
            Status = "ERROR"
            Titre = "ERREUR"
            CSS = 0
            Navigation = $false
            Charts = $false
            ErreursVisibles = 0
            TailleContenu = 0
            FichierHTML = ""
        }
    }
    
    Write-Host ""
}

# Résumé final
Write-Host "=" * 80 -ForegroundColor DarkGray
Write-Host "`n=== RÉSUMÉ DE L'AUDIT ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Page, Status, Titre, CSS, Navigation, Charts, ErreursVisibles -AutoSize

Write-Host "`nFichiers HTML sauvegardés dans: $tempDir" -ForegroundColor Gray

# Analyse globale
$pagesOK = ($results | Where-Object { $_.Status -eq "200" }).Count
$totalPages = $results.Count
$pagesAvecErreurs = ($results | Where-Object { $_.ErreursVisibles -gt 0 }).Count

Write-Host "`n=== ANALYSE GLOBALE ===" -ForegroundColor Cyan
Write-Host "Pages accessibles (200): $pagesOK / $totalPages" -ForegroundColor $(if ($pagesOK -eq $totalPages) { "Green" } else { "Red" })
Write-Host "Pages avec erreurs visibles: $pagesAvecErreurs" -ForegroundColor $(if ($pagesAvecErreurs -eq 0) { "Green" } else { "Red" })

if ($pagesOK -eq $totalPages -and $pagesAvecErreurs -eq 0) {
    Write-Host "`n✓ AUDIT RÉUSSI: Toutes les pages sont accessibles et sans erreur visible." -ForegroundColor Green
} else {
    Write-Host "`n✗ AUDIT AVEC PROBLÈMES: Certaines pages nécessitent une attention." -ForegroundColor Red
}

Write-Host "`nFin de l'audit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
