# Audit firmware caméra ESP32-CAM — uploadphotosserver

**Date** : 20 mars 2026
**Périmètre** : Firmware unifié `uploadphotosserver` (cibles msp1, n3pp, ffp3) + contrat serveur (GalleryUploadController)
**Type** : Audit complet (sécurité, fiabilité, contrat firmware-serveur, qualité de code)

---

## 1. Matrice de contrat firmware-serveur

| Aspect | MSP1 | N3PP | FFP3 |
|--------|------|------|------|
| **Build flag** | `-DTARGET_MSP1` | `-DTARGET_N3PP` | `-DTARGET_FFP3` |
| **SERVER_PATH** | `/msp1gallery/upload.php` | `/n3ppgallery/upload.php` | `/ffp3/ffp3gallery/upload.php` |
| **Deep sleep** | Oui (600 s) | Oui (600 s) | Oui (600 s) |
| **SD card** | Oui | Oui | Oui |
| **OTA target key** | `"msp1"` | `"n3pp"` | `"ffp3"` |
| **OTA metadata URL** | `http://iot.olution.info/ota/cam/metadata.json` | idem | idem |
| **Payload** | multipart/form-data, champ `imageFile`, boundary `RandomNerdTutorials` | idem | idem |
| **Auth côté firmware** | Header `X-Api-Key` | idem | idem |
| **Auth côté serveur** | `X-Api-Key` validé | idem | idem |
| **Taille max serveur** | 5 Mo | 5 Mo | 5 Mo |
| **Types acceptés serveur** | image/jpeg, image/jpg | idem | idem |
| **FIRMWARE_VERSION** | 2.38 (commune) | idem | idem |
| **XCLK freq** | 5 MHz | 5 MHz | 5 MHz |
| **EEPROM compteur SD** | 4 octets | 4 octets | 4 octets |
| **Créneau horaire** | 6h–22h | idem | idem |

**Constantes communes** : `SERVER_NAME=iot.olution.info`, `SERVER_PORT=80`, `UPLOAD_CHUNK_SIZE=4096`, vérification OTA périodique toutes les 2h (RTC), `WIFI_CONNECT_TIMEOUT_MS=5000`.

## 1.b Statut de synchronisation (mise à jour 20/03/2026)

Cette section reflète l'état réel actuel en mode "état + écarts connus".

- **Corrigé côté firmware** : C-01 (`TIME_TO_SLEEP=600`), E-01 (retries upload), E-02 (contrôle HTTP), E-04 (compteur SD robuste), E-05 (gestion explicite WiFi indisponible), bug use-after-free WiFi SSID corrigé.
- **Corrigé côté sécurité OTA** : vérification `sha256` obligatoire et vérification signature ECDSA optionnelle (si `signature` présente dans metadata).
- **Corrigé côté serveur** : validation `X-Api-Key` upload/contrôle, validation `board`/`sensor` sur endpoints de contrôle, code `202` pour photos basculées en corbeille auto.
- **Corrigé côté documentation** : version caméra alignée en `2.38` dans l'inventaire et la doc racine.
- **Écarts connus restant à traiter** : M-06 (transport HTTP en clair ; intégrité OTA assurée mais chiffrement non activé).
- **Lecture recommandée** : considérer les sections 2 à 6 comme le constat initial d'audit + backlog, puis appliquer cette section 1.b comme référence de statut actuel.

---

## 2. Constatations priorisées

### Sévérité CRITIQUE

#### C-01 — TIME_TO_SLEEP = 3 secondes (toutes cibles)

- **Fichier** : `firmwires/uploadphotosserver/include/config.h` lignes 61, 69, 77
- **Constat** : `TIME_TO_SLEEP` est défini à `3` pour msp1, n3pp et ffp3. La documentation (`.cursor/rules/esp32-cam-conventions.mdc`) et le fonctionnement opérationnel attendu sont de **600 secondes** (10 min).
- **Impact** : Avec 3 s de deep sleep + ~15-20 s de cycle boot/WiFi/capture/upload, la caméra prend une photo toutes les ~20 secondes. Cela provoque :
  - Inondation de la galerie (~4000 photos/jour par caméra)
  - Usure rapide de la flash EEPROM (compteur SD)
  - Sollicitation réseau et serveur continue
  - Vérification OTA à chaque boot (toutes les ~20 s — cf. M-08)
  - Consommation électrique excessive (pas d'économie réelle)
- **Recommandation** : Passer `TIME_TO_SLEEP` à `600` pour les 3 cibles.

#### C-02 — Upload photos non authentifié côté serveur

- **Fichiers** : `serveur/src/Controller/Gallery/GalleryUploadController.php`, `serveur/config/routes_config.php` (lignes 67-70)
- **Constat** : Le firmware envoie un header `X-Api-Key` (main.cpp L192), mais le serveur **ne le vérifie jamais**. Les routes `/msp1gallery/`, `/n3ppgallery/`, `/ffp3gallery/`, `/ffp3/ffp3gallery/` sont dans `public_paths` et accessibles sans authentification. N'importe quelle requête POST multipart valide est acceptée.
- **Impact** : Surface d'attaque ouverte — un tiers peut remplir le stockage serveur avec des JPEG arbitraires, potentiellement offensants ou malveillants. L'inventaire des appareils documente « X-Api-Key header » comme mécanisme d'auth, ce qui est trompeur.
- **Recommandation** : Ajouter une vérification du header `X-Api-Key` dans `GalleryUploadController::processUpload()`. Comparer avec la valeur de `$_ENV['API_KEY']`.

#### C-03 — OTA via HTTP non chiffré, sans vérification d'intégrité

- **Fichiers** : `firmwires/uploadphotosserver/include/config.h` L40, `firmwires/shared/n3_common/src/n3_ota.cpp`
- **Constat** : Les caméras vérifient et téléchargent les mises à jour firmware via `http://` (pas `https://`). Le champ `md5` du `metadata.json` est vide par convention. Aucune signature cryptographique du binaire n'est vérifiée.
- **Impact** : Un attaquant sur le réseau peut intercepter le metadata.json, injecter une URL de firmware malveillant, ou remplacer le binaire par un firmware compromis (MITM). Ce risque est déjà documenté dans `docs/AUDIT_OTA_SYSTEME.md`.
- **Recommandation** : Passer l'URL OTA en HTTPS. Remplir et vérifier le champ MD5 dans n3_ota.cpp. À terme, ajouter une signature Ed25519 (cf. audit OTA existant).

---

### Sévérité ÉLEVÉE

#### E-01 — Aucun réessai HTTP en cas d'échec d'upload

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L174-178
- **Constat** : Si `client.connect()` échoue, la photo est perdue : le framebuffer est libéré et le firmware entre en deep sleep. Pas de retry, pas de stockage local temporaire.
- **Impact** : Toute coupure réseau ponctuelle (bascule WiFi, congestion) entraîne une perte de photo irréversible.
- **Recommandation** : Ajouter 1-2 tentatives de reconnexion avec délai exponentiel avant d'abandonner. Optionnellement, sauvegarder sur SD si l'upload échoue.

#### E-02 — Code de retour HTTP non vérifié après upload

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L208-232
- **Constat** : Le firmware lit la réponse dans `getBody`/`statusLine` mais ne vérifie jamais le code HTTP (200, 400, 413, 415, 500). Il ne peut pas distinguer un upload réussi d'un échec serveur. La réponse est simplement affichée sur le port série.
- **Impact** : Impossible de diagnostiquer à distance un problème de contrat (champ manquant, taille dépassée, type refusé). Le firmware croit toujours avoir réussi.
- **Recommandation** : Parser le code HTTP de `statusLine` et loguer un avertissement si != 200.

#### E-03 — Parsing de réponse HTTP fragile (machine à états manuelle)

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L208-226
- **Constat** : La lecture de la réponse utilise un timer de 30 s avec une machine à états basée sur `\n` et `\r`. Le code est sensible à des réponses HTTP non standard, des connexions lentes, ou des réponses chunked.
- **Impact** : Timeout silencieux possible, body mal parsé, faux positif de succès.
- **Recommandation** : Utiliser `HTTPClient` de l'ESP-IDF (comme dans `n3_http.cpp`) qui gère correctement le parsing HTTP, ou au minimum vérifier la première ligne `HTTP/1.1 200`.

#### E-04 — Compteur EEPROM SD overflow à 255

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L150-159
- **Constat** : `EEPROM.read(0)` lit un seul octet (0-255). Après 255 photos, le compteur revient à 0 et les anciens fichiers `/picture1.jpg` etc. sont écrasés. `EEPROM_SIZE=1` dans config.h.
- **Impact** : Perte de photos sur la carte SD après 256 captures. Avec TIME_TO_SLEEP=3, cela arrive en ~1h30.
- **Recommandation** : Utiliser 2 ou 4 octets (uint16_t/uint32_t) ou Preferences au lieu d'EEPROM. Ou ajouter un horodatage dans le nom de fichier SD (comme le fait le serveur).

#### E-05 — Pas de gestion de l'échec WiFi avant tentative de photo

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L257, L354
- **Constat** : `Wificonnect()` peut échouer (retourne false via `n3WifiConnect`), mais `setup()` continue sans vérifier. La caméra prend une photo et tente l'upload, qui échouera inévitablement.
- **Impact** : Cycle de boot inutile (camera init, warmup, capture, tentative HTTP) consommant énergie et temps pour rien. La photo est perdue sauf si la SD est disponible.
- **Recommandation** : Vérifier le retour de `Wificonnect()`. Si échec, sauvegarder sur SD uniquement (si disponible) et entrer directement en deep sleep.

---

### Sévérité MOYENNE

#### M-01 — FIRMWARE_VERSION désynchronisée avec l'inventaire

- **Fichiers** : `config.h` L5 = `"2.10"`, `docs/inventaire_appareils.md` = `2.9`
- **Constat** : L'inventaire n'a pas été mis à jour lors du passage en version 2.10.
- **Recommandation** : Mettre à jour l'inventaire.

#### M-02 — Version unique pour 3 cibles distinctes

- **Fichier** : `config.h` L5
- **Constat** : msp1, n3pp et ffp3 partagent la même `FIRMWARE_VERSION`. Si un patch ne concerne qu'une cible, le système OTA ne peut pas les distinguer.
- **Recommandation** : Envisager un suffixe par cible (ex. `2.10-msp1`) ou des versions indépendantes dans `metadata.json`.

#### M-03 — Dossier `n3_ota/src/` vide (confusion de structure)

- **Fichier** : `firmwires/shared/n3_ota/src/` (vide) vs `firmwires/shared/n3_common/src/n3_ota.cpp|h`
- **Constat** : Le dossier `n3_ota/` existe comme coquille vide. L'implémentation réelle est dans `n3_common/`. Le `#include "n3_ota.h"` dans main.cpp fonctionne grâce au include path de `n3_common`, mais la structure est trompeuse.
- **Recommandation** : Supprimer le dossier `n3_ota/` vide ou y ajouter un fichier de redirection documentant la localisation réelle.

#### M-04 — `initializeCamera()` avec delay(10000)

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L128
- **Constat** : 10 secondes de délai pendant l'initialisation caméra. Avec les warmup (3 x 1 s) et les autres délais, le cycle total de boot approche 20-25 s avant la première photo.
- **Impact** : Allongement significatif du temps hors deep sleep, donc consommation accrue.
- **Recommandation** : Évaluer si ce délai de 10 s est réellement nécessaire pour la stabilisation AWB/AEC. Le réduire à 3-5 s si possible.

#### M-05 — Désactivation du brown-out detector

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L246
- **Constat** : `WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0)` est courant pour l'ESP32-CAM (appels de courant lors de l'activation du flash/WiFi), mais supprime la protection contre les sous-tensions.
- **Impact** : Risque de corruption NVS/EEPROM en cas de chute de tension pendant une écriture flash.
- **Recommandation** : Acceptable si l'alimentation 5V est stable. Documenter l'exigence d'alimentation dans le README.

#### M-06 — Transport HTTP en clair pour les photos et l'API key

- **Fichier** : `config.h` L7 (`SERVER_PORT 80`), `main.cpp` L192
- **Constat** : Les photos et le header `X-Api-Key` transitent en HTTP non chiffré.
- **Impact** : Interception possible sur le réseau local du lycée.
- **Recommandation** : Passer en HTTPS (WiFiClientSecure) si le certificat serveur le permet. Sinon, documenter le risque accepté.

#### M-07 — Qualité d'image en corbeille non signalée au firmware

- **Fichier** : `serveur/src/Service/GalleryTrashService.php` L73-78, `GalleryUploadController.php` L121
- **Constat** : Le serveur renvoie HTTP 200 même quand la photo est envoyée en corbeille (trop claire/sombre). Le firmware ne peut pas distinguer ce cas. Le message contient « corbeille auto: ... » mais le firmware ne parse pas le body.
- **Impact** : Les caméras qui produisent systématiquement des photos trop sombres/claires (problème matériel ou exposition) ne le savent pas.
- **Recommandation** : Envisager un code HTTP 202 ou un header spécifique pour les photos en corbeille, et loguer côté firmware.

#### M-08 — OTA_CHECK_EVERY_N_BOOTS = 1 (trop fréquent)

- **Fichier** : `config.h` L41
- **Constat** : Vérification OTA à chaque réveil. Avec TIME_TO_SLEEP=3, c'est un GET HTTP toutes les ~20 s. Même avec TIME_TO_SLEEP=600, c'est une requête toutes les 10 min.
- **Impact** : Charge réseau et serveur inutile, allongement du cycle de boot.
- **Recommandation** : Passer à 6 (toutes les heures avec 600 s) comme documenté dans les conventions.

---

### Sévérité FAIBLE

#### F-01 — Dépendance ESP Mail Client inutilisée

- **Fichier** : `firmwires/uploadphotosserver/platformio.ini` L20-21
- **Constat** : `mobizt/ESP Mail Client@3.4.24` est déclaré en lib_deps mais jamais utilisé dans le code caméra. C'est une bibliothèque volumineuse.
- **Impact** : Augmentation inutile de la taille du binaire et du temps de compilation.
- **Recommandation** : Retirer la dépendance.

#### F-02 — Utilisation de `String` Arduino dans le chemin critique

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L135, 182-183, 215-221
- **Constat** : `sendPhoto()` construit plusieurs `String` (head, tail, getAll, getBody, statusLine) par concaténation.
- **Impact** : Fragmentation heap potentielle. Atténué par la PSRAM sur ESP32-CAM.
- **Recommandation** : Acceptable pour l'instant. Préférer des buffers statiques si la fragmentation devient un problème.

#### F-03 — `reinterpret_cast` WifiCredential vers N3WifiNetwork

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L81
- **Constat** : Cast de `WifiCredential { ssid, password }` vers `N3WifiNetwork { ssid, pass }`. Les layouts sont identiques mais les types sont distincts — techniquement UB en C++.
- **Impact** : Fonctionne en pratique sur ESP32 (même ABI). Risque nul en l'état.
- **Recommandation** : Utiliser directement `N3WifiNetwork` dans `credentials.h` pour éliminer le cast.

#### F-04 — `loop()` vide si USE_DEEP_SLEEP = 0

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L361-369
- **Constat** : Le `#if USE_DEEP_SLEEP` dans `loop()` n'a pas de `#else`. Si quelqu'un désactive le deep sleep, la caméra prend une seule photo puis ne fait rien.
- **Impact** : Aucun impact actuellement (toutes les cibles ont USE_DEEP_SLEEP=1). Piège pour une future modification.
- **Recommandation** : Ajouter un `#else` avec un timer pour les photos périodiques (comme l'ancien firmware msp1).

#### F-05 — NTP fail-open (photos nocturnes possibles)

- **Fichier** : `firmwires/uploadphotosserver/src/main.cpp` L238
- **Constat** : Si `getLocalTime()` échoue, `inPhotoWindow()` retourne `true` — la photo est prise même la nuit.
- **Impact** : Documenté comme volontaire. Peut générer des photos noires inutiles (envoyées en corbeille côté serveur).
- **Recommandation** : Acceptable. Le serveur filtre les images trop sombres via `GalleryTrashService`.

---

## 3. Synthèse des écarts

| Sévérité | Nb | Codes |
|----------|----|-------|
| **CRITIQUE** | 3 | C-01, C-02, C-03 |
| **ÉLEVÉ** | 5 | E-01 à E-05 |
| **MOYEN** | 8 | M-01 à M-08 |
| **FAIBLE** | 5 | F-01 à F-05 |
| **Total** | **21** | |

---

## 4. Quick wins (corrections immédiates, faible risque)

| # | Action | Fichier(s) | Effort |
|---|--------|-----------|--------|
| 1 | `TIME_TO_SLEEP` = 600 (C-01) | `config.h` L61, 69, 77 | 1 min |
| 2 | `OTA_CHECK_EVERY_N_BOOTS` = 6 (M-08) | `config.h` L41 | 1 min |
| 3 | Retirer `ESP Mail Client` des lib_deps (F-01) | `platformio.ini` L20-21, 36-37, 52-53 | 1 min |
| 4 | Mettre à jour l'inventaire à 2.11 (M-01) | `docs/inventaire_appareils.md` | 1 min |
| 5 | Supprimer le dossier vide `n3_ota/` (M-03) | `firmwires/shared/n3_ota/` | 1 min |

---

## 5. Corrections structurelles (planification nécessaire)

| # | Action | Fichier(s) | Effort | Dépendances |
|---|--------|-----------|--------|-------------|
| 1 | Vérification `X-Api-Key` côté serveur (C-02) | `GalleryUploadController.php`, `.env` | 30 min | Clé API dans `.env` serveur |
| 2 | Passer OTA en HTTPS + vérif MD5 (C-03) | `config.h`, `n3_ota.cpp`, `metadata.json` | 2 h | Certificat serveur, WiFiClientSecure |
| 3 | Retry HTTP upload (E-01) | `main.cpp` | 1 h | Test sur matériel |
| 4 | Vérification code HTTP retour (E-02) | `main.cpp` | 30 min | — |
| 5 | Compteur SD robuste uint16/Preferences (E-04) | `main.cpp`, `config.h` | 1 h | Test SD physique |
| 6 | Gestion échec WiFi avant photo (E-05) | `main.cpp` | 30 min | — |
| 7 | Utiliser `N3WifiNetwork` dans credentials.h (F-03) | `credentials.h.example`, `main.cpp` | 15 min | Recompiler les 3 cibles |

---

## 6. Plan de validation après correction

### Phase 1 — Quick wins (compilation uniquement)

1. Appliquer les quick wins (cf. section 4).
2. Compiler les 3 cibles : `pio run -e msp1 && pio run -e n3pp && pio run -e ffp3`.
3. Vérifier l'absence d'erreur de compilation.
4. Incrémenter `FIRMWARE_VERSION` → `2.11`.
5. Mettre à jour `docs/inventaire_appareils.md`.

### Phase 2 — Corrections structurelles serveur (C-02)

1. Ajouter la vérification `X-Api-Key` dans `GalleryUploadController`.
2. Lancer le serveur local : `php -S localhost:8080 -t public` (depuis `serveur/`).
3. Tester avec curl :
   - Sans clé : `curl -X POST -F "imageFile=@test.jpg" http://localhost:8080/msp1gallery/upload.php` → doit retourner 401.
   - Avec clé : `curl -X POST -H "X-Api-Key: <clé>" -F "imageFile=@test.jpg" http://localhost:8080/msp1gallery/upload.php` → doit retourner 200.
4. Cycle de publication serveur (`publish-cycle.ps1`).

### Phase 3 — Corrections firmware (E-01 à E-05)

1. Appliquer les corrections firmware.
2. Cycle complet par cible : `erase_flash_monitor.ps1 -Project uploadphotosserver`.
3. Monitoring série 10 min minimum — vérifier :
   - Connexion WiFi réussie
   - Upload HTTP avec code 200 dans la réponse
   - Entrée en deep sleep après upload
   - Réveil après ~600 s
   - Pas de crash/WDT dans les logs
4. Analyse du log : `scripts/analyze_log_generic.ps1`.

### Phase 4 — OTA HTTPS (C-03)

1. Modifier `OTA_METADATA_URL` en `https://`.
2. Tester le téléchargement OTA sur un appareil de test.
3. Vérifier que le MD5 est contrôlé.
4. Déployer via `publish_ota.ps1`.

---

## 7. Fichiers audités

| Fichier | Rôle |
|---------|------|
| `firmwires/uploadphotosserver/src/main.cpp` | Code source unifié |
| `firmwires/uploadphotosserver/include/config.h` | Configuration par cible |
| `firmwires/uploadphotosserver/platformio.ini` | Build PlatformIO |
| `firmwires/uploadphotosserver/include/credentials.h.example` | Template secrets |
| `firmwires/credentials.h.example` | Template secrets partagé |
| `firmwires/shared/n3_wifi/src/n3_wifi.cpp|h` | Bibliothèque WiFi |
| `firmwires/shared/n3_http/src/n3_http.cpp|h` | Bibliothèque HTTP |
| `firmwires/shared/n3_time/src/n3_time.cpp|h` | Bibliothèque temps/RTC |
| `firmwires/shared/n3_common/src/n3_ota.cpp|h` | Bibliothèque OTA |
| `serveur/config/routes_gallery.php` | Routes upload galeries |
| `serveur/config/routes_config.php` | Chemins publics/protégés |
| `serveur/src/Controller/Gallery/GalleryUploadController.php` | Contrôleur upload |
| `serveur/src/Config/GalleryConfig.php` | Configuration galeries |
| `serveur/src/Service/GalleryTrashService.php` | Analyse qualité/corbeille |
| `docs/inventaire_appareils.md` | Registre appareils |
| `docs/AUDIT_OTA_SYSTEME.md` | Audit OTA existant (référence) |
| `docs/audit_firmwares_serveur.md` | Audit firmwares existant (référence) |
