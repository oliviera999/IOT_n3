# Audit du code serveur — msp1gallery et n3ppgallery

**Date :** 6 mars 2025  
**Périmètre :** `serveur/msp1gallery/` et `serveur/n3ppgallery/` (côté serveur PHP)

---

## 1. Vue d’ensemble

| Composant        | Fichiers                                      | Rôle principal                    |
|------------------|-----------------------------------------------|-----------------------------------|
| **msp1gallery**  | `upload.php`, `msp1-gallery.php`              | Upload ESP32-CAM, affichage galerie |
| **n3ppgallery**  | `upload.php`, `n3pp-gallery.php`, `triphotos.php` | Idem + tri/redressement photos   |

Les deux galeries partagent une logique d’upload très proche ; n3ppgallery ajoute un script de tri des photos.

---

## 2. upload.php (msp1gallery et n3ppgallery)

### 2.1 Points positifs

- Vérification du type de fichier via `getimagesize()` (détection d’image réelle).
- Contrôle de l’extension (jpg, jpeg, png, gif).
- Limite de taille (500 Mo — très élevée, voir ci‑dessous).
- Préfixe de nom avec date/heure pour limiter les collisions.

### 2.2 Problèmes de sécurité

#### 2.2.1 Absence d’authentification / autorisation

- **Risque :** N’importe qui peut envoyer des fichiers vers l’endpoint.
- **Recommandation :** Token partagé (query/post), API key, ou authentification par IP / certificat côté ESP32 ; vérifier le token en PHP avant tout traitement.

#### 2.2.2 Dépendance à `$_POST["submit"]` pour la vérification d’image

```php
if(isset($_POST["submit"])) {
  $check = getimagesize($_FILES["imageFile"]["tmp_name"]);
```

- Les firmwares ESP32-CAM n’envoient en général **pas** de champ `submit`. La vérification `getimagesize()` est alors **sautée** et seul le contrôle d’extension reste actif.
- **Risque :** Upload de fausses images (fichier renommé en .jpg avec contenu arbitraire) si l’extension est acceptée.
- **Recommandation :** Toujours appeler `getimagesize()` dès qu’un fichier est présent, sans condition sur `$_POST["submit"]` :

  ```php
  if (isset($_FILES["imageFile"]) && $_FILES["imageFile"]["error"] === UPLOAD_ERR_OK) {
      $check = getimagesize($_FILES["imageFile"]["tmp_name"]);
      if ($check === false) {
          echo "File is not an image.";
          $uploadOk = 0;
      }
  }
  ```

#### 2.2.3 Pas de vérification de `$_FILES["imageFile"]["error"]`

- En cas d’erreur d’upload (taille, partiel, etc.), le code peut quand même utiliser `tmp_name` ou `size`.
- **Recommandation :** Vérifier `$_FILES["imageFile"]["error"] === UPLOAD_ERR_OK` avant toute utilisation.

#### 2.2.4 Chemin de destination et basename

- `basename($_FILES["imageFile"]["name"])` limite le path traversal dans le **nom de fichier**.
- Le répertoire cible est fixe (`msp1photos/` ou `n3ppphotos/`) — pas de traversal côté répertoire.
- **Risque restant :** Caractères spéciaux ou noms très longs selon la config serveur ; prévoir sanitization (strip, longueur max) si besoin.

#### 2.2.5 Taille maximale (500 Mo)

- `500000000` octets = 500 Mo, très permissif pour des photos ESP32-CAM.
- **Recommandation :** Réduire (ex. 5–10 Mo) pour limiter abus et charge disque.

### 2.3 Comportement et robustesse

- Pas de création explicite du répertoire cible : si `msp1photos/` ou `n3ppphotos/` n’existe pas, l’upload échoue sans message clair.
- **Recommandation :** Vérifier/créer le répertoire au début du script et définir des permissions cohérentes.

---

## 3. msp1-gallery.php et n3pp-gallery.php

### 3.1 Points positifs

- Liste de fichiers via `scandir()` sur un répertoire fixe.
- Pagination (12 par page) et liens précédent/suivant.
- Usage de Featherlight pour la lightbox.

### 3.2 Problèmes de sécurité et bugs

#### 3.2.1 Injection XSS (affichage des noms de fichiers)

- Les noms de fichiers (`$show`) sont affichés dans la page sans échappement :

  ```php
  <img src="<?php echo $dir . $show; ?>" ... title="<?php echo $show; ?>" />
  <?php echo $show; ?>
  ```

- Un fichier nommé par exemple `"><script>...</script>.jpg` pourrait injecter du script.
- **Recommandation :** Toujours échapper les sorties HTML : `htmlspecialchars($show, ENT_QUOTES, 'UTF-8')` pour `title`, texte et attributs.

#### 3.2.2 Path traversal dans l’URL des images

- `$dir` est fixe (`msp1photos/` ou `n3ppphotos/`) et `$show` provient de `scandir()`. En pratique, `scandir` ne remonte pas au‑dessus du répertoire.
- Pour plus de défense en profondeur : vérifier que `$show` ne contient pas `..` ou `/` avant de l’utiliser dans des URLs ou chemins.

#### 3.2.3 Pagination incorrecte (msp1-gallery.php)

- Ligne 57 : `$shows = array_slice($files, $per_page * intval($_GET['page']) - 12, $per_page);`
- Pour la page 1 : `per_page * 1 - 12 = 0` → correct.
- Pour la page 2 : `12 * 2 - 12 = 12` → correct.
- **Bug :** La ligne 59 fait `rsort($files)` **après** avoir déjà fait `array_reverse($files)` et **après** le `array_slice` : l’ordre des `$files` utilisé pour la pagination peut être incohérent. De plus, `$max_pages` est calculé à partir de `$files_count` qui inclut `.` et `..` :

  ```php
  $files_count = count($files);  // inclut . et ..
  $max_pages = ceil($files_count / $per_page);
  ```

- **Recommandation :** Exclure `.` et `..` avant de compter et de paginer ; fixer l’ordre une seule fois (ex. `rsort` ou `array_reverse`) puis faire `array_slice` sur cet ordre.

#### 3.2.4 Liens « précédent / suivant » (msp1-gallery.php)

- Lignes 60–62 : les liens pointent vers `ffp3-gallery.php` au lieu de `msp1-gallery.php` (copier-coller depuis ffp3).
- **Recommandation :** Remplacer par `msp1-gallery.php` dans msp1gallery.

#### 3.2.5 Variables non initialisées

- Si `$_GET['page']` est absent ou invalide, `intval($_GET['page'])` vaut 0 ; `$prev_link` et `$next_link` peuvent ne pas être définis, puis sont utilisés plus bas dans `<?php echo $prev_link; ?>`.
- **Recommandation :** Initialiser `$prev_link = ''; $next_link = '';` et normaliser `$page = max(1, intval($_GET['page'] ?? 1));`.

#### 3.2.6 Incohérences de libellés (msp1-gallery.php)

- Titre : "photos du potagerffp3" (faute + mauvais projet).
- Lien nav "phasmopolis" avec `href` msp1datas au lieu de n3pp pour phasmopolis.
- À aligner avec le vrai projet (msp1 = Le tiny garden, n3pp = Phasmopolis).

---

## 4. triphotos.php (n3ppgallery uniquement)

### 4.1 Rôle

- Parcourir `n3ppphotos/`, détecter les images en paysage, les redresser (rotation -90°) et les déplacer.

### 4.2 Problèmes de sécurité et de conception

#### 4.2.1 Accès sans authentification

- Script qui modifie et déplace des fichiers. S’il est appelable via le web sans contrôle d’accès, n’importe qui peut le déclencher.
- **Recommandation :** Protéger par token, cron interne, ou accès admin ; ne pas exposer en GET sans contrôle.

#### 4.2.2 Destination « redressées » = source

- `$dossierPhotosRedressees = 'n3ppphotos/';` : la photo est redressée **puis** déplacée vers le même dossier avec `rename($filePath, $destination . $file)`. Comme on a déjà écrit avec `imagejpeg($image, $filePath)`, le déplacement revient à renommer dans le même répertoire (comportement possible mais à clarifier).
- **Risque :** Confusion logique ; si un jour la destination change, risque d’écrasement ou de doublons.

#### 4.2.3 Debug et sortie HTML

- Présence de `echo "Test1";`, `echo "Test2";`, etc. en production.
- **Recommandation :** Supprimer tous les `echo` de debug ou les conditionner à un mode développement.

#### 4.2.4 Gestion d’erreurs

- Pas de vérification que `getimagesize($filePath)` ou `imagecreatefromjpeg($filePath)` réussissent (fichier non image, corrompu, etc.).
- **Recommandation :** Vérifier les retours et ignorer / logger les fichiers invalides au lieu de faire croire le script.

#### 4.2.5 Ressources image non libérées

- Dans `redresserPhoto()` et `calculerLuminositeMoyenne()`, `imagecreatefromjpeg()` alloue une ressource ; il n’y a pas de `imagedestroy()`.
- **Recommandation :** Appeler `imagedestroy($image)` après usage pour éviter fuites mémoire sur beaucoup de fichiers.

#### 4.2.6 Code mort (luminosité)

- La logique de tri par luminosité est commentée ; seules la détection paysage et la rotation sont actives. La fonction `calculerLuminositeMoyenne()` reste définie et non utilisée — à supprimer ou réactiver proprement.

---

## 5. Synthèse des recommandations prioritaires

| Priorité | Composant     | Action |
|----------|---------------|--------|
| Haute    | upload.php (x2) | Toujours valider l’image avec `getimagesize()` (sans dépendre de `submit`) ; vérifier `UPLOAD_ERR_OK` ; ajouter un mécanisme d’authentification ou token. |
| Haute    | upload.php (x2) | Limiter la taille max (ex. 10 Mo) et s’assurer que le répertoire cible existe. |
| Haute    | msp1-gallery.php | Corriger les liens de pagination (ffp3-gallery → msp1-gallery). |
| Haute    | msp1-gallery.php, n3pp-gallery.php | Échapper les noms de fichiers avec `htmlspecialchars()` pour éviter XSS. |
| Moyenne  | msp1-gallery.php, n3pp-gallery.php | Initialiser `$prev_link` / `$next_link` ; corriger le calcul de pagination (exclure `.` et `..`, ordre cohérent). |
| Moyenne  | triphotos.php | Supprimer les `echo` de debug ; protéger l’accès au script ; ajouter vérifications d’erreur et `imagedestroy()`. |
| Basse    | msp1-gallery.php | Corriger titre et libellés (potager/ffp3/phasmopolis). |

---

## 6. Conclusion

- **upload.php** : Logique utile (type, extension, taille) mais conditionnée à `submit` non envoyé par l’ESP32, et sans contrôle d’accès. À durcir (validation systématique, erreur d’upload, auth/token, taille).
- **msp1-gallery.php / n3pp-gallery.php** : Risque XSS sur les noms de fichiers, bugs de pagination et de liens (msp1), variables non initialisées. Corrections simples mais importantes.
- **triphotos.php** : Script sensible (écriture/disque) exposé sans auth, debug en production, et gestion d’erreurs/ressources à améliorer.

En appliquant les recommandations ci‑dessus, le code sera plus sûr et plus fiable pour un déploiement IoT.
