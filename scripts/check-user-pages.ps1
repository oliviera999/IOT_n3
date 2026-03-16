# Script pour verifier les pages specifiques demandees par l'utilisateur
$ErrorActionPreference = 'Stop'

$baseUrl = 'https://iot.olution.info'
$pagesToCheck = @(
    @{ Name = 'Home page'; Url = '/' },
    @{ Name = 'Aquaponie landscape view'; Url = '/aquaponie' },
    @{ Name = 'Aquaponie classic view'; Url = '/aquaponie-alt' },
    @{ Name = 'MSP1 weather data'; Url = '/msp1/msp1datas/msp1-data.php' },
    @{ Name = 'N3PP greenhouse data'; Url = '/n3pp/n3ppdatas/n3pp-data.php' },
    @{ Name = 'MSP1 photo gallery'; Url = '/gallery/msp1' },
    @{ Name = 'N3PP photo gallery'; Url = '/gallery/n3pp' },
    @{ Name = 'FFP3 photo gallery'; Url = '/gallery/ffp3' }
)

Write-Host "=== Verification des pages IoT ===" -ForegroundColor Cyan
Write-Host "Serveur : $baseUrl" -ForegroundColor Gray
Write-Host ""

$results = @()

foreach ($page in $pagesToCheck) {
    $url = $baseUrl + $page.Url
    Write-Host "Verification : $($page.Name)" -ForegroundColor Yellow
    Write-Host "  URL : $url" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $statusCode = $response.StatusCode
        $contentLength = $response.Content.Length
        
        # Verifier la presence de certains elements dans le contenu
        $hasNav = $response.Content -match '<nav|class="nav|id="nav'
        $hasFooter = $response.Content -match '<footer|class="footer|id="footer'
        $hasError = $response.Content -match 'error|Error|ERROR|Fatal|Exception'
        
        $result = [PSCustomObject]@{
            Name = $page.Name
            Url = $url
            StatusCode = $statusCode
            ContentLength = $contentLength
            HasNav = $hasNav
            HasFooter = $hasFooter
            HasError = $hasError
            Success = $true
            ErrorMessage = $null
        }
        
        Write-Host "  Status : $statusCode" -ForegroundColor Green
        Write-Host "  Taille contenu : $contentLength octets" -ForegroundColor Gray
        Write-Host "  Navigation : $(if($hasNav){'Oui'}else{'Non'})" -ForegroundColor $(if($hasNav){'Green'}else{'Red'})
        Write-Host "  Footer : $(if($hasFooter){'Oui'}else{'Non'})" -ForegroundColor $(if($hasFooter){'Green'}else{'Red'})
        Write-Host "  Erreurs dans le contenu : $(if($hasError){'Oui'}else{'Non'})" -ForegroundColor $(if($hasError){'Red'}else{'Green'})
        
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        $errorMsg = $_.Exception.Message
        
        $result = [PSCustomObject]@{
            Name = $page.Name
            Url = $url
            StatusCode = $statusCode
            ContentLength = 0
            HasNav = $false
            HasFooter = $false
            HasError = $true
            Success = $false
            ErrorMessage = $errorMsg
        }
        
        Write-Host "  Status : $statusCode" -ForegroundColor Red
        Write-Host "  Erreur : $errorMsg" -ForegroundColor Red
    }
    
    $results += $result
    Write-Host ""
}

# Resume
Write-Host "=== RESUME ===" -ForegroundColor Cyan
$successCount = ($results | Where-Object { $_.Success -and $_.StatusCode -eq 200 }).Count
$errorCount = ($results | Where-Object { -not $_.Success -or $_.StatusCode -ne 200 }).Count

Write-Host "Pages OK (200) : $successCount / $($results.Count)" -ForegroundColor $(if($successCount -eq $results.Count){'Green'}else{'Yellow'})
Write-Host "Pages en erreur : $errorCount / $($results.Count)" -ForegroundColor $(if($errorCount -gt 0){'Red'}else{'Green'})
Write-Host ""

# Details des erreurs
if ($errorCount -gt 0) {
    Write-Host "=== PAGES EN ERREUR ===" -ForegroundColor Red
    foreach ($r in ($results | Where-Object { -not $_.Success -or $_.StatusCode -ne 200 })) {
        Write-Host "- $($r.Name) : HTTP $($r.StatusCode)" -ForegroundColor Red
        Write-Host "  $($r.Url)" -ForegroundColor Gray
        if ($r.ErrorMessage) {
            Write-Host "  Erreur : $($r.ErrorMessage)" -ForegroundColor Gray
        }
    }
}

# Export JSON
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$reportPath = "scripts/reports/user-pages-check-$timestamp.json"
$results | ConvertTo-Json -Depth 3 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host ""
Write-Host "Rapport JSON : $reportPath" -ForegroundColor Green
