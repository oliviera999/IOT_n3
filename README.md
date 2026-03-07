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
                           · site initial/ : ancienne version des fichiers serveur — consultation uniquement, ne pas modifier
```

- **Firmwares** : [firmwires/](firmwires/) — compilation et upload avec [PlatformIO](https://platformio.org/).
- **Serveur** : [serveur/](serveur/) — applications PHP (msp1, n3pp, ffp3) pour tableaux de bord, API et galeries.

---

## Lien Firmware ↔ Serveur

Chaque firmware qui envoie des données ou est piloté à distance est relié à un dossier serveur. Les projets « standalone » (robot, démo) n’ont pas de backend associé.

| Firmware (dans `firmwires/`) | Carte | Dossier serveur associé | Rôle du serveur |
|------------------------------|--------|--------------------------|------------------|
| **[n3pp4_2](firmwires/n3pp4_2/)** — N3PhasmesProto (serre / aquaponie) | ESP32 | **[serveur/n3pp](serveur/n3pp/)** | Réception des données (`n3ppdatas`), contrôle des sorties (`n3ppcontrol`), galerie photos (`n3ppgallery`) |
| **[msp2_5](firmwires/msp2_5/)** — MeteoStationPrototype (météo + tracker solaire) | ESP32 | **[serveur/msp1](serveur/msp1/)** | Réception des données (`msp1datas`), contrôle (`msp1control`), galerie (`msp1gallery`) |
| **[uploadphotosserver_msp1](firmwires/uploadphotosserver_msp1/)** | ESP32-CAM | **[serveur/msp1gallery](serveur/msp1gallery/)** | Envoi vers l’endpoint **msp1gallery** (upload.php). Le nom du firmware indique la *destination*, pas un lien exclusif au projet MSP. |
| **[uploadphotosserver_n3pp_1_6_deppsleep](firmwires/uploadphotosserver_n3pp_1_6_deppsleep/)** | ESP32-CAM | **[serveur/n3ppgallery](serveur/n3ppgallery/)** | Envoi vers l’endpoint **n3ppgallery**. Le nom indique la *destination*, pas un lien exclusif au projet N3PP. |
| **[uploadphotosserver_ffp3_1_5_deppsleep](firmwires/uploadphotosserver_ffp3_1_5_deppsleep/)** | ESP32-CAM | **[serveur/ffp3](serveur/ffp3/)** | Envoi vers la galerie **FFP3**. Même principe : destination configurée, pas d’association fixe à un « type » de module. |
| **[ffp5cs](firmwires/ffp5cs/)** — Contrôleur aquaponie (WROOM/S3) | ESP32 / ESP32-S3 | **[serveur/ffp3](serveur/ffp3/)** | Même plateforme : FFP3 est le backend web (Slim 4) pour les données et le contrôle des ESP FFP5CS |
| **[ratata](firmwires/ratata/)** — Kit ZYC0108-EN (voiture / robot) | UNO + ESP32-CAM | — | Pas de serveur dédié (démo locale, stream HTTP possible en direct) |
| **[LVGL_Widgets](firmwires/LVGL_Widgets/)** — Interface écran tactile | ESP32-S3 | — | Pas de serveur dédié |

**À propos des modules photo (ESP32-CAM)** : les noms `uploadphotosserver_msp1`, `uploadphotosserver_n3pp_*`, `uploadphotosserver_ffp3_*` désignent **l’endpoint cible** (msp1gallery, n3ppgallery ou ffp3), et non une association obligatoire aux projets MSP ou N3PP. Une même caméra peut être configurée pour envoyer vers l’une ou l’autre galerie selon le besoin (configuration dans le firmware).

En résumé (données et contrôle) :

- **N3PP** (serre/aquaponie) : firmware `n3pp4_2` → **serveur/n3pp**
- **MSP1** (météo) : firmware `msp2_5` → **serveur/msp1**
- **FFP3** (aquaponie avancée) : firmware `ffp5cs` → **serveur/ffp3**

Les **galeries photo** (msp1gallery, n3ppgallery, ffp3) sont des endpoints d’upload indépendants ; les firmwares « uploadphotosserver_* » sont des variantes configurées pour l’une ou l’autre destination.

---

## Documentation détaillée

- **Contexte :** [n3.olution.info](https://n3.olution.info) (présentation salle aérée n³) · [iot.olution.info](https://iot.olution.info) (données et contrôle).
- **Recommandations IoT (salle n³)** : voir [RECOMMANDATIONS_IOT.md](RECOMMANDATIONS_IOT.md) pour les recommandations techniques (sécurité, inventaire, backend, monitoring).
- **Inventaire des appareils** : voir [docs/inventaire_appareils.md](docs/inventaire_appareils.md) pour le registre et le nommage (n3-*).
- **Firmwares** : voir [firmwires/README.md](firmwires/README.md) pour la liste des projets, cartes, commandes de compilation et structure.
- **FFP3 (serveur)** : voir [serveur/ffp3/README.md](serveur/ffp3/README.md) pour l’installation, la configuration et l’architecture de l’application Slim 4.
- **Analyse de l’arborescence** : voir [ANALYSE_ARBORESCENCE.md](ANALYSE_ARBORESCENCE.md) pour une analyse détaillée des dossiers et des points d’attention.

---

## Démarrage rapide

1. **Compiler un firmware** : aller dans le dossier du projet sous `firmwires/` et lancer `pio run` (puis `pio run -t upload` pour flasher). Adapter le port série dans `platformio.ini`.
2. **Serveur** : les applications sous `serveur/` sont déployées sur le domaine iot.olution.info (msp1, n3pp, ffp3). Pour ffp3, suivre le README du dossier pour PHP, Composer et base de données.
