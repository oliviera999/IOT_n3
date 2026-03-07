---
name: esp32-cam-photo-upload
description: Travailler sur les firmwares ESP32-CAM du projet n3 (uploadphotosserver_msp1, uploadphotosserver_n3pp, uploadphotosserver_ffp3). Utiliser quand l'utilisateur modifie un firmware camera, ajoute une nouvelle camera, debug un probleme de photo ou d'upload galerie.
---

# ESP32-CAM — Firmwares photo

## Les 3 firmwares camera

| Firmware | Galerie cible | Deep sleep | OTA | SD |
|----------|--------------|------------|-----|-----|
| `uploadphotosserver_msp1` | `/msp1gallery/upload.php` | Non (timer 10min) | Oui | Non |
| `uploadphotosserver_n3pp_1_6_deppsleep` | `/n3ppgallery/upload.php` | Oui (600s) | Non | Oui |
| `uploadphotosserver_ffp3_1_5_deppsleep` | `/ffp3/ffp3gallery/upload.php` | Oui (600s) | Non | Non |

Tous : ESP32-CAM AI Thinker, OV2640, POST multipart vers `iot.olution.info`.

## Config camera — ne pas modifier sans raison

```cpp
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22
```

Ces pins sont specifiques a la board AI Thinker. Ne pas modifier sauf changement de board.

## Upload multipart — pattern commun

```cpp
String head = "--RandomNerdTutorials\r\n"
              "Content-Disposition: form-data; name=\"imageFile\"; filename=\"photo.jpg\"\r\n"
              "Content-Type: image/jpeg\r\n\r\n";
String tail = "\r\n--RandomNerdTutorials--\r\n";
```

Points critiques :
- Le boundary `RandomNerdTutorials` doit correspondre cote serveur (`GalleryUploadController`)
- Toujours envoyer le `Content-Length` total (head + image + tail)
- Ne PAS appeler `esp_camera_fb_return(fb)` avant d'avoir fini d'envoyer `fb->buf`

## Bug connu — use-after-free (n3pp)

Dans `uploadphotosserver_n3pp_*`, `sendPhoto()` appelle `esp_camera_fb_return(fb)` avant la boucle d'envoi HTTP qui utilise encore `fb->buf` et `fb->len`. C'est un acces memoire invalide. Corriger en deplacant le `return` apres l'envoi complet.

## Deep sleep

Pour les variantes deep sleep :
```cpp
esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
esp_deep_sleep_start();
```

- Le WiFi et la camera sont reinitialises a chaque reveil
- Le warmup camera (`warmupCamera()`) est necessaire pour eviter les photos vertes
- Creneau horaire 6h-22h via NTP (`pool.ntp.org`, GMT+0, DST 3600s)

## Ajout d'une nouvelle camera

1. Dupliquer le firmware le plus proche (msp1 si pas de deep sleep, ffp3 si deep sleep)
2. Modifier l'URL de la galerie dans les constantes
3. Creer le `credentials.h.example` (externaliser SSID/password)
4. Cote serveur : ajouter la route dans `public/index.php` et la methode dans `GalleryUploadController`
5. Configurer le dossier de stockage dans `.env` (`GALLERY_*_DIR`)
6. Enregistrer l'appareil dans `docs/inventaire_appareils.md`

## Depannage

| Probleme | Cause probable | Solution |
|----------|----------------|----------|
| Photo noire | Flash LED non activee ou exposition insuffisante | Activer GPIO 4 (flash LED) avant capture |
| Photo verte | Camera pas prete | Ajouter `warmupCamera()` avec captures jetables |
| Upload echoue (code -1) | Serveur injoignable ou timeout | Verifier URL, reseau, timeout HTTP |
| Upload echoue (code 500) | Erreur serveur galerie | Verifier droits ecriture du dossier galerie |
| Redemarrage en boucle | Brown-out | Verifier alimentation 5V, `WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0)` |
| SD non montee (n3pp) | Conflit pins SD/camera | Utiliser SD_MMC en mode 1-bit |
