<#
.SYNOPSIS
    Deploie le serveur : push des modifs vers GitHub, puis DEPLOY_NOW.sh en local.

.DESCRIPTION
    1. git pull dans serveur/
    2. Si modifs locales dans serveur : commit + push vers GitHub
    3. Si reference serveur modifiee : commit + push dans le depot parent
    4. bash DEPLOY_NOW.sh dans serveur/ffp3/ (composer, verifications)
    A executer depuis la racine IOT_n3. Necessite Git et bash (Git Bash sous Windows).

.PARAMETER Message
    Message de commit pour les modifs serveur (defaut : "deploiement serveur").

.PARAMETER NoPush
    Ne pas pousser vers GitHub (pull et DEPLOY_NOW uniquement).

.EXAMPLE
    .\scripts\deploy-server.ps1

.EXAMPLE
    .\scripts\deploy-server.ps1 -Message "correction routes_helpers"
#>

[CmdletBinding()]
param(
    [string]$Message = 'deploiement serveur',
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
    (Get-Location).Path
}

$serveurDir = Join-Path $root 'serveur'
$ffp3Dir = Join-Path $serveurDir 'ffp3'
$deployScript = Join-Path $ffp3Dir 'DEPLOY_NOW.sh'

if (-not (Test-Path $serveurDir)) {
    Write-Error "Dossier serveur introuvable: $serveurDir. Executez le script depuis la racine IOT_n3."
    exit 1
}
if (-not (Test-Path $deployScript)) {
    Write-Error "DEPLOY_NOW.sh introuvable: $deployScript"
    exit 1
}

Write-Host "Deploiement serveur" -ForegroundColor Cyan
Write-Host "  1. git pull (serveur)" -ForegroundColor Gray
Write-Host "  2. commit + push serveur si modifs" -ForegroundColor Gray
Write-Host "  3. commit + push parent si ref serveur modifiee" -ForegroundColor Gray
Write-Host "  4. bash DEPLOY_NOW.sh (serveur/ffp3)" -ForegroundColor Gray
if ($NoPush) { Write-Host "  (-NoPush : etapes 2-3 ignorees)" -ForegroundColor Yellow }
Write-Host ""

# Etape 1 : pull dans le submodule serveur
Push-Location $serveurDir
try {
    Write-Host "[1/4] git pull (serveur)..." -ForegroundColor Cyan
    git pull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git pull a echoue."
        exit 1
    }
    Write-Host ""
} finally {
    Pop-Location
}

# Etape 2 : commit + push serveur si modifs
$serveurPushed = $false
if (-not $NoPush) {
    Push-Location $serveurDir
    try {
        $status = git status --porcelain 2>$null
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $upstream = git rev-parse --abbrev-ref '@{u}' 2>$null
        $commitsAhead = 0
        if ($upstream) {
            $commitsAhead = (git rev-list "$upstream..HEAD" 2>$null | Measure-Object -Line).Lines
        }
        $needPush = $status -or ([int]$commitsAhead -gt 0)

        if ($needPush) {
            Write-Host "[2/4] Modifs detectees dans serveur - commit et push..." -ForegroundColor Cyan
            if ($status) {
                git add -A
                git commit -m "[serveur] $Message"
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Aucun commit (peut-etre rien a commiter apres add)."
                } else {
                    $serveurPushed = $true
                }
            }
            git push
            if ($LASTEXITCODE -eq 0) { $serveurPushed = $true }
            Write-Host ""
        } else {
            Write-Host "[2/4] serveur : rien a pousser" -ForegroundColor Gray
            Write-Host ""
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[2/4] Push : ignore (-NoPush)" -ForegroundColor Gray
    Write-Host ""
}

# Etape 3 : commit + push parent si reference serveur modifiee
if (-not $NoPush -and $serveurPushed) {
    Push-Location $root
    try {
        $subStatus = git status --short serveur 2>$null
        if ($subStatus) {
            Write-Host "[3/4] Reference serveur modifiee - commit et push parent..." -ForegroundColor Cyan
            git add serveur
            git commit -m "[projet] reference serveur mise a jour"
            git push
            Write-Host ""
        } else {
            Write-Host "[3/4] Parent : rien a pousser" -ForegroundColor Gray
            Write-Host ""
        }
    } finally {
        Pop-Location
    }
} elseif (-not $NoPush) {
    Write-Host "[3/4] Parent : rien a pousser" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "[3/4] Push : ignore (-NoPush)" -ForegroundColor Gray
    Write-Host ""
}

# Etape 4 : executer DEPLOY_NOW.sh depuis serveur/ffp3
$bashExe = $null
if ($env:OS -eq 'Windows_NT') {
    $gitBash = 'C:\Program Files\Git\bin\bash.exe'
    if (Test-Path $gitBash) {
        $bashExe = $gitBash
    }
}
if (-not $bashExe) {
    $bashExe = 'bash'
}

Push-Location $ffp3Dir
try {
    Write-Host "[4/4] $bashExe DEPLOY_NOW.sh..." -ForegroundColor Cyan
    Write-Host ""
    & $bashExe $deployScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "DEPLOY_NOW.sh a echoue (code $LASTEXITCODE)."
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Deploiement termine." -ForegroundColor Green
