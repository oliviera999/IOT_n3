# inspect-chart-data.ps1
# Inspecte les données des graphiques Highcharts sur les pages météo et serre

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("meteo", "serre", "both")]
    [string]$Page = "both"
)

$ErrorActionPreference = "Continue"

Write-Host "`n=== Inspection des données de graphiques Highcharts ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

function Extract-JavaScriptVariable {
    param(
        [string]$Html,
        [string]$VarName
    )

    # Pattern pour extraire la variable JavaScript
    $pattern = "var\s+$VarName\s*=\s*(\[.*?\]);"
    if ($Html -match $pattern) {
        return $matches[1]
    }
    return $null
}

function Inspect-PageChartData {
    param(
        [string]$Url,
        [string]$PageName,
        [array]$ExpectedVars
    )

    Write-Host "📊 Inspection: $PageName" -ForegroundColor Yellow
    Write-Host "   URL: $Url`n" -ForegroundColor Gray

    try {
        # Récupérer le HTML de la page
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        $html = $response.Content

        Write-Host "   ✓ Page récupérée (HTTP $($response.StatusCode), $($html.Length) caractères)" -ForegroundColor Green

        # Extraire et analyser les variables de données
        Write-Host "`n   Variables de données:" -ForegroundColor Cyan

        $dataFound = $false
        foreach ($varName in $ExpectedVars) {
            $varData = Extract-JavaScriptVariable -Html $html -VarName $varName
            
            if ($varData) {
                # Compter les éléments dans le tableau
                $elementCount = ($varData -split ',').Count
                
                # Extraire un échantillon (premiers éléments)
                $sample = $varData
                if ($sample.Length -gt 100) {
                    $sample = $sample.Substring(0, 100) + "..."
                }

                Write-Host "      ✓ $varName : $elementCount éléments" -ForegroundColor Green
                Write-Host "        Échantillon: $sample" -ForegroundColor Gray
                $dataFound = $true
            } else {
                Write-Host "      ✗ $varName : NON TROUVÉE" -ForegroundColor Red
            }
        }

        # Vérifier measure_count
        Write-Host "`n   Statistiques:" -ForegroundColor Cyan
        if ($html -match 'measure_count\s*=\s*(\d+)') {
            $measureCount = $matches[1]
            Write-Host "      ✓ measure_count = $measureCount" -ForegroundColor Green
        } elseif ($html -match '(\d+)\s+mesures') {
            $measureCount = $matches[1]
            Write-Host "      ✓ Mesures affichées: $measureCount" -ForegroundColor Green
        } else {
            Write-Host "      ⚠ measure_count non trouvé" -ForegroundColor Yellow
        }

        # Vérifier les appels zipSeries
        Write-Host "`n   Appels zipSeries:" -ForegroundColor Cyan
        $zipSeriesCalls = [regex]::Matches($html, 'zipSeries\([^)]+\)')
        Write-Host "      ✓ $($zipSeriesCalls.Count) appels zipSeries() trouvés" -ForegroundColor Green
        
        if ($zipSeriesCalls.Count -gt 0) {
            Write-Host "      Exemples:" -ForegroundColor Gray
            for ($i = 0; $i -lt [Math]::Min(3, $zipSeriesCalls.Count); $i++) {
                $call = $zipSeriesCalls[$i].Value
                if ($call.Length -gt 80) {
                    $call = $call.Substring(0, 80) + "..."
                }
                Write-Host "        - $call" -ForegroundColor Gray
            }
        }

        # Résumé
        Write-Host "`n   Diagnostic:" -ForegroundColor Cyan
        if ($dataFound -and $zipSeriesCalls.Count -gt 0) {
            Write-Host "      ✓ Les données sont présentes et les graphiques sont initialisés" -ForegroundColor Green
            Write-Host "      → Les graphiques DEVRAIENT afficher des courbes de données" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Problème détecté avec les données ou l'initialisation" -ForegroundColor Red
            Write-Host "      → Les graphiques pourraient être vides" -ForegroundColor Red
        }

    } catch {
        Write-Host "   ✗ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

# Configuration des pages à tester
$pages = @{
    "meteo" = @{
        Name = "Météo (MSP1)"
        Url = "https://iot.olution.info/meteo"
        Vars = @("reading_time", "TempAirInt", "TempAirExt", "HumidAirInt", "HumidAirExt", "LuminositeMoy", "HumidSol", "TempEau")
    }
    "serre" = @{
        Name = "Serre (N3PP)"
        Url = "https://iot.olution.info/serre"
        Vars = @("reading_time", "TempAir", "Humidite", "Luminosite", "HumidMoy", "Humid1", "Humid2", "Humid3", "Humid4")
    }
}

# Tester les pages demandées
if ($Page -eq "both") {
    foreach ($pageKey in $pages.Keys) {
        $pageConfig = $pages[$pageKey]
        Inspect-PageChartData -Url $pageConfig.Url -PageName $pageConfig.Name -ExpectedVars $pageConfig.Vars
        Write-Host ("=" * 80) -ForegroundColor Gray
    }
} else {
    $pageConfig = $pages[$Page]
    Inspect-PageChartData -Url $pageConfig.Url -PageName $pageConfig.Name -ExpectedVars $pageConfig.Vars
}

Write-Host "`n=== Conclusion ===" -ForegroundColor Cyan
Write-Host @"

L'inspection automatique est terminée. Pour une vérification visuelle complète:

1. Ouvrez les pages dans un navigateur
2. Faites défiler jusqu'à la section "Graphiques"
3. Vérifiez visuellement que les courbes de données s'affichent
4. Si les graphiques sont vides, ouvrez la console développeur (F12) pour voir les erreurs JS

"@ -ForegroundColor Yellow

Write-Host "Script terminé.`n" -ForegroundColor Green
