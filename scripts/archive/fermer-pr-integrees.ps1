# Ferme les PR Cursor integrees sur master (plan build/PR 2026-05-30).
# Prerequis : gh auth login (une fois)
# Usage depuis la racine IOT_n3 :
#   .\scripts\fermer-pr-integrees.ps1
#   .\scripts\fermer-pr-integrees.ps1 -DryRun

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repo = "oliviera999/IOT_n3"

$comment = @"
Correctifs integres sur ``master`` (commit parent ``c2689f6`` et suivants) :

- **Serveur 5.1.3** : POST FFP3 atomique, HMAC en-tetes ``X-Sig-*``, auto-creation table OTA ; marées/tide conservees.
- **FFP5CS 13.83** : fallback niveaux timeout, file SD S3, garde-fou HTTPS.
- Branche PR alignee sur ``origin/master`` ; diff vide cote depot parent.

Cette PR peut etre fermee sans merge.
"@

$prs = @(10, 11, 12, 13, 14, 15, 16, 17)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) introuvable. Installer : winget install GitHub.cli"
}

$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "gh non authentifie. Executer : gh auth login"
}

foreach ($n in $prs) {
    Write-Host "--- PR #$n ---"
    if ($DryRun) {
        gh pr view $n --repo $repo --json title,state,headRefName 2>&1
        continue
    }
    gh pr comment $n --repo $repo --body $comment 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Commentaire PR #$n echoue"
        continue
    }
    gh pr close $n --repo $repo --comment "Fermee : deja integree sur master." 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Fermeture PR #$n echoue"
    }
}

Write-Host "Termine."
