<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use ApiPlatform\Test\ApiTestCase;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Tools\SchemaTool;

/**
 * Base class for HTTP tests against the API (API Platform's own test client).
 *
 * Every test starts with an empty schema built from the entity mapping, so it needs
 * a throwaway database: never run these against the dev database. CI runs them in
 * the `functional tests` job, with its own Postgres service.
 */
abstract class FunctionalTestCase extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        self::bootKernel();

        $manager = self::getContainer()->get('doctrine')->getManager();
        \assert($manager instanceof EntityManagerInterface);
        $connection = $manager->getConnection();
        // From the configuration, before connecting, so a wrong DATABASE_URL is refused, not opened.
        $database = $connection->getParams()['dbname'] ?? null;
        if (!\is_string($database) || !str_contains($database, 'test')) {
            throw new \RuntimeException(\sprintf('Functional tests drop the schema. Refusing to run against "%s": point DATABASE_URL at a database whose name contains "test".', $database));
        }

        $connection->executeStatement('CREATE EXTENSION IF NOT EXISTS citext');
        $schemaTool = new SchemaTool($manager);
        $metadata = $manager->getMetadataFactory()->getAllMetadata();
        $schemaTool->dropSchema($metadata);
        $schemaTool->createSchema($metadata);
        $manager->clear();
    }
}
