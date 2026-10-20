<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Command\MigrateDatabaseCommand;
use Doctrine\DBAL\Connection;
use Doctrine\DBAL\DriverManager;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\Console\Tester\CommandTester;

/**
 * The entrypoint's migrate step (#85): the real migrations from an empty database, a second run with nothing to do,
 * and a run that waits out another process's lock.
 */
final class MigrateDatabaseCommandTest extends KernelTestCase
{
    private Connection $connection;

    protected function setUp(): void
    {
        self::bootKernel();
        $connection = self::getContainer()->get(Connection::class);
        \assert($connection instanceof Connection);
        $database = $connection->getParams()['dbname'] ?? null;
        if (!\is_string($database) || !str_contains($database, 'test')) {
            throw new \RuntimeException(\sprintf('This test empties the database. Refusing to run against "%s": point DATABASE_URL at a database whose name contains "test".', $database));
        }
        $this->connection = $connection;
        $this->connection->executeStatement('DROP SCHEMA public CASCADE');
        $this->connection->executeStatement('CREATE SCHEMA public');
    }

    public function testMigratesAnEmptyDatabaseThenHasNothingToDo(): void
    {
        $first = $this->tester();
        self::assertSame(0, $first->execute([]), $first->getDisplay());
        self::assertStringContainsString('Updating database statistics', $first->getDisplay());
        self::assertGreaterThan(0, (int) $this->connection->fetchOne('SELECT count(*) FROM doctrine_migration_versions'));

        $second = $this->tester();
        self::assertSame(0, $second->execute([]), $second->getDisplay());
    }

    public function testFailsWhenAnotherProcessHoldsTheLock(): void
    {
        $other = DriverManager::getConnection($this->connection->getParams());
        self::assertTrue((bool) $other->fetchOne('SELECT pg_try_advisory_lock(hashtext(?))', [MigrateDatabaseCommand::LOCK_NAME]));
        try {
            $tester = $this->tester();
            self::assertSame(1, $tester->execute(['--lock-timeout' => '1']));
            self::assertStringContainsString('held the migration lock', $tester->getDisplay());
            self::assertSame(0, (int) $this->connection->fetchOne("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'"));
        } finally {
            $other->close();
        }

        $tester = $this->tester();
        self::assertSame(0, $tester->execute(['--lock-timeout' => '5']), $tester->getDisplay());
    }

    private function tester(): CommandTester
    {
        $application = new Application(self::$kernel);

        return new CommandTester($application->find('app:database:migrate'));
    }
}
