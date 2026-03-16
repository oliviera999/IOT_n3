# Supprime les caches Cursor pour liberer de l'espace.
# N'affecte PAS l'historique des chats (workspaceStorage non supprime).
# Fermer Cursor avant d'executer.

$folders = @(
    "$env:LOCALAPPDATA\Cursor\Cache",
    "$env:LOCALAPPDATA\Cursor\Code Cache",
    "$env:LOCALAPPDATA\Cursor\GPUCache",
    "$env:LOCALAPPDATA\Cursor\blob_storage",
    "$env:LOCALAPPDATA\Cursor\Crashpad",
    "$env:APPDATA\Cursor\Cache"
)

foreach ($f in $folders) {
    if (Test-Path $f) {
        Remove-Item -Path $f -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Supprime : $f"
    }
}
Write-Host "Termine. Redemarrez Cursor si besoin."
