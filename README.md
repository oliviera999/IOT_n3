# n³ IOT Datas – Projet IoT

Espace de travail regroupant les **firmwares** (ESP32, Arduino) et les **applications serveur** (PHP) pour la collecte de données, le contrôle à distance et les galeries photos. Ces projets font partie de **[la salle aérée n³](https://n3.olution.info)** (Nature, Numérique, Nomade — Lycée Lyautey, Casablanca). Données et contrôle : **https://iot.olution.info**.

---

## Structure du projet

```
IOT_n3/
├── .gitignore
├── README.md           → Ce fichier
├── RECOMMANDATIONS_IOT.md
├── ANALYSE_ARBORESCENCE.md
├── docs/               → Inventaire des appareils (inventaire_appareils.md)
├── firmwires/          → Submodule n3_firmwires (tous les projets firmware PlatformIO)
└── serveur/            → Applications web PHP (msp1, n3pp, msp1gallery, n3ppgallery, ffp3)
                           · archives/ (site-initial, ffp3) : anciennes versions — consultation uniquement, ne pas modifier
```

- **Firmwares** : [firmwires/](firmwires/) — compilation et upload avec [PlatformIO](https://platformio.org/).
- **Serveur** : [serveur/](serveur/) — applications PHP (msp1, n3pp, ffp3) pour tableaux de bord, API et galeries.

---

## Lien Firmware ↔ Serveur

Chaque firmware qui envoie des données ou est piloté à distance est relié à un dossier serveur. Les projets « standalone » (robot, démo) n’ont pas de backend associé.

| Firmware (dans `firmwires/`) | Carte | Dossier serveur associé | Rôle du serveur |
|------------------------------|--------|--------------------------|------------------|
| **[n3pp](firmwires/n3pp/)** — N3PhasmesProto (serre / aquaponie) | ESP32 | **Module N3PP** ([serveur](serveur/README.md)) | Réception des données (`n3ppdatas`), contrôle des sorties (`n3ppcontrol`), galerie photos (`n3ppgallery`) |
| **[msp](firmwires/msp/)** — MeteoStationPrototype (météo + tracker solaire) | ESP32 | **Module MSP1** ([serveur](serveur/README.md)) | Réception des données (`msp1datas`), contrôle (`msp1control`), galerie (`msp1gallery`) |
| **[uploadphotosserver](firmwires/uploadphotosserver/)** (unifié, envs msp1/n3pp/ffp3) | ESP32-CAM | **msp1gallery, n3ppgallery, ffp3gallery** | Envoi JPEG vers l’endpoint selon l’env de build + contrôle distant au réveil (GET paramètres depuis `UploadPhoto*Outputs`, POST version firmware). Un seul firmware avec 3 envs PlatformIO. |
| **[ffp5cs](firmwires/ffp5cs/)** — Contrôleur aquaponie (WROOM/S3) | ESP32 / ESP32-S3 | **Serveur unifié** ([serveur/](serveur/)) | FFP3 : backend web (Slim 4) pour les données et le contrôle des ESP FFP5CS ; archive dans [serveur/archives/ffp3/](serveur/archives/ffp3/) |
| **[poissonglouton](firmwires/poissonglouton/)** — Compteur recyclage ludique | ESP32-S3 (avec ou sans écran) | **Serveur unifié** ([serveur/](serveur/)) | Comptage bouteilles (IR + ultrason), feedback audio/visuel, envoi batch vers `/pgl/post-data`, stats sur `/pgl` |
| **[ratata](firmwires/ratata/)** — Kit ZYC0108-EN (voiture / robot) | UNO + ESP32-CAM | — | Pas de serveur dédié (démo locale, stream HTTP possible en direct) |
| **[LVGL_Widgets](firmwires/LVGL_Widgets/)** — Interface écran tactile | ESP32-S3 | — | Pas de serveur dédié |

**À propos des modules photo (ESP32-CAM)** : le firmware **uploadphotosserver** (unifié) propose 3 envs (msp1, n3pp, ffp3) ciblant msp1gallery, n3ppgallery ou ffp3gallery. Les variantes legacy sont dans `firmwires/archive/`.

En résumé (données et contrôle) :

- **N3PP** (serre/aquaponie) : firmware `n3pp` → **module N3PP** (routes `/n3pp/`, `/serre`)
- **MSP1** (météo) : firmware `msp` → **module MSP1** (routes `/msp1/`, `/meteo`)
- **FFP3** (aquaponie avancée) : firmware `ffp5cs` → **serveur/ffp3**
- **Poissonglouton** (poubelle recyclage) : firmware `poissonglouton` → **module PGL** (route API `/pgl/post-data`, page stats `/pgl`)

Les **galeries photo** (msp1gallery, n3ppgallery, ffp3) sont des endpoints d’upload indépendants ; les firmwares « uploadphotosserver » sont des variantes configurées pour l’une ou l’autre destination. Les uploads caméra envoient le header `X-Api-Key` ; la validation serveur doit être vérifiée/renforcée selon l’endpoint (voir `docs/audit_firmware_camera_2026-03.md`).

---

## Documentation détaillée

- **Contexte :** [n3.olution.info](https://n3.olution.info) (présentation salle aérée n³) · [iot.olution.info](https://iot.olution.info) (données et contrôle).
- **Recommandations IoT (salle n³)** : voir [RECOMMANDATIONS_IOT.md](RECOMMANDATIONS_IOT.md) pour les recommandations techniques (sécurité, inventaire, backend, monitoring).
- **Inventaire des appareils** : voir [docs/inventaire_appareils.md](docs/inventaire_appareils.md) pour le registre et le nommage (n3-*).
- **Firmwares** : voir [firmwires/README.md](firmwires/README.md) pour la liste des projets, cartes, commandes de compilation et structure.
- **Scripts** : voir [scripts/README.md](scripts/README.md) pour l'inventaire des scripts de publication, audit, déploiement et tests.
- **FFP3 (serveur)** : voir [serveur/ffp3/README.md](serveur/archives/ffp3/README.md) ou [serveur/analyse-ffp3/README.md](serveur/analyse-ffp3/README.md) pour l’installation, la configuration et l’architecture de l’application Slim 4.
- **Audit des échanges serveur ↔ ESP** : voir [docs/audit_echanges_serveur_esp.md](docs/audit_echanges_serveur_esp.md) pour la synthèse des flux, endpoints et authentification.
- **Diagnostic erreurs serveur** : [cronlog production](https://iot.olution.info/public/cronlog.txt) ; [error_log production](https://iot.olution.info/public/error_log) (accès autorisé comme le cronlog) ; processus de debug (référence d’erreur, script d'analyse) : [serveur/docs/DEBUG_ERREURS_SERVEUR.md](serveur/docs/DEBUG_ERREURS_SERVEUR.md).
- **Analyse de l’arborescence** : voir [ANALYSE_ARBORESCENCE.md](ANALYSE_ARBORESCENCE.md) pour une analyse détaillée des dossiers et des points d’attention.

---

## Démarrage rapide

1. **Compiler un firmware** : aller dans le dossier du projet sous `firmwires/` et lancer `pio run` (puis `pio run -t upload` pour flasher). Adapter le port série dans `platformio.ini`.
2. **Serveur** : les applications sous `serveur/` sont déployées sur le domaine iot.olution.info (msp1, n3pp, ffp3). Pour ffp3, suivre le README du dossier pour PHP, Composer et base de données.
3. **Publication OTA** : depuis la racine, `.\scripts\publish_ota.ps1` publie vers `serveur/ota/` (n3pp, msp, caméras). **ffp5cs (aquaponie)** : cibles `ffp5-wroom-prod`, `ffp5-wroom-beta`, `ffp5-s3-prod`, `ffp5-s3-test` — ex. `.\scripts\publish_ota.ps1 -Targets ffp5-wroom-prod,ffp5-wroom-beta,ffp5-s3-prod,ffp5-s3-test -Build`, ou depuis `firmwires/ffp5cs` : `.\scripts\publish_ota.ps1 -Build`. URLs OTA ffp5cs : `https://iot.olution.info/ota/` (metadata racine `serveur/ota/metadata.json`).
