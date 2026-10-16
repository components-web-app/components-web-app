<?php

declare(strict_types=1);

namespace App\Command;

use League\Flysystem\FilesystemOperator;
use League\Flysystem\StorageAttributes;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

// Run by `delete review` before the uninstall (#166); refuses a prefix not ending in review/<slug>/, so it can't empty a shared path.
#[AsCommand(name: 'app:storage:delete-review-files', description: "Deletes every stored file under this review app's storage path prefix")]
final class DeleteReviewStorageCommand
{
    public function __construct(
        #[Autowire(service: 'api_components.filesystem.gcloud')]
        private readonly FilesystemOperator $filesystem,
        #[Autowire(param: 'app.storage_path_prefix')]
        private readonly string $pathPrefix,
    ) {
    }

    public function __invoke(OutputInterface $output): int
    {
        if (!preg_match('~(^|/)review/[^/]+/$~', $this->pathPrefix)) {
            $output->writeln(sprintf('<error>Refusing: GCLOUD_PATH_PREFIX "%s" is not a single review app\'s prefix (review/<slug>/).</error>', $this->pathPrefix));

            return Command::FAILURE;
        }

        $deleted = 0;
        foreach ($this->filesystem->listContents('', true) as $item) {
            if ($item instanceof StorageAttributes && $item->isFile()) {
                $this->filesystem->delete($item->path());
                ++$deleted;
            }
        }
        $output->writeln(sprintf('Deleted %d file(s) under %s', $deleted, $this->pathPrefix));

        return Command::SUCCESS;
    }
}
