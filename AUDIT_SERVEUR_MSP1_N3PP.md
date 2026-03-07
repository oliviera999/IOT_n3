# Audit du code serveur MSP1 et N3PP

**Date :** 6 mars 2025  
**Périmètre :** `serveur/msp1/`, `serveur/n3pp/`, `serveur/msp1gallery/`, `serveur/n3ppgallery/`

---

## 1. Synthèse

| Critère              | MSP1 | N3PP |
|----------------------|------|------|
| Injection SQL        | 🔴 Critique | 🔴 Critique |
| Secrets en clair     | 🔴 Critique | 🔴 Critique |
| Authentification     | 🔴 Absente (securecontrol) | 🔴 Absente |
| Upload de fichiers   | 🟠 Risques | 🟠 Risques |
| Gestion des erreurs  | 🟠 Fuite d’infos | 🟠 Fuite d’infos |
| Cohérence / bugs     | 🟠 Table msp1 vs n3pp | 🔴 Bug config + SQL cassé |

---

## 2. Sécurité

### 2.1 Injection SQL (critique)

**Fichiers concernés (MSP1 et N3PP) :**

- **`post-msp1-data.php`** (l.56–66) : construction de la requête par concaténation de `$_POST` après uniquement `test_input()` (trim, stripslashes, htmlspecialchars). **Aucune requête préparée** → risque d’injection SQL si un champ contient des guillemets ou du SQL.
- **`post-n3pp-data.php`** / **`post-n3pp-data2.php`** : même schéma pour l’INSERT et les UPDATE.
- **`msp1-database.php`** / **`n3pp-database.php`** :
  - `createOutput()` : paramètres concaténés dans la requête (l.22–29).
  - `deleteOutput($id)`, `updateOutput($id, $state)` : `$id` et `$state` concaténés.
  - `getAllOutputStates($board)`, `getOutputBoardById($id)`, `updateLastBoardTime($board)`, `createBoard($board)`, `deleteBoard($board)`, `getBoard($board)` : id/board concaténés.
- **`msp1-config.php`** / **`n3pp-config.php`** :
  - `getFirstReadings($limit)` : `$limit` concaténé (l.237 msp1, équivalent n3pp).
  - `stddevReading2($value)` : `$value` concaténé → risque si `$value` vient de l’utilisateur.
  - `countDatas($var, $thresh)`, `delDatas()`, `changeDatas()`, `countDatasTempEau()`, `delDatasTempEau()`, `changeDatasTempEau()` : `$var` et `$thresh` concaténés → **injection SQL possible** si appelés avec des paramètres utilisateur non validés.
  - Dans **n3pp-config.php**, les fonctions utilisent `global $servername, ...` alors que **`$servername` n’est pas défini** (seul `$host_name` l’est) → voir section 3.

**Recommandation :** Utiliser **uniquement** des requêtes préparées (`mysqli_prepare` / `bind_param` ou PDO) pour toute donnée entrante (POST, GET, paramètres de fonctions). Ne jamais concaténer des entrées utilisateur dans une chaîne SQL.

---

### 2.2 Secrets et credentials (critique)

- **Mot de passe BDD** `Iot#Olution1` et **clé API** `fdGTMoptd5CD2ert3` sont en clair dans :
  - `post-msp1-data.php`, `post-n3pp-data.php`, `post-n3pp-data2.php`
  - `msp1-config.php`, `n3pp-config.php`, `n3pp-config2.php`
  - `msp1-database.php`, `n3pp-database.php`
  - `n3pp-data2.php`, `data_analysis.php`
- **Chemins absolus** type `/home4/oliviera/iot.olution.info/...` dans les `include_once` des pages sous `securecontrol/` (msp1 et n3pp) → dépendance à l’environnement et fuite d’info sur l’hébergement.

**Recommandation :**

- Mettre les credentials et la clé API dans un fichier **hors du dépôt** (ex. `config.local.php` ou variables d’environnement), inclus depuis un chemin fixe ou `getenv()`.
- Ne pas committer ce fichier (ajout dans `.gitignore`). Documenter les variables attendues.

---

### 2.3 Authentification des interfaces de contrôle

- Les dossiers **`msp1control/securecontrol/`** et **`n3ppcontrol/securecontrol/`** n’ont **aucune vérification de session ni de mot de passe** dans les scripts PHP lus.
- Les endpoints **`msp1-outputs-action.php`** et **`n3pp-outputs-action.php`** permettent de modifier des sorties (UPDATE/DELETE) en GET/POST **sans authentification**.
- Toute personne connaissant l’URL peut donc piloter les sorties (pompe, reset, etc.).

**Recommandation :** Protéger toutes les pages sous `securecontrol/` et les scripts `*-outputs-action.php` par une authentification (session PHP après login, ou au minimum .htpasswd). Ne pas exposer les actions de contrôle sans contrôle d’accès.

---

### 2.4 Upload de fichiers (msp1gallery / n3ppgallery)

- **`msp1gallery/upload.php`** et **`n3ppgallery/upload.php`** :
  - Vérification par `getimagesize()` et extension (jpg, png, jpeg, gif) → contournable (fichier renommé, ou contenu non-image avec en-tête image).
  - Taille max 500 000 000 octets (~500 Mo) → très permissif.
  - **Aucune authentification** : tout le monde peut envoyer des fichiers.
  - Nom de fichier : `basename($_FILES["imageFile"]["name"])` utilisé dans le chemin → risque de traversal si le serveur ne normalise pas (ex. `../../../tmp/script.php`).
  - Pas de nom aléatoire côté serveur pour éviter les collisions et les noms prédéfinis.

**Recommandation :** Vérifier le type MIME côté serveur (et si possible signature magique), limiter la taille (ex. 5–10 Mo), générer un nom de fichier côté serveur (id unique + extension autorisée), et protéger l’upload par authentification. Valider l’extension contre une liste blanche stricte et refuser tout caractère spécial dans le nom original.

---

### 2.5 Gestion des erreurs et fuite d’informations

- Dans **post-msp1-data.php**, **post-n3pp-data.php**, **post-n3pp-data2.php** : en cas d’erreur SQL, le message affiche la requête complète :  
  `echo "Error: " . $sql . "<br>" . $conn->error;`  
  → exposition de la structure des tables et des données en production.
- Même logique dans **msp1-database.php** et **n3pp-database.php** pour les fonctions de contrôle (createOutput, deleteOutput, updateOutput, etc.).

**Recommandation :** En production, ne jamais afficher `$sql` ni `$conn->error` à l’utilisateur. Logger les erreurs dans un fichier ou un service dédié et renvoyer un message générique (ex. « Erreur technique »).

---

## 3. Bugs et incohérences

### 3.1 N3PP – Variable `$servername` manquante (n3pp-config.php)

- En tête de fichier sont définis : `$host_name`, `$dbname`, `$username`, `$password`.
- Les fonctions **getSensorData()**, **exportSensorData()** et d’autres utilisent :  
  `global $servername, $username, $password, $dbname;`  
  puis `new mysqli($servername, ...)`.
- **`$servername` n’est jamais défini** dans ce fichier → en exécution, `$servername` est undefined et la connexion échoue (visible dans `error_log` : « Undefined variable $password » / « Access denied for user ''@'localhost' »).

**Correction recommandée :** Dans **n3pp-config.php**, ajouter par exemple après la ligne 5 :  
`$servername = $host_name; // ou $servername = "localhost";`  
et s’assurer que toutes les fonctions qui utilisent cette connexion ont bien accès à `$servername` (ou utilisent partout `$host_name` de façon cohérente).

### 3.2 N3PP – post-n3pp-data.php : mauvaise table et SQL invalide

- **Lignes 54–68** : les UPDATE ciblent la table **`msp1Outputs`** au lieu de **`n3ppOutputs`** (projet n3pp).
- Du code commenté (l.64–71) contient encore des références à `EtatPompe`, `ffp3Data`, etc., et une ligne **non commentée** (l.66) :  
  `UPDATE msp1Outputs SET state = '" . $EtatPompe . "' WHERE gpio= '13';`  
  avec une variable **`$EtatPompe`** non définie (le script utilise `$etatPompe`).  
  → Erreur PHP (variable undefined) et incohérence de schéma (msp1 vs n3pp).

**Recommandation :**  
- Remplacer tous les `msp1Outputs` par **`n3ppOutputs`** dans **post-n3pp-data.php**.  
- Supprimer ou commenter correctement le bloc mort (l.64–71) et ne pas utiliser `$EtatPompe` ; utiliser uniquement `$etatPompe` si un UPDATE sur gpio=13 est requis pour n3pp.

### 3.3 Doublon de connexion (msp1-config.php / n3pp-config.php)

- La connexion `mysqli_connect` est faite deux fois (l.10 et l.20) avec les mêmes paramètres. Redondant et source de confusion.

**Recommandation :** Une seule connexion en tête de fichier ; réutiliser `$connection` partout où c’est pertinent, ou utiliser uniquement des fonctions qui créent leur connexion avec les mêmes variables.

### 3.4 msp1-config.php : incohérence de schéma (état pompe / reset)

- Les fonctions **etatPompeAqua()**, **etatResetMode()**, **stopPompeAqua()**, **runPompeAqua()**, **rebootEsp()** interrogent ou mettent à jour une colonne **`state`** dans la table **`msp1Data`** avec des conditions sur **`gpio`** (ex. gpio='13', gpio='110').
- La table **msp1Data** (côté post-msp1-data.php) est utilisée pour des **mesures** (TempAirInt, Humidite, etc.) avec un `reading_time`. Il est peu probable qu’elle contienne des colonnes `state` et `gpio` au même sens que **msp1Outputs**.  
  → Probable confusion entre table de **données** (msp1Data) et table d’**outputs** (msp1Outputs). Même remarque pour **n3pp-config.php** (requêtes sur `n3ppData` avec `state`/`gpio`).

**Recommandation :** Vérifier le schéma réel des tables (msp1Data, msp1Outputs, n3ppData, n3ppOutputs). Si l’état des sorties doit être lu/écrit, utiliser uniquement les tables *Outputs et pas les tables *Data pour `state`/`gpio`.

---

## 4. Bonnes pratiques déjà en place

- **msp1-config.php** / **n3pp-config.php** : les fonctions **getSensorData()**, **getLastReadings()**, **exportSensorData()**, **maxReading()**, **minReading()**, **avgReading()**, **stddevReading()** utilisent des requêtes préparées pour les dates et parfois d’autres paramètres.
- Vérification de la méthode HTTP (POST pour les endpoints de post de données) et contrôle de la clé API pour accepter les envois des capteurs.
- Séparation relative entre données (msp1datas / n3ppdatas), contrôle (msp1control / n3ppcontrol) et galerie (msp1gallery / n3ppgallery).

---

## 5. Plan d’actions priorisé

| Priorité | Action |
|----------|--------|
| P0 | Corriger **n3pp-config.php** : définir `$servername` (ou utiliser `$host_name` partout). |
| P0 | Corriger **post-n3pp-data.php** : table **n3ppOutputs** (pas msp1Outputs), supprimer/corriger le bloc avec `$EtatPompe`. |
| P1 | Remplacer toutes les requêtes à risque (post-*-data.php, *-database.php, *-config.php) par des **requêtes préparées**. |
| P1 | Sortir les **secrets** (BDD, clé API) dans un fichier de config hors dépôt ou variables d’environnement. |
| P1 | Ajouter une **authentification** sur securecontrol et sur *-outputs-action.php. |
| P2 | Renforcer l’**upload** (taille, type, nom de fichier, auth). |
| P2 | Cesser d’afficher **$sql** et **$conn->error** en production ; logger les erreurs côté serveur. |
| P2 | Clarifier le schéma BDD (Data vs Outputs) et corriger les fonctions etatPompeAqua / etatResetMode / etc. si elles doivent utiliser les tables *Outputs. |

---

## 6. Fichiers audités (liste non exhaustive)

**MSP1**  
- `serveur/msp1/msp1datas/post-msp1-data.php`  
- `serveur/msp1/msp1datas/msp1-config.php`  
- `serveur/msp1/msp1control/msp1-outputs-action.php`  
- `serveur/msp1/msp1control/msp1-database.php`  
- `serveur/msp1/msp1control/securecontrol/msp1-outputs.php`  
- `serveur/msp1gallery/upload.php`  

**N3PP**  
- `serveur/n3pp/n3ppdatas/post-n3pp-data.php`, `post-n3pp-data2.php`  
- `serveur/n3pp/n3ppdatas/n3pp-config.php`, `n3pp-config2.php`  
- `serveur/n3pp/n3ppcontrol/n3pp-outputs-action.php`  
- `serveur/n3pp/n3ppcontrol/n3pp-database.php`  
- `serveur/n3pp/n3ppcontrol/securecontrol/n3pp-outputs.php`  
- `serveur/n3ppgallery/upload.php`  
- `serveur/n3pp/n3ppdatas/n3pp-data.php` (formulaires et appels config)

---

*Fin du rapport d’audit.*
