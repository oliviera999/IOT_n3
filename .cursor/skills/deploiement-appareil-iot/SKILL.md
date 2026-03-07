---
name: deploiement-appareil-iot
description: Provisionnement et mise en service d'un appareil IoT dans le projet n3 (flash firmware, configuration credentials, enregistrement inventaire, verification connectivite). Utiliser quand l'utilisateur veut deployer, configurer, mettre en service ou enregistrer un nouvel appareil ESP32/ESP32-CAM.
---

# Deploiement d'un appareil IoT

## Vue d'ensemble

Deployer un appareil = le rendre operationnel sur le reseau n3 avec son firmware, ses credentials et son enregistrement dans l'inventaire.

## Workflow complet

### 1. Preparer le firmware

- Verifier que le firmware compile sans warning : `pio run`
- Verifier que `credentials.h` existe et est rempli avec les bonnes valeurs :
  - SSID / mot de passe WiFi du reseau du lycee
  - URL du serveur (`https://iot.olution.info` ou URL specifique)
  - Cle API ou secret HMAC selon le type de firmware

Si `credentials.h` n'existe pas, le creer a partir de `credentials.h.example`.

### 2. Flasher le firmware

```bash
cd firmwires/<projet>/
pio run -t upload --upload-port <COMx>
```

Si le firmware utilise un filesystem (LittleFS) :
```bash
pio run -t uploadfs --upload-port <COMx>
pio run -t upload --upload-port <COMx>
```

### 3. Verifier le demarrage

```bash
pio device monitor -p <COMx> -b 115200
```

Verifier dans les logs :
- [ ] Connexion WiFi reussie (ou mode offline-first actif)
- [ ] Adresse IP obtenue
- [ ] Premiere communication avec le serveur (si applicable)
- [ ] Lecture capteurs OK (pas de NaN, pas de valeurs aberrantes)
- [ ] Version firmware affichee

### 4. Verifier cote serveur

- Verifier que les donnees arrivent dans la bonne table
- Pour les galeries photo : verifier que les images sont recues et stockees
- Verifier les logs Monolog cote serveur (pas d'erreurs 400/401/500)

### 5. Enregistrer dans l'inventaire

Mettre a jour `docs/inventaire_appareils.md` :

| Champ | Exemple |
|-------|---------|
| Identifiant | `n3-msp-02` |
| Type de firmware | `msp2_5` |
| Emplacement | Station meteo — toit |
| Board/endpoint | `board=2` |
| Version firmware | `2.5` |
| Derniere donnee | `2026-03-06` |

Convention de nommage : prefixe `n3-`, puis type, puis numero.

### 6. Documentation

Si c'est un nouveau type d'appareil (pas encore dans le tableau firmware-serveur) :
- Ajouter le lien dans le README racine
- Documenter l'endpoint cote serveur

## Cas particuliers

### ESP32-CAM (upload photos)

Les 3 firmwares camera (`uploadphotosserver_*`) necessitent :
- `credentials.h` avec URL de la galerie cible
- Verifier la resolution et la qualite JPEG dans le code
- Tester en mode deep sleep si applicable (consommation)

### FFP5CS (aquaponie)

Le deploiement ffp5cs est plus complexe :
- Utiliser le script `erase_flash_fs_monitor_5min_analyze.ps1` du sous-module
- Verifier la config NVS apres premier boot
- Tester les modes offline et degrades
- Voir les skills ffp5cs specifiques dans `firmwires/ffp5cs/.cursor/skills/`

## Depannage rapide

| Symptome | Verification |
|----------|-------------|
| Pas de connexion WiFi | SSID/password dans credentials.h, signal WiFi |
| Donnees pas recues sur serveur | URL serveur, cle API, pare-feu/proxy |
| Capteur retourne NaN | Cablage, alimentation, delai entre lectures |
| Upload echoue | Cable USB data, drivers, mode boot ESP32 |
| Deep sleep ne se reveille pas | Cablage du pin de reveil, timer configure |
