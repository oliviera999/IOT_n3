---
name: migration-firmware-credentials
description: Moderniser les firmwares legacy du projet n3 (n3pp4_2, msp2_5, ESP32-CAM) en externalisant les secrets dans credentials.h, en ajoutant de la validation capteurs, et en ameliorant la securite. Utiliser quand l'utilisateur veut securiser un firmware, externaliser des credentials, ou moderniser un firmware legacy.
---

# Migration firmwares legacy — Externalisation des secrets

## Etat actuel

Les firmwares `n3pp4_2`, `msp2_5` et les 3 `uploadphotosserver_*` ont des secrets codes en dur :
- WiFi SSID et mot de passe
- Cle API serveur (`fdGTMoptd5CD2ert3`)
- Identifiants SMTP (Gmail)
- Mot de passe OTA (camera msp1)

## Migration par etapes

Appliquer ces etapes une par une, firmware par firmware. Ne pas tout migrer en bloc.

### Etape 1 — Creer credentials.h.example

Dans chaque dossier firmware :

```cpp
#ifndef CREDENTIALS_H
#define CREDENTIALS_H

// WiFi (multi-reseaux)
const char* WIFI_SSID_1 = "VOTRE_SSID_1";
const char* WIFI_PASS_1 = "VOTRE_MOT_DE_PASSE_1";
const char* WIFI_SSID_2 = "VOTRE_SSID_2";
const char* WIFI_PASS_2 = "VOTRE_MOT_DE_PASSE_2";

// Serveur IoT
const char* SERVER_URL = "http://iot.olution.info";
const char* API_KEY = "VOTRE_CLE_API";

// SMTP (alertes mail) — si applicable
const char* SMTP_HOST = "smtp.gmail.com";
const char* SMTP_USER = "VOTRE_EMAIL@gmail.com";
const char* SMTP_PASS = "VOTRE_MOT_DE_PASSE_APP";

// OTA — si applicable
const char* OTA_PASSWORD = "VOTRE_MOT_DE_PASSE_OTA";

#endif
```

### Etape 2 — Verifier le .gitignore

S'assurer que `credentials.h` est exclu dans `.gitignore` (racine ou `firmwires/`) :

```
credentials.h
```

Verifier que seul `credentials.h.example` est versionne.

### Etape 3 — Remplacer les constantes en dur

Dans `main.cpp`, remplacer :

```cpp
// AVANT (a supprimer)
const char* ssid = "MonSSID";
const char* password = "MonPassword";
String apiKeyValue = "fdGTMoptd5CD2ert3";

// APRES
#include "credentials.h"
// Utiliser WIFI_SSID_1, WIFI_PASS_1, API_KEY directement
```

Faire un `pio run` apres chaque remplacement pour verifier la compilation.

### Etape 4 — Verifier le fonctionnement

1. Copier `credentials.h.example` → `credentials.h`
2. Remplir avec les vraies valeurs
3. `pio run -t upload`
4. `pio device monitor` — verifier WiFi + envoi donnees

## Ameliorations supplementaires (optionnelles)

### Validation capteurs (recommandee)

Ajouter la validation apres chaque lecture de capteur :

```cpp
float temp = dht.readTemperature();
if (isnan(temp) || temp < -40.0 || temp > 80.0) {
    Serial.println("[CAPTEUR] Temperature invalide, valeur par defaut");
    temp = 20.0; // valeur par defaut sure
}
```

### Migration vers JSON (a planifier)

Les firmwares n3pp4_2 et msp2_5 utilisent `application/x-www-form-urlencoded`.
La migration vers JSON necessite un plan car le serveur doit etre mis a jour simultanement.
Ne pas migrer sans coordination (voir skill `contrat-firmware-serveur`).

### Ajout authentification sur les cameras

Les uploads photo ne sont pas authentifies. Pour ajouter une cle API :
1. Ajouter `API_KEY` dans `credentials.h`
2. Ajouter un header ou champ `api_key` dans la requete multipart
3. Valider cote serveur dans `GalleryUploadController`

## Ordre de priorite recommande

1. **Externaliser les secrets** (etapes 1-4) — risque minimal, gain immediat
2. **Validation capteurs** — correction de bugs potentiels
3. **Auth galeries** — securite
4. **Migration JSON** — necessite plus de planification
