# Test des API temps réel N3PP / MSP (vérification que les endpoints répondent correctement)
# Usage: .\scripts\test-realtime-api.ps1 [-BaseUrl "http://localhost:8080"] [-Context "n3pp"|"msp1"]

param(
    [string]$BaseUrl = "http://localhost:8080",
    [ValidateSet("n3pp", "msp1")]
    [string]$Context = "n3pp"
)

$prefix = if ($Context -eq "msp1") { "/msp1/api/realtime" } else { "/n3pp/api/realtime" }
$base = $BaseUrl.TrimEnd("/")

Write-Host "=== Test API temps réel $Context ===" -ForegroundColor Cyan
Write-Host "Base: $base$prefix"
Write-Host ""

# 1. sensors/latest
Write-Host "1. GET $prefix/sensors/latest" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod -Uri "$base$prefix/sensors/latest" -Method Get
    Write-Host "   timestamp: $($r.timestamp)"
    Write-Host "   reading_time: $($r.reading_time)"
    Write-Host "   sensors (cles): $($r.sensors.PSObject.Properties.Name -join ', ')"
    if ($r.sensors -and ($r.sensors.PSObject.Properties | Measure-Object).Count -eq 0) {
        Write-Host "   (sensors vide - pas de donnees en BDD)" -ForegroundColor Gray
    }
    $lastTs = $r.timestamp
} catch {
    Write-Host "   ERREUR: $_" -ForegroundColor Red
    $lastTs = [int][double]::Parse((Get-Date -UFormat %s)) - 3600
}

# 2. sensors/since (timestamp il y a 1h)
$since = $lastTs - 3600
if ($since -lt 1) { $since = 1 }
Write-Host ""
Write-Host "2. GET $prefix/sensors/since/$since" -ForegroundColor Yellow
try {
    $r2 = Invoke-RestMethod -Uri "$base$prefix/sensors/since/$since" -Method Get
    Write-Host "   count: $($r2.count)"
    Write-Host "   readings: $($r2.readings.Count) element(s)"
    if ($r2.readings -and $r2.readings.Count -gt 0) {
        $first = $r2.readings[0]
        Write-Host "   premiere lecture: timestamp=$($first.timestamp), sensors presentes"
    }
} catch {
    Write-Host "   ERREUR: $_" -ForegroundColor Red
}

# 3. system/health
Write-Host ""
Write-Host "3. GET $prefix/system/health" -ForegroundColor Yellow
try {
    $h = Invoke-RestMethod -Uri "$base$prefix/system/health" -Method Get
    Write-Host "   online: $($h.online)"
    Write-Host "   last_reading_ago_seconds: $($h.last_reading_ago_seconds)"
    Write-Host "   readings_today: $($h.readings_today)"
} catch {
    Write-Host "   ERREUR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Fin test ===" -ForegroundColor Cyan
Write-Host "Pour tester en local: php -S localhost:8080 -t public (depuis serveur/) puis relancer avec -BaseUrl http://localhost:8080"
