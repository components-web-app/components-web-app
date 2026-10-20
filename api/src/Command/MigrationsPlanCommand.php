<?php

declare(strict_types=1);

namespace App\Command;

use Doctrine\DBAL\Connection;
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
 * or postUp() fails here instead of running.
 *
 * The last lines are for bin/devops/k8s.sh: CWA_DATABASE_SERVER_VERSION=<version> and CWA_MIGRATIONS_PENDING=<count>.
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
                    $status = $this->runCommand('doctrine:migrations:migrate', ['--dry-run' => true, '--write-sql' => $file, '--all-or-nothing' => true], $output);
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
