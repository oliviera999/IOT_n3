<#
.SYNOPSIS
    Automatise le cycle de publication du projet IOT_n3 (version + doc + commit + optionnel push).

.DESCRIPTION
    Pour le composant "serveur" :
    1. Incrémente le fichier serveur/VERSION (patch Semantic Versioning).
    2. Ajoute une entrée dans serveur/CHANGELOG.md.
    3. Commit dans le sous-module serveur avec [serveur] <Message>.
    4. Commit la référence du submodule dans le dépôt parent avec [projet] référence serveur <version> - <Message>.
    5. Si -Push : pousse le serveur puis le dépôt parent.

    À exécuter depuis la racine du dépôt IOT_n3. Les modifications de code doivent déjà être faites
    (le script ajoute VERSION, CHANGELOG et tous les fichiers modifiés suivis au commit).

.PARAMETER Component
    Composant à publier. Pour l'instant seul "serveur" est supporté.

.PARAMETER Message
    Description courte en français pour le commit (ex. "version dans footer page d'accueil").

.PARAMETER Type
    Type d'entrée CHANGELOG : Modifié (défaut), Ajout, Correctif.

.PARAMETER Push
    Pousser vers origin après les commits (submodule puis parent).

.PARAMETER DryRun
    Affiche les actions sans les exécuter.

.EXAMPLE
    .\scripts\publish-cycle.ps1 -Component serveur -Message "version dans footer page d'accueil"
.EXAMPLE
    .\scripts\publish-cycle.ps1 -Component serveur -Message "nouvelle route msp1" -Push
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('serveur')]
    [string] $Component,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Modifié', 'Ajout', 'Correctif')]
    [string] $Type = 'Modifié',

    [Parameter(Mandatory = $false)]
    [switch] $Push,

    [Parameter(Mandatory = $false)]
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$root = $null
if ($PSScriptRoot) {
    $root = Resolve-Path (Join-Path $PSScriptRoot '..')
} else {
    $root = Get-Location
}

if (-not (Test-Path (Join-Path $root 'serveur\VERSION'))) {
    Write-Error "Répertoire racine IOT_n3 non détecté (serveur\VERSION introuvable). Exécutez le script depuis la racine ou depuis scripts\."
    exit 1
}

# --- Serveur ---
if ($Component -eq 'serveur') {
    $versionFile = Join-Path $root 'serveur\VERSION'
    $changelogFile = Join-Path $root 'serveur\CHANGELOG.md'
    $serveurDir = Join-Path $root 'serveur'

    $currentVersion = (Get-Content $versionFile -Raw).Trim()
    if ($currentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        Write-Error "Format VERSION attendu: MAJOR.MINOR.PATCH (ex. 5.0.7). Reçu: $currentVersion"
        exit 1
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $newVersion = "$major.$minor.$($patch + 1)"
    $date = Get-Date -Format 'yyyy-MM-dd'

    if ($DryRun) {
        Write-Host "[DryRun] Version actuelle: $currentVersion -> nouvelle: $newVersion"
        Write-Host "[DryRun] CHANGELOG: entrée $Type - $Message"
        Write-Host "[DryRun] Commit serveur: [serveur] $Message"
        Write-Host "[DryRun] Commit parent: [projet] référence serveur $newVersion - $Message"
        if ($Push) { Write-Host "[DryRun] Push serveur puis parent" }
        exit 0
    }

    Set-Content -Path $versionFile -Value $newVersion -NoNewline
    Write-Host "VERSION: $currentVersion -> $newVersion"

    $changelogContent = Get-Content $changelogFile -Raw
    $newBlock = @"
## [$newVersion] - $date

### $Type - $Message
- **Résumé** : $Message.

---

"@
    $repl = '$1' + $newBlock + '$2'
    $changelogContent = [regex]::Replace($changelogContent, '(\r?\n---\r?\n\r?\n)(## \[)', $repl, 1)
    Set-Content -Path $changelogFile -Value $changelogContent -NoNewline

    Push-Location $serveurDir
    try {
        git add VERSION CHANGELOG.md
        git add -u
        git commit -m "[serveur] $Message"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Aucun commit serveur (aucune modification ou commit vide). Vérifiez que des fichiers sont modifiés."
            Pop-Location
            exit 0
        }
    } finally {
        Pop-Location
    }

    Push-Location $root
    try {
        git add serveur
        git commit -m "[projet] référence serveur $newVersion - $Message"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Commit parent ignoré (pas de changement de référence submodule)."
        }
    } finally {
        Pop-Location
    }

    if ($Push) {
        Push-Location $serveurDir
        try {
            git push
        } finally {
            Pop-Location
        }
        Push-Location $root
        try {
            git push
        } finally {
            Pop-Location
        }
        Write-Host "Push effectué (serveur puis parent)."
    } else {
        Write-Host "Pour pousser : exécutez avec -Push ou faites git push dans serveur puis à la racine."
    }
}
