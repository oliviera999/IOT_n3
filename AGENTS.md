# AGENTS.md

## Cursor Cloud specific instructions

### Architecture

Ce projet IoT est composé de deux submodules Git :
- **`serveur/`** : backend PHP Slim 4 (le service principal à lancer en dev).
- **`firmwires/`** : firmwares ESP32/Arduino (PlatformIO, pas nécessaire pour le dev serveur).

### Lancer le serveur de développement

```bash
cd /workspace/serveur
php -S 127.0.0.1:8082 -t public public/index.php
```

Le serveur intégré PHP active un **mode fallback local** (`PHP_SAPI === 'cli-server'`) : les pages de données (aquaponie, météo, serre) sont rendues avec des séries vides, sans connexion MySQL. Cela permet de tester le routage, les templates Twig, les assets CSS/JS et les formulaires.

### Tests

```bash
cd /workspace/serveur && ./vendor/bin/phpunit
```

Les tests nécessitant une base de données MySQL sont automatiquement skippés en environnement local sans DB. Le `ContainerWiringTest` utilise SQLite en mémoire — l'extension `php8.2-sqlite3` est requise.

### Lint

Pas d'outil de lint configuré dans le projet. Utiliser `php -l` pour la vérification syntaxique :

```bash
find serveur/src/ -name "*.php" -exec php -l {} \;
```

### Configuration (.env)

Copier `serveur/.env.example` vers `serveur/.env`. Pour le dev local sans base de données :
- Passer `AUTH_METHOD=none` pour désactiver l'authentification.
- Passer `ENV=test` pour éviter la compilation du cache DI (qui échoue sans MySQL).
- Supprimer `serveur/var/cache/di/` si le cache existe déjà (`rm -rf serveur/var/cache/di/`).

Le mode `cli-server` utilise automatiquement un fallback SQLite en mémoire quand MySQL est inaccessible.

### Submodules

L'initialisation récursive (`git submodule update --init --recursive`) peut échouer à cause d'un ancien chemin dans `serveur/site initial/`. Les submodules principaux (`serveur/` et `firmwires/`) sont déjà checkoutés correctement — ignorer cette erreur.

### Routes utiles en dev local (http://127.0.0.1:8082)

Voir `serveur/README.md` pour la liste complète. Routes principales : `/`, `/aquaponie`, `/meteo`, `/serre`, `/ping`.
