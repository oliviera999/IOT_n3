# =============================================================================
# Execute l'integration ffp5cs en subtree dans n3_firmwires (Option 1)
# =============================================================================
# A lancer dans un terminal PowerShell sur ta machine (connexion stable).
# Depuis la racine IOT_n3 : .\scripts\run-subtree-add-ffp5cs.ps1
#
# Etapes : clone propre de n3_firmwires -> retrait submodule ffp5cs -> subtree add -> push
# =============================================================================

$ErrorActionPreference = "Stop"
$tmp = Join-Path $env:TEMP "n3_firmwires_subtree"
$n3url = "https://github.com/oliviera999/n3_firmwires.git"
$ffp5csUrl = "https://github.com/oliviera999/ffp5cs.git"

Write-Host "Clone propre de n3_firmwires dans $tmp" -ForegroundColor Cyan
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
git clone $n3url $tmp
Set-Location $tmp

$gm = Get-Content ".gitmodules" -Raw -ErrorAction SilentlyContinue
if ($gm -and $gm -match 'submodule "ffp5cs"') {
    Write-Host "Retrait du submodule ffp5cs..." -ForegroundColor Cyan
    git submodule deinit -f ffp5cs 2>$null
    git rm ffp5cs
    git add .gitmodules
    git commit -m "[n3_firmwires] retrait submodule ffp5cs"
}

Write-Host "Integration ffp5cs en subtree (branche main)..." -ForegroundColor Cyan
git config http.postBuffer 524288000
git subtree add --prefix=ffp5cs $ffp5csUrl main
if ($LASTEXITCODE -ne 0) {
    Write-Host "Echec. Verifiez la connexion et rejouez le script." -ForegroundColor Red
    exit 1
}

Write-Host "Push vers origin master..." -ForegroundColor Cyan
git push origin master
Write-Host "Termine. Dans IOT_n3 : cd firmwires ; git pull ; cd .. ; git add firmwires ; git commit -m '[projet] ref firmwires (ffp5cs subtree)' ; git push" -ForegroundColor Green
