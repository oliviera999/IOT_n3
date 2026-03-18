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

Les tests nécessitant une base de données MySQL sont automatiquement skippés en environnement local sans DB.

### Lint

Pas d'outil de lint configuré dans le projet. Utiliser `php -l` pour la vérification syntaxique :

```bash
find serveur/src/ -name "*.php" -exec php -l {} \;
```

### Configuration (.env)

Copier `serveur/.env.example` vers `serveur/.env`. Pour le dev local sans base de données, les valeurs par défaut suffisent. Passer `AUTH_METHOD=none` pour désactiver l'authentification en local.

### Submodules

L'initialisation récursive (`git submodule update --init --recursive`) peut échouer à cause d'un ancien chemin dans `serveur/site initial/`. Les submodules principaux (`serveur/` et `firmwires/`) sont déjà checkoutés correctement — ignorer cette erreur.

### Routes utiles en dev local (http://127.0.0.1:8082)

Voir `serveur/README.md` pour la liste complète. Routes principales : `/`, `/aquaponie`, `/meteo`, `/serre`, `/ping`.
