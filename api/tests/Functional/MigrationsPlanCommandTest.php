<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Command\MigrationsPlanCommand;
use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\Console\Tester\CommandTester;

/**
 * The deploy's migrations plan (#180): it lists what is pending with its SQL, on a read-only session, and changes nothing.
 */
final class MigrationsPlanCommandTest extends KernelTestCase
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

    protected function tearDown(): void
    {
        // The plan leaves its session read-only.
        $this->connection->executeStatement('SET SESSION CHARACTERISTICS AS TRANSACTION READ WRITE');
        parent::tearDown();
    }

    public function testAnEmptyDatabaseHasEveryMigrationPendingAndGetsNoTables(): void
    {
        $tester = $this->tester('app:database:migrations-plan');
        self::assertSame(0, $tester->execute([]), $tester->getDisplay());

        self::assertMatchesRegularExpression('/^CWA_MIGRATIONS_PENDING=[1-9]\d*$/m', $tester->getDisplay());
        self::assertMatchesRegularExpression('/^CWA_DATABASE_SERVER_VERSION=\d+/m', $tester->getDisplay());
        self::assertSame('on', $this->connection->fetchOne('SHOW transaction_read_only'));
        self::assertSame(0, (int) $this->connection->fetchOne("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'"));
    }

    public function testShowsThePendingSqlWithoutRunningIt(): void
    {
        $migrate = $this->tester('app:database:migrate');
        self::assertSame(0, $migrate->execute([]), $migrate->getDisplay());
        $latest = (string) $this->connection->fetchOne('SELECT version FROM doctrine_migration_versions ORDER BY version DESC LIMIT 1');
        $this->connection->executeStatement('DELETE FROM doctrine_migration_versions WHERE version = ?', [$latest]);
        $executed = (int) $this->connection->fetchOne('SELECT count(*) FROM doctrine_migration_versions');
        $this->reboot();

        $tester = $this->tester('app:database:migrations-plan');
        self::assertSame(0, $tester->execute([]), $tester->getDisplay());

        self::assertStringContainsString('CWA_MIGRATIONS_PENDING=1', $tester->getDisplay());
        self::assertStringContainsString('-- Version ' . $latest, $tester->getDisplay());
        self::assertSame($executed, (int) $this->connection->fetchOne('SELECT count(*) FROM doctrine_migration_versions'));
    }

    public function testNothingPending(): void
    {
        $migrate = $this->tester('app:database:migrate');
        self::assertSame(0, $migrate->execute([]), $migrate->getDisplay());
        $this->reboot();

        $tester = $this->tester('app:database:migrations-plan');
        self::assertSame(0, $tester->execute([]), $tester->getDisplay());
        self::assertStringContainsString('CWA_MIGRATIONS_PENDING=0', $tester->getDisplay());
        self::assertStringNotContainsString('The SQL the pending migrations will run', $tester->getDisplay());
    }

    // A migration writing from up() hits this on the plan's session; it makes the plan incomplete, not failed (#183).
    public function testAWriteOnTheReadOnlySessionIsRecognised(): void
    {
        $this->connection->executeStatement('CREATE TABLE plan_probe (id INT)');
        $this->connection->executeStatement('SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY');
        try {
            $this->connection->executeStatement('INSERT INTO plan_probe VALUES (1)');
            self::fail('The read-only session accepted a write.');
        } catch (\Doctrine\DBAL\Exception $e) {
            self::assertTrue(MigrationsPlanCommand::isReadOnlyViolation($e));
            self::assertTrue(MigrationsPlanCommand::isReadOnlyViolation(new \RuntimeException('Migration failed', 0, $e)));
        }

        try {
            $this->connection->executeStatement('SELECT * FROM no_such_table');
            self::fail('The query should fail.');
        } catch (\Doctrine\DBAL\Exception $e) {
            self::assertFalse(MigrationsPlanCommand::isReadOnlyViolation($e), 'Any other error still fails the plan');
        }
    }

    // A deploy plans in a new process: migrations this process ran are frozen.
    private function reboot(): void
    {
        self::ensureKernelShutdown();
        self::bootKernel();
        $connection = self::getContainer()->get(Connection::class);
        \assert($connection instanceof Connection);
        $this->connection = $connection;
    }

    private function tester(string $command): CommandTester
    {
        return new CommandTester(new Application(self::$kernel)->find($command));
    }
}
