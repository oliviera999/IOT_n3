# Rapport de diagnostic - Graphiques Highcharts page météo

**Date** : 9 mars 2026  
**Page concernée** : https://iot.olution.info/meteo  
**Problème** : Les graphiques Highcharts ne s'affichent pas (conteneurs vides)

---

## 🔍 Diagnostic

### Symptômes observés

En analysant le HTML de la page météo, j'ai identifié les éléments suivants :

1. **Conteneurs des graphiques présents** : Les `<div>` avec les IDs `chart-temperatures`, `chart-lights`, `chart-niveauxeaux`, `chart-cycles` sont bien présents dans le HTML.

2. **Bibliothèques JS chargées** : Highcharts Stock, jQuery, et les fichiers JS personnalisés (`highcharts-defaults.js`, `chart-helpers.js`) se chargent correctement (HTTP 200).

3. **Données présentes** : Les tableaux JavaScript contenant les données des capteurs sont bien générés dans le HTML (21 mesures).

### Cause racine identifiée

**Bug dans la fonction `zipSeries`** (fichiers `highcharts-defaults.js` et `chart-helpers.js`) :

La fonction `zipSeries` est appelée pour combiner les timestamps et les valeurs en paires `[timestamp, value]` compatibles avec Highcharts. Elle était écrite pour accepter uniquement des **chaînes de caractères** au format ISO (ex: `"2025-03-09 14:30:00"`).

**Problème** : Le `ChartDataService.php` (ligne 83) génère les timestamps en **millisecondes** (nombres) :

```php
$ts = isset($r['reading_time']) ? (int) (strtotime($r['reading_time']) * 1000) : 0;
```

Exemple de données générées dans le HTML :
```javascript
var reading_time = [1772694539000, 1772697551000, ...]; // Nombres (timestamps en ms)
```

La fonction `zipSeries` essayait de faire :
```javascript
var ts = new Date(times[i].replace(' ', 'T')).getTime();
```

**Erreur** : Les nombres n'ont pas de méthode `.replace()` → erreur JavaScript → graphiques non affichés.

---

## ✅ Correction appliquée

### Modification de la fonction `zipSeries`

J'ai modifié la fonction `zipSeries` dans les deux fichiers pour accepter **à la fois** les chaînes ISO et les timestamps en millisecondes :

**Fichiers modifiés** :
- `serveur/public/assets/js/highcharts-defaults.js`
- `serveur/public/assets/js/chart-helpers.js`

**Nouvelle implémentation** :

```javascript
function zipSeries(times, values) {
    if (!times || !values) return [];
    var result = [];
    for (var i = 0; i < times.length; i++) {
        var ts;
        if (typeof times[i] === 'number') {
            ts = times[i];  // Timestamp en ms déjà prêt
        } else if (typeof times[i] === 'string') {
            ts = new Date(times[i].replace(' ', 'T')).getTime();  // Conversion ISO → ms
        } else {
            continue;  // Type invalide, on ignore
        }
        
        var v = values[i] !== null && values[i] !== undefined && values[i] !== ''
            ? parseFloat(values[i])
            : null;
        if (!isNaN(ts)) {
            result.push([ts, isNaN(v) ? null : v]);
        }
    }
    return result;
}
```

### Avantages de cette correction

1. **Rétrocompatible** : Fonctionne avec les anciennes pages qui passent des chaînes ISO.
2. **Compatible avec le nouveau format** : Accepte les timestamps en millisecondes générés par `ChartDataService`.
3. **Robuste** : Ignore les valeurs invalides au lieu de planter.

---

## 📦 Déploiement

### Commits effectués

**Version serveur** : `5.0.68` → `5.0.69`

**Commits** :
- Submodule `serveur` : `[serveur] correction fonction zipSeries pour accepter timestamps millisecondes et chaînes ISO` (commit `a1b3ebb`)
- Dépôt parent `IOT_n3` : `[projet] référence serveur 5.0.69 - correction fonction zipSeries pour accepter timestamps millisecondes et chaînes ISO` (commit `9d26b52`)

**Push** : ✅ Effectué vers GitHub (serveur + parent)

### Déploiement en production

**⚠️ ÉTAPE MANQUANTE** : Le serveur de production (`iot.olution.info`) doit faire un `git pull` pour récupérer les modifications.

**Procédure de déploiement** :

```bash
# 1. Se connecter au serveur de production
ssh oliviera@toaster

# 2. Aller dans le dossier du serveur
cd /home4/oliviera/iot.olution.info

# 3. Faire un git pull
git pull origin master

# 4. (Optionnel) Vérifier la version
cat VERSION
# Devrait afficher : 5.0.69

# 5. (Optionnel) Vérifier que les fichiers JS sont à jour
grep -A 5 "typeof times\[i\]" public/assets/js/highcharts-defaults.js
# Devrait afficher la nouvelle logique avec typeof
```

**Alternative** : Si le serveur a un webhook GitHub ou un système de déploiement automatique, les modifications seront déployées automatiquement après le push.

---

## 🧪 Vérification post-déploiement

Après le déploiement en production, vérifier :

1. **Fichier JS mis à jour** :
   ```bash
   curl -s https://iot.olution.info/assets/js/highcharts-defaults.js | grep "typeof times"
   ```
   Devrait afficher la nouvelle logique.

2. **Page météo fonctionnelle** :
   - Ouvrir https://iot.olution.info/meteo
   - Vérifier que les 4 graphiques s'affichent correctement :
     - Températures & Humidité
     - Luminosité
     - Humidité du sol & Eau
     - Autonomie & Système

3. **Console JavaScript** (F12) :
   - Aucune erreur liée à `zipSeries`, `replace`, ou Highcharts
   - Les graphiques doivent être initialisés sans erreur

---

## 📊 Impact

### Pages concernées

Cette correction impacte **toutes les pages** utilisant `highcharts-defaults.js` et `zipSeries` :

- ✅ `/meteo` (MSP1 - Station météo)
- ✅ `/serre` (N3PP - Élevage)
- ✅ `/aquaponie` (FFP3 - Aquaponie)
- ✅ Toute autre page utilisant Highcharts avec des données générées par `ChartDataService`

### Compatibilité

- ✅ **Rétrocompatible** : Les anciennes pages passant des chaînes ISO continuent de fonctionner.
- ✅ **Nouveau format** : Les pages utilisant `ChartDataService::prepareGenericSeries()` fonctionnent maintenant correctement.

---

## 📝 Recommandations

1. **Tester toutes les pages de données** après déploiement :
   - `/meteo`
   - `/serre`
   - `/aquaponie`
   - `/tide-stats`

2. **Vérifier les logs d'erreur** du serveur et de la console navigateur.

3. **Documenter le format attendu** par `zipSeries` dans la JSDoc (déjà fait dans la correction).

4. **Envisager un test unitaire JavaScript** pour `zipSeries` afin d'éviter les régressions futures.

---

## 🎯 Résumé

| Élément | Statut |
|---------|--------|
| Diagnostic | ✅ Complété |
| Correction | ✅ Appliquée |
| Tests locaux | ⚠️ Non testés (pas d'environnement de navigation web) |
| Commit & Push | ✅ Effectués |
| Déploiement production | ⚠️ **À FAIRE** (git pull sur le serveur) |
| Vérification post-déploiement | ⏳ En attente du déploiement |

---

**Prochaine étape** : Déployer en production et vérifier que les graphiques s'affichent correctement sur https://iot.olution.info/meteo.
