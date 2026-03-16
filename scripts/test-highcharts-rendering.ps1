# test-highcharts-rendering.ps1
# Vérifie le rendu des graphiques Highcharts sur les pages météo et serre

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

Write-Host "`n=== Test de rendu des graphiques Highcharts ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

$pages = @(
    @{
        Name = "Météo (MSP1)"
        Url = "https://iot.olution.info/meteo"
        ExpectedCharts = @(
            "chart-temperatures",
            "chart-lights",
            "chart-niveauxeaux",
            "chart-cycles"
        )
        ChartTitles = @(
            "Températures & Humidité",
            "Luminosité",
            "Humidité du sol & Eau",
            "Autonomie & Système"
        )
    },
    @{
        Name = "Serre (N3PP)"
        Url = "https://iot.olution.info/serre"
        ExpectedCharts = @(
            "chart-niveauxeaux",
            "chart-temperatures",
            "chart-cycles"
        )
        ChartTitles = @(
            "Humidité du sol",
            "Température, Humidité air & Luminosité",
            "Autonomie & Système"
        )
    }
)

function Test-PageHighcharts {
    param(
        [string]$Url,
        [string]$PageName,
        [array]$ExpectedCharts,
        [array]$ChartTitles
    )

    Write-Host "📊 Test de: $PageName" -ForegroundColor Yellow
    Write-Host "   URL: $Url" -ForegroundColor Gray

    try {
        # Récupérer le HTML de la page
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        $html = $response.Content

        Write-Host "   ✓ Page accessible (HTTP $($response.StatusCode))" -ForegroundColor Green

        # Vérifier la présence de Highcharts
        $hasHighchartsLib = $html -match 'highstock\.js|highcharts\.js'
        if ($hasHighchartsLib) {
            Write-Host "   ✓ Bibliothèque Highcharts chargée" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Bibliothèque Highcharts NON trouvée" -ForegroundColor Red
        }

        # Vérifier la présence de highcharts-defaults.js
        $hasDefaultsJs = $html -match 'highcharts-defaults\.js'
        if ($hasDefaultsJs) {
            Write-Host "   ✓ highcharts-defaults.js chargé" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ highcharts-defaults.js NON trouvé" -ForegroundColor Yellow
        }

        # Vérifier la présence de chart-helpers.js
        $hasHelpersJs = $html -match 'chart-helpers\.js'
        if ($hasHelpersJs) {
            Write-Host "   ✓ chart-helpers.js chargé" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ chart-helpers.js NON trouvé" -ForegroundColor Yellow
        }

        # Vérifier la présence de la fonction zipSeries
        $hasZipSeries = $html -match 'function zipSeries|zipSeries\('
        if ($hasZipSeries) {
            Write-Host "   ✓ Fonction zipSeries présente" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Fonction zipSeries NON trouvée" -ForegroundColor Red
        }

        # Vérifier les conteneurs de graphiques
        Write-Host "`n   Conteneurs de graphiques:" -ForegroundColor Cyan
        $allContainersFound = $true
        foreach ($chartId in $ExpectedCharts) {
            $pattern = "id=`"$chartId`""
            if ($html -match $pattern) {
                Write-Host "      ✓ #$chartId trouvé" -ForegroundColor Green
            } else {
                Write-Host "      ✗ #$chartId MANQUANT" -ForegroundColor Red
                $allContainersFound = $false
            }
        }

        # Vérifier les appels Highcharts.stockChart
        Write-Host "`n   Initialisation des graphiques:" -ForegroundColor Cyan
        $allChartsInitialized = $true
        foreach ($chartId in $ExpectedCharts) {
            $pattern = "Highcharts\.stockChart\('$chartId'"
            if ($html -match $pattern) {
                Write-Host "      ✓ Highcharts.stockChart('$chartId') trouvé" -ForegroundColor Green
            } else {
                Write-Host "      ✗ Highcharts.stockChart('$chartId') MANQUANT" -ForegroundColor Red
                $allChartsInitialized = $false
            }
        }

        # Vérifier la présence de données
        Write-Host "`n   Données de séries:" -ForegroundColor Cyan
        $hasReadingTime = $html -match 'var reading_time\s*=\s*\['
        if ($hasReadingTime) {
            Write-Host "      ✓ Variable reading_time présente" -ForegroundColor Green
            
            # Extraire un échantillon de reading_time pour vérifier si elle contient des données
            if ($html -match 'var reading_time\s*=\s*(\[[^\]]*\])') {
                $readingTimeContent = $matches[1]
                if ($readingTimeContent.Length -gt 10) {
                    Write-Host "      ✓ reading_time contient des données" -ForegroundColor Green
                } else {
                    Write-Host "      ⚠ reading_time semble vide" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "      ✗ Variable reading_time MANQUANTE" -ForegroundColor Red
        }

        # Vérifier measure_count
        if ($html -match 'measure_count\s*>\s*0') {
            Write-Host "      ✓ Condition measure_count > 0 présente" -ForegroundColor Green
        } else {
            Write-Host "      ⚠ Condition measure_count > 0 non trouvée" -ForegroundColor Yellow
        }

        # Résumé
        Write-Host "`n   Résumé:" -ForegroundColor Cyan
        if ($hasHighchartsLib -and $allContainersFound -and $allChartsInitialized -and $hasReadingTime) {
            Write-Host "      ✓ Tous les éléments nécessaires sont présents" -ForegroundColor Green
            Write-Host "      → Les graphiques DEVRAIENT s'afficher correctement" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Des éléments sont manquants" -ForegroundColor Red
            Write-Host "      → Les graphiques pourraient NE PAS s'afficher" -ForegroundColor Red
        }

        if ($Verbose) {
            Write-Host "`n   Détails supplémentaires:" -ForegroundColor Gray
            Write-Host "      Taille HTML: $($html.Length) caractères" -ForegroundColor Gray
            Write-Host "      Headers Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Gray
        }

    } catch {
        Write-Host "   ✗ ERREUR lors du test: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

# Tester chaque page
foreach ($page in $pages) {
    Test-PageHighcharts -Url $page.Url -PageName $page.Name -ExpectedCharts $page.ExpectedCharts -ChartTitles $page.ChartTitles
    Write-Host ("=" * 80) -ForegroundColor Gray
}

Write-Host "`n=== Instructions pour vérification visuelle ===" -ForegroundColor Cyan
Write-Host @"

Ce script a vérifié la présence des éléments nécessaires au rendu des graphiques.
Pour une vérification visuelle complète, ouvrez les pages dans un navigateur:

1. https://iot.olution.info/meteo
   - Faites défiler jusqu'à la section "Graphiques"
   - Vérifiez que 4 graphiques s'affichent avec des courbes de données

2. https://iot.olution.info/serre
   - Faites défiler jusqu'à la section "Graphiques"
   - Vérifiez que 3 graphiques s'affichent avec des courbes de données

Si les graphiques sont vides ou ne s'affichent pas:
- Ouvrez la console développeur (F12)
- Vérifiez les erreurs JavaScript
- Vérifiez que les fichiers JS se chargent correctement (onglet Network)
- Vérifiez que les variables de données (reading_time, TempAirInt, etc.) contiennent des valeurs

"@ -ForegroundColor Yellow

Write-Host "Script terminé.`n" -ForegroundColor Green
