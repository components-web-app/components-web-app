<?php

declare(strict_types=1);

namespace App\Command;

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\Driver\Exception as DriverException;
use Doctrine\Migrations\DependencyFactory;
use Doctrine\Migrations\Metadata\Storage\TableMetadataStorageConfiguration;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Prints the pending migrations and their SQL without changing the database (#180): the deploy's plan Job runs it
 * with the new image against the track's database. The session is read-only, so a migration that writes from up()
 * or postUp() can't run here: the plan then lists the pending migrations without their SQL and says so (#183).
 *
 * The last lines are for bin/devops/k8s.sh: CWA_DATABASE_SERVER_VERSION=<version>, CWA_MIGRATIONS_PENDING=<count>
 * and, when the SQL couldn't be shown, CWA_MIGRATIONS_PLAN_INCOMPLETE=1.
 */
#[AsCommand(name: 'app:database:migrations-plan', description: 'Shows the pending migrations and their SQL, read-only')]
final class MigrationsPlanCommand extends Command
{
    public function __construct(
        private readonly Connection $connection,
        #[Autowire(service: 'doctrine.migrations.dependency_factory')]
        private readonly DependencyFactory $dependencyFactory,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $this->connection->executeStatement('SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY');
        if (!\in_array($this->connection->fetchOne('SHOW transaction_read_only'), ['on', true, 't'], true)) {
            $output->writeln('<error>Could not make the database session read-only, so no plan was made.</error>');

            return Command::FAILURE;
        }
        $serverVersion = (string) $this->connection->fetchOne('SHOW server_version');

        // Exit 1 means out of date, which is what a plan is for.
        $this->runCommand('doctrine:migrations:up-to-date', ['--list-migrations' => true], $output);
        $pending = $this->dependencyFactory->getMigrationStatusCalculator()->getNewMigrations()->count();

        if ($pending > 0) {
            if ($this->hasMetadataTable()) {
                $file = tempnam(sys_get_temp_dir(), 'migrations-plan');
                if (false === $file) {
                    throw new \RuntimeException('Could not create a temporary file for the SQL.');
                }
                try {
                    try {
                        $status = $this->runCommand('doctrine:migrations:migrate', ['--dry-run' => true, '--write-sql' => $file, '--all-or-nothing' => true], $output);
                    } catch (\Throwable $e) {
                        if (!self::isReadOnlyViolation($e)) {
                            throw $e;
                        }
                        // A migration writing from up() or postUp() can't be planned read-only; the deploy still backs up and migrates (#183).
                        $output->writeln([
                            '',
                            '<comment>A pending migration writes through the connection in up() or postUp(), which a read-only plan cannot run: ' . $e->getMessage() . '</comment>',
                            '<comment>Nothing was changed. The SQL is not shown; read the pending migrations above before deploying.</comment>',
                        ]);
                        $output->writeln(['', 'CWA_DATABASE_SERVER_VERSION=' . $serverVersion, 'CWA_MIGRATIONS_PENDING=' . $pending, 'CWA_MIGRATIONS_PLAN_INCOMPLETE=1']);

                        return Command::SUCCESS;
                    }
                    if (Command::SUCCESS !== $status) {
                        $output->writeln('<error>The dry run failed, so the plan is incomplete.</error>');

                        return Command::FAILURE;
                    }
                    $output->writeln(['', 'The SQL the pending migrations will run:', '']);
                    $output->writeln((string) file_get_contents($file), OutputInterface::OUTPUT_RAW);
                } finally {
                    @unlink($file);
                }
            } else {
                $output->writeln('The database has no migrations table yet (a new or emptied database): every migration is pending, and the SQL is not shown.');
            }
        }

        $output->writeln(['', 'CWA_DATABASE_SERVER_VERSION=' . $serverVersion, 'CWA_MIGRATIONS_PENDING=' . $pending]);

        return Command::SUCCESS;
    }

    /**
     * True when $e, or one it wraps, is PostgreSQL refusing a write in a read-only transaction (SQLSTATE 25006).
     */
    public static function isReadOnlyViolation(\Throwable $e): bool
    {
        for ($current = $e; null !== $current; $current = $current->getPrevious()) {
            if ($current instanceof DriverException && '25006' === $current->getSQLState()) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param array<string, mixed> $arguments
     */
    private function runCommand(string $name, array $arguments, OutputInterface $output): int
    {
        $command = $this->getApplication()?->find($name);
        if (null === $command) {
            throw new \LogicException(\sprintf('%s is not registered.', $name));
        }
        $input = new ArrayInput($arguments);
        $input->setInteractive(false);

        return $command->run($input, $output);
    }

    private function hasMetadataTable(): bool
    {
        $storage = $this->dependencyFactory->getConfiguration()->getMetadataStorageConfiguration();
        $table = $storage instanceof TableMetadataStorageConfiguration ? $storage->getTableName() : 'doctrine_migration_versions';

        return $this->connection->createSchemaManager()->tablesExist([$table]);
    }
}
