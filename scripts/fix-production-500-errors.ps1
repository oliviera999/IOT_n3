# Script de correction des erreurs 500 sur le serveur de production
# Vide le cache DI compilé et teste les pages

param(
    [switch]$TestOnly,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Correction des erreurs 500 - Serveur IoT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Configuration
$serverUrl = "https://iot.olution.info"
$clearCacheUrl = "$serverUrl/admin/clear-cache-page"

# Fonction de test d'une page
function Test-Page {
    param(
        [string]$Url,
        [string]$Name,
        [int]$ExpectedStatus = 200
    )
    
    Write-Host "Test: $Name" -ForegroundColor Yellow
    Write-Host "  URL: $Url" -ForegroundColor Gray
    
    try {
        $response = curl -I -s --max-time 10 $Url 2>&1
        $statusLine = ($response | Select-String -Pattern "HTTP/\d\.\d (\d{3})" | Select-Object -First 1).Matches.Groups[1].Value
        
        if ($statusLine -eq $ExpectedStatus -or ($statusLine -eq "302" -and $ExpectedStatus -eq 200)) {
            Write-Host "  ✓ Status: $statusLine" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Status: $statusLine (attendu: $ExpectedStatus)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ✗ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test initial
Write-Host "=== Test initial ===" -ForegroundColor Cyan
$initialTests = @(
    @{ Url = "$serverUrl/meteo"; Name = "Méteo" },
    @{ Url = "$serverUrl/serre"; Name = "Serre" }
)

$allOk = $true
foreach ($test in $initialTests) {
    $result = Test-Page -Url $test.Url -Name $test.Name
    if (-not $result) { $allOk = $false }
}

if ($allOk) {
    Write-Host "`n✓ Toutes les pages fonctionnent correctement." -ForegroundColor Green
    Write-Host "Aucune action nécessaire." -ForegroundColor Green
    exit 0
}

if ($TestOnly) {
    Write-Host "`nMode test uniquement. Arrêt." -ForegroundColor Yellow
    exit 1
}

# Correction : vider le cache DI via l'interface admin
Write-Host "`n=== Correction : vidage du cache DI ===" -ForegroundColor Cyan
Write-Host "Tentative de vidage du cache via l'interface admin..." -ForegroundColor Yellow
Write-Host "URL: $clearCacheUrl" -ForegroundColor Gray

try {
    $response = curl -s --max-time 15 $clearCacheUrl 2>&1
    
    if ($response -match "Cache vidé|Cache cleared|success") {
        Write-Host "✓ Cache vidé avec succès via l'interface admin" -ForegroundColor Green
    } else {
        Write-Host "⚠ Réponse inattendue de l'interface admin" -ForegroundColor Yellow
        if ($Verbose) {
            Write-Host "Réponse: $response" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "✗ Erreur lors du vidage du cache via l'interface admin" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n⚠ Action manuelle requise (au choix) :" -ForegroundColor Yellow
    Write-Host "  a. Via HTTP (sans SSH) : https://iot.olution.info/public/maintenance/clear-di-cache.php" -ForegroundColor White
    Write-Host "     (vide var/cache/di et var/cache/twig, puis opcache_reset)" -ForegroundColor Gray
    Write-Host "  b. Via SSH : rm -rf /home4/oliviera/iot.olution.info/var/cache/di/*" -ForegroundColor White
    Write-Host "  Puis testez : https://iot.olution.info/meteo" -ForegroundColor White
    exit 1
}

# Attendre quelques secondes pour que le cache soit bien vidé
Write-Host "`nAttente de 5 secondes..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Test après correction
Write-Host "`n=== Test après correction ===" -ForegroundColor Cyan
$postTests = @(
    @{ Url = "$serverUrl/meteo"; Name = "Méteo" },
    @{ Url = "$serverUrl/serre"; Name = "Serre" },
    @{ Url = "$serverUrl/meteo-control"; Name = "Méteo Control"; ExpectedStatus = 302 },
    @{ Url = "$serverUrl/serre-control"; Name = "Serre Control"; ExpectedStatus = 302 }
)

$allOk = $true
foreach ($test in $postTests) {
    $expectedStatus = if ($test.ExpectedStatus) { $test.ExpectedStatus } else { 200 }
    $result = Test-Page -Url $test.Url -Name $test.Name -ExpectedStatus $expectedStatus
    if (-not $result) { $allOk = $false }
}

# Résumé
Write-Host "`n=== Résumé ===" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "✓ Toutes les pages fonctionnent correctement après correction." -ForegroundColor Green
    Write-Host "Le problème est résolu." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Certaines pages sont toujours en erreur." -ForegroundColor Red
    Write-Host "`n⚠ Actions supplémentaires requises :" -ForegroundColor Yellow
    Write-Host "  1. Vérifier les logs d'erreur : tail -100 serveur/error_log" -ForegroundColor White
    Write-Host "  2. Vérifier le fichier .env : cat serveur/.env" -ForegroundColor White
    Write-Host "  3. Tester la connexion BDD : php serveur/test-db.php" -ForegroundColor White
    Write-Host "  4. Consulter le rapport détaillé : docs/rapport_test_pages_2026-03-09_erreurs_500.md" -ForegroundColor White
    exit 1
}
