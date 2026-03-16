# Script de test des pages IoT avec curl
# Teste les nouvelles URLs unifiées et les redirections legacy

$pages = @(
    @{
        Name = "Méteo (nouvelle URL)"
        Url = "https://iot.olution.info/meteo"
        ExpectedStatus = 200
    },
    @{
        Name = "Méteo Control"
        Url = "https://iot.olution.info/meteo-control"
        ExpectedStatus = 302  # Redirection vers login si non authentifié
    },
    @{
        Name = "Serre (nouvelle URL)"
        Url = "https://iot.olution.info/serre"
        ExpectedStatus = 200
    },
    @{
        Name = "Serre Control"
        Url = "https://iot.olution.info/serre-control"
        ExpectedStatus = 302  # Redirection vers login si non authentifié
    },
    @{
        Name = "Redirection MSP1 legacy"
        Url = "https://iot.olution.info/msp1/msp1datas/msp1-data.php"
        ExpectedStatus = 301
        ExpectedLocation = "/meteo"
    },
    @{
        Name = "Redirection N3PP legacy"
        Url = "https://iot.olution.info/n3pp/n3ppdatas/n3pp-data.php"
        ExpectedStatus = 301
        ExpectedLocation = "/serre"
    }
)

Write-Host "`n=== Test des pages IoT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

$results = @()

foreach ($page in $pages) {
    Write-Host "Test: $($page.Name)" -ForegroundColor Yellow
    Write-Host "  URL: $($page.Url)" -ForegroundColor Gray
    
    try {
        # Récupérer les headers sans suivre les redirections
        $response = curl -I -s --max-time 10 $page.Url 2>&1
        
        # Parser le status code
        $statusLine = ($response | Select-String -Pattern "HTTP/\d\.\d (\d{3})" | Select-Object -First 1).Matches.Groups[1].Value
        
        # Parser la location si présente
        $location = ($response | Select-String -Pattern "Location: (.+)" | Select-Object -First 1).Matches.Groups[1].Value
        if ($location) {
            $location = $location.Trim()
        }
        
        # Vérifier le résultat
        $success = $statusLine -eq $page.ExpectedStatus
        if ($page.ExpectedLocation -and $location) {
            $success = $success -and ($location -eq $page.ExpectedLocation)
        }
        
        if ($success) {
            Write-Host "  ✓ Status: $statusLine" -ForegroundColor Green
            if ($location) {
                Write-Host "  ✓ Location: $location" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ Status: $statusLine (attendu: $($page.ExpectedStatus))" -ForegroundColor Red
            if ($page.ExpectedLocation) {
                Write-Host "  ✗ Location: $location (attendu: $($page.ExpectedLocation))" -ForegroundColor Red
            }
        }
        
        $results += [PSCustomObject]@{
            Page = $page.Name
            Status = $statusLine
            Expected = $page.ExpectedStatus
            Success = $success
            Location = $location
        }
        
    } catch {
        Write-Host "  ✗ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Page = $page.Name
            Status = "ERROR"
            Expected = $page.ExpectedStatus
            Success = $false
            Location = ""
        }
    }
    
    Write-Host ""
}

# Résumé
Write-Host "`n=== Résumé ===" -ForegroundColor Cyan
$successCount = ($results | Where-Object { $_.Success }).Count
$totalCount = $results.Count
Write-Host "Tests réussis: $successCount / $totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })

# Afficher les échecs
$failures = $results | Where-Object { -not $_.Success }
if ($failures) {
    Write-Host "`nÉchecs:" -ForegroundColor Red
    $failures | Format-Table -AutoSize
}
