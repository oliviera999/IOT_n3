# Audit du code des firmwares utilisés par le serveur

**Date** : 2026-03-09  
**Périmètre** : firmwares qui envoient des données ou reçoivent des commandes du serveur unifié PHP (iot.olution.info).

---

## 1. Vue d'ensemble

| Firmware | Carte | Endpoints serveur | Rôle |
|----------|--------|-------------------|------|
| **n3pp** | ESP32 | `/n3pp/n3ppdatas/post-n3pp-data.php`, `/n3pp/n3ppcontrol/n3pp-outputs-action.php` | Données serre, contrôle sorties |
| **msp** | ESP32 | `/msp1/msp1datas/post-msp1-data.php`, `/msp1/msp1control/msp1-outputs-action.php` | Données météo, contrôle sorties |
| **uploadphotosserver** | ESP32-CAM | `/msp1gallery/upload.php`, `/n3ppgallery/upload.php`, `/ffp3/ffp3gallery/upload.php` | Upload photos (3 envs) |
| **ffp5cs** | ESP32 / ESP32-S3 | `/post-data`, `/heartbeat`, `/api/outputs/state` (prod/test/test3/s3) | Données aquaponie, heartbeat, état sorties |
| **uploadphotosserver_ffp3_1_5_deppsleep** | ESP32-CAM | `/ffp3/ffp3gallery/upload.php` | Legacy → ffp3 |

---

## 2. Tableau récapitulatif par firmware

| Critère | n3pp | msp | ffp5cs | uploadphotosserver | uploadphotosserver_ffp3_1_5 |
|---------|---------|--------|--------|-------------------|----------------------------|
| **Credentials externalisés** | Oui (credentials.h) | Oui (credentials.h) | Oui (secrets.h, secrets_config.h) | Oui (credentials.h) | **Oui (2026-03)** — migration effectuée |
| **Contrat aligné** | Oui | Oui | Oui | Oui | Oui |
| **Validation capteurs** | Partielle (DHT isnan+0) | Partielle (DHT isnan sans fallback) | Complète (isnan, plages, SensorValidation) | N/A (caméra) | N/A |
| **Version** | 4.11 (n3pp_config.h) | 2.12 (msp_config.h) | 12.27 (config.h) | 2.8 (config.h) | — |
| **OTA** | HTTP via n3_ota | HTTP via n3_ota | HTTPS (OTAManager) | HTTP via n3_ota (toutes cibles) | ArduinoOTA local |
| **Modularisation** | main ~430 L | main ~292 L | Référence (app, modules) | Bonne | Legacy monolithique |

---

## 3. Sécurité et secrets

### État actuel (post-audit 2026-03)

- **firmwires/.gitignore** : exclut `credentials.h`, `secrets.h`, `secrets_config.h`.
- **ffp5cs/.gitignore** : exclut idem.
- **uploadphotosserver_ffp3_1_5_deppsleep** : secrets WiFi **retirés du code** — migration vers `credentials.h` (via `credentials.h.example`). Avant : ssid, password en dur dans main.cpp (risque critique).

### ffp5cs — secrets_config.h

- `config.h` inclut optionnellement `secrets_config.h` (API_KEY, DEFAULT_RECIPIENT).
- Si absent : fallback `"CHANGEZ_MOI"` et `"changez@moi.example"`.
- Pas de `secrets_config.h.example` — à créer pour guider le déploiement.

### Recommandations sécurité

| Risque | Gravité | Firmware(s) | Recommandation |
|--------|---------|-------------|----------------|
| ~~Secrets WiFi en dur~~ | ~~Critique~~ | ~~uploadphotosserver_ffp3_1_5~~ | **Corrigé** — migration credentials.h |
| Clé API fallback "CHANGEZ_MOI" | Moyenne | ffp5cs | Créer secrets_config.h.example, documenter |
| Upload galerie sans auth | Moyenne | uploadphotosserver | Token ou HMAC ou rate limit si exposé |
| Pas de HMAC sur post-data | Faible | ffp5cs | Optionnel : ajouter HMAC puis durcir |

---

## 4. Contrat firmware ↔ serveur

### Alignement vérifié

- **N3PP** : champs POST (`TempAir`, `Humidite`, `Luminosite`, `Humid1`–`4`, etc.) mappés par `N3ppPostDataController` vers `N3ppSensorData`.
- **MSP** : champs POST (`TempAirInt`, `TempAirExt`, `HumidAirInt`, etc.) mappés par `MspPostDataController` vers `MspSensorData`.
- **FFP3** : champs POST alignés avec `SensorData` et `PostDataController`.
- **Galeries** : champ `imageFile`, boundary `RandomNerdTutorials`, chemins conformes à `GalleryUploadController`.

### Authentification

- n3pp, msp, ffp5cs : `api_key` dans le corps POST.
- Galeries : aucune (upload public).

---

## 5. Validation des capteurs

### n3pp

- **DHT** : `isnan()` vérifié, fallback 0.0f en cas d'échec (`n3pp_sensors.cpp`).
- **Humidité sol / luminosité** : pas de validation de plage (0/4095 si déconnecté non géré explicitement).

### msp

- **DHT** : `isnan()` vérifié mais **aucun fallback** — les variables restent NaN et sont envoyées au serveur.
- **DS18B20** : gestion -127°C et 25°C (relecture), pas de plage min/max.
- **Humidité sol / pluie** : pas de validation.

### ffp5cs

- Validation complète : `isnan()`, plages (`SensorConfig::WaterTemp::MIN_VALID`, `AirSensor::TEMP_MIN`, etc.), `SensorValidation::sanitize*`, valeurs par défaut sûres.

### Recommandation msp

- Ajouter un fallback (ex. dernière valeur valide ou valeur par défaut documentée) lorsque `isnan(tempAirInt)` ou `isnan(humidAirInt)` — éviter d'envoyer NaN au serveur.

---

## 6. Versionnage et cohérence metadata

| Source | Version firmware | OTA metadata (serveur) |
|--------|------------------|------------------------|
| n3pp | 4.11 | (ota/n3pp/) |
| msp | 2.12 | (ota/msp/) |
| ffp5cs | 12.27 | 12.26 (ffp3/ota/) |
| uploadphotosserver | 2.8 | 2.6 (ota/cam/) |

- **Dérive** : versions OTA parfois en retard (metadata pas à jour après publication). Aligner metadata lors du `publish_ota.ps1`.
- **Conventions** : incrémenter version à chaque modification, documenter dans VERSION.md / CHANGELOG.

---

## 7. OTA

- **n3pp, msp** : OTA HTTP distant via n3_ota (metadata.json + firmware.bin). URLs prod/test.
- **ffp5cs** : OTA dédié via `OTAManager`, HTTPS, script `ffp5cs/scripts/publish_ota.ps1`.
- **uploadphotosserver** : OTA distant HTTP **implémenté** pour les trois cibles (msp1, n3pp, ffp3) via `n3OtaCheck` à chaque boot (OTA_CHECK_EVERY_N_BOOTS=1). Contredit l'ancien audit OTA.
- **uploadphotosserver_ffp3_1_5_deppsleep** : ArduinoOTA local uniquement, pas d'OTA distant.

---

## 8. Offline-first et robustesse réseau

- **ffp5cs** : timeouts 5 s (POST), 8 s (GET outputs) ; queue NVS pour POST en échec ; pas de blocage > 3 s sans feed watchdog.
- **n3pp, msp** : dépend de n3_http (lib partagée) — timeouts à vérifier dans n3_common.
- **uploadphotosserver** : deep sleep 600 s (toutes cibles) ; pas de blocage prolongé.

---

## 9. Non-conformités et actions correctives

### Résolues (audit 2026-03)

| Non-conformité | Gravité | Action |
|----------------|---------|--------|
| Secrets WiFi en dur dans uploadphotosserver_ffp3_1_5_deppsleep | Critique | Migration vers credentials.h effectuée ; forward declarations ajoutées pour compilation |

### À traiter

| Non-conformité | Gravité | Action recommandée |
|----------------|---------|--------------------|
| ~~msp : DHT isnan sans fallback~~ | ~~Majeur~~ | **Corrigé** — fallback 20°C / 50 % en cas de NaN |
| ffp5cs : pas de secrets_config.h.example | Mineur | Créer le template |
| Dérive versions OTA vs firmware | Mineur | Synchroniser metadata lors de publish_ota |
| Upload galerie sans authentification | Moyen | Token, HMAC ou rate limit si exposition publique |

---

## 10. Fichiers de référence

- Routes serveur : `serveur/public/index.php`
- Contrôleurs : `N3ppPostDataController`, `MspPostDataController`, `PostDataController`, `HeartbeatController`, `GalleryUploadController`
- DTO : `serveur/src/Domain/N3ppSensorData.php`, `MspSensorData.php`, `SensorData.php`
- Firmwares : `firmwires/n3pp/`, `firmwires/msp/`, `firmwires/uploadphotosserver/`, `firmwires/ffp5cs/`, `firmwires/uploadphotosserver_ffp3_1_5_deppsleep/`
- Règles : `.cursor/rules/coherence-firmware-serveur.mdc`, `conventions-firmwares.mdc`, `securite-et-secrets.mdc`
