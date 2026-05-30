# Changelog IOT_n3

Modifications notables du depot racine (regles, doc, structure).

Format : [version] - date - description.

---

## [2026.05] - 2026-05-30

### Firmwires — build et publication phase 1

- Submodule **firmwires** : n3pp **4.39**, msp **2.43**, uploadphotosserver **2.39** (modules caméra, `n3_outputs_json`, poissonglouton).
- Correctifs build : constantes OLED, `API_SIG_SECRET` fallback, `ArduinoJson`/`Arduino_JSON` deps.

## [2026.05] - 2026-05-19

### Audit firmwares n3pp et msp — modernisation contrat

Cycle d'audit complet (n3pp v4.38, msp v2.42, libs partagées, serveur PHP).

**Bugs critiques corrigés**
- **n3pp** : `String emailMessage` locale qui masquait la globale → alertes batterie/sécheresse/arrosage envoyaient un message vide (corrigé dans `n3pp_automation.cpp` et `main.cpp`).
- **n3pp + msp** : `server.begin()` retiré du `loop()` (aucune route enregistrée).
- **n3pp + msp** : bloc périodique `intervalDatas` repositionné AVANT `sommeil()` (mort en deep sleep).
- **n3pp** : cooldown 5 min sur l'arrosage auto, clamp `tempsArrosageSec ≤ 20 s`, suppression de la double mesure `PontDiv`.
- **msp** : remplacement de `analogRead(27)` codé en dur par la macro `PLUIE`, DS18B20 avec test `DEVICE_DISCONNECTED_C` + plage -20…70 °C + retry + fallback 20 °C, init des servos à un angle de repli, réduction des boucles OLED (3×6 → 3 pages) pour limiter le risque WDT.
- **shared/n3_http** : ajout du timeout `N3_HTTP_TIMEOUT_MS` (5 s) ; vérification WiFi avant requête ; lib marquée dépréciée au profit de `n3_data`.
- **shared/libn3_iot** : `N3AnalogSensor` délègue à `n3_analog_sensors` (filtrage médiane), DS18B20 corrigé (`DEVICE_DISCONNECTED_C`), DHT bornes physiques.

**Robustesse**
- **n3pp + msp** : `outputs_state` exige désormais HTTP 200 strict + compteur d'échecs consécutifs `[SERVER][GET][OFFLINE]`.
- **n3pp + msp** : `configTime` appelé 1× par réveil au lieu de chaque `loop()`.
- **n3pp + msp** : validation DHT enrichie (bornes -40…80 °C, 0…100 %).
- **msp** : capteur pluie distingue "sec" vs "débranché" (raw ≤ 3).

**Modernisation contrat firmware ↔ serveur**
- **HMAC FFP3 désormais supporté côté n3pp/msp** : `n3DataPost` ajoute `timestamp` + `signature` (HMAC-SHA256 du timestamp avec `API_SIG_SECRET`) si `API_SIG_SECRET` est défini dans `credentials.h` et que l'horloge est sync.
- **Côté serveur** : nouveau trait `HmacAuthTrait` (utilisé par `MspPostDataController` et `N3ppPostDataController`), même contrat que FFP3 avec fallback `api_key`.
- **Alias modernes** : `POST /msp1/post-data`, `POST /n3pp/post-data` (URLs courtes, contrat identique).
- **Nouveaux endpoints heartbeat** : `POST /msp1/heartbeat` et `POST /n3pp/heartbeat` (auth HMAC ou api_key, tables `msp1Heartbeat` / `n3ppHeartbeat`). Migration SQL : `serveur/migrations/CREATE_LEGACY_HEARTBEAT_TABLES.sql`.

**Factorisation libs partagées**
- **shared/n3_common** v1.4.0 : nouveau `n3_outputs_json.{h,cpp}` (parsing GPIO `readIntByKey` / `tryReadIntByKey` / `readStringByKey`) — supprime ~75 lignes dupliquées entre `n3pp_network.cpp` et `msp_network.cpp`. Ajout de `N3_HTTP_TIMEOUT_MS` et `N3_DEFAULT_FREQ_WAKE_UP_S` dans `n3_defaults.h`.
- **shared/n3_data** : nouveau champ `sigSecret` + `currentEpochSeconds` dans `N3PostConfig` pour le HMAC FFP3 (compat ascendante via `apiKey`).
- **shared/n3_battery** v1.0.1 : déclaration explicite de la dépendance `n3_analog_sensors`.
- **shared/libn3_iot** v1.1.0 : ADC filtré (`n3_analog_sensors`), DS18B20 `DEVICE_DISCONNECTED_C`.

**Sécurité**
- **OTA** confirmé : `shared/n3_common/n3_ota` (≥ 1.3.0) vérifie le `sha256` du firmware + la `signature` ECDSA P-256 avant le flash (clé publique embarquée dans `n3_ota_pubkey.h`).
- `firmwires/.gitignore` : ajout de `*.key`, `*.pem`, `scripts/ota_keys/`.
- `credentials.h.example` racine : ajout de `API_SIG_SECRET` ; suppression des noms legacy `n3pp4_2` / `msp2_5`.
- `serveur/.env.example` : documentation étendue de `API_SIG_SECRET` (FFP3 + Msp + N3pp).

**Documentation et règles Cursor**
- Nouveau : `serveur/docs/API_MSP1_N3PP.md` (contrat HTTP complet : URLs, auth, champs, codes HTTP, GPIO map, alias modernes).
- Nouveau : `serveur/docs/OTA_N3PP_MSP.md` (format metadata.json, vérification sha256+signature, publication via `publish_ota.ps1`).
- Nouveau : `firmwires/shared/README.md` (inventaire complet des libs partagées, intégration, sécurité, versionnage).
- Mise à jour : `firmwires/README.md` (libs partagées élargies à `n3_data`, `n3_hmac`, `n3_sleep`, `n3_display`, `n3_outputs_json`), `firmwires/credentials.h.example` (noms legacy supprimés + `API_SIG_SECRET`).
- `firmwires/RAPPORT_ANALYSE.md` et `firmwires/RECOMMANDATIONS.md` marqués comme archives (constats obsolètes depuis l'externalisation des credentials).
- `.cursor/rules/firmwares-legacy-n3pp-msp.mdc` réécrit : libs partagées correctes, contrat HMAC FFP3, OTA sha256/ECDSA, bornes capteurs.
- `.cursor/rules/workflow-scripts-firmwares.mdc` : `analyze_log_generic.ps1` confirmé versionné.
- `.cursor/rules/git-et-versionnement.mdc` : source de version `FIRMWARE_VERSION` dans `*_config.h` (pas `main.cpp`).

**Tests**
- `serveur/tools/local-smoke-test.ps1` : ajout POST `/msp1/post-data` + `/n3pp/post-data` (legacy et moderne), 401 sur clé invalide, heartbeats.
- `serveur/tests/Controller/HmacAuthTraitTest.php` : couverture du trait HMAC (HMAC valide, signature invalide, signature incomplète, secret manquant).

**Inventaire**
- `docs/inventaire_appareils.md` : n3pp 4.37 → 4.38, msp 2.40 → 2.42, mention `/post-data` et HMAC en option.

---

## [2026.03] - 2026-03-16

### Renommage firmwares
- **n3pp4_2 → n3pp** : dossier et références (scripts, doc, règles, serveur, skills). Version n3pp 4.15.
- **msp2_5 → msp** : idem. Version msp 2.15.
- Scripts : `publish_ota.ps1`, `erase_flash_monitor.ps1`, `find-bugs.ps1` pointent vers `firmwires/n3pp` et `firmwires/msp`.
- Documentation, `.cursor/rules`, `.cursor/skills`, libs partagées et inventaire alignés.

---

## [2026.03] - 2026-03-10

### Audit documentation
- **firmwares.manifest.json** : création du manifest pour `scripts/firmwires-list.ps1` (n3pp, msp, uploadphotosserver, ffp5cs, ratata, LVGL_Widgets).
- **ANALYSE_ARBORESCENCE** : mise à jour section uploadphotosserver (projet unifié, 3 envs), structure serveur (Slim 4, modules msp1/n3pp).
- **inventaire_appareils** : alignement versions firmware (n3pp 4.13, msp 2.13).
- **RECOMMANDATIONS_IOT** : caméras → uploadphotosserver unifié.
- **README** : clarification liens module N3PP/MSP1 (serveur unifié Slim 4).
- **serveur/docs/README** : mise à jour version 5.0.102.
- **docs/archive/** : archivage rapports ponctuels (check-pages, rapport_*, resume_*, diagnostic-*).

---

## [2025.03] - 2025-03-07

### OTA et déploiement (n3pp, msp1 test)
- **Publication OTA** : ajout des cibles `n3pp-test` et `msp-test` dans `scripts/publish_ota.ps1` (env `esp32dev_test`, binaires vers `serveur/ota/n3pp-test/` et `serveur/ota/msp-test/`).
- **n3pp** (v4.5) : URL OTA conditionnelle selon `TEST_MODE` (n3pp-test vs n3pp).
- **msp** (v2.7) : URL OTA conditionnelle selon `TEST_MODE` (msp-test vs msp) ; version passée en `version.c_str()` dans la config OTA.
- **Documentation** : skill déploiement-appareil-iot (section OTA distant), README racine (point Publication OTA).

---

## [2025.03] - 2025-03-06

### Règles projet
- **Cycle obligatoire** : chaque modification (firmware ou serveur) doit être associée à une incrémentation de version, une mise à jour des fichiers de documentation concernés, suivie d’un commit et d’un push de tout le projet (dépôt parent et submodules) vers GitHub.
- Règles détaillées dans `.cursor/rules/git-et-versionnement.mdc` et `documentation.mdc`.
- Mise à jour des règles : contexte serveur unifié, procédure de push complète (submodules puis parent).

### Référence submodule serveur
- **serveur** : version 5.0.27 (voir serveur/VERSION et serveur/CHANGELOG.md).
