<#
.SYNOPSIS
    Corrige le problème de cache DI sur le serveur de production

.DESCRIPTION
    Ce script déploie le script de maintenance clear-di-cache.php sur le serveur,
    l'exécute via HTTP pour vider le cache DI compilé, puis vérifie que les pages
    fonctionnent à nouveau.

.PARAMETER SkipDeploy
    Ne pas déployer le script de maintenance (si déjà présent sur le serveur)

.PARAMETER SkipVerify
    Ne pas vérifier les pages après le nettoyage du cache

.EXAMPLE
    .\scripts\fix-di-cache-prod.ps1

.EXAMPLE
    .\scripts\fix-di-cache-prod.ps1 -SkipDeploy
#>

[CmdletBinding()]
param(
    [switch]$SkipDeploy,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

$baseUrl = 'https://iot.olution.info'
# DocumentRoot = racine dépôt ; fichiers public/ accessibles via /public/
$maintenanceScript = 'public/maintenance/clear-di-cache.php'
$maintenanceUrl = "$baseUrl/$maintenanceScript"

Write-Host "=== Correction du cache DI sur le serveur de production ===" -ForegroundColor Cyan
Write-Host ""

# Étape 1 : Déployer le script de maintenance
if (-not $SkipDeploy) {
    Write-Host "Étape 1 : Déploiement du script de maintenance" -ForegroundColor Yellow
    Write-Host "  ATTENTION : Ce script nécessite un accès FTP/SSH au serveur" -ForegroundColor Gray
    Write-Host "  Le script de maintenance a été créé dans :" -ForegroundColor Gray
    Write-Host "    serveur/public/maintenance/clear-di-cache.php" -ForegroundColor White
    Write-Host ""
    Write-Host "  Actions requises :" -ForegroundColor Gray
    Write-Host "    1. Se connecter au serveur via FTP/SSH" -ForegroundColor Gray
    Write-Host "    2. Uploader le fichier vers : /public/maintenance/clear-di-cache.php" -ForegroundColor Gray
    Write-Host "    3. Vérifier les permissions (chmod 644)" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "  Le script a-t-il été déployé sur le serveur ? (o/n)"
    if ($response -ne 'o' -and $response -ne 'O') {
        Write-Host "Déploiement annulé. Déployez le script puis relancez avec -SkipDeploy" -ForegroundColor Yellow
        exit 0
    }
}

# Étape 2 : Exécuter le script de maintenance via HTTP
Write-Host ""
Write-Host "Étape 2 : Exécution du script de maintenance" -ForegroundColor Yellow
Write-Host "  URL : $maintenanceUrl" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri $maintenanceUrl -Method Get -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    
    Write-Host "  Status : $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Sortie du script de maintenance ===" -ForegroundColor Cyan
    Write-Host $response.Content
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($response.StatusCode -eq 200) {
        Write-Host ""
        Write-Host "✓ Cache DI vidé avec succès" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ ERREUR lors de l'exécution du script" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Solutions alternatives :" -ForegroundColor Yellow
    Write-Host "    1. Vérifier que le script est bien uploadé sur le serveur" -ForegroundColor Gray
    Write-Host "    2. Accéder manuellement à : $maintenanceUrl" -ForegroundColor Gray
    Write-Host "    3. Ou en SSH : rm -f /home4/oliviera/iot.olution.info/var/cache/di/CompiledContainer.php" -ForegroundColor Gray
    exit 1
}

# Étape 3 : Vérifier que les pages fonctionnent
if (-not $SkipVerify) {
    Write-Host ""
    Write-Host "Étape 3 : Vérification des pages" -ForegroundColor Yellow
    
    $pagesToCheck = @(
        @{ Name = 'Aquaponie landscape'; Url = '/aquaponie' },
        @{ Name = 'Aquaponie classic'; Url = '/aquaponie-alt' },
        @{ Name = 'MSP1 data'; Url = '/msp1/msp1datas/msp1-data.php' },
        @{ Name = 'N3PP data'; Url = '/n3pp/n3ppdatas/n3pp-data.php' }
    )
    
    $allOk = $true
    foreach ($page in $pagesToCheck) {
        $url = $baseUrl + $page.Url
        Write-Host "  Vérification : $($page.Name) ... " -NoNewline
        
        try {
            $resp = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                Write-Host "OK (200)" -ForegroundColor Green
            } else {
                Write-Host "⚠ $($resp.StatusCode)" -ForegroundColor Yellow
                $allOk = $false
            }
        } catch {
            $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            Write-Host "✗ ERREUR ($code)" -ForegroundColor Red
            $allOk = $false
        }
    }
    
    Write-Host ""
    if ($allOk) {
        Write-Host "✓ Toutes les pages fonctionnent correctement" -ForegroundColor Green
    } else {
        Write-Host "⚠ Certaines pages ont encore des problèmes" -ForegroundColor Yellow
        Write-Host "  Consulter le cronlog : https://iot.olution.info/public/cronlog.txt" -ForegroundColor Gray
    }
}

# Étape 4 : Rappel de sécurité
Write-Host ""
Write-Host "=== IMPORTANT : Sécurité ===" -ForegroundColor Red
Write-Host "Le script de maintenance doit être supprimé du serveur :" -ForegroundColor Yellow
Write-Host "  rm /home4/oliviera/iot.olution.info/public/maintenance/clear-di-cache.php" -ForegroundColor White
Write-Host ""
Write-Host "Ou via FTP : supprimer le fichier public/maintenance/clear-di-cache.php" -ForegroundColor White
Write-Host ""

Write-Host "=== Correction terminée ===" -ForegroundColor Cyan
