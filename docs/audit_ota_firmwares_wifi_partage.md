# Audit OTA — firmwares modifiés (WiFi partagé scan+RSSI)

**Contexte** : modifications apportées dans la conversation « WiFi partagé (scan + RSSI) pour msp, n3pp et ESP32-CAM ». Ce document audite l’OTA pour les trois firmwares concernés.

---

## 1. n3pp4_2 (serre / aquaponie)

### Mécanisme OTA
- **Type** : OTA HTTP distant via la lib **n3_common** (symbole `n3OtaCheck`, `N3OtaConfig`).
- **Moment** : après `Wificonnect()` dans `setup()`.
- **URLs** :
  - Prod : `http://iot.olution.info/ota/n3pp/metadata.json`
  - Test : `http://iot.olution.info/ota/n3pp-test/metadata.json` (si `TEST_MODE`).
- **Version** : lue dans le code (`String version = "4.6"`), passée en `version.c_str()` dans la config OTA.
- **Script** : `scripts/upload_hook_otadata.py` → pointe vers `../scripts/upload_esp32_otadata_reset.py` pour effacer la partition `otadata` après flash USB (prochain boot sur app0).

### Impact du changement WiFi
- OTA s’exécute **après** la connexion WiFi. Avec la nouvelle logique (scan + tri RSSI + BSSID), la connexion peut être plus rapide quand plusieurs AP sont visibles, donc la vérification OTA peut avoir lieu plus tôt.
- Si WiFi échoue, aucun changement de comportement : OTA n’est pas exécuté (comme avant).

### Points d’attention
- **Version** : toujours `4.6` ; les conventions projet demandent d’incrémenter la version à chaque modification. À incrémenter si on publie un firmware avec le WiFi partagé.
- **Implémentation n3_ota** : le code source de `n3OtaCheck` / `N3OtaConfig` n’est pas présent sous `firmwires/shared/` dans le dépôt (la lib est résolue au build, ex. `n3_common @ 1.1.0`). Pour un audit complet du flux HTTP (metadata, téléchargement, rollback), il faudrait auditer le code de cette lib.

---

## 2. msp2_5 (station météo)

### Mécanisme OTA
- **Type** : OTA HTTP distant via **n3_common** (`n3OtaCheck`, `N3OtaConfig`).
- **Moment** : après `Wificonnect()` dans `setup()`.
- **URLs** :
  - Prod : `http://iot.olution.info/ota/msp/metadata.json`
  - Test : `http://iot.olution.info/ota/msp-test/metadata.json` (si `TEST_MODE`).
- **Version** : `String version = "2.8"` dans `main.cpp`, passée à la config OTA.
- **Script** : même hook `upload_hook_otadata.py` que n3pp (reset otadata après flash USB).

### Impact du changement WiFi
- Identique à n3pp : OTA après WiFi ; connexion potentiellement plus rapide avec le scan RSSI ; pas d’OTA si WiFi en échec.

### Points d’attention
- **Version** : toujours `2.8` ; à incrémenter si publication d’un firmware avec WiFi partagé.
- Même remarque que pour n3pp concernant l’audit détaillé de la lib n3_ota / n3_common.

---

## 3. uploadphotosserver (ESP32-CAM, msp1 / n3pp / ffp3)

### Mécanisme OTA actuel
- **TARGET_MSP1** uniquement :
  - **ArduinoOTA** (OTA local) : port 3232, hostname `esp32cam-msp1`, pas de mot de passe dans le code.
  - `ArduinoOTA.begin()` en fin de `setup()`, `ArduinoOTA.handle()` dans `loop()`.
- **TARGET_N3PP** et **TARGET_FFP3** : pas d’OTA dans le code (deep sleep, pas de boucle ; le device fait une photo puis se rendort).

### Écart avec la doc / conventions
- Le fichier `.cursor/rules/esp32-cam-conventions.mdc` décrit un **OTA distant HTTP** pour toutes les cibles cam :
  - `GET http://iot.olution.info/ota/cam/metadata.json`
  - Format multi‑cible (`msp1`, `n3pp`, `ffp3`) avec version, url, md5.
  - Vérification au boot + périodique (msp1 : 2 h ; n3pp/ffp3 : tous les 6 réveils).
- **Dans le code actuel** : aucun appel à un équivalent `n3OtaCheck` ni lecture de `metadata.json` ; seule l’OTA local ArduinoOTA (msp1) est implémentée.
- **Conclusion** : l’OTA distant HTTP pour les caméras est prévu côté infra (script `scripts/publish_ota.ps1` met à jour `serveur/ota/cam/metadata.json` et les binaires), mais **n’est pas implémenté dans le firmware**. Les caméras ne se mettent pas à jour automatiquement via le serveur.

### Impact du changement WiFi
- Connexion WiFi (scan + RSSI) utilisée avant toute action réseau (photo, OTA local). Pas de changement de sémantique OTA : ArduinoOTA (msp1) reste dépendante du WiFi comme avant.

### Points d’attention
- **Version** : `FIRMWARE_VERSION "2.2"` dans `config.h` ; à incrémenter si publication avec WiFi partagé.
- **Sécurité ArduinoOTA** : pas de mot de passe configuré ; acceptable seulement si le réseau est maîtrisé.
- **Évolution recommandée** : implémenter l’OTA distant HTTP (metadata.json + téléchargement firmware) pour les trois cibles cam, comme décrit dans les conventions, afin d’aligner code et déploiement.

---

## 4. Publication OTA (script commun)

- **Script** : `scripts/publish_ota.ps1` (racine IOT_n3).
- **Cibles concernées** :
  - n3pp, n3pp-test, msp, msp-test → version lue dans `main.cpp` (`String version = "..."`).
  - cam-msp1, cam-n3pp, cam-ffp3 → version lue dans `include/config.h` (`FIRMWARE_VERSION`).
- **Actions** : compilation optionnelle (`-Build`), copie des `firmware.bin` vers `serveur/ota/...`, mise à jour des `metadata.json`, commit + push dans le sous‑module serveur.
- Les metadata n3pp/msp sont au format simple (version, url, md5) ; les metadata cam sont au format multi‑cible (clés msp1, n3pp, ffp3).

---

## 5. Synthèse et actions recommandées

| Firmware              | OTA actuel                    | Dépendance WiFi     | Version à jour ? |
|-----------------------|-------------------------------|----------------------|------------------|
| n3pp4_2               | HTTP distant (n3_ota)         | Après Wificonnect()  | Non (4.6)         |
| msp2_5                | HTTP distant (n3_ota)         | Après Wificonnect()  | Non (2.8)         |
| uploadphotosserver    | ArduinoOTA (msp1 seulement)  | WiFi requis          | Non (2.2)         |

**Recommandations :**
1. **Versions** : incrémenter les versions (n3pp, msp, uploadphotosserver) avant toute publication OTA des firmwares modifiés (WiFi partagé).
2. **n3pp / msp** : pas de régression OTA liée au WiFi ; le flux reste « WiFi puis OTA ». Amélioration possible du temps de connexion.
3. **uploadphotosserver** : documenter clairement que l’OTA distant HTTP (metadata.json) n’est pas encore implémenté dans le firmware, ou prévoir son implémentation pour aligner avec les conventions et le script `publish_ota.ps1`.
