# Rapport de test des pages IoT - Erreurs 500 critiques

**Date**: 2026-03-09 14:45 UTC  
**Testeur**: Agent Cursor  
**Statut**: ❌ **CRITIQUE - Toutes les pages en erreur 500**

## Résumé exécutif

**TOUTES les pages du site IoT retournent des erreurs 500 Internal Server Error.**

Les redirections 301 fonctionnent correctement, mais les pages de destination échouent systématiquement.

## Résultats des tests

### 1. Pages principales (nouvelles URLs unifiées)

| Page | URL | Statut attendu | Statut réel | Résultat |
|------|-----|----------------|-------------|----------|
| Méteo | `/meteo` | 200 OK | **500 Error** | ❌ ÉCHEC |
| Méteo Control | `/meteo-control` | 200/302 | **500 Error** | ❌ ÉCHEC |
| Serre | `/serre` | 200 OK | **500 Error** | ❌ ÉCHEC |
| Serre Control | `/serre-control` | 200/302 | **500 Error** | ❌ ÉCHEC |

### 2. Redirections legacy (anciennes URLs)

| Page | URL | Statut | Redirection | Résultat |
|------|-----|--------|-------------|----------|
| MSP1 legacy | `/msp1/msp1datas/msp1-data.php` | **301** → `/meteo` | ✅ OK | Puis **500 Error** ❌ |
| N3PP legacy | `/n3pp/n3ppdatas/n3pp-data.php` | **301** → `/serre` | ✅ OK | Puis **500 Error** ❌ |

**Conclusion**: Les redirections 301 fonctionnent, mais les pages de destination échouent.

## Messages d'erreur

Toutes les pages affichent le message générique du serveur :

```
Une erreur serveur est survenue. Veuillez réessayer ultérieurement.

Référence : <hash unique>
```

Exemples de références d'erreur :
- `/meteo` : `e3adb1a51025`
- `/serre` : `936402ec644e`
- `/meteo-control` : `9266c63795c2`
- `/serre-control` : `2b068ccb3d80`

## Diagnostic des causes possibles

### 1. Cache DI compilé corrompu (TRÈS PROBABLE)

Le container de dépendances PHP-DI est compilé en production (`serveur/var/cache/di/`). Si ce cache est obsolète ou corrompu après un déploiement, toutes les pages échouent.

**Solution** : Vider le cache DI compilé sur le serveur de production.

```bash
# Sur le serveur de production
rm -rf /home/olution/www/iot.olution.info/serveur/var/cache/di/*
```

### 2. Erreur de connexion à la base de données

Les controllers MSP et N3PP dépendent de la connexion PDO. Si le fichier `.env` est manquant ou mal configuré, la connexion échoue.

**Vérifications** :
- Le fichier `.env` existe-t-il sur le serveur ?
- Les credentials de base de données sont-ils corrects ?
- La base de données est-elle accessible ?

### 3. Fichier `.env` manquant ou mal configuré

Le serveur charge les variables d'environnement depuis `.env` (via `App\Config\Env::load()`).

**Vérifications** :
- Le fichier `serveur/.env` existe sur le serveur de production
- Les variables requises sont définies : `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `ENV`, `AUTH_METHOD`

### 4. Problème avec les dépendances PHP (MOINS PROBABLE)

Si les dépendances Composer ne sont pas installées ou sont obsolètes.

**Solution** :
```bash
cd /home/olution/www/iot.olution.info/serveur
composer install --no-dev --optimize-autoloader
```

## Actions recommandées (par ordre de priorité)

### 1. Vider le cache DI (URGENT)

```bash
# Via SSH sur le serveur de production
cd /home/olution/www/iot.olution.info/serveur
rm -rf var/cache/di/*
```

Ou utiliser la page d'administration (si accessible) :
- URL : `https://iot.olution.info/admin/clear-cache-page`

### 2. Vérifier les logs d'erreur PHP

```bash
# Sur le serveur de production
tail -100 /home/olution/www/iot.olution.info/serveur/error_log
```

Ou via cPanel : Fichiers → Gestionnaire de fichiers → `serveur/error_log`

### 3. Vérifier la configuration `.env`

```bash
# Sur le serveur de production
cat /home/olution/www/iot.olution.info/serveur/.env
```

Variables requises :
```env
ENV=prod
DB_HOST=localhost
DB_NAME=olution_iot
DB_USER=olution_iot_user
DB_PASSWORD=<secret>
AUTH_METHOD=session
```

### 4. Tester la connexion à la base de données

Créer un script de test temporaire `serveur/test-db.php` :

```php
<?php
require __DIR__ . '/vendor/autoload.php';
App\Config\Env::load();

try {
    $pdo = App\Config\Database::getConnection();
    echo "✓ Connexion BDD OK\n";
    $stmt = $pdo->query("SELECT COUNT(*) FROM msp1Data");
    echo "✓ Requête test OK: " . $stmt->fetchColumn() . " lignes\n";
} catch (Exception $e) {
    echo "✗ Erreur: " . $e->getMessage() . "\n";
}
```

Exécuter : `php serveur/test-db.php`

## Impact utilisateur

**Sévérité** : 🔴 **CRITIQUE**

- ❌ Aucune page de données accessible (méteo, serre)
- ❌ Aucune page de contrôle accessible
- ❌ Site IoT complètement hors service
- ✅ Les redirections 301 fonctionnent (SEO préservé)
- ✅ Les firmwares ESP32 peuvent toujours envoyer des données (endpoints API différents)

## Prochaines étapes

1. **Accéder au serveur de production** (SSH ou cPanel)
2. **Vider le cache DI** : `rm -rf serveur/var/cache/di/*`
3. **Consulter les logs d'erreur** : `tail -100 serveur/error_log`
4. **Tester à nouveau** les pages après vidage du cache
5. **Si le problème persiste**, vérifier `.env` et connexion BDD

## Notes techniques

### Routes testées

Les routes suivantes sont définies dans `serveur/public/index.php` :

```php
// Ligne 846-847 : Nouvelles routes unifiées
$app->map(['GET', 'POST'], '/meteo', [MspDataController::class, 'show']);
$app->get('/meteo-control', [MspOutputController::class, 'showControlPage']);

// Ligne 882-883
$app->map(['GET', 'POST'], '/serre', [N3ppDataController::class, 'show']);
$app->get('/serre-control', [N3ppOutputController::class, 'showControlPage']);

// Ligne 853-856 : Redirections 301
$app->map(['GET', 'POST'], '/msp1/msp1datas/msp1-data.php', function (...) {
    return $response->withHeader('Location', $basePath . '/meteo')->withStatus(301);
});
$app->map(['GET', 'POST'], '/n3pp/n3ppdatas/n3pp-data.php', function (...) {
    return $response->withHeader('Location', $basePath . '/serre')->withStatus(301);
});
```

### Dépendances des controllers

Les controllers MSP et N3PP dépendent de :
- `TemplateRenderer` (templates Twig)
- `MspSensorRepository` / `N3ppSensorRepository` (accès BDD)
- `CsrfService` (protection CSRF)
- `DateRangeExtractor` (extraction plages de dates)
- `CsvExportService` (export CSV)
- `ChartDataService` (données graphiques)

Tous ces services dépendent de la connexion PDO, qui dépend de `Database::getConnection()`, qui dépend du fichier `.env`.

### Middleware d'authentification

Les pages de contrôle (`/meteo-control`, `/serre-control`) sont protégées par le middleware d'authentification (lignes 232-261 de `index.php`).

Si l'erreur 500 survient **avant** le middleware d'authentification, c'est un problème de container DI ou de connexion BDD.

## Conclusion

Le problème est **critique** et nécessite une intervention immédiate sur le serveur de production.

La cause la plus probable est un **cache DI corrompu** après le dernier déploiement.

**Action immédiate recommandée** : Vider le cache DI sur le serveur de production.
