# =============================================================================
# Génération de la paire de clés ECDSA P-256 pour signature OTA
# =============================================================================
# A exécuter UNE SEULE FOIS sur la machine de build.
# La clé privée reste sur la machine de build — ne jamais la commiter.
# La clé publique est intégrée dans le firmware via n3_ota_pubkey.h.
#
# Prérequis : openssl dans le PATH OU .NET 6+
#
# Usage :
#   .\scripts\generate_ota_keys.ps1
#   .\scripts\generate_ota_keys.ps1 -OutDir scripts\ota_keys
# =============================================================================

param(
    [string]$OutDir     = "scripts\ota_keys",
    [string]$HeaderFile = "firmwires\shared\n3_common\src\n3_ota_pubkey.h"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
if ((Get-Location).Path -ne $root) { Set-Location $root }

$privKey   = Join-Path $OutDir "ota_signing_key.pem"
$pubKeyPem = Join-Path $OutDir "ota_signing_pubkey.pem"

Write-Host "=== Génération clé ECDSA P-256 pour signature OTA ===" -ForegroundColor Cyan

# Créer le répertoire si nécessaire
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Vérifier que la clé n'existe pas déjà
if (Test-Path $privKey) {
    Write-Host ""
    Write-Host "ATTENTION : Une clé privée existe déjà : $privKey" -ForegroundColor Yellow
    Write-Host "Écraser ? (o/N) " -NoNewline -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -notmatch "^[oOyY]$") {
        Write-Host "Annulé." -ForegroundColor Gray
        exit 0
    }
}

$generatedOk = $false

# Chercher openssl dans le PATH ou emplacements Windows courants
$opensslCmd = Get-Command "openssl" -ErrorAction SilentlyContinue
if (-not $opensslCmd) {
    $opensslPaths = @(
        "C:\Program Files\OpenSSL-Win64\bin\openssl.exe",
        "C:\Program Files\OpenSSL-Win32\bin\openssl.exe",
        "C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe"
    )
    foreach ($p in $opensslPaths) {
        if (Test-Path $p) {
            $env:PATH = "$(Split-Path $p -Parent);$env:PATH"
            $opensslCmd = Get-Command "openssl" -ErrorAction SilentlyContinue
            if ($opensslCmd) { break }
        }
    }
}

# --- Tentative via openssl ---
if ($opensslCmd) {
    Write-Host "Utilisation d'openssl..." -ForegroundColor Gray

    try {
        & openssl ecparam -name prime256v1 -genkey -noout -out $privKey 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "ecparam échoué" }

        & openssl ec -in $privKey -pubout -out $pubKeyPem 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "ec pubout échoué" }

        $generatedOk = $true
        Write-Host "  openssl : OK" -ForegroundColor Green
    } catch {
        Write-Host "  openssl a échoué : $_ — tentative .NET..." -ForegroundColor Yellow
    }
}

# --- Fallback .NET ECDsa ---
if (-not $generatedOk) {
    Write-Host "Utilisation .NET ECDsa..." -ForegroundColor Gray
    try {
        # Création ECDsa P-256 : Create() sans paramètre d'abord (compatible .NET 5+, P-256 par défaut)
        $ecdsa = $null
        try {
            $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        } catch { }
        if (-not $ecdsa) {
            # Sinon, créer via courbe explicite
            $curve = $null
            try {
                $curve = [System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256")
            } catch {
                try {
                    $curve = [System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistp256")
                } catch {
                    try {
                        $curve = [System.Security.Cryptography.ECCurve+NamedCurves]::nistP256
                    } catch { }
                }
            }
            if ($curve) {
                $ecdsa = [System.Security.Cryptography.ECDsa]::Create($curve)
            }
        }
        if (-not $ecdsa) {
            throw "ECDsa.Create a renvoyé null. Installez .NET 6+ (dotnet --version) ou openssl."
        }

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

        # Clé privée et publique PEM (.NET 5+ a Export*Pem, sinon conversion manuelle)
        $privPem = $null
        $pubPem  = $null

        if ($ecdsa.GetType().GetMethod("ExportECPrivateKeyPem")) {
            $privPem = $ecdsa.ExportECPrivateKeyPem()
            $pubPem  = $ecdsa.ExportSubjectPublicKeyInfoPem()
        } else {
            # .NET Framework : export DER puis conversion PEM
            function To-Pem {
                param([byte[]]$der, [string]$label)
                $b64 = [Convert]::ToBase64String($der)
                $lines = for ($i = 0; $i -lt $b64.Length; $i += 64) {
                    $len = [Math]::Min(64, $b64.Length - $i)
                    $b64.Substring($i, $len)
                }
                "-----BEGIN $label-----`n" + ($lines -join "`n") + "`n-----END $label-----"
            }
            $privPem = To-Pem -der $ecdsa.ExportECPrivateKey() -label "EC PRIVATE KEY"
            $pubPem  = To-Pem -der $ecdsa.ExportSubjectPublicKeyInfo() -label "PUBLIC KEY"
        }

        [System.IO.File]::WriteAllText((Join-Path $PWD $privKey), $privPem, $utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $PWD $pubKeyPem), $pubPem, $utf8NoBom)

        $ecdsa.Dispose()
        $generatedOk = $true
        Write-Host "  .NET ECDsa : OK" -ForegroundColor Green
    } catch {
        Write-Host "Erreur : impossible de générer les clés avec openssl ou .NET : $_" -ForegroundColor Red
        Write-Host "Installez openssl (https://slproweb.com/products/Win32OpenSSL.html) ou .NET 6+." -ForegroundColor Yellow
        exit 1
    }
}

# --- Lire la clé publique PEM pour l'intégrer dans le header C++ ---
$pubPemContent = (Get-Content -Path $pubKeyPem -Raw).TrimEnd()

$generatedDate = Get-Date -Format "yyyy-MM-dd"

$headerContent = @"
#pragma once

// =============================================================================
// Clé publique ECDSA P-256 pour vérification de signature OTA
// Certificat CA pour validation TLS HTTPS
//
// Généré le : $generatedDate
// Source    : scripts/generate_ota_keys.ps1
//
// CE FICHIER EST COMMITABLE (clé publique uniquement).
// La clé privée (scripts/ota_keys/ota_signing_key.pem) ne doit JAMAIS être
// commitée — elle est ignorée par .gitignore.
// =============================================================================

// -----------------------------------------------------------------------------
// Certificat CA pour validation TLS du serveur iot.olution.info
//
// Actuellement en mode setInsecure() : canal chiffré, certificat serveur
// non vérifié. La signature ECDSA garantit l'authenticité du firmware.
//
// Pour activer la validation complète du certificat serveur (Phase 2) :
//   1. openssl s_client -connect iot.olution.info:443 -showcerts 2>/dev/null \
//        | openssl x509 -noout -text | grep "Issuer:"
//   2. Télécharger le certificat CA racine correspondant
//   3. Remplacer le commentaire ci-dessous par :
//      #define OTA_CA_CERT R"CA(-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n)CA"
// -----------------------------------------------------------------------------
// OTA_CA_CERT non défini → setInsecure() (transitoire)

// -----------------------------------------------------------------------------
// Clé publique ECDSA P-256 (format SPKI/PEM)
// Vérification : mbedtls_pk_parse_public_key + mbedtls_pk_verify
// -----------------------------------------------------------------------------
#define OTA_SIGNING_PUBLIC_KEY_PEM R"OTAKEY(
$pubPemContent
)OTAKEY"
"@

[System.IO.File]::WriteAllText(
    (Join-Path $PWD $HeaderFile),
    $headerContent,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "=== Fichiers générés ===" -ForegroundColor Green
Write-Host "  Clé privée (GARDER SECRET) : $privKey" -ForegroundColor Yellow
Write-Host "  Clé publique PEM           : $pubKeyPem" -ForegroundColor Gray
Write-Host "  Header firmware            : $HeaderFile" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT :" -ForegroundColor Red
Write-Host "  - La clé privée est dans .gitignore — ne JAMAIS la commiter." -ForegroundColor Red
Write-Host "  - Commiter $HeaderFile (clé publique) pour l'intégrer aux firmwares." -ForegroundColor Cyan
Write-Host "  - Publier avec signature : .\scripts\publish_ota.ps1 -SignKey $privKey" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vérification de la signature (openssl) :" -ForegroundColor Gray
Write-Host "  openssl dgst -sha256 -verify $pubKeyPem -signature <sig.der> firmware.bin" -ForegroundColor Gray
