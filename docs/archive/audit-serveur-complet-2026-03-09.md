# Audit complet du serveur distant

- **Date** : 2026-03-09 19:42:01
- **Serveur** : https://iot.olution.info
- **Version serveur** : 5.0.69

## Resume executif

| Metrique | Valeur |
|----------|--------|
| Tests OK | 22 |
| Avertissements | 17 |
| Erreurs | 39 |
| Total tests | 78 |

## 1. Pages web

| Chemin | Code HTTP | Attendu | Temps (ms) | Statut |
|--------|-----------|---------|------------|--------|
| `/` | 0 | 200 | 15052 | Erreur (attendu 200) |
| `/aquaponie` | 0 | 200 | 15003 | Erreur (attendu 200) |
| `/aquaponie-alt` | 0 | 200 | 15006 | Erreur (attendu 200) |
| `/aquaponie-description` | 0 | 200 | 15013 | Erreur (attendu 200) |
| `/aquaponie-test` | 0 | 200 | 15011 | Erreur (attendu 200) |
| `/aquaponie-alt-test` | 0 | 200 | 15012 | Erreur (attendu 200) |
| `/aquamobile` | 0 | 200 | 15010 | Erreur (attendu 200) |
| `/aquamobile-test` | 0 | 200 | 15003 | Erreur (attendu 200) |
| `/aquamobile-alt` | 0 | 200 | 15007 | Erreur (attendu 200) |
| `/aquamobile-alt-test` | 0 | 200 | 15029 | Erreur (attendu 200) |
| `/meteo` | 0 | 200 | 15011 | Erreur (attendu 200) |
| `/serre` | 0 | 200 | 15014 | Erreur (attendu 200) |
| `/login` | 0 | 200 | 15024 | Erreur (attendu 200) |
| `/gallery/msp1` | 0 | 200 | 15003 | Erreur (attendu 200) |
| `/gallery/n3pp` | 0 | 200 | 15016 | Erreur (attendu 200) |
| `/gallery/ffp3` | 0 | 200 | 15008 | Erreur (attendu 200) |
| `/dashboard` | 0 | 0 | 15007 | Timeout/Inconnu |
| `/dashboard-test` | 0 | 0 | 15013 | Timeout/Inconnu |
| `/dashboard3` | 0 | 0 | 15001 | Timeout/Inconnu |
| `/dashboard3-test` | 0 | 0 | 15028 | Timeout/Inconnu |
| `/tide-stats` | 0 | 0 | 15003 | Timeout/Inconnu |
| `/tide-stats-test` | 0 | 0 | 15026 | Timeout/Inconnu |
| `/tide-stats3` | 0 | 0 | 15003 | Timeout/Inconnu |
| `/tide-stats3-test` | 0 | 0 | 15017 | Timeout/Inconnu |
| `/control` | 0 | 0 | 15002 | Timeout/Inconnu |
| `/control-test` | 0 | 0 | 15006 | Timeout/Inconnu |
| `/supervision` | 0 | 0 | 15007 | Timeout/Inconnu |
| `/aquaponie-control` | 0 | 0 | 15015 | Timeout/Inconnu |
| `/aquaponie-control-test` | 0 | 0 | 15012 | Timeout/Inconnu |
| `/aquamobile-control` | 0 | 0 | 15024 | Timeout/Inconnu |
| `/aquamobile-control-test` | 0 | 0 | 15003 | Timeout/Inconnu |
| `/meteo-control` | 0 | 0 | 15003 | Timeout/Inconnu |
| `/serre-control` | 0 | 0 | 15006 | Timeout/Inconnu |


## 2. APIs temps reel

| Chemin | Code HTTP | Attendu | Temps (ms) | Statut | JSON |
|--------|-----------|---------|------------|--------|------|
| `/api/realtime/sensors/latest` | 0 | 200 | 15006 | Erreur (attendu 200) | - |
| `/api/realtime/outputs/state` | 0 | 200 | 15000 | Erreur (attendu 200) | - |
| `/api/realtime/system/health` | 0 | 200 | 15002 | Erreur (attendu 200) | - |
| `/api/health` | 0 | 200 | 15005 | Erreur (attendu 200) | - |
| `/api/realtime-test/sensors/latest` | 0 | 200 | 15020 | Erreur (attendu 200) | - |
| `/api/realtime-test/system/health` | 0 | 200 | 15013 | Erreur (attendu 200) | - |
| `/api/realtime3-test/system/health` | 0 | 200 | 15001 | Erreur (attendu 200) | - |
| `/api/realtime3/system/health` | 0 | 200 | 15008 | Erreur (attendu 200) | - |
| `/msp1/api/realtime/sensors/latest` | 0 | 200 | 15006 | Erreur (attendu 200) | - |
| `/msp1/api/realtime/system/health` | 200 | 200 | 3506 | OK | Valide |
| `/msp1/api/outputs/state` | 200 | 200 | 905 | OK | Valide |
| `/n3pp/api/realtime/sensors/latest` | 200 | 200 | 1448 | OK | Valide |
| `/n3pp/api/realtime/system/health` | 200 | 200 | 319 | OK | Valide |
| `/n3pp/api/outputs/state` | 200 | 200 | 407 | OK | Valide |
| `/ping` | 200 | 200 | 435 | OK | - |


## 3. Endpoints firmware (GET sur POST-only)

Ces endpoints n'acceptent que POST. Un GET doit retourner 405 (Method Not Allowed).

| Chemin | Code HTTP | Attendu | Temps (ms) | Statut |
|--------|-----------|---------|------------|--------|
| `/post-data` | 405 | 405 | 594 | OK |
| `/heartbeat` | 405 | 405 | 280 | OK |
| `/post-ffp3-data.php` | 405 | 405 | 244 | OK |
| `/msp1/msp1datas/post-msp1-data.php` | 405 | 405 | 596 | OK |
| `/n3pp/n3ppdatas/post-n3pp-data.php` | 405 | 405 | 406 | OK |


## 4. Redirections legacy

| Chemin | Code HTTP | Attendu | Temps (ms) | Statut |
|--------|-----------|---------|------------|--------|
| `/ffp3/` | 404 | 301 | 263 | Erreur (attendu 301) |
| `/ffp3/dashboard` | 200 | 301 | 310 | Erreur (attendu 301) |
| `/ffp3/aquaponie` | 200 | 301 | 264 | Erreur (attendu 301) |
| `/ffp3-data` | 301 | 301 | 386 | OK |
| `/msp1/msp1control/` | 301 | 301 | 730 | OK |
| `/msp1/msp1control/index.php` | 301 | 301 | 270 | OK |
| `/n3pp/n3ppcontrol/` | 301 | 301 | 278 | OK |
| `/n3pp/n3ppcontrol/index.php` | 301 | 301 | 297 | OK |
| `/ffp3/heartbeat.php` | 200 | 301 | 257 | Erreur (attendu 301) |


## 5. Ressources statiques et OTA

| Chemin | Code HTTP | Attendu | Temps (ms) | Statut |
|--------|-----------|---------|------------|--------|
| `/assets/css/main.css` | 200 | 200 | 589 | OK |
| `/assets/logo.png` | 200 | 200 | 551 | OK |
| `/manifest.json` | 200 | 200 | 382 | OK |
| `/robots.txt` | 200 | 200 | 399 | OK |
| `/favicon.ico` | 204 | 200 | 533 | Erreur (attendu 200) |
| `/service-worker.js` | 200 | 200 | 340 | OK |
| `/ota/metadata.json` | 200 | 200 | 268 | OK |


## 6. Logs serveur

### Disponibilite

| Log | URL | Code HTTP |
|-----|-----|-----------|
| cronlog.txt | https://iot.olution.info/public/cronlog.txt | 200 |
| error_log | https://iot.olution.info/public/error_log | 404 |

### Analyse error_log

| Metrique | Valeur |
|----------|--------|
| Total lignes d'erreur | 0 |
| Lignes `[n3 500]` | 0 |
| PHP Fatal / Fatal error | 0 |
| Lignes 404 (FFP3/n3-iot) | 0 |
**Dernieres lignes error_log (max 30) :**

```

```

### Analyse cronlog.txt

| Metrique | Valeur |
|----------|--------|
| Lignes `[ERROR]` | 1091 |
| Exceptions non gerees | 742 |
| Erreurs insertion | 326 |

**Dernieres lignes cronlog (max 30) :**

```
[2026-03-09 19:32:04] [ERROR] Exception non gérée [09ad73463266]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/latest
[2026-03-09 19:32:04] [ERROR] Exception non gérée [d43e1f897a00]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:06] [ERROR] Exception non gérée [8095110766dd]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:32:10] [ERROR] Exception non gérée [baac50e26aef]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/latest
[2026-03-09 19:32:10] [ERROR] Exception non gérée [d7bf4b9a3be3]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:17] [ERROR] Exception non gérée [6f710c3c3139]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:32:19] [ERROR] Exception non gérée [7fce546b3179]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:32:23] [ERROR] Exception non gérée [d935b53a4054]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:23] [ERROR] Exception non gérée [b343d2a34f6b]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/since/1772714254
[2026-03-09 19:32:23] [ERROR] Exception non gérée [f68c690d8a9e]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:23] [ERROR] Exception non gérée [e3c5a179bb11]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/since/1772714254
[2026-03-09 19:32:27] [ERROR] Exception non gérée [be24ca1adcfa]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/latest
[2026-03-09 19:32:27] [ERROR] Exception non gérée [262c90654698]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:27] [ERROR] Exception non gérée [0b214ed13d93]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:32:33] [ERROR] Exception non gérée [564bd43f3bf5]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:32:35] [ERROR] Exception non gérée [851b3d421e6a]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/sensors/latest
[2026-03-09 19:32:35] [ERROR] Exception non gérée [d5355b5100a5]: Class "App\Service\Realtime\Ffp3RealtimeDataProvider" not found in /home4/oliviera/iot.olution.info/src/Service/RealtimeDataService.php:12 — GET https://iot.olution.info/api/realtime/system/health
[2026-03-09 19:32:45] [ERROR] Exception non gérée [ca2bc3f28cdf]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:32:47] [ERROR] Exception non gérée [b0d06887009f]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:32:55] [ERROR] Exception non gérée [144250955680]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:33:00] [ERROR] Exception non gérée [2da993a8a2a3]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:33:11] [ERROR] Exception non gérée [e060cb4f6193]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:33:13] [ERROR] Exception non gérée [57ce88d4bd08]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:33:21] [ERROR] Exception non gérée [eabb473653d8]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:33:23] [ERROR] Exception non gérée [067b442daca2]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:33:34] [ERROR] Exception non gérée [4aea2073378a]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:33:40] [ERROR] Exception non gérée [a4e045c3ee89]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
[2026-03-09 19:33:47] [ERROR] Exception non gérée [0268d6517e9a]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:33:50] [ERROR] Exception non gérée [28a446dd9f67]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — POST http://iot.olution.info/n3pp/n3ppdatas/post-n3pp-data.php
[2026-03-09 19:34:01] [ERROR] Exception non gérée [abd3732140c5]: Class "App\Repository\AbstractSensorRepository" not found in /home4/oliviera/iot.olution.info/src/Repository/N3ppSensorRepository.php:14 — GET http://iot.olution.info/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3
```


## 7. Securite

### Certificat SSL

| Propriete | Valeur |
|-----------|--------|
| Valide | Oui |
| Sujet | CN=iot.olution.info |
| Emetteur | CN=R13, O=Let's Encrypt, C=US |
| Expiration | 2026-05-09 10:12:36 |
| Jours restants | 60 |
### Headers de securite (page d'accueil)

| Header | Present | Valeur |
|--------|---------|--------|
| X-Content-Type-Options | **Non** | - |
| X-Frame-Options | **Non** | - |
| Strict-Transport-Security | **Non** | - |
| Content-Security-Policy | **Non** | - |
| X-XSS-Protection | **Non** | - |
| Referrer-Policy | **Non** | - |

### Fichiers sensibles

| Chemin | Code HTTP | Statut |
|--------|-----------|--------|
| `/.env` | 404 | Protege |
| `/.git/config` | 404 | Protege |
| `/.git/HEAD` | 404 | Protege |
| `/vendor/autoload.php` | 404 | Protege |
| `/config/container.php` | 404 | Protege |
| `/var/cache/` | 404 | Protege |
| `/src/Config/Env.php` | 404 | Protege |
| `/composer.json` | 404 | Protege |
| `/composer.lock` | 404 | Protege |

### Logs exposes

| Fichier | Accessible | Risque |
|---------|-----------|--------|
| `/public/error_log` | Non | - |
| `/public/cronlog.txt` | Oui | Faible - log applicatif de diagnostic |


## 8. Performance

| Metrique | Valeur |
|----------|--------|
| URLs mesurees | 78 |
| Moyenne | 8328 ms |
| Minimum | 237 ms |
| Maximum | 15052 ms |
| P95 | 15026 ms |
| Pages lentes (> 3s) | 43 |
### Pages lentes (> 3 secondes)

| Chemin | Temps (ms) |
|--------|------------|
| `/` | 15052 |
| `/aquamobile-alt-test` | 15029 |
| `/dashboard3-test` | 15028 |
| `/tide-stats-test` | 15026 |
| `/login` | 15024 |
| `/aquamobile-control` | 15024 |
| `/api/realtime-test/sensors/latest` | 15020 |
| `/tide-stats3-test` | 15017 |
| `/gallery/n3pp` | 15016 |
| `/aquaponie-control` | 15015 |
| `/serre` | 15014 |
| `/api/realtime-test/system/health` | 15013 |
| `/dashboard-test` | 15013 |
| `/aquaponie-description` | 15013 |
| `/aquaponie-control-test` | 15012 |
| `/aquaponie-alt-test` | 15012 |
| `/aquaponie-test` | 15011 |
| `/meteo` | 15011 |
| `/aquamobile` | 15010 |
| `/gallery/ffp3` | 15008 |
| `/api/realtime3/system/health` | 15008 |
| `/supervision` | 15007 |
| `/aquamobile-alt` | 15007 |
| `/dashboard` | 15007 |
| `/api/realtime/sensors/latest` | 15006 |
| `/serre-control` | 15006 |
| `/control-test` | 15006 |
| `/aquaponie-alt` | 15006 |
| `/msp1/api/realtime/sensors/latest` | 15006 |
| `/api/health` | 15005 |
| `/aquamobile-test` | 15003 |
| `/gallery/msp1` | 15003 |
| `/aquaponie` | 15003 |
| `/meteo-control` | 15003 |
| `/aquamobile-control-test` | 15003 |
| `/tide-stats` | 15003 |
| `/tide-stats3` | 15003 |
| `/control` | 15002 |
| `/api/realtime/system/health` | 15002 |
| `/dashboard3` | 15001 |
| `/api/realtime3-test/system/health` | 15001 |
| `/api/realtime/outputs/state` | 15000 |
| `/msp1/api/realtime/system/health` | 3506 |

### Top 10 pages les plus lentes

| Chemin | Temps (ms) |
|--------|------------|
| `/` | 15052 |
| `/aquamobile-alt-test` | 15029 |
| `/dashboard3-test` | 15028 |
| `/tide-stats-test` | 15026 |
| `/aquamobile-control` | 15024 |
| `/login` | 15024 |
| `/api/realtime-test/sensors/latest` | 15020 |
| `/tide-stats3-test` | 15017 |
| `/gallery/n3pp` | 15016 |
| `/aquaponie-control` | 15015 |

---

## Recommandations
- **Corriger les erreurs HTTP** : 39 endpoint(s) retournent un code inattendu. Voir les sections detaillees ci-dessus.
- **Analyser cronlog** : 1091 lignes [ERROR] detectees.
- **Ajouter des headers de securite** : seulement 0/6 headers presents. Ajouter au minimum `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`.
- **Optimiser les pages lentes** : 43 page(s) au-dessus de 3 secondes.

---
*Rapport genere par `scripts/audit-serveur-complet.ps1`*
