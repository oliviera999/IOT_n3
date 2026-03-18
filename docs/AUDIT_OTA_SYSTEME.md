# AUDIT DU SYSTÈME OTA — IOT_n3

**Date** : 2026-03-15
**Périmètre** : Système de mise à jour OTA (Over-The-Air) — tous firmwares + côté serveur
**Classification** : Évaluation de sécurité technique

---

## RÉSUMÉ EXÉCUTIF

Le projet IOT_n3 implémente un système OTA pour plusieurs cibles ESP32 (n3pp, msp, caméras, ffp5cs). L'infrastructure opérationnelle (scripts de publication, métadonnées, gestion des versions) est fonctionnelle et bien structurée. Cependant, **la posture de sécurité est critique** : absence de signatures cryptographiques, canaux non chiffrés (HTTP), aucune authentification sur les endpoints OTA, et aucun mécanisme de rollback.

**Action immédiate requise** sur les points V1, V2 et V3 avant tout déploiement en production étendu.

---

## 1. ARCHITECTURE DU SYSTÈME OTA

### 1.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                     Machine développeur                         │
│  PlatformIO Build → publish_ota.ps1 → Git push                │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│          Dépôt GitHub n3_serveur (sous-module)                  │
│          serveur/ota/** (firmware.bin + metadata.json)          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│           Serveur Apache — iot.olution.info                     │
│   /ota/n3pp/     /ota/msp/     /ota/cam/     /ffp3/ota/        │
│   (HTTP plain pour n3pp/msp/cam — HTTPS pour ffp5cs seulement) │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
         ┌─────────┐    ┌─────────┐    ┌─────────────┐
         │  n3pp   │    │   msp   │    │ cam (3 cib.)│
         │ ESP32   │    │ ESP32   │    │  ESP32-CAM  │
         └─────────┘    └─────────┘    └─────────────┘
```

### 1.2 Endpoints OTA

| Cible       | Environnement | Endpoint métadonnées                        | Endpoint binaire                          | Protocole |
|-------------|---------------|---------------------------------------------|-------------------------------------------|-----------|
| n3pp        | Production    | `/ota/n3pp/metadata.json`                   | `/ota/n3pp/firmware.bin`                  | **HTTP**  |
| n3pp        | Test          | `/ota/n3pp-test/metadata.json`              | `/ota/n3pp-test/firmware.bin`             | **HTTP**  |
| msp         | Production    | `/ota/msp/metadata.json`                    | `/ota/msp/firmware.bin`                   | **HTTP**  |
| msp         | Test          | `/ota/msp-test/metadata.json`               | `/ota/msp-test/firmware.bin`              | **HTTP**  |
| cam (msp1)  | Production    | `/ota/cam/metadata.json` (clé `msp1`)       | `/ota/cam/msp1/firmware.bin`              | **HTTP**  |
| cam (n3pp)  | Production    | `/ota/cam/metadata.json` (clé `n3pp`)       | `/ota/cam/n3pp/firmware.bin`              | **HTTP**  |
| cam (ffp3)  | Production    | `/ota/cam/metadata.json` (clé `ffp3`)       | `/ota/cam/ffp3/firmware.bin`              | **HTTP**  |
| ffp5cs      | Production    | `/ffp3/ota/metadata.json`                   | `/ffp3/ota/firmware.bin`                  | **HTTPS** |

### 1.3 Format des métadonnées

**Cibles simples (n3pp, msp) :**
```json
{
  "version": "4.5",
  "url": "http://iot.olution.info/ota/n3pp/firmware.bin",
  "md5": "abc123def456..."
}
```

**Multi-cible (caméras) :**
```json
{
  "msp1": { "version": "1.0", "url": "...", "md5": "..." },
  "n3pp": { "version": "1.0", "url": "...", "md5": "..." },
  "ffp3": { "version": "1.0", "url": "...", "md5": "..." }
}
```

---

## 2. CÔTÉ FIRMWARE — ANALYSE PAR CIBLE

### 2.1 n3pp

| Aspect               | État actuel                                        |
|----------------------|----------------------------------------------------|
| Bibliothèque OTA     | Arduino HttpClient (OTA intégré ESP32)             |
| URL OTA              | Conditionnelle via `#ifdef TEST_MODE`              |
| Vérification version | Comparaison de chaîne (`version > currentVersion`) |
| Intégrité            | MD5 uniquement                                     |
| Chiffrement canal    | **HTTP non chiffré**                               |
| Authentification     | **Aucune**                                         |
| Rollback             | **Aucun mécanisme documenté**                      |
| Timeout              | Non documenté                                      |
| Retry                | Non documenté                                      |

**Extrait de sélection d'environnement :**
```cpp
#ifdef TEST_MODE
  String otaUrl = "http://iot.olution.info/ota/n3pp-test/metadata.json";
#else
  String otaUrl = "http://iot.olution.info/ota/n3pp/metadata.json";
#endif
```

### 2.2 msp

Structure identique à n3pp. Mêmes lacunes de sécurité.

### 2.3 uploadphotosserver (caméras)

| Aspect               | État actuel                                        |
|----------------------|----------------------------------------------------|
| Cibles               | msp1, n3pp, ffp3 (3 binaires distincts)           |
| Métadonnées          | JSON partagé avec clé par cible                   |
| Authentification     | **Aucune**                                         |
| Chiffrement          | **HTTP non chiffré**                               |
| Gestion d'erreur     | Continue avec firmware existant en cas d'échec    |

### 2.4 ffp5cs (meilleure implémentation)

| Aspect               | État actuel                                        |
|----------------------|----------------------------------------------------|
| Protocole            | **HTTPS** (seule cible sécurisée)                  |
| Config               | Fichiers par environnement (prod, test, test3)    |
| Timeout              | 15–20 secondes                                    |
| Retry                | 2 tentatives par requête                          |
| File d'attente       | NVS pour les POST en échec                        |
| Mode offline         | Supporté (offline-first)                          |
| Rollback             | **Non implémenté**                                 |

**ffp5cs sert de référence** pour l'amélioration des autres cibles.

---

## 3. CÔTÉ SERVEUR — ANALYSE

### 3.1 Script de publication `publish_ota.ps1`

**Workflow :**
1. Build optionnel via `pio run -e <env>`
2. Localisation du binaire `.pio/build/<env>/firmware.bin`
3. Validation :
   - Existence du fichier
   - Extraction de la version depuis le code source
   - Vérification taille ≤ AppMaxSize
4. Copie vers `serveur/ota/<cible>/firmware.bin`
5. Calcul MD5
6. Mise à jour de `metadata.json`
7. Commit Git du sous-module serveur
8. Push Git (sous-module puis dépôt parent)

**Configuration par cible :**
```powershell
"n3pp" = @{
    ProjectDir   = "firmwares\n3pp"
    PioEnv       = "esp32dev"
    OtaDest      = "serveur\ota\n3pp"
    MetadataPath = "serveur\ota\n3pp\metadata.json"
    OtaUrl       = "http://iot.olution.info/ota/n3pp/firmware.bin"
    AppMaxSize   = 1966080  # ~1,88 MB
}
```

**Points forts :**
- Validation de taille du binaire avant déploiement
- Extraction automatique de version depuis le code source
- Gestion des métadonnées multi-cible pour les caméras
- Workflow Git automatisé (commit + push)

**Points faibles :**
- MD5 au lieu de signature cryptographique
- URLs en HTTP dans la configuration
- Aucun log d'audit des publications
- Outil Windows uniquement (PowerShell)

### 3.2 Serving Apache

- Fichiers statiques servis directement
- Règles de réécriture `.htaccess`
- **Aucune authentification**
- **Aucun rate limiting**
- **Aucun throttling de bande passante**

### 3.3 Tailles des partitions app

| Cible              | AppMaxSize   |
|--------------------|--------------|
| n3pp            | 1 966 080 B  |
| msp             | 1 966 080 B  |
| uploadphotosserver | 1 966 080 B  |
| ffp5cs             | Personnalisé |

---

## 4. VULNÉRABILITÉS IDENTIFIÉES

### Tableau de synthèse

| ID  | Titre                                    | Sévérité     | Catégorie        |
|-----|------------------------------------------|--------------|------------------|
| V1  | Aucune signature cryptographique         | **CRITIQUE** | Authenticité     |
| V2  | Canal OTA en HTTP non chiffré            | **CRITIQUE** | Confidentialité  |
| V3  | Aucune authentification sur les endpoints| **ÉLEVÉE**   | Autorisation     |
| V4  | MD5 seul pour l'intégrité               | **ÉLEVÉE**   | Intégrité        |
| V5  | Aucune protection anti-downgrade         | **ÉLEVÉE**   | Disponibilité    |
| V6  | Métadonnées partagées multi-cible cam    | **MOYENNE**  | Déploiement      |
| V7  | Aucun mécanisme de rollback firmware     | **MOYENNE**  | Récupérabilité   |
| V8  | Secrets potentiellement codés en dur     | **MOYENNE**  | Secrets          |
| V9  | Aucun rate limiting sur les endpoints    | **MOYENNE**  | Disponibilité    |
| V10 | Aucun log d'audit des publications       | **FAIBLE**   | Traçabilité      |

---

### V1 — Aucune signature cryptographique (**CRITIQUE**)

**Description :** Les binaires et métadonnées ne sont authentifiés que par un hash MD5, qui est cryptographiquement cassé et ne prouve pas l'origine.

**Impact :**
- Attaque MITM : injection de firmware malveillant sur le canal HTTP
- Aucune preuve d'authenticité ou d'origine
- Compromission du serveur de distribution → tous les appareils vulnérables

**Cibles affectées :** n3pp, msp, caméras (ffp5cs partiellement mitigé via HTTPS)

**Correction :**
```
1. Générer une paire de clés ED25519 ou RSA-2048
2. Signer le binaire lors du build (publish_ota.ps1)
3. Ajouter la signature dans metadata.json :
   { "version": "4.5", "url": "...", "md5": "...", "signature": "base64..." }
4. Vérifier la signature côté firmware avant de flasher
```

---

### V2 — Canal OTA en HTTP non chiffré (**CRITIQUE**)

**Description :** La majorité des cibles télécharge firmware et métadonnées en HTTP plain.

**Impact :**
- Écoute du firmware en transit (reverse engineering facilité)
- Attaque par rejeu ou modification du flux
- Exposition de chaînes de caractères embarquées dans le firmware

**Cibles affectées :** n3pp, msp, caméras — ffp5cs utilise HTTPS

**Correction :**
```powershell
# publish_ota.ps1 : changer les URLs
OtaUrl = "https://iot.olution.info/ota/n3pp/firmware.bin"

# Firmware : activer la vérification du certificat
# et envisager le certificate pinning
```

---

### V3 — Aucune authentification sur les endpoints OTA (**ÉLEVÉE**)

**Description :** N'importe quel client peut télécharger n'importe quel firmware sans s'identifier.

**Impact :**
- Reconnaissance de l'état du parc (versions exposées)
- Attaques de downgrade ciblées
- Extraction et analyse du firmware par des tiers

**Correction (option simple) :**
```
GET /ota/n3pp/metadata.json?key=<DEVICE_API_KEY>
```

**Correction (option robuste) :**
```
Authorization: Bearer <JWT signé avec identifiant appareil>
```

---

### V4 — MD5 seul pour l'intégrité (**ÉLEVÉE**)

**Description :** MD5 est cryptographiquement cassé depuis 2004 (collisions démontrables).

**Impact :** Un attaquant peut forger un binaire malveillant avec le même MD5 qu'un binaire légitime.

**Correction :**
```powershell
# Remplacer dans publish_ota.ps1
$hash = (Get-FileHash -Path $destBin -Algorithm SHA256).Hash
# et intégrer la signature V1 en parallèle
```

---

### V5 — Aucune protection anti-downgrade (**ÉLEVÉE**)

**Description :** Un appareil peut être forcé vers une version antérieure vulnérable.

**Impact :** Exploitation de vulnérabilités corrigées en forçant un downgrade.

**Correction :**
```json
// metadata.json : ajouter
{
  "version": "4.5",
  "min_version": "4.3",
  ...
}
```
```cpp
// Firmware : rejeter si version proposée < version actuelle ou < min_version
if (proposedVersion < currentVersion) {
    Serial.println("Downgrade refusé");
    return;
}
```

---

### V6 — Métadonnées partagées multi-cible caméras (**MOYENNE**)

**Description :** Un seul fichier `cam/metadata.json` gère 3 cibles matérielles différentes (msp1, n3pp, ffp3).

**Risque :** Déploiement d'un firmware incompatible sur la mauvaise cible en cas d'erreur de clé.

**Correction :**
```
serveur/ota/cam/msp1/metadata.json
serveur/ota/cam/n3pp/metadata.json
serveur/ota/cam/ffp3/metadata.json
```

---

### V7 — Aucun mécanisme de rollback firmware (**MOYENNE**)

**Description :** En cas d'échec de mise à jour, l'appareil est potentiellement inutilisable sans intervention physique.

**Correction :**
```
1. Configurer le partitionnement dual OTA (ota_0 / ota_1)
2. Compteur de boots en NVS : rollback automatique si boot_count > 3
3. Conservation du binaire précédent sur le serveur
```

---

### V8 — Secrets potentiellement codés en dur (**MOYENNE**)

**Description :** LVGL_Widgets identifié dans `RECOMMANDATIONS_IOT.md` comme ayant des secrets en dur.

**Cibles confirmées sécurisées :** n3pp, msp (credentials.h externalisé)
**À vérifier :** uploadphotosserver, LVGL_Widgets

---

### V9 — Aucun rate limiting sur les endpoints OTA (**MOYENNE**)

**Description :** Un client peut interroger les endpoints OTA sans limite de fréquence.

**Impact :** DoS potentiel ; détection difficile d'appareils compromis.

**Correction Apache :**
```apache
# .htaccess
<IfModule mod_evasive20.c>
    DOSHashTableSize    3097
    DOSPageCount        5
    DOSSiteCount        50
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   10
</IfModule>
```

---

### V10 — Aucun log d'audit des publications (**FAIBLE**)

**Description :** Aucune traçabilité de qui a publié quelle version, quand.

**Correction :**
```powershell
# publish_ota.ps1 : ajouter en fin de publication
$auditEntry = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    target    = $targetName
    version   = $version
    md5       = $hash
    deployer  = $env:USERNAME
} | ConvertTo-Json
Add-Content -Path "ota-audit.jsonl" -Value $auditEntry
```

---

## 5. GESTION DES VERSIONS

### 5.1 Schéma de versions par cible

| Cible              | Version actuelle | Fichier source              | Format    |
|--------------------|------------------|-----------------------------|-----------|
| n3pp            | 4.5              | `src/main.cpp`              | `X.Y`     |
| msp             | 2.7              | `src/main.cpp`              | `X.Y`     |
| uploadphotosserver | Non documentée   | `config.h` (par cible)      | `X.Y`     |
| ffp5cs             | Par env          | Config env-spécifique       | `X.Y.Z`   |
| Projet global      | 2025.03          | `/VERSION`                  | `YYYY.MM` |

### 5.2 Environnements TEST vs PROD

| Cible | Prod                | Test                    | Contrôle           |
|-------|---------------------|-------------------------|--------------------|
| n3pp  | `/ota/n3pp/`        | `/ota/n3pp-test/`       | `#ifdef TEST_MODE` |
| msp   | `/ota/msp/`         | `/ota/msp-test/`        | `#ifdef TEST_MODE` |
| cam   | `/ota/cam/`         | Non documenté           | Build env          |
| ffp5cs| `/ffp3/ota/`        | Env séparés             | Config fichiers    |

---

## 6. RECOMMANDATIONS PAR PRIORITÉ

### Phase 1 — Immédiat (sécurité critique)

- [ ] **Passer en HTTPS** tous les endpoints OTA (modifier `OtaUrl` dans `publish_ota.ps1`)
- [ ] **Implémenter SHA-256** à la place de MD5 dans le calcul d'intégrité
- [ ] **Ajouter une signature ED25519** sur les binaires (signer à la publication, vérifier au flash)
- [ ] **Authentifier les endpoints OTA** avec une clé API par appareil

### Phase 2 — Court terme (impact élevé)

- [ ] **Protection anti-downgrade** : champ `min_version` dans les métadonnées + rejet firmware
- [ ] **Log d'audit** des publications OTA (fichier `ota-audit.jsonl`)
- [ ] **Séparer les métadonnées** des caméras (un fichier par cible)
- [ ] **Externaliser les secrets** de LVGL_Widgets et vérifier uploadphotosserver

### Phase 3 — Moyen terme (disponibilité)

- [ ] **Dual-partition OTA** (ota_0/ota_1) avec rollback automatique sur boot failure
- [ ] **Rate limiting Apache** sur les endpoints `/ota/*`
- [ ] **Documenter** la table de partitions pour chaque board (`docs/OTA_PARTITIONS.md`)
- [ ] **Registre firmware** des appareils avec version courante (`docs/inventaire_appareils.md`)

### Phase 4 — Long terme (architecture)

- [ ] **Pipeline CI/CD** multi-plateforme (remplacement PowerShell par script bash/Python)
- [ ] **Dashboard de gestion OTA** (version courante par appareil, progression des rollouts)
- [ ] **Déploiement progressif** (staged rollout par pourcentage d'appareils)
- [ ] **Intégration Secure Boot ESP32** (vérification signature au démarrage matériel)

---

## 7. CONFORMITÉ ET STANDARDS

| Standard                         | Exigence                        | Statut      |
|----------------------------------|---------------------------------|-------------|
| OWASP IoT Top 10 — I2            | Mise à jour firmware sécurisée  | **NON CONFORME** |
| NIST Cybersecurity Framework     | Gestion des mises à jour        | **PARTIEL** |
| ETSI EN 303 645 (IoT Security)   | Chiffrement des canaux          | **NON CONFORME** |
| ESP-IDF Secure Boot              | Vérification au démarrage       | **NON IMPLÉMENTÉ** |

---

## ANNEXE — FICHIERS CLÉS OTA

| Fichier                                    | Rôle                                      |
|--------------------------------------------|-------------------------------------------|
| `scripts/publish_ota.ps1`                  | Script principal de publication (426 l.)  |
| `scripts/publish-cycle.ps1`               | Gestion version + changelog               |
| `serveur/ota/n3pp/metadata.json`          | Métadonnées OTA n3pp prod                 |
| `serveur/ota/n3pp-test/metadata.json`     | Métadonnées OTA n3pp test                 |
| `serveur/ota/msp/metadata.json`           | Métadonnées OTA msp prod                  |
| `serveur/ota/cam/metadata.json`           | Métadonnées OTA caméras (3 cibles)        |
| `serveur/ota/metadata.json`          | Métadonnées OTA ffp5cs (HTTPS)            |
| `firmwares/n3pp/src/main.cpp`          | Code OTA client n3pp                      |
| `firmwares/msp/src/main.cpp`           | Code OTA client msp                       |
| `firmwares/uploadphotosserver/src/main.cpp`| Code OTA client caméras                  |
| `firmwares/ffp5cs/src/web_server.cpp`     | Code OTA client ffp5cs (avancé)           |
| `docs/audit_echanges_serveur_esp.md`      | Documentation API                         |
| `RECOMMANDATIONS_IOT.md`                  | Bonnes pratiques existantes               |
