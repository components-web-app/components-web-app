<?php

declare(strict_types=1);

namespace App\Command;

use App\RedisWatch\CloudflareEdgeCache;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Purges everything at the CDN in CADDY_CACHE_CDN_CONFIG without touching Souin, for a deploy whose new pod's cache is already current (#218).
 */
#[AsCommand(name: 'app:edge-cache:purge-everything', description: 'Purges everything at the configured CDN (Cloudflare), leaving the local HTTP cache alone')]
final class PurgeEdgeCacheCommand extends Command
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        #[Autowire(env: 'string:default::CADDY_CACHE_CDN_CONFIG')]
        private readonly string $cdnConfig,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $edge = CloudflareEdgeCache::fromCdnConfig($this->cdnConfig, $this->httpClient);
        if (null === $edge) {
            $output->writeln('<error>CADDY_CACHE_CDN_CONFIG has no Cloudflare zone (provider cloudflare, zone_id, api_key): nothing purged.</error>');

            return Command::FAILURE;
        }
        try {
            $edge->purgeEverything();
        } catch (\RuntimeException $e) {
            $output->writeln(\sprintf('<error>Purging %s failed: %s</error>', $edge->name(), $e->getMessage()));

            return Command::FAILURE;
        }
        $output->writeln(\sprintf('Purged everything in %s.', $edge->name()));

        return Command::SUCCESS;
    }
}
