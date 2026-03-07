---
name: tests-phpunit-serveur
description: Ecrire et executer les tests PHPUnit du serveur PHP IoT n3. Utiliser quand l'utilisateur veut lancer les tests, ecrire un nouveau test, debugger un test en echec, ou ameliorer la couverture de tests du serveur.
---

# Tests PHPUnit — Serveur IoT

## Lancer les tests

```bash
cd serveur
php vendor/bin/phpunit
# ou via le script wrapper
php tools/run-phpunit.php
```

## Structure des tests

```
serveur/tests/
├── Middleware/
│   └── EnvironmentMiddlewareTest.php
├── Repository/
│   └── SensorReadRepositoryTest.php
├── Security/
│   ├── CsrfServiceTest.php
│   └── SignatureValidatorTest.php
└── Service/
    ├── ChartDataServiceTest.php
    ├── LogServiceTest.php
    ├── OutputCacheServiceTest.php
    ├── PumpServiceTest.php
    ├── SensorDataServiceTest.php
    ├── SensorStatisticsServiceTest.php
    ├── StatisticsAggregatorServiceTest.php
    └── SystemHealthServiceTest.php
```

Namespace : `Tests\` (PSR-4, defini dans `composer.json` → `autoload-dev`).

## Ecrire un nouveau test

### Convention de nommage

- Fichier : `<Classe>Test.php` dans le sous-dossier correspondant
- Classe : `class MonServiceTest extends TestCase`
- Methodes : `testNomDuComportement()`

### Template minimal

```php
<?php
declare(strict_types=1);

namespace Tests\Service;

use PHPUnit\Framework\TestCase;
use App\Service\MonService;

class MonServiceTest extends TestCase
{
    private MonService $service;

    protected function setUp(): void
    {
        // Mock des dependances si necessaire
        $this->service = new MonService(/* ... */);
    }

    public function testComportementNominal(): void
    {
        $result = $this->service->doSomething('input');
        $this->assertSame('expected', $result);
    }

    public function testCasErreur(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->service->doSomething('invalid');
    }
}
```

### Mocker PDO pour les repositories

Les repositories dependent de PDO. Utiliser des mocks :

```php
$pdo = $this->createMock(\PDO::class);
$stmt = $this->createMock(\PDOStatement::class);

$pdo->method('prepare')->willReturn($stmt);
$stmt->method('execute')->willReturn(true);
$stmt->method('fetchAll')->willReturn([/* donnees de test */]);

$repository = new MonRepository($pdo);
```

## Zones a tester en priorite

| Zone | Couverture actuelle | Priorite |
|------|-------------------|----------|
| Services | Bonne (8 tests) | Maintenir |
| Security | Correcte (CSRF, signature) | Ajouter auth |
| Repositories | Faible (1 test) | Augmenter |
| Controllers | Aucun test | Haute — ajouter les cas critiques |
| Middleware | 1 test (environment) | Ajouter auth middleware |

### Tests controllers — approche recommandee

Tester les controllers en integrant Slim 4 et en envoyant des requetes simulees :

```php
use Slim\Psr7\Factory\ServerRequestFactory;

$request = (new ServerRequestFactory())
    ->createServerRequest('POST', '/post-data')
    ->withParsedBody(['api_key' => 'test', 'temperature' => '22.5']);

$response = $controller($request, new \Slim\Psr7\Response());
$this->assertSame(200, $response->getStatusCode());
```

## Scripts de diagnostic complementaires

En plus de PHPUnit, le dossier `serveur/tools/` contient des scripts utiles :

- `verify_environments.php` — verifie coherence des environnements
- `check_env.php` — verifie les variables d'environnement
- `check_tables_server.php` — verifie les tables BDD
- `diagnostic_esp32.php` — diagnostic de connectivite firmware
- `diagnostic_500_errors.php` — analyse des erreurs HTTP 500

Ces scripts ne sont pas des tests unitaires mais des outils de diagnostic a lancer manuellement.
