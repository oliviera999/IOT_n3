# Audit des bugs suite au changement de structure serveur

**Date :** 6 mars 2025  
**Contexte :** Migration vers le serveur unifié Slim 4 (front controller unique `public/index.php`). Vérification de la cohérence firmware ↔ serveur et des chemins d’accès.

---

## 1. Résumé

| Gravité | Nombre | Description |
|--------|--------|-------------|
| **Critique** | 2 | URLs inexistantes ou réécriture manquante → 404 en production |
| **Moyen** | 2 | Fichiers .ino avec chemins obsolètes (doublons des .cpp) |
| **Mineur** | 2 | Chemins absolus galeries, crons legacy |

---

## 2. Bugs critiques

### 2.1 Réécriture `/ffp3/` manquante quand DocumentRoot = `public/`

**Problème :** La doc de déploiement recommande `DocumentRoot = .../public`. Dans ce cas, seul `serveur/public/.htaccess` est utilisé. La règle de rétrocompatibilité `^ffp3/(.*)$ → $1` se trouve dans `serveur/.htaccess`, qui n’est **pas** appliqué.

**Impact :** Les firmwares **ffp5cs** envoient vers :
- `https://iot.olution.info/ffp3/post-data`
- `https://iot.olution.info/ffp3/heartbeat`
- `https://iot.olution.info/ffp3/api/outputs/state`

Slim n’a que les routes `/post-data`, `/heartbeat`, `/api/outputs/state` (sans préfixe `/ffp3/`). Sans réécriture, les requêtes vers `/ffp3/post-data` etc. renvoient **404**.

**Correction :** Ajouter dans `serveur/public/.htaccess` (avant la règle vers `index.php`) :

```apache
# Rétrocompatibilité firmware ffp5cs : /ffp3/post-data → /post-data, etc.
RewriteRule ^ffp3/(.*)$ $1 [L]
```

---

### 2.2 LVGL_Widgets et ffp5cs/LVGL_Widgets : URLs legacy inexistantes

**Problème :** Les deux projets utilisent des URLs de l’ancien backend procédural :

- `http://iot.olution.info/ffp3/ffp3datas/post-ffp3-data2.php`
- `http://iot.olution.info/ffp3/ffp3control/ffp3-outputs-action2.php?action=outputs_state&board=1`

Le serveur unifié n’expose **pas** ces routes. Il expose uniquement :
- `/post-ffp3-data.php` (alias vers PostDataController) — et non `post-ffp3-data**2**.php`
- `/api/outputs/state` (GET) — pas de route `/ffp3/ffp3control/ffp3-outputs-action2.php`

**Impact :** Envoi de données et récupération de l’état des sorties depuis LVGL_Widgets → **404**.

**Corrections possibles :**
- **Option A (recommandée) :** Adapter les firmwares LVGL pour utiliser les routes actuelles :
  - POST données : `https://iot.olution.info/ffp3/post-data` (ou `/post-data` si réécriture en place)
  - GET outputs : `https://iot.olution.info/ffp3/api/outputs/state` (ou `/api/outputs/state`)
- **Option B :** Ajouter dans `public/index.php` des alias legacy :
  - `POST /ffp3/ffp3datas/post-ffp3-data2.php` → `PostDataController::handle`
  - `GET /ffp3/ffp3control/ffp3-outputs-action2.php` → `OutputController::getOutputsState` (avec query `action=outputs_state&board=1`)

---

## 3. Bugs moyens (incohérence .ino vs .cpp)

### 3.1 uploadphotosserver_msp1

- **main.cpp (source utilisée)** : `serverPath = "/msp1gallery/upload.php"` ✅ conforme au serveur
- **uploadphotosserver_msp1.ino** : `serverPath = "/msp1/msp1gallery/upload.php"` ❌

Si quelqu’un compile l’ancien .ino, les photos seraient envoyées vers une URL qui n’existe pas.

**Correction :** Dans `uploadphotosserver_msp1.ino`, remplacer par `/msp1gallery/upload.php`.

### 3.2 uploadphotosserver_n3pp_1_6_deppsleep

- **main.cpp** : `serverPath = "/n3ppgallery/upload.php"` ✅
- **uploadphotosserver_n3pp_1_6_deppsleep.ino** : `serverPath = "/n3pp/n3ppgallery/upload.php"` ❌

Même principe.

**Correction :** Dans le .ino, remplacer par `/n3ppgallery/upload.php`.

---

## 4. Points d’attention (mineurs)

### 4.1 Galeries : chemins absolus dans `.env`

`GalleryUploadController` construit le répertoire cible avec :

```php
$baseDir = dirname(__DIR__, 3);  // racine serveur
$targetDir = $baseDir . '/' . rtrim($uploadDir, '/');
```

Si dans `.env` on définit par exemple `GALLERY_MSP1_DIR=/var/www/uploads/msp1`, on obtient un chemin du type `.../serveur//var/www/...`, invalide. Les valeurs relatives (`uploads/msp1`, etc.) fonctionnent correctement.

**Recommandation :** Documenter que `GALLERY_*_DIR` doit être un chemin **relatif** à la racine du projet, ou adapter le contrôleur pour gérer un chemin absolu (si `$uploadDir[0] === '/'` alors utiliser `$uploadDir` tel quel).

### 4.2 Crons et scripts legacy

La doc (`QUE_FAIRE_COTE_SERVEUR.md`) signale que les anciens scripts (`cronmsp1.php`, `cronn3pp.php`, `triphotos.php`) ne sont plus forcément disponibles. Si des crons ou liens pointent encore vers ces scripts, ils échoueront. À recenser côté hébergeur et à remplacer par les commandes/endpoints prévus par le serveur unifié.

---

## 5. Ce qui est cohérent

- **n3pp4_2** (main.cpp + .ino) : `/n3pp/n3ppdatas/post-n3pp-data.php`, `/n3pp/n3ppcontrol/n3pp-outputs-action.php` → routes présentes dans Slim ✅  
- **msp2_5** : `/msp1/msp1datas/post-msp1-data.php`, `/msp1/msp1control/msp1-outputs-action.php` → routes présentes ✅  
- **ffp5cs** (config.h) : `/ffp3/post-data`, `/ffp3/api/outputs/state`, `/ffp3/heartbeat` → OK **à condition** que la réécriture `/ffp3/` → racine soit active (voir 2.1)  
- **uploadphotosserver_ffp3_1_5_deppsleep** : `/ffp3/ffp3gallery/upload.php` → route enregistrée dans Slim ✅  
- **MSP/N3PP** : Contrôleurs et repositories (MspPostData, N3ppPostData, MspOutput, N3ppOutput) et tables `msp1Data`, `msp1Outputs`, `n3ppData`, `n3ppOutputs` sont alignés avec les routes et le contrat firmware ✅  

---

## 6. Plan d’action recommandé (corrections appliquées le 6 mars 2025)

1. ~~**Immédiat :** Ajouter la réécriture `^ffp3/(.*)$` dans `serveur/public/.htaccess`~~ → **Fait** (réécriture ajoutée dans `public/.htaccess`).
2. ~~**Court terme :** Corriger les `.ino` des upload photos (msp1, n3pp)~~ → **Fait** (`uploadphotosserver_msp1.ino`, `uploadphotosserver_n3pp_1_6_deppsleep.ino`).
3. ~~**Court terme :** Alias legacy LVGL~~ → **Fait** : routes `POST /ffp3datas/post-ffp3-data2.php` et `GET /ffp3control/ffp3-outputs-action2.php` ajoutées (après réécriture `/ffp3/` → racine), avec chemins déclarés publics dans le middleware d’auth.
4. **Documentation :** Préciser dans la doc déploiement que la réécriture `/ffp3/` est désormais dans `public/.htaccess`, et que `GALLERY_*_DIR` est relatif à la racine du projet.
