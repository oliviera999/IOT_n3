<#
.SYNOPSIS
    Deploie le serveur : push des modifs vers GitHub, puis DEPLOY_NOW.sh en local.

.DESCRIPTION
    1. git pull dans serveur/
    2. Si modifs locales dans serveur : commit + push vers GitHub
    3. Si reference serveur modifiee : commit + push dans le depot parent
    4. bash DEPLOY_NOW.sh (auto-detecte sous serveur/analyse-ffp3, archives/ffp3 ou ffp3) si present (composer, verifications)
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

if (-not (Test-Path $serveurDir)) {
    Write-Error "Dossier serveur introuvable: $serveurDir. Executez le script depuis la racine IOT_n3."
    exit 1
}

# Localiser DEPLOY_NOW.sh : le sous-projet FFP3 a change de chemin au fil des reorganisations
# (serveur/ffp3 -> serveur/archives/ffp3 -> extrait serveur/analyse-ffp3). On detecte le premier present.
$ffp3Dir = $null
$deployScript = $null
foreach ($cand in @('analyse-ffp3', 'archives/ffp3', 'ffp3')) {
    $candDir = Join-Path $serveurDir $cand
    $candScript = Join-Path $candDir 'DEPLOY_NOW.sh'
    if (Test-Path $candScript) {
        $ffp3Dir = $candDir
        $deployScript = $candScript
        break
    }
}
if (-not $deployScript) {
    Write-Warning "DEPLOY_NOW.sh introuvable sous serveur/ (analyse-ffp3, archives/ffp3, ffp3). L'etape 4 sera ignoree ; le pull/commit/push (etapes 1-3) reste effectue."
}

Write-Host "Deploiement serveur" -ForegroundColor Cyan
Write-Host "  1. git pull (serveur)" -ForegroundColor Gray
Write-Host "  2. commit + push serveur si modifs" -ForegroundColor Gray
Write-Host "  3. commit + push parent si ref serveur modifiee" -ForegroundColor Gray
Write-Host "  4. bash DEPLOY_NOW.sh (auto-detecte, si present)" -ForegroundColor Gray
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

# Etape 4 : executer DEPLOY_NOW.sh (si present). Best-effort : en prod, un CRON fait deja
# le git pull cote serveur ; cette etape sert au declenchement manuel / aux dependances.
if (-not $deployScript) {
    Write-Host "[4/4] DEPLOY_NOW.sh introuvable : etape ignoree." -ForegroundColor Yellow
    Write-Host ""
} else {
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
        Write-Host "[4/4] $bashExe DEPLOY_NOW.sh ($ffp3Dir)..." -ForegroundColor Cyan
        Write-Host ""
        & $bashExe $deployScript
        if ($LASTEXITCODE -ne 0) {
            Write-Error "DEPLOY_NOW.sh a echoue (code $LASTEXITCODE)."
            exit 1
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Deploiement termine." -ForegroundColor Green
