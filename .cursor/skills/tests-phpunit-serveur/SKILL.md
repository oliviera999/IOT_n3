---
name: tests-phpunit-serveur
description: Ecrire et executer les tests PHPUnit du serveur PHP IoT n3. Utiliser quand l'utilisateur veut lancer les tests, ecrire un nouveau test, debugger un test en echec, ou ameliorer la couverture de tests du serveur.
---

# Tests PHPUnit — Serveur IoT

## Lancer les tests

```bash
cd serveur
# Option recommandee (stack Docker locale)
powershell -ExecutionPolicy Bypass -File .\tools\local-docker.ps1 -Action up
powershell -ExecutionPolicy Bypass -File .\tools\local-docker.ps1 -Action smoke   # optionnel, HTTP/API
powershell -ExecutionPolicy Bypass -File .\tools\local-docker.ps1 -Action test

# Option hors Docker
php vendor/bin/phpunit
# ou via le script wrapper
php tools/run-phpunit.php

# Suites dédiées (composer.json)
composer test:unit           # exclut tests/Integration
composer test:integration  # uniquement tests/Integration (MySQL / snapshot)
```

`phpunit.xml` définit deux suites **Unit** et **Integration** ; sans `--testsuite`, PHPUnit exécute les deux. Aligné schéma PHPUnit 10.5+ ; en cas de warning de schéma déprécié, exécuter `vendor/bin/phpunit --migrate-configuration`.

## Structure des tests

```
serveur/tests/
├── Integration/
│   ├── IntegrationDbTestCase.php              # PDO, seuil snapshot, isolation ENV prod
│   ├── RealDatasetDockerDbTest.php            # volumétrie / Boards / msp1Data
│   └── SensorRepositoriesSnapshotIntegrationTest.php  # SensorRead, Msp, N3pp, BoardRepository
├── AssetWhitelistCoherenceTest.php      # cohérence whitelist assets
├── RoutesConfigSecurityTest.php         # chemins publics vs routes sensibles
├── TwigPartialsCoherenceTest.php        # partials Twig référencés
├── Controller/
│   ├── AbstractPostDataControllerTest.php
│   └── AuthControllerRedirectTest.php
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

Namespace : `Tests\` (PSR-4, defini dans `composer.json` → `autoload-dev`). Ordre de grandeur **~67 tests Unit** + **~9 tests Integration** (voir sortie PHPUnit).

### Tests d'integration BDD (Docker)

- Etendre `IntegrationDbTestCase` (`#[BackupGlobals(false)]` pour eviter les restaurations PHPUnit de `$_ENV` incoherent avec `TableConfig`) ; `setUp` force `TableConfig` en `prod` puis `tearDown` restaure `$_ENV['ENV']`.
- Sans import volumineux ou sans `DB_*`, les methodes font `markTestSkipped`.
- Pour activer les assertions « snapshot » : `tools/import-mysql-dump-to-local-docker.ps1` (voir `serveur/README.md`), puis `composer test:integration` ou `local-docker.ps1 -Action test`.

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
| Services | Bonne (8 fichiers de test) | Maintenir |
| Security | Correcte (CSRF, signature) | Renforcer si nouveaux flux sensibles |
| Config / cohérence | `RoutesConfigSecurityTest`, `TwigPartialsCoherenceTest`, `AssetWhitelistCoherenceTest` | Maintenir |
| Repositories | Faible (1 fichier) | Augmenter |
| Controllers | Partielle (`AbstractPostDataControllerTest`, `AuthControllerRedirectTest`) | Etendre aux autres contrôleurs / cas critiques |
| Middleware | 1 test (environment) | Ajouter tests middleware auth si evolutions |

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
- `local-smoke-test.ps1` — validation HTTP/API/upload locale (orchestree par `local-docker.ps1 -Action smoke`). Paramètre **`-TimeoutSec`** (defaut **60**) pour les pages lourdes ou machines lentes.
- `import-mysql-dump-to-local-docker.ps1` — import dump phpMyAdmin vers base staging puis synchro mappee vers `iot_n3_local` (donnees reelles pour tests etendus).
- `verify_environments.php` — coherence PROD/TEST/S3 et connexion BDD via **`.env`** (`Database::getConnection()` ; Docker local : `DB_HOST=db`).

Ces scripts ne sont pas des tests unitaires mais des outils de diagnostic a lancer manuellement.
