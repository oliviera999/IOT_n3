# Résumé : Test des pages IoT - Erreurs 500 critiques

**Date** : 2026-03-09  
**Statut** : 🔴 **CRITIQUE - Site hors service**

## Résultat des tests

### ❌ Toutes les pages retournent des erreurs 500

| Page | URL | Statut | Résultat |
|------|-----|--------|----------|
| Méteo | `/meteo` | **500** | ❌ |
| Méteo Control | `/meteo-control` | **500** | ❌ |
| Serre | `/serre` | **500** | ❌ |
| Serre Control | `/serre-control` | **500** | ❌ |

### ✅ Les redirections 301 fonctionnent

| Ancienne URL | Nouvelle URL | Statut | Résultat |
|--------------|--------------|--------|----------|
| `/msp1/msp1datas/msp1-data.php` | `/meteo` | **301** | ✅ (puis 500) |
| `/n3pp/n3ppdatas/n3pp-data.php` | `/serre` | **301** | ✅ (puis 500) |

## Cause probable

**Cache DI compilé corrompu** après le dernier déploiement.

Le container de dépendances PHP-DI est compilé en production. Si ce cache est obsolète, toutes les pages échouent.

## Solution rapide

### Option 1 : Via l'interface admin (si accessible)

Ouvrir dans un navigateur (nécessite authentification) :
```
https://iot.olution.info/admin/clear-cache-page
```

### Option 2 : Via SSH

```bash
ssh user@iot.olution.info
cd /home/olution/www/iot.olution.info/serveur
rm -rf var/cache/di/*
```

### Option 3 : Via cPanel

1. Fichiers → Gestionnaire de fichiers
2. Naviguer vers `serveur/var/cache/di/`
3. Sélectionner tous les fichiers
4. Supprimer

### Option 4 : Via script PowerShell (depuis ce workspace)

```powershell
.\scripts\fix-production-500-errors.ps1
```

## Vérifications supplémentaires

Si le vidage du cache ne résout pas le problème :

### 1. Consulter les logs d'erreur

```bash
tail -100 /home/olution/www/iot.olution.info/serveur/error_log
```

### 2. Vérifier le fichier .env

```bash
cat /home/olution/www/iot.olution.info/serveur/.env
```

Variables requises :
- `ENV=prod`
- `DB_HOST=localhost`
- `DB_NAME=olution_iot`
- `DB_USER=...`
- `DB_PASSWORD=...`
- `AUTH_METHOD=session`

### 3. Tester la connexion à la base de données

Créer `serveur/test-db.php` :

```php
<?php
require __DIR__ . '/vendor/autoload.php';
App\Config\Env::load();

try {
    $pdo = App\Config\Database::getConnection();
    echo "✓ Connexion BDD OK\n";
} catch (Exception $e) {
    echo "✗ Erreur: " . $e->getMessage() . "\n";
}
```

Exécuter : `php serveur/test-db.php`

## Impact

- ❌ Site IoT complètement hors service pour les utilisateurs
- ❌ Aucune page de données accessible
- ❌ Aucune page de contrôle accessible
- ✅ Les firmwares ESP32 peuvent toujours envoyer des données (endpoints API différents)
- ✅ Les redirections 301 fonctionnent (SEO préservé)

## Documentation complète

Voir le rapport détaillé : `docs/rapport_test_pages_2026-03-09_erreurs_500.md`
