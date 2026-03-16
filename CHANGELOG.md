# Changelog IOT_n3

Modifications notables du depot racine (regles, doc, structure).

Format : [version] - date - description.

---

## [2026.03] - 2026-03-10

### Audit documentation
- **firmwares.manifest.json** : création du manifest pour `scripts/firmwires-list.ps1` (n3pp4_2, msp2_5, uploadphotosserver, ffp5cs, ratata, LVGL_Widgets).
- **ANALYSE_ARBORESCENCE** : mise à jour section uploadphotosserver (projet unifié, 3 envs), structure serveur (Slim 4, modules msp1/n3pp).
- **inventaire_appareils** : alignement versions firmware (n3pp 4.13, msp 2.13).
- **RECOMMANDATIONS_IOT** : caméras → uploadphotosserver unifié.
- **README** : clarification liens module N3PP/MSP1 (serveur unifié Slim 4).
- **serveur/docs/README** : mise à jour version 5.0.102.
- **docs/archive/** : archivage rapports ponctuels (check-pages, rapport_*, resume_*, diagnostic-*).

---

## [2025.03] - 2025-03-07

### OTA et déploiement (n3pp, msp1 test)
- **Publication OTA** : ajout des cibles `n3pp-test` et `msp-test` dans `scripts/publish_ota.ps1` (env `esp32dev_test`, binaires vers `serveur/ota/n3pp-test/` et `serveur/ota/msp-test/`).
- **n3pp4_2** (v4.5) : URL OTA conditionnelle selon `TEST_MODE` (n3pp-test vs n3pp).
- **msp2_5** (v2.7) : URL OTA conditionnelle selon `TEST_MODE` (msp-test vs msp) ; version passée en `version.c_str()` dans la config OTA.
- **Documentation** : skill déploiement-appareil-iot (section OTA distant), README racine (point Publication OTA).

---

## [2025.03] - 2025-03-06

### Règles projet
- **Cycle obligatoire** : chaque modification (firmware ou serveur) doit être associée à une incrémentation de version, une mise à jour des fichiers de documentation concernés, suivie d’un commit et d’un push de tout le projet (dépôt parent et submodules) vers GitHub.
- Règles détaillées dans `.cursor/rules/git-et-versionnement.mdc` et `documentation.mdc`.
- Mise à jour des règles : contexte serveur unifié, procédure de push complète (submodules puis parent).

### Référence submodule serveur
- **serveur** : version 5.0.27 (voir serveur/VERSION et serveur/CHANGELOG.md).
