# Registre des appareils IoT – Salle aérée n³

*Dernière mise à jour : 10 mars 2026.*

Ce document recense les appareils (ESP32, ESP32-CAM, etc.) déployés ou prévus pour **[la salle aérée n³](https://n3.olution.info)**. Backend : [iot.olution.info](https://iot.olution.info).

---

## Tableau d'inventaire

| Identifiant | Type de firmware | Carte | Emplacement / pôle | Endpoint serveur | Version firmware | Auth |
|-------------|------------------|-------|---------------------|------------------|------------------|------|
| n3-n3pp-01 | n3pp | ESP32 (esp32dev) | Serre / aquaponie | `/n3pp/n3ppdatas/post-n3pp-data.php` (board=3) | 4.13 | API key POST |
| n3-msp-01 | msp | ESP32 (esp32dev) | Station météo extérieure | `/msp1/msp1datas/post-msp1-data.php` (board=2) | 2.13 | API key POST |
| n3-ffp5cs-01 | ffp5cs | ESP32-WROOM | Aquaponie (FFP3) | `/ffp3/post-data` | 12.31 | HMAC-SHA256 |
| n3-ffp5cs-s3 | ffp5cs | ESP32-S3 (N16R8) | Aquaponie (FFP3) — test S3 | `/ffp3/post-data3-test` | 12.31 | HMAC-SHA256 |
| n3-cam-msp-01 | uploadphotosserver (msp1) | ESP32-CAM | Station météo | `/msp1gallery/upload.php` | 2.9 | X-Api-Key header |
| n3-cam-n3pp-01 | uploadphotosserver (n3pp) | ESP32-CAM | Serre | `/n3ppgallery/upload.php` | 2.9 | X-Api-Key header |
| n3-cam-ffp3-01 | uploadphotosserver (ffp3) | ESP32-CAM | Aquaponie | `/ffp3/ffp3gallery/upload.php` | 2.9 | X-Api-Key header |

---

## Nommage recommandé

- **Préfixe commun :** `n3-` pour tous les identifiants (hostname mDNS, noms dans les logs, registre).
- **Exemples :** `n3-n3pp-01`, `n3-msp-01`, `n3-ffp5cs-serre`, `n3-cam-msp-01`.

Cela facilite le diagnostic sur le réseau du lycée et la lecture des logs.

---

## Références

- Présentation salle n³ : [n3.olution.info](https://n3.olution.info)
- Backend IoT : [iot.olution.info](https://iot.olution.info)
- Liens firmware ↔ serveur : [README racine](../README.md), [RECOMMANDATIONS_IOT](../RECOMMANDATIONS_IOT.md)
