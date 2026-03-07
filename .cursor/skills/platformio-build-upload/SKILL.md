---
name: platformio-build-upload
description: Compile, upload et monitore les firmwares ESP32/Arduino via PlatformIO CLI. Utiliser quand l'utilisateur veut builder, flasher, uploader un firmware, lancer le serial monitor, ou debugger un probleme de compilation PlatformIO.
---

# PlatformIO — Build, Upload & Monitor

## Contexte

Tous les firmwares du projet n3 sont geres avec PlatformIO (pas Arduino IDE).
Dossier racine des firmwares : `firmwires/`.
Chaque sous-dossier contient un `platformio.ini` avec un ou plusieurs environnements.

## Commandes essentielles

Toujours executer depuis le dossier du firmware concerne (ex. `firmwires/msp2_5/`).

### Compilation

```bash
pio run                      # Build tous les environnements
pio run -e <env>             # Build un environnement specifique
```

Verifier : **zero warning, zero erreur**. Les warnings doivent etre corriges ou justifies.

### Upload (flash)

```bash
pio run -t upload            # Upload sur le port auto-detecte
pio run -t upload --upload-port COM5   # Port specifique
```

Si le port n'est pas detecte :
- Verifier le cable USB (data, pas charge seule)
- Verifier les drivers (CP2102 / CH340)
- Sur Windows : `Get-WmiObject Win32_SerialPort | Select Name, DeviceID`

### Upload du filesystem (LittleFS/SPIFFS)

```bash
pio run -t uploadfs          # Upload les fichiers data/
pio run -t uploadfs --upload-port COM5
```

Necessaire pour les firmwares avec interface web (ex. ffp5cs).

### Serial Monitor

```bash
pio device monitor           # Monitor par defaut
pio device monitor -b 115200 # Baudrate specifique
pio device monitor -p COM5   # Port specifique
```

### Nettoyage

```bash
pio run -t clean             # Nettoyer le build
```

## Workflow type

1. **Compiler** : `pio run` — verifier zero warning
2. **Flasher** : `pio run -t upload`
3. **Monitorer** : `pio device monitor` — verifier les logs de demarrage
4. Si le firmware utilise LittleFS : flasher `uploadfs` avant `upload`

## Environnements multiples

Certains firmwares ont plusieurs environnements (ex. `ratata` avec 8 env Arduino UNO + ESP32-CAM).
Toujours specifier `-e <env>` quand il y en a plusieurs.

Pour lister les environnements disponibles :

```bash
pio project config           # Affiche la config complete
```

## Port serie — bonnes pratiques

- Ne PAS coder en dur `upload_port = COMx` dans les `platformio.ini` versionnes.
- Utiliser un fichier `platformio_local.ini` (non versionne) ou une variable d'environnement.
- Si l'utilisateur a besoin d'un port specifique, utiliser `--upload-port` en ligne de commande.

## Erreurs courantes

| Erreur | Cause probable | Solution |
|--------|----------------|----------|
| `No serial data` | Mauvais baudrate | Verifier `monitor_speed` dans platformio.ini |
| `Upload failed: could not open port` | Port occupe ou mauvais driver | Fermer le monitor, verifier les drivers |
| `Error: esp_tool failed` | Mode boot non active | Maintenir BOOT pendant reset sur certains ESP32 |
| `fatal error: credentials.h: No such file` | Fichier secrets manquant | Copier `credentials.h.example` → `credentials.h` et remplir |
