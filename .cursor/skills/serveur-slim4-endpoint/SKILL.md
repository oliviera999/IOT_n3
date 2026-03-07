---
name: serveur-slim4-endpoint
description: Creer ou modifier des endpoints dans le serveur PHP Slim 4 unifie (msp1, n3pp, galeries, ffp3). Utiliser quand l'utilisateur veut ajouter une route, creer un Controller, modifier un endpoint API, ou travailler sur le backend PHP du projet IoT.
---

# Serveur Slim 4 — Endpoints

## Architecture

Le serveur est une application **Slim 4 unifiee** dans `serveur/`.
Exception : `serveur/ffp3/` est un sous-module autonome (sa propre app Slim 4).

### Serveur principal (serveur/)

```
serveur/
├── public/index.php          # Front controller
├── config/dependencies.php   # DI container (PHP-DI)
├── src/
│   ├── Controller/
│   │   ├── Msp/              # Endpoints station meteo
│   │   ├── N3pp/             # Endpoints serre/phasmes
│   │   └── Gallery/          # Upload de photos
│   ├── Domain/               # DTO (MspSensorData, N3ppSensorData)
│   ├── Repository/           # Acces BDD (PDO prepared statements)
│   └── Service/              # Services metier
├── templates/                # Vues Twig
└── tests/                    # PHPUnit
```

### FFP3 (serveur/ffp3/)

App autonome avec sa propre structure. Voir `serveur/ffp3/README.md`.

## Creer un nouvel endpoint

### 1. Creer le Controller

Namespace : `App\Controller\<Module>\` (ex. `App\Controller\Msp\`).

```php
<?php
declare(strict_types=1);

namespace App\Controller\Msp;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class MonNouveauController
{
    public function __construct(
        private readonly MonRepository $repository
    ) {}

    public function __invoke(Request $request, Response $response): Response
    {
        // Valider les entrees
        $data = $request->getParsedBody();

        // Traiter
        $result = $this->repository->getData();

        // Repondre
        $response->getBody()->write(json_encode($result));
        return $response->withHeader('Content-Type', 'application/json');
    }
}
```

### 2. Creer le Repository (si acces BDD)

```php
<?php
declare(strict_types=1);

namespace App\Repository;

use PDO;

class MonRepository
{
    public function __construct(private readonly PDO $pdo) {}

    public function getData(): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM ma_table WHERE id = ?');
        $stmt->execute([$id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
```

Regles strictes :
- **Prepared statements** uniquement (jamais de concatenation SQL)
- Utiliser le service PDO du container (pas de connexion manuelle)
- Type hinting strict partout

### 3. Enregistrer la route

Dans le fichier de routes (ou `public/index.php` selon la structure) :

```php
$app->post('/mon-endpoint', MonNouveauController::class);
$app->get('/mon-endpoint', MonNouveauController::class . ':list');
```

### 4. Enregistrer dans le container DI

Dans `config/dependencies.php` :

```php
MonRepository::class => function (ContainerInterface $c) {
    return new MonRepository($c->get(PDO::class));
},
MonNouveauController::class => function (ContainerInterface $c) {
    return new MonNouveauController($c->get(MonRepository::class));
},
```

### 5. Valider les entrees

Pour un endpoint POST recevant des donnees de firmware :
- Verifier la presence et le type de chaque champ
- Valider la cle API ou signature HMAC
- Retourner 400 (bad request) si invalide, 401 si non authentifie
- Logger les requetes suspectes via Monolog

## Tester

```bash
# Tests unitaires
cd serveur && php vendor/bin/phpunit

# Serveur local
php -S localhost:8080 -t public

# Test manuel
curl -X POST http://localhost:8080/mon-endpoint \
  -H "Content-Type: application/json" \
  -d '{"api_key":"test","field1":"value1"}'
```

## Checklist nouvel endpoint

- [ ] Controller cree dans le bon namespace
- [ ] Repository avec prepared statements
- [ ] Route enregistree
- [ ] DI container configure
- [ ] Validation des entrees (types, bornes, auth)
- [ ] Codes HTTP corrects (200, 400, 401, 500)
- [ ] Tests PHPUnit ecrits
- [ ] Contrat documente (si le firmware doit appeler cet endpoint)
