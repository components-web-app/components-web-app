<?php

declare(strict_types=1);

namespace App\Command;

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\DriverManager;
use Doctrine\DBAL\Platforms\PostgreSQLPlatform;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

/**
 * Runs the migrations and ANALYZE once at a time across every process that starts against the database
 * (API pods, CronJob pods, a deploy's Job), holding a Postgres advisory lock (#85). The entrypoint calls it.
 *
 * The lock is held on its own connection, so a reconnect inside the migrations can't drop it. A process that
 * waited finds nothing left to migrate.
 */
#[AsCommand(name: 'app:database:migrate', description: 'Runs the migrations and ANALYZE, one process at a time')]
final class MigrateDatabaseCommand extends Command
{
    public const string LOCK_NAME = 'cwa-database-migrate';

    public function __construct(private readonly Connection $connection)
    {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption('lock-timeout', null, InputOption::VALUE_REQUIRED, 'Seconds to wait for another process to finish', '600');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $timeout = (int) $input->getOption('lock-timeout');
        $lock = null;
        if ($this->connection->getDatabasePlatform() instanceof PostgreSQLPlatform) {
            $lock = DriverManager::getConnection($this->connection->getParams());
            if (!$this->acquire($lock, $timeout, $output)) {
                $output->writeln(\sprintf('<error>Another process held the migration lock for over %d seconds.</error>', $timeout));
                $lock->close();

                return Command::FAILURE;
            }
        }

        try {
            $migrate = $this->getApplication()?->find('doctrine:migrations:migrate');
            if (null === $migrate) {
                throw new \LogicException('doctrine:migrations:migrate is not registered.');
            }
            $arguments = new ArrayInput(['--allow-no-migration' => true, '--all-or-nothing' => true]);
            $arguments->setInteractive(false);
            $status = $migrate->run($arguments, $output);
            if (Command::SUCCESS !== $status) {
                return $status;
            }

            if ($lock) {
                // Small component tables never reach autoanalyze's threshold; without statistics the planner misjudges
                // the JOINED-inheritance hydration join by orders of magnitude (CLAUDE.md, Postgres with no statistics).
                $output->writeln('Updating database statistics...');
                try {
                    $this->connection->executeStatement('ANALYZE');
                } catch (\Throwable $e) {
                    $output->writeln(\sprintf('<comment>ANALYZE failed (non-fatal); queries may be slow until it runs: %s</comment>', $e->getMessage()));
                }
            }

            return Command::SUCCESS;
        } finally {
            if ($lock) {
                $lock->executeQuery('SELECT pg_advisory_unlock(hashtext(?))', [self::LOCK_NAME]);
                $lock->close();
            }
        }
    }

    private function acquire(Connection $lock, int $timeout, OutputInterface $output): bool
    {
        $deadline = time() + max(0, $timeout);
        $announced = false;
        while (true) {
            if (\in_array($lock->fetchOne('SELECT pg_try_advisory_lock(hashtext(?))', [self::LOCK_NAME]), [true, 't', 1], true)) {
                return true;
            }
            if (time() >= $deadline) {
                return false;
            }
            if (!$announced) {
                $output->writeln('Another process is migrating; waiting for it to finish...');
                $announced = true;
            }
            sleep(1);
        }
    }
}
