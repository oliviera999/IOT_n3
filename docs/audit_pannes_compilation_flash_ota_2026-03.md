# Audit des pannes compilation/flash/OTA (mars 2026)

## Objectif

Transformer les incidents observés dans les conversations passées en protocole opérationnel unique pour réduire les pannes récurrentes sous Windows + PlatformIO.

## Sources analysées

Analyse des transcripts parent (et non des sous-agents), notamment :

- [OTA COM3 version bloquée 13.30](351120f6-943f-4d76-8950-d067d80ae874)
- [Monitor COM5 erase OTA wroom-prod](360f014b-dfea-415d-a78b-3d8d5cd623da)
- [Test OTA aquaponie incrément build](e6b20190-269f-496f-bf90-099c16bdd379)
- [Aquaponie-test statut hors ligne](7cd2e14a-7631-4f3d-9d8f-eca6ab8b93e6)
- [Contrôle distant uploadphotosserver](f7adb3c6-d052-4d92-bdcd-03791382d007)
- [OTA cam uploadphotosserver commits](b437b350-5ad0-42bb-8ea3-7f3e8a4868c8)
- [Environnement wroom-beta endpoints](5e39d5d6-21da-463c-9639-3cfea1c2bc13)

## 1) Incidents récurrents (fréquence x impact)

### P1 - Bloquants majeurs

1. **Port COM verrouillé / mauvais COM**
   - Symptômes: `PermissionError(13)`, `Access refused`, `Write timeout`.
   - Impact: upload et monitor impossibles, diagnostic bloqué.
2. **Boot crash après flash**
   - Symptômes: `Guru Meditation`, `Cache error`, `LoadProhibited`, `Stack canary`.
   - Impact: firmware inutilisable, impossible d'exécuter un test OTA fiable.
3. **OTA publiée mais non appliquée**
   - Symptômes: version locale ne bouge pas après publication OTA.
   - Impact: dérive entre firmware attendu et firmware réellement exécuté.

### P2 - Dégradation forte

4. **Artefacts build incohérents**
   - Symptômes: échec `checkprogsize`, chemins `.pio/build` vs `C:\pio-builds`, erreurs intermittentes `FRAMEWORK_DIR`.
   - Impact: builds instables, temps perdu en fausses pistes.
5. **Modification automatique non voulue de `sdkconfig.defaults`**
   - Symptômes: diff apparaissant sans intention explicite après build.
   - Impact: risque de régression silencieuse (boot/config low-level).
6. **Monitor série vide**
   - Symptômes: port ouvert mais pas de logs.
   - Impact: forte incertitude diagnostic (baud, mauvais port, monitor désactivé, timing reset).

### P3 - Gênes opérationnelles

7. **Blocage par auth côté endpoint de déclenchement OTA**
   - Symptômes: `302 /login` sur trigger OTA.
   - Impact: test OTA remote non automatisable sans session.

## 2) Cartographie des systèmes utilisés

## Chaîne firmware

- **Build/flash**: PlatformIO (`pio run -e <env>`, `-t upload`, `pio device monitor`).
- **Effacement flash**: `firmwires/ffp5cs/tools/erase_flash.ps1`.
- **Redirection build Windows**: `firmwires/scripts/pio_redirect_build_dir.py` + helpers `firmwires/scripts/Get-PioBuildHelpers.ps1`.
- **Gestion multi-env**: `wroom-prod`, `wroom-test`, `wroom-beta`, `wroom-s3-*`, `uploadphotosserver` (`msp1`, `n3pp`, `ffp3`).

## Chaîne OTA

- **Publication**: `scripts/publish_ota.ps1`.
- **Entrées clés**: `-Targets`, `-Build`, signatures, hash, validations de taille.
- **Sorties**: binaires dans `serveur/ota/...` et mise à jour de `serveur/ota/metadata.json`.
- **Déploiement**: push sur `serveur` puis parent; prod récupère par cron.

## Dépendances critiques

- Port série exclusif (1 seul process à la fois).
- Cohérence des chemins d'artefacts (`C:\pio-builds` vs `.pio/build`).
- Alignement env/canal OTA (prod/test/beta).
- Ordre de commit/push submodule puis parent.
- Cohérence `version` firmware <-> metadata OTA.

## 3) Runbook diagnostic/correction (4 scénarios)

## Scénario A - Upload bloqué COM

### Diagnostic rapide

1. Vérifier que le port attendu existe.
2. Fermer monitor PlatformIO/Arduino/PuTTY.
3. Rebrancher la carte; si besoin BOOT + EN.

### Correctif standard

1. Relancer upload explicitement: `pio run -e <env> -t upload --upload-port COMx`.
2. Si échec persistant, changer câble/port USB, retester.
3. Capturer 20-30 s de monitor après upload.

### Critère de sortie

- Upload `SUCCESS` + monitor ouvert sans erreur de port.

## Scénario B - Build cassé / artefacts incohérents

### Diagnostic rapide

1. Vérifier que la build est lancée dans le bon sous-projet (pas `platformio.ini` racine placeholder).
2. Vérifier la cohérence env/artefacts (helpers `Get-PioBuildHelpers.ps1`).
3. Détecter les erreurs typiques: `checkprogsize`, `FRAMEWORK_DIR`, chemins manquants.

### Correctif standard

1. Nettoyage ciblé de l'env fautif (`.pio/build/<env>` ou `C:\pio-builds\<projet>\<env>`).
2. Rebuild de l'env.
3. Si instable, warmup build sur env de référence puis rebuild env cible.

### Critère de sortie

- Build complet sans erreur + `firmware.bin` présent à l'emplacement attendu.

## Scénario C - Boot panic après flash

### Diagnostic rapide

1. Monitor immédiatement après reset.
2. Capturer signature du crash (`Cache error`, `LoadProhibited`, `Stack canary`).
3. Vérifier si crash avant logique app (init flash) ou après (code applicatif).

### Correctif standard

1. `erase_flash` puis reflash propre.
2. Rejouer monitor 2-5 min.
3. Si crash persiste, isoler par env (ex: comparer `wroom-beta` vs `wroom-prod`) pour distinguer config/env de problème matériel.

### Critère de sortie

- Pas de reboot en boucle ni panic sur une fenêtre de monitor minimale de 2-5 min.

## Scénario D - OTA non appliquée

### Diagnostic rapide

1. Vérifier publication OTA (`metadata.json` + URL binaire).
2. Vérifier canal et cible (prod/test, wroom/s3, cam env).
3. Vérifier version locale dans logs après reboot.

### Correctif standard

1. Republier la cible correcte avec `scripts/publish_ota.ps1`.
2. Forcer un cycle de vérification OTA (reboot ou endpoint dédié si auth disponible).
3. Confirmer l'absence de rollback et la nouvelle version active.

### Critère de sortie

- Version locale observée = version publiée dans metadata OTA.

## 4) Preuves de validation standardisées

Ne clôturer un incident que si les 4 preuves ci-dessous existent:

1. **Preuve build/flash**
   - `SUCCESS` upload + taille firmware cohérente.
2. **Preuve stabilité runtime**
   - monitor 20-30 s minimum (idéal 2-5 min) sans panic/reboot boucle.
3. **Preuve publication OTA**
   - `metadata.json` mis à jour avec la version cible et URL correcte.
4. **Preuve convergence**
   - logs firmware montrant la version active finale attendue.

Format conseillé de clôture:

- env + port
- version avant/après
- hash (SHA-256 ou MD5 selon cible)
- lien de transcript parent de référence

## 5) Priorisation des actions (ROI)

## Priorité immédiate (fort ROI)

1. **Checklist pré-check 60 s obligatoire avant tout flash**
   - bon projet, bon env, port COM libre, bon câble, monitor fermé.
2. **Politique stricte sur `sdkconfig.defaults`**
   - ne jamais inclure ces diffs sans intention explicite + revue.
3. **Validation en 4 preuves**
   - empêcher les faux positifs "c'est publié donc c'est OK".

## Priorité courte échéance

4. **Standardiser un script unique de diagnostic express**
   - COM + build-dir + présence firmware.bin + rappel canal OTA.
5. **Template de compte-rendu incident**
   - même structure pour gagner du temps en support/diagnostic.

## Priorité structurelle

6. **Durcir la séparation env/canaux**
   - éviter les confusions `prod/test/beta` dans les tests OTA.
7. **Réduire la variabilité outillage Windows**
   - documenter et automatiser la résolution des erreurs `checkprogsize`/`FRAMEWORK_DIR`.

## Pré-check 60 secondes (opérationnel)

1. Je suis dans le bon firmware (pas la racine `IOT_n3`).
2. J'utilise le bon env (`wroom-prod`, `wroom-beta`, `msp1`, etc.).
3. Le port COM cible est visible et libre.
4. Aucun monitor concurrent n'est ouvert.
5. Le canal OTA visé correspond à l'env.
6. La version cible est bien incrémentée avant build.

---

Ce document sert de standard d'exploitation pour les prochaines sessions de compilation/flash/OTA.
