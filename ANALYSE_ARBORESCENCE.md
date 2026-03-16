# Analyse générale de l'arborescence – IOT_n3

**Date :** 5 mars 2026 (mise à jour doc : mars 2026)  
**Périmètre :** `c:\IOT_n3`

---

## 1. Vue d'ensemble

Le workspace **IOT_n3** est un projet **IoT (Internet des Objets)** centré sur :

- **Firmwares** : microcontrôleurs ESP32, ESP32-CAM, Arduino UNO (PlatformIO)
- **Serveur** : applications web PHP pour collecte de données, tableaux de bord, galeries photos et contrôle à distance
- **Domaine métier** : serre/aquaponie, station météo, suivi de photos, robot/voiture (kit Ratata)

**Point d’entrée web :** `https://iot.olution.info` (référencé dans le code et la doc).

---

## 2. Structure racine

```
c:\IOT_n3\
├── .gitignore
├── README.md, RECOMMANDATIONS_IOT.md, ANALYSE_ARBORESCENCE.md
├── docs\               # Inventaire des appareils (inventaire_appareils.md)
├── firmwires\          # Tous les projets firmware (ESP32, Arduino, PlatformIO)
└── serveur\            # Applications web PHP (données, contrôle, galeries)
```

- **Dépôt Git** initialisé à la racine (IOT_n3) ; **serveur** est un submodule **n3_serveur** (contenant msp1, n3pp, ffp3 intégré) ; **firmwires** (submodule) contient **ffp5cs** en dossier ordinaire. Voir [RECOMMANDATIONS_IOT.md](RECOMMANDATIONS_IOT.md).
- **README racine** : [README.md](README.md) décrit le projet, les liens firmware ↔ serveur, et pointe vers [docs/inventaire_appareils.md](docs/inventaire_appareils.md).

---

## 3. Dossier `firmwires/`

Regroupe **tous les firmwares** pour cartes ESP32, ESP32-CAM et Arduino UNO. Outil de build : **PlatformIO**.

### 3.1 Documentation centrale

| Fichier | Rôle |
|--------|------|
| `README.md` | Description des projets, commandes de compilation/upload, structure des dossiers |
| `RAPPORT_ANALYSE.md` | Rapport d’analyse (bugs, sécurité, recommandations) – mars 2025 |
| `RECOMMANDATIONS.md` | Recommandations (Git, nommage, partition, refactor) – mis à jour (état actuel) |
| `.gitignore` | À la racine firmwires et IOT_n3 : `.pio/`, `desktop.ini`, fichiers sensibles, `error_log` |

### 3.2 Projets firmware (détail)

#### A. N3PhasmesProto – `n3pp/`

- **Carte :** ESP32 (`esp32dev`)
- **Rôle :** Contrôle serre / aquaponie
- **Fonctionnalités :** Température/humidité air (DHT), 4× humidité sol, pompe, luminosité, nourrissage poisson, mails d’alerte, serveur web, NTP, OLED, deep sleep
- **Fichiers :** `platformio.ini`, `src/main.cpp` (~1300 lignes), `n3pp.ino` (ancien sketch Arduino)
- **Stack :** AsyncTCP, ESPAsyncWebServer, DHT, ESP Mail Client, Arduino_JSON, Adafruit GFX/SSD1306, ESP32Time, Preferences

#### B. MeteoStationPrototype – `msp/`

- **Carte :** ESP32 (`esp32dev`)
- **Rôle :** Station météo + tracker solaire
- **Fonctionnalités :** 2× DHT, humidité sol, pluie, DS18B20, 4 LDR, 2 servos, relais, mails, serveur web, NTP, OLED
- **Fichiers :** `platformio.ini`, `src/main.cpp` (~1058 lignes), `lib/`, `include/`, `test/`
- **Stack :** idem n3pp + OneWire, DallasTemperature, ESP32Servo, Preferences, ESPmDNS
- **Note :** la ligne `board_build.partitions = min_spiffs.csv` a été retirée ; partition par défaut utilisée

#### C. Upload photos (ESP32-CAM) – projet unifié

| Env PlatformIO | Cible galerie | Deep sleep | Remarques |
|----------------|---------------|------------|-----------|
| `msp1` | msp1gallery | 600 s | OTA, SD, envoi 6h–22h |
| `n3pp` | n3ppgallery | 600 s | OTA, SD |
| `ffp3` | ffp3gallery | 600 s | idem |

Un seul firmware **uploadphotosserver** avec trois envs PlatformIO. Les envs indiquent l’**endpoint cible** (msp1gallery, n3ppgallery, ffp3gallery). Compilation : `pio run -e msp1` / `-e n3pp` / `-e ffp3`. Capture JPEG, POST HTTP vers le serveur, WiFi, NTP, LED de statut (GPIO 33).

#### D. Ratata – Kit ZYC0108-EN – `ratata/`

- **Documentation dédiée :** voir [firmwires/ratata/README.md](firmwires/ratata/README.md) pour la structure, les huit exemples et les broches.
- **Un projet, 8 environnements** (objectif : un `platformio.ini` à la racine de `ratata/`) :
  - **7 env. Arduino UNO :** `1_auto_move`, `2_servo_angle`, `3_ultrasonic_follow`, `4_obstacle_avoidance`, `5_tracking`, `6_2_arduino_uno`, `test`
  - **1 env. ESP32-CAM :** `6_1_esp32_car` (voiture avec caméra WiFi, stream HTTP)
- **Structure actuelle :** `ZYC0108-EN/ZYC0108-EN/2_Arduino_Code/` contient les exemples (1_Auto_move, 2_servo_Angle, …, 6.1_ESP32_Car, 6.2_Arduino_UNO, test). Optionnel : `src/` + `platformio.ini` à la racine pour build PlatformIO.
- **Broches communes UNO :** 74HCT595N, PWM 5/6, Servo 9, Ultrason 12/13, suivi de ligne A0–A2

#### E. FFP5CS – Contrôleur aquaponie ESP32 – `ffp5cs/`

- **Projet le plus structuré** : architecture modulaire, plusieurs environnements (WROOM, S3, prod/test, PSRAM, native).
- **Cartes :** ESP32-WROOM, ESP32-S3 (N16R8, 16 Mo flash, 8 Mo PSRAM).
- **Fonctionnalités :** Nourrissage auto, niveau d’eau, remplissage, détection marées, DHT/DS18B20, alertes mail, interface web, Light Sleep, OTA, LittleFS.
- **Structure :**
  - `src/` : `app.cpp`, `sensors.cpp`, `actuators.cpp`, `web_server.cpp`, `system_boot.cpp`, etc.
  - `include/` : `config.h`, `automatism.h`, `sensors.h`, `pins.h`, `wifi_manager.h`, `mailer.h`, etc.
  - `data/` : interface web (HTML, assets, SW), scripts build (mklittlefs)
  - `config/partitions/` : partitions OTA/FS
  - `managed_components/` : nombreuses libs (RainMaker, LittleFS, etc.)
  - `tools/` : scripts Python (pio_add_mklittlefs_path, pio_write_build_version)
  - `test/`, `test psram s3/`, `test psram s3 2/` : projets de test
- **Environnements notables :** `wroom-prod`, `wroom-test`, `wroom-s3-*`, `native` (tests), etc.
- **Dépôt Git :** sous-dossier `ffp5cs` contient un `.git/` (sous-projet versionné)

#### F. LVGL_Widgets – `LVGL_Widgets/`

- **Carte :** ESP32-S3 (`esp32-s3-devkitc-1`), écran JC4827W543 (Arduino_GFX, TouchLib), PSRAM.
- **Stack :** LVGL 8.4, AsyncTCP, ESPAsyncWebServer, DHT, OneWire, DallasTemperature, NTP, ElegantOTA, Grove Ultrasonic.
- **Fichier principal :** `src/main.cpp` (très volumineux : setup vers ligne 1630, loop vers 1753).

#### G. Projets de test (dans ou à côté de ffp5cs)

- `ffp5cs/test psram s3/` et `ffp5cs/test psram s3 2/` : tests ESP32-S3 PSRAM, chacun avec son `platformio.ini` et `src/main.cpp`.

### 3.3 Fichiers de configuration communs (firmwires)

- **Port série :** la plupart des `platformio.ini` ont `upload_port = COM3`, `monitor_port = COM3` en dur (à adapter selon la machine).
- **.vscode :** `firmwires/.vscode/settings.json` présent (config éditeur/PlatformIO).

### 3.4 Synthèse firmwares

| Projet | Carte(s) | Lignes main.cpp (ordre de grandeur) | Modularité |
|--------|----------|-------------------------------------|------------|
| n3pp | ESP32 | ~1300 | Monolithique |
| msp | ESP32 | ~1058 | Monolithique |
| uploadphotosserver | ESP32-CAM | variable | Un fichier principal unifié (3 envs) |
| ratata (par ex.) | UNO / ESP32-CAM | variable (court à ~500) | Un main par exemple |
| ffp5cs | WROOM / S3 | réparti en plusieurs .cpp | Modulaire |
| LVGL_Widgets | ESP32-S3 | ~1700+ | Monolithique |

---

## 4. Dossier `serveur/`

Applications **PHP** pour la collecte de données, le contrôle des appareils et l’affichage web. Domaine : **iot.olution.info**.

### 4.1 Entrée principale

- **`public/index.php`** : front controller Slim 4 d’accueil « n³ iot datas » (HTML5 UP – Massively). Liens vers ffp3, msp1, n3pp, etc. CSS hébergé sur `https://iot.olution.info/assets/css/`.
- **`README.txt`** : crédits du thème Massively (HTML5 UP), pas une doc technique du serveur.

### 4.2 Modules par produit

Les modules MSP1 et N3PP sont des routes et Controllers dans l'app Slim unifiée.

#### A. Module MSP1 (météo)

- **Routes** : `/msp1/msp1datas/post-msp1-data.php` (POST firmware), `/meteo` (page données), `/meteo-control` (page contrôle)
- **Controllers** : `src/Controller/Msp/` (MspPostDataController, MspDataController, MspOutputController)
- **Templates** : `msp1_data.twig`, `msp1_control.twig`

La galerie photos : routes **`/msp1gallery/`** (voir ci-dessous).

#### B. Module N3PP (serre)

- **Routes** : `/n3pp/n3ppdatas/post-n3pp-data.php` (POST firmware), `/serre` (page données), `/serre-control` (page contrôle)
- **Controllers** : `src/Controller/N3pp/` (N3ppPostDataController, N3ppDataController, N3ppOutputController)
- **Templates** : `n3pp_data.twig`, `n3pp_control.twig`

La galerie photos : routes **`/n3ppgallery/`** (voir ci-dessous).

#### Galeries photo

- **Routes** : `/msp1gallery/upload.php`, `/n3ppgallery/upload.php`, `/ffp3/ffp3gallery/upload.php` — gérées par `GalleryUploadController`, `GalleryViewController`

Présence de **error_log** et de fichiers « old » / « 2 » indiquant des évolutions et du legacy.

#### C. FFP3 – `serveur/ffp3/`

Application **moderne** (PHP 8.1+, Slim 4, Twig, PHP-DI, Monolog, PHPUnit).

- **Architecture :**
  - **public/** : front controller `index.php`, assets (images aquaponie, etc.)
  - **src/** :  
    - **Config/** : Env, PDO, TableConfig, dépendances  
    - **Controller/** : Aquaponie, Auth, Cache, Dashboard, Export, Heartbeat, Home, Output, PostData, RealtimeApi, Supervision, TideStats  
    - **Domain/** : DTO (ex. SensorData)  
    - **Repository/** : SensorRepository, OutputRepository, BoardRepository, SensorReadRepository, AbstractRepository  
    - **Service/** : SensorDataService, OutputService, OutputCacheService, RealtimeDataService, ErrorAlertService, TideAnalysisService, WaterBalanceService, TemplateRenderer, LogService, etc.  
    - **Middleware/** : ErrorHandler, Auth, TokenAuth, Environment  
    - **Security/** : AuthService, CsrfService  
    - **Util/** : ResponseHelper, RequestHelper, MathUtils, StateNormalizer, TableValidator  
    - **Command/** : commandes CLI/CRON
  - **templates/** : vues Twig (Bootstrap 5, Highcharts)
  - **tests/** : PHPUnit (SensorDataServiceTest, OutputCacheServiceTest, CsrfServiceTest, etc.)
  - **bin/** : scripts (diagnose-controllers, clear-cache)
  - **tools/** : `ping_standalone.php`, `generate_password_hash.php`, `run-phpunit.php`
  - **config/** : `dependencies.php`
  - **docs/** : documentation
  - **VERSION**, **CHANGELOG.md**

- **Fonctionnalités :** ingestion données capteurs (POST avec clé API + HMAC-SHA256), dashboard (Highcharts, CSV), surveillance aquaponie, contrôle GPIO, sync ESP32 ↔ serveur, tâches planifiées (CRON), logging (Monolog).

- **Dépôt Git :** `serveur/ffp3/` est un dossier versionné dans le dépôt **n3_serveur** (ffp3 a été fusionné avec historique via `git subtree add` ; ce n’est plus un sous-dépôt séparé).

### 4.3 Fichiers communs / divers

- **error_log** : présents dans plusieurs sous-dossiers (msp1, n3pp, galeries) – à ne pas versionner en production.
- **Fichiers « old » / « 2 »** : variantes ou anciennes versions (ex. `n3pp-outputsold.php`, `n3pp-databaseold.php`, `n3pp-outputs2.php`) – à clarifier ou archiver.

### 4.4 Dossier `serveur/site initial/`

- **Rôle** : archive d’une ancienne version des fichiers serveur (ex. ffp3_prov4).
- **Règle** : **ne pas modifier** ce dossier. Il est conservé pour **consultation uniquement** (référence, comparaison avec la version actuelle, historique, dépannage).
- Les évolutions et corrections se font dans les dossiers actuels du serveur (msp1, n3pp, ffp3, galeries), pas dans `site initial/`.

### 4.5 Synthèse serveur

| Chemin | Type | Rôle |
|--------|------|------|
| `serveur/public/index.php` | Slim 4 | Front controller unique |
| Modules msp1, n3pp | Slim 4 | Controllers `src/Controller/Msp/`, `N3pp/` — données, contrôle, galeries |
| `serveur/ffp3/` | Slim 4 (dossier) | Sous-projet historique, scripts, doc ; code actif dans `serveur/src/` |

---

## 5. Points d’attention transversaux

### 5.1 Versionnement

- **Racine IOT_n3** : dépôt Git initialisé (`.gitignore` racine). **serveur** est un submodule pointant vers **n3_serveur** (dépôt contenant msp1, n3pp, galeries et ffp3 en dossier intégré) ; **firmwires/ffp5cs** est un dossier ordinaire dans le submodule firmwires. Voir RECOMMANDATIONS_IOT.md §3 pour les URLs et la procédure.
- **Registre des appareils** : voir `docs/inventaire_appareils.md`.

### 5.2 Sécurité (déjà signalée dans RAPPORT_ANALYSE)

- **n3pp** et **msp** : secrets externalisés dans `credentials.h` (non versionné) + `credentials.h.example`. Autres firmwares : à vérifier (LVGL_Widgets a encore une clé en dur).

### 5.3 Configuration

- Port série **COM3** en dur dans la plupart des `platformio.ini` ; à adapter ou documenter par machine.
- **msp** : `board_build.partitions = min_spiffs.csv` sans fichier `min_spiffs.csv` dans le dépôt.

### 5.4 Qualité de code (firmwares)

- **n3pp** : bug dans `batterie()` (`sampleTotal += analogRead(...)` au lieu des `samples[sampleIndex]`), et affichage OLED utilisant `digitalRead()` sur des variables (à corriger en affichage direct des variables).
- Plusieurs firmwares **monolithiques** (un seul `main.cpp` très long) ; ffp5cs sert de référence pour une structure modulaire.

### 5.5 Redondances

- **Duplication** entre n3pp et msp (WiFi, NTP, mail, OLED, serveur web) ; RECOMMANDATIONS suggère un dossier `common/` ou lib partagée.

### 5.6 Nommage et chemins

- **ffp5cs** : chemins courts recommandés sous Windows (limite longueur ligne de commande pour build S3).

---

## 6. Arborescence schématique (principaux dossiers)

```
c:\IOT_n3\
├── firmwires\
│   ├── .gitignore
│   ├── .vscode\settings.json
│   ├── README.md, RAPPORT_ANALYSE.md, RECOMMANDATIONS.md
│   ├── n3pp\              # N3PhasmesProto (ESP32 serre/aquaponie)
│   ├── msp\              # MeteoStationPrototype (ESP32 météo + tracker)
│   ├── uploadphotosserver\       # ESP32-CAM unifié (envs msp1, n3pp, ffp3)
│   ├── ratata\              # Kit ZYC0108-EN (8 env. UNO + ESP32-CAM)
│   ├── ffp5cs\              # Contrôleur aquaponie (WROOM/S3, modulaire) (dossier ordinaire)
│   ├── LVGL_Widgets\        # ESP32-S3 + écran LVGL
│   └── (test psram s3, test psram s3 2 dans ffp5cs)
│
└── serveur\
    ├── public\index.php     # Front controller Slim 4 unique
    ├── src\Controller\     # Msp, N3pp, Ffp3, Gallery
    ├── config\              # routes_msp1_n3pp.php, routes_helpers.php
    ├── site initial\        # Archive — consultation uniquement
    ├── msp1gallery\         # Routes /msp1gallery/ (upload photos)
    ├── n3ppgallery\        # Routes /n3ppgallery/ (upload photos)
    └── ffp3\                # Sous-projet historique (scripts, doc)
```

*Note :* Le dossier **serveur/** dans IOT_n3 est un clone du dépôt **n3_serveur** (submodule) ; ffp3 n’est plus un sous-dépôt séparé mais un dossier versionné dans n3_serveur.

---

## 7. Recommandations synthétiques

1. **Racine** : le README (`README.md`) décrit le projet et les liens firmware ↔ serveur ; à maintenir à jour.
2. **Git** : dépôt à la racine ; submodules **serveur** (n3_serveur) et **firmwires** (ffp5cs est un dossier dans firmwires) ; stratégie documentée dans RECOMMANDATIONS_IOT.md.
3. **Firmwares** : appliquer les corrections et recommandations de `RAPPORT_ANALYSE.md` (bugs n3pp, secrets, partition msp) ; à terme, s’inspirer de ffp5cs pour modulariser n3pp et msp.
4. **Serveur** : éviter de versionner `error_log` ; clarifier le rôle des fichiers « old » / « 2 » dans n3pp et les archiver ou supprimer si obsolètes.
5. **Documentation** : garder le README firmwires à jour (déjà bien détaillé) et faire pointer le README racine vers les différentes parties du projet.

---

*Rapport généré à partir de l’exploration de l’arborescence, des README, platformio.ini et des principaux fichiers sources.*
