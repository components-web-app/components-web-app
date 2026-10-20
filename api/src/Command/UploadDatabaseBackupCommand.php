<?php

declare(strict_types=1);

namespace App\Command;

use App\Database\BackupObjects;
use App\Database\PublicObjectProbe;
use Google\Auth\Credentials\InsecureCredentials;
use Google\Cloud\Storage\Bucket;
use Google\Cloud\Storage\StorageClient;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Uploads a database dump to a private Cloud Storage bucket and keeps the newest few (#180). The deploy's backup Job
 * runs it after pg_dump. A backup anyone can read is deleted again and the command fails.
 *
 * Prints CWA_DATABASE_BACKUP=gs://<bucket>/<object> for bin/devops/k8s.sh.
 */
#[AsCommand(name: 'app:database:backup-upload', description: 'Uploads a database dump to a private bucket and keeps the newest few')]
final class UploadDatabaseBackupCommand extends Command
{
    /**
     * @param array<string, mixed> $keyFile
     */
    public function __construct(
        private readonly PublicObjectProbe $probe,
        #[Autowire(env: 'json:GCLOUD_JSON')]
        private readonly array $keyFile,
        #[Autowire(env: 'GCLOUD_API_ENDPOINT')]
        private readonly string $apiEndpoint = '',
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this
            ->addArgument('file', InputArgument::REQUIRED, 'The dump to upload')
            ->addOption('bucket', null, InputOption::VALUE_REQUIRED, 'The private bucket for backups')
            ->addOption('directory', null, InputOption::VALUE_REQUIRED, 'The path in the bucket', '')
            ->addOption('label', null, InputOption::VALUE_REQUIRED, 'Added to the name, e.g. the commit', 'backup')
            ->addOption('keep', null, InputOption::VALUE_REQUIRED, 'How many backups to keep in the directory', '5');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $file = (string) $input->getArgument('file');
        $bucketName = trim((string) $input->getOption('bucket'));
        $keep = (int) $input->getOption('keep');
        if ('' === $bucketName) {
            $output->writeln('<error>No backup bucket (--bucket).</error>');

            return Command::INVALID;
        }
        if ($keep < 1) {
            $output->writeln('<error>--keep must be at least 1.</error>');

            return Command::INVALID;
        }
        $size = is_file($file) ? filesize($file) : false;
        if (!$size) {
            $output->writeln(\sprintf('<error>The dump %s is missing or empty.</error>', $file));

            return Command::FAILURE;
        }

        $directory = BackupObjects::directory((string) $input->getOption('directory'));
        $name = BackupObjects::name($directory, new \DateTimeImmutable(), (string) $input->getOption('label'));
        $bucket = $this->bucket($bucketName);

        $handle = fopen($file, 'r');
        if (false === $handle) {
            throw new \RuntimeException(\sprintf('Could not read %s.', $file));
        }
        $object = $bucket->upload($handle, ['name' => $name, 'metadata' => ['contentType' => 'application/octet-stream']]);
        $stored = (int) ($object->info()['size'] ?? 0);
        if ($stored !== $size) {
            $output->writeln(\sprintf('<error>gs://%s/%s holds %d bytes, not the dump\'s %d.</error>', $bucketName, $name, $stored, $size));

            return Command::FAILURE;
        }

        // An emulator has no credentials to refuse (#157).
        if ('' === $this->apiEndpoint) {
            $public = $this->probe->isPublic($bucketName, $name);
            if (true === $public) {
                $object->delete();
                $output->writeln(\sprintf('<error>Anyone can read objects in the bucket %s, so the backup was deleted again. Use a private bucket (no allUsers or allAuthenticatedUsers access).</error>', $bucketName));

                return Command::FAILURE;
            }
            if (null === $public) {
                $output->writeln(\sprintf('<comment>Could not check that gs://%s/%s is private: check the bucket allows no public access.</comment>', $bucketName, $name));
            }
        }
        $output->writeln(\sprintf('Uploaded the database backup (%d bytes).', $size));

        $names = [];
        foreach ($bucket->objects(['prefix' => $directory, 'fields' => 'items/name,nextPageToken']) as $listed) {
            $names[] = $listed->name();
        }
        foreach (BackupObjects::expired($names, $directory, $keep) as $old) {
            try {
                $bucket->object($old)->delete();
                $output->writeln(\sprintf('Deleted the older backup gs://%s/%s', $bucketName, $old));
            } catch (\Throwable $e) {
                $output->writeln(\sprintf('<comment>Could not delete the older backup gs://%s/%s: %s</comment>', $bucketName, $old, $e->getMessage()));
            }
        }

        $output->writeln(\sprintf('CWA_DATABASE_BACKUP=gs://%s/%s', $bucketName, $name));

        return Command::SUCCESS;
    }

    private function bucket(string $name): Bucket
    {
        $options = ['projectId' => $this->keyFile['project_id'] ?? null, 'keyFile' => $this->keyFile];
        if ('' !== $this->apiEndpoint) {
            $options = ['projectId' => 'test', 'apiEndpoint' => $this->apiEndpoint, 'credentialsFetcher' => new InsecureCredentials()];
        }

        return new StorageClient($options)->bucket($name);
    }
}
