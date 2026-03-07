---
name: nouveau-firmware-iot
description: Scaffolding d'un nouveau projet firmware ESP32/Arduino pour le projet n3 IoT. Utiliser quand l'utilisateur veut creer un nouveau firmware, ajouter un nouvel appareil, ou demarrer un nouveau projet PlatformIO dans firmwires/.
---

# Nouveau firmware IoT — Scaffolding

## Quand utiliser

Quand l'utilisateur veut creer un nouveau firmware pour un appareil ESP32, ESP32-CAM ou Arduino dans le cadre du projet n3.

## Structure cible

```
firmwires/<nom_projet>/
├── platformio.ini
├── src/
│   └── main.cpp
├── include/
│   └── (headers si necessaire)
├── credentials.h.example
└── lib/
    └── (librairies locales si necessaire)
```

## Etape 1 — Nommer le projet

Convention : nom court, descriptif, sans espaces.
Exemples existants : `n3pp4_2`, `msp2_5`, `uploadphotosserver_msp1`, `ffp5cs`.

## Etape 2 — Creer le platformio.ini

Template minimal :

```ini
[env:<nom>]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps =
    ; ajouter les dependances ici
```

Boards courants du projet :
- `esp32dev` — ESP32 WROOM generique
- `esp32-s3-devkitc-1` — ESP32-S3
- `esp32cam` — ESP32-CAM AI-Thinker
- `uno` — Arduino UNO

Ne PAS coder en dur `upload_port` dans le fichier versionne.

## Etape 3 — Creer credentials.h.example

Fichier template avec des placeholders :

```cpp
#ifndef CREDENTIALS_H
#define CREDENTIALS_H

const char* WIFI_SSID = "VOTRE_SSID";
const char* WIFI_PASSWORD = "VOTRE_MOT_DE_PASSE";
const char* SERVER_URL = "https://iot.olution.info";
const char* API_KEY = "VOTRE_CLE_API";

#endif
```

Le vrai `credentials.h` ne doit JAMAIS etre versionne (verifier `.gitignore`).

## Etape 4 — Creer le main.cpp minimal

Inclure au minimum :
- `#include "credentials.h"`
- WiFi connection avec timeout
- Logs `Serial.printf` clairs avec tag module
- Validation basique des capteurs si applicable
- Boucle principale non bloquante

Respecter les conventions firmwares du projet :
- Offline-first (fonctionner sans reseau)
- Timeouts courts (5s max sur operations reseau)
- Pas de nombres magiques
- Nommage : PascalCase (classes), camelCase (fonctions), UPPER_SNAKE_CASE (constantes)

## Etape 5 — Enregistrer l'appareil

1. Ajouter dans `docs/inventaire_appareils.md` :
   - Identifiant `n3-<type>-<numero>` (ex. `n3-nouveau-01`)
   - Type de firmware
   - Emplacement prevu
   - Version

2. Si le firmware communique avec le serveur, ajouter le lien dans le tableau du `README.md` racine.

## Etape 6 — Verifier le .gitignore

S'assurer que le `.gitignore` (racine ou `firmwires/`) exclut :
- `credentials.h`
- `.pio/`
- `desktop.ini`

## Modele de reference

Pour un firmware connecte complet, s'inspirer de `ffp5cs` :
- Architecture modulaire (capteurs, actionneurs, web, mail)
- Config locale NVS
- HMAC-SHA256 pour l'auth serveur
- Heartbeat / supervision
