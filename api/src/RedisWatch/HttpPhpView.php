<?php

declare(strict_types=1);

namespace App\RedisWatch;

use Symfony\Contracts\HttpClient\Exception\ExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Requests a cheap cacheable API path through the API service and reads its Cache-Status.
 */
final class HttpPhpView implements PhpView
{
    public const string PATH = '/_api/_/site_config_parameters.jsonld';

    public function __construct(
        private readonly HttpClientInterface $client,
        private readonly string $baseUrl,
        private readonly float $timeout = 10.0,
    ) {
    }

    public function check(): PhpViewResult
    {
        try {
            $response = $this->client->request('GET', rtrim($this->baseUrl, '/').self::PATH, [
                'headers' => ['Accept' => 'application/ld+json', 'User-Agent' => 'cwa-redis-watch'],
                'timeout' => $this->timeout,
                'max_redirects' => 0,
            ]);
            $status = $response->getStatusCode();
            $cacheStatus = $response->getHeaders(false)['cache-status'][0] ?? '';
        } catch (ExceptionInterface $e) {
            return PhpViewResult::unknown('the API did not answer: '.$e->getMessage());
        }
        if (200 !== $status) {
            return PhpViewResult::unknown(\sprintf('the API answered %d', $status));
        }

        return PhpViewResult::fromCacheStatus($cacheStatus);
    }
}
