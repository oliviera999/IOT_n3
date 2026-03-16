# Rapport de vérification des pages IoT — 2026-03-09

## Résumé exécutif

**Date/heure** : 2026-03-09 14:06  
**Serveur** : https://iot.olution.info  
**Pages testées** : 8 pages principales  
**Résultat** : 4 pages OK (50%), 4 pages en erreur 500 (50%)

### Statut global : ⚠️ CRITIQUE

Le serveur présente des erreurs critiques 500 sur les pages de données principales (aquaponie, MSP1, N3PP). Les galeries photos fonctionnent correctement.

---

## Détail par page

### ✅ 1. Page d'accueil — https://iot.olution.info/

- **Status HTTP** : 200 OK ✅
- **Taille contenu** : 22 244 octets
- **Navigation visible** : Oui ✅
- **Footer visible** : Oui ✅
- **Erreurs JavaScript** : Aucune détectée
- **Problèmes visuels** : Aucun
- **Verdict** : Page fonctionnelle

---

### ❌ 2. Aquaponie landscape view — https://iot.olution.info/aquaponie

- **Status HTTP** : 500 Internal Server Error ❌
- **Navigation visible** : N/A (page ne charge pas)
- **Footer visible** : N/A
- **Erreurs détectées** : Exception PHP critique
- **Cause identifiée** : 
  ```
  App\Controller\AquaponieController::__construct(): 
  Argument #7 ($dateRangeExtractor) must be of type App\Service\DateRangeExtractor, 
  App\Security\CsrfService given
  ```
- **Fichier concerné** : `/src/Controller/AquaponieController.php:24`
- **Problème** : Le container DI (Dependency Injection) utilise un cache compilé obsolète qui ne correspond plus aux signatures actuelles des constructeurs
- **Verdict** : Page inaccessible

---

### ❌ 3. Aquaponie classic view — https://iot.olution.info/aquaponie-alt

- **Status HTTP** : 500 Internal Server Error ❌
- **Navigation visible** : N/A
- **Footer visible** : N/A
- **Erreurs détectées** : Même erreur que `/aquaponie`
- **Cause** : Même problème de cache DI compilé
- **Verdict** : Page inaccessible

---

### ❌ 4. MSP1 weather data — https://iot.olution.info/msp1/msp1datas/msp1-data.php

- **Status HTTP** : 500 Internal Server Error ❌
- **Navigation visible** : N/A
- **Footer visible** : N/A
- **Erreurs détectées** : Exception PHP critique
- **Cause identifiée** :
  ```
  Too few arguments to function App\Controller\Msp\MspDataController::__construct(), 
  3 passed in CompiledContainer.php on line 492 and exactly 6 expected
  ```
- **Fichier concerné** : `/src/Controller/Msp/MspDataController.php:39`
- **Problème** : Le cache DI compilé ne fournit que 3 paramètres au lieu de 6
- **Verdict** : Page inaccessible

---

### ❌ 5. N3PP greenhouse data — https://iot.olution.info/n3pp/n3ppdatas/n3pp-data.php

- **Status HTTP** : 500 Internal Server Error ❌
- **Navigation visible** : N/A
- **Footer visible** : N/A
- **Erreurs détectées** : Exception PHP critique
- **Cause identifiée** :
  ```
  Too few arguments to function App\Controller\N3pp\N3ppDataController::__construct(), 
  3 passed in CompiledContainer.php on line 525 and exactly 6 expected
  ```
- **Fichier concerné** : `/src/Controller/N3pp/N3ppDataController.php:37`
- **Problème** : Le cache DI compilé ne fournit que 3 paramètres au lieu de 6
- **Verdict** : Page inaccessible

---

### ✅ 6. MSP1 photo gallery — https://iot.olution.info/gallery/msp1

- **Status HTTP** : 200 OK ✅
- **Taille contenu** : 6 961 octets
- **Navigation visible** : Oui ✅
- **Footer visible** : Oui ✅
- **Erreurs JavaScript** : Aucune détectée
- **Problèmes visuels** : Aucun
- **Verdict** : Page fonctionnelle

---

### ✅ 7. N3PP photo gallery — https://iot.olution.info/gallery/n3pp

- **Status HTTP** : 200 OK ✅
- **Taille contenu** : 6 995 octets
- **Navigation visible** : Oui ✅
- **Footer visible** : Oui ✅
- **Erreurs JavaScript** : Aucune détectée
- **Problèmes visuels** : Aucun
- **Verdict** : Page fonctionnelle

---

### ✅ 8. FFP3 photo gallery — https://iot.olution.info/gallery/ffp3

- **Status HTTP** : 200 OK ✅
- **Taille contenu** : 6 936 octets
- **Navigation visible** : Oui ✅
- **Footer visible** : Oui ✅
- **Erreurs JavaScript** : Aucune détectée
- **Problèmes visuels** : Aucun
- **Verdict** : Page fonctionnelle

---

## Analyse des logs serveur

### Cronlog.txt (accessible)

- **URL** : https://iot.olution.info/public/cronlog.txt
- **Status** : 200 OK
- **Erreurs récentes** :
  - 476 lignes `[ERROR]`
  - 127 exceptions non gérées
  - 326 erreurs d'insertion BDD

### error_log (non accessible)

- **URL** : https://iot.olution.info/public/error_log
- **Status** : 404 Not Found
- Le fichier error_log n'est pas accessible publiquement (probablement pour des raisons de sécurité)

---

## Pages FFP3 supplémentaires testées

Les pages suivantes retournent également des erreurs 404 :

- `/ffp3/` → 404
- `/ffp3/dashboard` → 404
- `/ffp3/aquaponie` → 404
- `/ffp3/control` → 404
- `/ffp3/tide-stats` → 404
- `/ffp3/dashboard-test` → 404
- `/ffp3/aquaponie-test` → 404
- `/ffp3/control-test` → 404

**Note** : Ces routes ne sont peut-être pas encore déployées ou nécessitent une configuration `.htaccess` spécifique.

---

## Cause racine identifiée

### Problème principal : Cache DI (Dependency Injection) obsolète

Le serveur utilise un système de cache pour le container DI (fichier compilé : `/var/cache/di/CompiledContainer.php`). Ce cache contient des définitions obsolètes des constructeurs des contrôleurs, ce qui provoque des erreurs de type mismatch lors de l'injection des dépendances.

**Preuve** :
- Le fichier `serveur/config/dependencies.php` contient les bonnes définitions avec les bons paramètres
- Les erreurs mentionnent toutes le fichier `CompiledContainer.php` (cache compilé)
- Les signatures des constructeurs dans le code source sont correctes

### Contrôleurs affectés

1. **AquaponieController** (lignes 245-256 de dependencies.php)
   - Définition correcte : 8 paramètres
   - Cache compilé : ordre incorrect des paramètres

2. **MspDataController** (lignes 364-372 de dependencies.php)
   - Définition correcte : 6 paramètres
   - Cache compilé : seulement 3 paramètres fournis

3. **N3ppDataController** (lignes 391-399 de dependencies.php)
   - Définition correcte : 6 paramètres
   - Cache compilé : seulement 3 paramètres fournis

---

## Solution recommandée

### Action immédiate requise : Vider le cache DI sur le serveur de production

Le cache DI compilé doit être supprimé pour forcer la régénération avec les définitions à jour.

**Commandes à exécuter sur le serveur** :

```bash
# Se connecter au serveur via SSH
ssh utilisateur@iot.olution.info

# Naviguer vers le dossier du serveur
cd /home4/oliviera/iot.olution.info

# Supprimer le cache DI compilé
rm -rf var/cache/di/CompiledContainer.php

# Vérifier que le dossier cache existe et a les bonnes permissions
ls -la var/cache/di/

# Si le dossier n'existe pas, le créer
mkdir -p var/cache/di
chmod 755 var/cache/di
```

**Alternative si pas d'accès SSH** : Créer un script PHP de maintenance accessible via HTTP :

```php
<?php
// serveur/public/clear-cache.php (à supprimer après utilisation)
$cacheFile = __DIR__ . '/../var/cache/di/CompiledContainer.php';
if (file_exists($cacheFile)) {
    unlink($cacheFile);
    echo "Cache DI supprimé avec succès.\n";
} else {
    echo "Fichier de cache non trouvé.\n";
}
```

### Vérification post-correction

Après suppression du cache, relancer le script de vérification :

```powershell
.\scripts\check-user-pages.ps1
```

Toutes les pages devraient retourner HTTP 200.

---

## Problèmes secondaires détectés

### 1. Routes FFP3 manquantes (404)

Les routes `/ffp3/*` retournent 404. Vérifier :
- Configuration `.htaccess` dans `serveur/public/`
- Définition des routes dans `serveur/public/index.php`
- Déploiement complet du code sur le serveur

### 2. Erreurs d'insertion BDD (326 occurrences)

Le cronlog montre de nombreuses erreurs d'insertion. Causes possibles :
- Colonnes manquantes dans les tables BDD
- Types de données incompatibles
- Contraintes de clés étrangères

**Action** : Analyser les dernières lignes du cronlog pour identifier les colonnes problématiques.

### 3. Exceptions non gérées (127 occurrences)

De nombreuses exceptions non gérées dans le cronlog. Exemples :
- `Class "App\Controller\N3pp\N3ppRealtimeApiController" not found`
- Erreurs de typage dans les constructeurs

**Action** : Vérifier que tous les fichiers de classes sont déployés sur le serveur.

---

## Recommandations

### Court terme (urgent)

1. ✅ **Vider le cache DI** (voir solution ci-dessus)
2. ✅ **Vérifier le déploiement complet** du code source sur le serveur
3. ✅ **Tester toutes les pages** après correction

### Moyen terme

1. Ajouter un script de déploiement automatisé qui vide les caches
2. Configurer un monitoring des erreurs 500 avec alertes
3. Mettre en place un environnement de staging pour tester avant prod
4. Documenter la procédure de vidage de cache dans le README serveur

### Long terme

1. Migrer vers un système de cache plus robuste (Redis, Memcached)
2. Implémenter un système de health check automatique
3. Ajouter des tests d'intégration pour les routes critiques
4. Configurer un système de rollback automatique en cas d'erreur

---

## Fichiers de référence

- Script de vérification : `scripts/check-user-pages.ps1`
- Rapport détaillé : `scripts/reports/check-pages-2026-03-09-1405.md`
- Rapport JSON : `scripts/reports/user-pages-check-2026-03-09-140604.json`
- Configuration DI : `serveur/config/dependencies.php`
- Logs serveur : https://iot.olution.info/public/cronlog.txt

---

**Rapport généré le** : 2026-03-09 14:06  
**Généré par** : Agent Cursor (vérification automatisée)  
**Prochaine vérification recommandée** : Après correction du cache DI
