<?php

declare(strict_types=1);

namespace App\Command;

use App\Entity\RedisWatchState;
use App\RedisWatch\CloudflareEdgeCache;
use App\RedisWatch\HttpPhpView;
use App\RedisWatch\MailNotifier;
use App\RedisWatch\RedisWatcher;
use App\RedisWatch\RespCacheStore;
use Doctrine\DBAL\Exception\TableNotFoundException;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Scaled mode's Redis watch (#85), run by a CronJob: notices when php couldn't reach Redis, flushes the cache once it
 * can again, and emails MAILER_EMAIL. See App\RedisWatch\RedisWatcher.
 */
#[AsCommand(name: 'app:redis-watch', description: 'Flushes the cache and emails once Redis is reachable again after an outage')]
final class RedisWatchCommand extends Command
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly HttpClientInterface $httpClient,
        private readonly MailNotifier $notifier,
        #[Autowire(env: 'string:default::CADDY_CACHE_STORAGE')]
        private readonly string $cacheStorage,
        #[Autowire(env: 'string:default::CADDY_CACHE_CDN_CONFIG')]
        private readonly string $cdnConfig,
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this
            ->addOption('redis', null, InputOption::VALUE_REQUIRED, 'Redis host:port, instead of the address in CADDY_CACHE_STORAGE')
            ->addOption('api-url', null, InputOption::VALUE_REQUIRED, 'The API service, e.g. http://<release>-cwa, to see whether php reaches Redis')
            ->addOption('attempts', null, InputOption::VALUE_REQUIRED, 'Checks that must all fail before Redis counts as unreachable', '3')
            ->addOption('timeout', null, InputOption::VALUE_REQUIRED, 'Seconds to wait for Redis', '2');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $timeout = (float) $input->getOption('timeout');
        $apiUrl = trim((string) $input->getOption('api-url'));
        // The store block php's Souin uses, so the job checks the same Redis with the same password.
        $store = RespCacheStore::fromSouinStorage($this->cacheStorage, $timeout);
        $redis = trim((string) $input->getOption('redis'));
        if ('' !== $redis) {
            $store = new RespCacheStore($redis, $store?->password() ?? '', $timeout);
        }
        if (null === $store || '' === $apiUrl) {
            $output->writeln('<error>Needs --api-url, and a Redis store block in CADDY_CACHE_STORAGE (scaled mode) or --redis.</error>');

            return Command::INVALID;
        }

        try {
            $state = $this->entityManager->find(RedisWatchState::class, RedisWatchState::ID);
        } catch (TableNotFoundException) {
            // A new release's CronJob can start before its API pods have migrated.
            $output->writeln('The database is not migrated yet; checking next run.');

            return Command::SUCCESS;
        }
        if (null === $state) {
            $state = new RedisWatchState();
            $this->entityManager->persist($state);
        }

        $watcher = new RedisWatcher(
            $store,
            new HttpPhpView($this->httpClient, $apiUrl),
            $this->notifier,
            CloudflareEdgeCache::fromCdnConfig($this->cdnConfig, $this->httpClient),
            (int) $input->getOption('attempts'),
        );
        $outcome = $watcher->run($state, new \DateTimeImmutable());
        $this->entityManager->flush();

        foreach ($outcome->lines as $line) {
            $output->writeln($outcome->failed ? '<error>'.$line.'</error>' : $line);
        }

        return $outcome->failed ? Command::FAILURE : Command::SUCCESS;
    }
}
