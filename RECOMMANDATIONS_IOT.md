# Recommandations techniques – IoT de la salle aérée n³

*Dernière mise à jour : mars 2026.*

**Contexte :** [La salle aérée n³](https://n3.olution.info) (Nature, Numérique, Nomade) — Lycée Lyautey de Casablanca. Espace pédagogique en plein air : aquaponie, jardins, station météo, objets connectés et robotique.

**Périmètre :** Gestion technique de l’aspect IoT du projet : firmwares (ESP32, ESP32-CAM, Arduino), backends (iot.olution.info), et cohérence d’ensemble.

---

## 1. Contexte et écosystème

### 1.1 Deux portails

| Portail | Rôle |
|--------|------|
| **[n3.olution.info](https://n3.olution.info)** | Vitrine et présentation de la salle aérée n³ (pédagogie, pôles, communauté). |
| **[iot.olution.info](https://iot.olution.info)** | Backend IoT : collecte des données capteurs, contrôle des appareils, galeries photos. |

Tous les firmwares du dépôt **IOT_n3** qui envoient des données ou sont pilotés à distance ciblent **iot.olution.info**. Ce document vise à structurer et sécuriser cet écosystème IoT au service de n³.

### 1.2 Inventaire des flux IoT

| Type d’objet | Firmware | Backend | Données / usage |
|--------------|----------|---------|------------------|
| Serre / aquaponie (N3PP) | `n3pp4_2` | serveur/n3pp | Température, humidité, pompe, nourrissage → n3ppdatas, n3ppcontrol |
| Station météo (MSP) | `msp2_5` | serveur/msp1 | DHT, pluie, DS18B20, tracker solaire → msp1datas, msp1control |
| Aquaponie avancée (FFP) | `ffp5cs` | serveur/ffp3 | Données + contrôle via API FFP3 (Slim 4) |
| Caméras (photos) | uploadphotosserver_msp1, _n3pp_*, _ffp3_* | msp1gallery, n3ppgallery, ffp3 | Envoi JPEG vers upload.php. **Les noms des firmwares indiquent l’endpoint cible** (msp1gallery, n3ppgallery ou ffp3), pas une association exclusive à MSP ou N3PP : une caméra peut envoyer vers n’importe quelle galerie selon la config. |
| Robot / démo | ratata, LVGL_Widgets | — | Usage local ou stream direct |

---

## 2. Recommandations par thème

### 2.1 Sécurité et secrets

**Problème :** **n3pp4_2** et **msp2_5** ont déjà externalisé les secrets dans `credentials.h` (avec `credentials.h.example`). Les autres firmwares (uploadphotosserver_*, LVGL_Widgets) peuvent encore avoir des secrets en dur dans les sources. Risque en cas de partage du code ou dépôt public pour ces derniers.

**Recommandations :**

1. **Externaliser les secrets**  
   - Créer un fichier **non versionné** (ex. `credentials.h` ou `config_private.h`) inclus uniquement en local, avec :
     - SSID / mot de passe WiFi
     - Clé API (iot.olution.info)
     - Identifiants SMTP (optionnel : désactiver l’envoi en dev)
   - Ajouter ce fichier au `.gitignore` et fournir un `credentials.h.example` avec des placeholders.

2. **Clé API**  
   - Utiliser une clé par type d’usage ou par board si besoin (n3pp, msp1, ffp3).  
   - Documenter la rotation des clés et s’assurer que le serveur (msp1, n3pp, ffp3) valide bien la clé côté backend.

3. **HTTPS**  
   - Les URLs actuelles sont en `http://`. Pour la production, exposer iot.olution.info en **HTTPS** et configurer les firmwares en conséquence (certificats ou validation désactivée en dev uniquement, avec documentation).

4. **FFP3**  
   - Conserver l’usage de HMAC-SHA256 pour l’ingestion des données et s’en inspirer pour les autres backends si une évolution est prévue.

---

### 2.2 Inventaire et identification des appareils

**Problème :** Les boards sont identifiés par des paramètres en dur (`board=2`, `board=3`, etc.) ou par type dans le code. Aucun registre central des appareils déployés dans la salle n³.

**Recommandations :**

1. **Registre des appareils**  
   - Tenir un document ou tableau (ex. `docs/inventaire_appareils.md` ou table dédiée côté serveur) listant :
     - Identifiant (ex. `n3pp-board3`, `msp-board2`, `ffp5cs-serre`)
     - Type de firmware (n3pp4_2, msp2_5, ffp5cs, etc.)
     - Emplacement / pôle dans la salle n³
     - Dernière version firmware connue, dernière donnée reçue
   - Option : page d’administration sur iot.olution.info listant les boards et leur dernier heartbeat.

2. **Nommage cohérent**  
   - Utiliser un préfixe commun (ex. `n3-`) pour hostname mDNS ou noms dans les logs (ex. `n3-msp-01`, `n3-n3pp-01`) pour faciliter le diagnostic sur le réseau du lycée.

3. **Version et build**  
   - Afficher la version du firmware dans les logs et, si possible, dans les requêtes POST (paramètre `version` ou équivalent). FFP5CS le fait déjà ; étendre l’idée à n3pp4_2 et msp2_5.

---

### 2.3 Configuration et build

**Recommandations :**

1. **Port série**  
   - Les `platformio.ini` utilisent `upload_port = COM3` en dur.  
   - Utiliser des **variables d’environnement** (ex. `UPLOAD_PORT`, `MONITOR_PORT`) ou un `platformio.ini` local (non versionné) pour éviter d’écraser la config par machine. Documenter dans chaque README.

2. **Partition msp2_5**  
   - Le fichier `min_spiffs.csv` est référencé mais absent. Soit ajouter le fichier de partition dans le dépôt, soit retirer la ligne `board_build.partitions = min_spiffs.csv` pour utiliser la partition par défaut et éviter les confusions.

3. **Environnements PlatformIO**  
   - Pour les projets multi-environnements (ratata, ffp5cs), garder une nomenclature claire (ex. `wroom-test`, `wroom-prod`) et documenter dans le README quel environnement correspond à quel déploiement dans la salle n³.

---

### 2.4 Qualité du code et bugs connus

D’après le [RAPPORT_ANALYSE](firmwires/RAPPORT_ANALYSE.md) :

1. **n3pp4_2 – batterie()**  
   - Remplacer `sampleTotal += analogRead(pontdiv);` par `sampleTotal += samples[sampleIndex];` pour rester cohérent avec la moyenne glissante.

2. **n3pp4_2 – affichage OLED**  
   - Remplacer `display.print(digitalRead(HeureArrosage));` (et idem pour SeuilSec, SeuilPontDiv, WakeUp) par l’affichage direct des variables (ce sont des variables, pas des broches).

3. **Modularisation**  
   - n3pp4_2 et msp2_5 sont monolithiques (un seul `main.cpp` très long). À moyen terme, s’inspirer de **ffp5cs** (modules capteurs, actionneurs, web, mail) pour faciliter la maintenance et la réutilisation (ex. lib commune WiFi/NTP/OLED).

---

### 2.5 Backend : cohérence et évolution

**Constat :** Deux familles de backends coexistent :

- **msp1 et n3pp** : PHP procédural (control, datas, gallery), clé API simple, structure par dossiers.
- **ffp3** : Application structurée (Slim 4, Twig, PHP-DI, PHPUnit), API plus riche, HMAC, logging centralisé.

**Recommandations :**

1. **Court terme**  
   - Documenter clairement quel firmware parle à quel backend (voir [README](README.md) et ce fichier).  
   - Éviter de versionner les `error_log` et fichiers temporaires ; les ajouter au `.gitignore` du serveur si nécessaire.

2. **Moyen terme**  
   - Unifier les **endpoints** (URLs, format des POST) dans un même document (ex. `docs/api_iot.md`) pour faciliter l’intégration de nouveaux capteurs ou tableaux de bord.  
   - Si de nouveaux projets IoT pour la salle n³ voient le jour, privilégier l’intégration avec **FFP3** (API, auth, logs) plutôt que de multiplier les scripts PHP isolés.

3. **Option long terme**  
   - Envisager une migration progressive des flux msp1/n3pp vers une API centralisée (FFP3 ou autre) avec rétrocompatibilité, pour un seul point d’entrée données + contrôle + galeries pour toute la salle n³.

---

### 2.5bis Structure des dossiers galerie / upload photo

**Structure en place :** Les galeries ont été déplacées à la **racine** de `serveur/`. Les firmwares d’upload photo ont été mis à jour en conséquence.

**À noter :** Les modules photo ne sont pas réservés à MSP ou N3PP ; les noms msp1gallery / n3ppgallery désignent des **endpoints d’upload** (destinations possibles), pas des galeries « dédiées » à la météo ou à la serre. Toute caméra peut être configurée pour envoyer vers l’un ou l’autre selon le besoin.

**Structure actuelle (galeries à la racine de `serveur/`) :**
- `serveur/msp1gallery/` (upload.php, msp1-gallery.php) → URL `/msp1gallery/upload.php`
- `serveur/n3ppgallery/` (upload.php, n3pp-gallery.php, triphotos.php) → URL `/n3ppgallery/upload.php`. **triphotos.php** modifie/déplace des fichiers : le protéger en production (cron, token `TRIPHOTOS_SECRET`, ou accès restreint).
- FFP3 : galerie intégrée dans l’app Slim (routes dans `serveur/ffp3/`).

Les firmwares **uploadphotosserver_msp1** et **uploadphotosserver_n3pp_1_6_deppsleep** envoient respectivement vers `/msp1gallery/upload.php` et `/n3ppgallery/upload.php`. Vérifier que le serveur web (Apache/Nginx) expose bien ces chemins à la racine du site (ex. `https://iot.olution.info/msp1gallery/`, `https://iot.olution.info/n3ppgallery/`).

---

### 2.6 Monitoring et robustesse

**Recommandations :**

1. **Heartbeat / présence**  
   - S’assurer que chaque type de firmware envoie des données à intervalle régulier (déjà le cas pour les POST données). Si possible, exposer un endpoint léger « ping » ou utiliser la dernière date de réception des données comme indicateur de présence. FFP3 gère déjà des notions de heartbeat/supervision.

2. **Alertes**  
   - Les mails d’alerte (n3pp, msp) sont utiles pour la salle n³ (arrosage, sécheresse, etc.). Centraliser les adresses et les conditions d’envoi dans la doc ou la config pour éviter les envois en double ou en dev.

3. **Logs et diagnostic**  
   - Côté serveur (ffp3 : Monolog), garder une politique de rétention et de niveau de log (info en prod, debug en dev). Côté firmware, documenter les niveaux de trace série (ex. `CORE_DEBUG_LEVEL`) pour le dépannage sur site.

4. **OTA**  
   - Les projets upload photos et ffp5cs utilisent l’OTA. Documenter la procédure de mise à jour à distance (URL, mot de passe OTA) et la réserver à un usage encadré (éviter les mises à jour accidentelles depuis la classe).

---

### 2.7 Versionnement et déploiement

**Recommandations :**

1. **Dépôt racine**  
   - Dépôt Git initialisé à la racine **IOT_n3**. **firmwires** (n3_firmwires) et **serveur** (n3_serveur) sont des sous-modules (voir §3 « Versionnement et submodules »).

2. **Tags et releases**  
   - Tagger les versions stables (ex. `n3-iot-2025.03`) pour pouvoir retrouver un état cohérent firmwares + serveur après une mise à jour.

3. **Documentation des déploiements**  
   - Indiquer dans un fichier (ex. `docs/deploiement.md`) quels firmwares sont déployés où (salle n³, labo, démo), et sur quelle URL/board ils sont configurés (iot.olution.info, board=2/3, etc.).
   - **Cron / mise à jour serveur :** les dépôts IOT_n3 et n3_serveur utilisent la branche **master** (pas `main`). Pour un cron qui met à jour le code sur iot.olution.info : `cd /chemin/vers/site && git pull origin master` (et éventuellement `git submodule update --init --recursive` si le site est un clone avec submodules).

---

### 2.8 Documentation et lien avec n³

**Recommandations :**

1. **README racine**  
   - Le [README](README.md) décrit la structure, les liens firmware ↔ serveur, le contexte **salle aérée n³**, et les liens [n3.olution.info](https://n3.olution.info) / [iot.olution.info](https://iot.olution.info). L’inventaire des appareils est dans [docs/inventaire_appareils.md](docs/inventaire_appareils.md).

2. **Onboarding**  
   - Rédiger un court « guide de contribution » ou « guide technique n³ IoT » (dans `docs/` ou à la racine) : comment cloner, compiler un firmware, où sont les secrets, comment tester en local sans toucher à la prod.

3. **Pédagogie**  
   - Si des élèves ou enseignants contribuent au code, documenter les pôles de la salle n³ (lien vers [n3.olution.info/accueil/poles/](https://n3.olution.info/accueil/poles/)) et quels appareils sont associés à quels usages (serre, météo, aquaponie, robotique).

---

## 3. Synthèse des actions

| Priorité | Thème | Action | État |
|----------|------|--------|------|
| Haute | Sécurité | Externaliser WiFi, SMTP et clé API dans un fichier non versionné ; documenter `.env` / `credentials.h.example`. | **Partiel** : fait pour n3pp4_2 et msp2_5 (credentials.h) ; à compléter pour uploadphotosserver_*, LVGL_Widgets si applicable. |
| Haute | Bugs | Corriger `batterie()` et affichage OLED dans n3pp4_2 (voir RAPPORT_ANALYSE). | **Fait** |
| Moyenne | Config | Gérer la partition msp2_5 (fichier ou suppression de la ligne) ; utiliser variables d’env pour les ports série. | **Fait** |
| Moyenne | Inventaire | Créer un registre des appareils (tableau ou page admin) et un nommage cohérent (n3-*). | **Fait** ([docs/inventaire_appareils.md](docs/inventaire_appareils.md)) |
| Moyenne | Versionnement | Git à la racine IOT_n3 ; submodules ; tags. | **Fait** |
| Moyenne | Cycle de livraison | À chaque modification : incrémenter la version, mettre à jour la doc concernée, commit puis push (submodules puis dépôt parent). Voir `.cursor/rules/git-et-versionnement.mdc`. | **Règle** |
| Moyenne | Doc | Contexte salle n³ et liens n3 / iot dans le README. | **Fait** |
| Basse | Backend | Documenter les APIs (URLs, formats) ; à long terme, viser une convergence vers une API centralisée (type FFP3). | À faire |
| Basse | Code | Modulariser n3pp4_2 et msp2_5 ; extraire une lib commune (WiFi, NTP, OLED, HTTP). | À faire |

### Versionnement et submodules

- **Dépôt racine :** `git init` à la racine de IOT_n3. Fichier `.gitignore` racine (`.pio/`, fichiers sensibles, `error_log`, etc.).
- **Submodules :** **firmwires** pointe vers **n3_firmwires** (https://github.com/oliviera999/n3_firmwires.git) ; **serveur** pointe vers **n3_serveur** (https://github.com/oliviera999/n3_serveur.git), qui contient msp1, n3pp, les galeries et ffp3. ffp5cs est un dossier ordinaire dans n3_firmwires (plus de submodule ffp5cs à la racine).
- **Clone avec submodules :** `git clone --recurse-submodules <url>` ou `git submodule update --init --recursive`.
- **Tags :** ex. `git tag n3-iot-2025.03` pour une release.

### Gestion des firmwares

- **Registre central :** le fichier **firmwires/firmwares.manifest.json** recense tous les projets firmware (chemin, carte, environnement PlatformIO, lien serveur, cible OTA). C’est la source de vérité pour lister les firmwares et, à terme, pour faire évoluer les scripts (build, OTA, inventaire).
- **Liste et versions :** depuis la racine IOT_n3, exécuter `.\scripts\firmwires-list.ps1` pour afficher le tableau des firmwares ; `-WithVersion` ajoute la version extraite du code, `-Json` sortie JSON.
- **Publication OTA :** `.\scripts\publish_ota.ps1` (n3pp, msp, cam-msp1, cam-n3pp, cam-ffp3) ; ffp5cs utilise son propre script dans `firmwires/ffp5cs/scripts/`. Après publication OTA, committer la référence du sous-module serveur dans le dépôt parent.
- **Inventaire :** tenir à jour **docs/inventaire_appareils.md** (identifiant n3-*, type de firmware, emplacement, dernière version). La sortie de `firmwires-list.ps1 -WithVersion` peut aider à aligner les versions connues.
- **Migration déjà en place :** firmwires est le submodule **n3_firmwires**. En cas de clone sans migration effectuée, voir [SUBMODULES_SETUP.md](SUBMODULES_SETUP.md) et `scripts/migrate-firmwires-to-submodule.ps1`.

---

## 4. Références

- **Présentation salle aérée n³ :** [https://n3.olution.info](https://n3.olution.info)  
- **Backend IoT :** [https://iot.olution.info](https://iot.olution.info)  
- **Documentation projet :** [README](README.md), [ANALYSE_ARBORESCENCE](ANALYSE_ARBORESCENCE.md), [docs/inventaire_appareils](docs/inventaire_appareils.md), [firmwires/README](firmwires/README.md), [firmwires/RAPPORT_ANALYSE](firmwires/RAPPORT_ANALYSE.md), [serveur/ffp3/README](serveur/ffp3/README.md) (ffp3 fait partie du dépôt n3_serveur).

---

*Document de recommandations techniques pour la gestion de l’IoT de la salle aérée n³. À mettre à jour au fil des évolutions du projet.*
