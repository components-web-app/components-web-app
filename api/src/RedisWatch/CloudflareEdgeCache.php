<?php

declare(strict_types=1);

namespace App\RedisWatch;

use Symfony\Contracts\HttpClient\Exception\ExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Purges a Cloudflare zone with the credentials in CADDY_CACHE_CDN_CONFIG, as the patched Souin's flush does
 * (v1.7.9-cloudflare-purge.patch): the watch job can't reach Souin, whose admin API is loopback-only (#85).
 */
final class CloudflareEdgeCache implements EdgeCache
{
    private const int ATTEMPTS = 3;
    private const int MAX_WAIT_SECONDS = 30;

    /** @var \Closure(int): void */
    private \Closure $sleep;

    /**
     * @param (callable(int): void)|null $sleep
     */
    public function __construct(
        private readonly HttpClientInterface $client,
        private readonly string $zoneId,
        private readonly string $apiKey,
        private readonly string $email = '',
        ?callable $sleep = null,
    ) {
        $this->sleep = $sleep ? $sleep(...) : static function (int $seconds): void { sleep($seconds); };
    }

    /**
     * The zone from Souin's `cdn` block lines (`provider cloudflare`, `zone_id …`, `api_key …`, optional `email …`);
     * null for any other provider or none.
     *
     * @param (callable(int): void)|null $sleep
     */
    public static function fromCdnConfig(string $config, HttpClientInterface $client, ?callable $sleep = null): ?self
    {
        $settings = [];
        foreach (preg_split('/\R/', $config) ?: [] as $line) {
            $words = preg_split('/\s+/', trim($line), 2);
            if (2 === \count($words ?: [])) {
                $settings[$words[0]] = trim($words[1], " \t\"'");
            }
        }
        if ('cloudflare' !== ($settings['provider'] ?? '') || '' === ($settings['zone_id'] ?? '') || '' === ($settings['api_key'] ?? '')) {
            return null;
        }

        return new self($client, $settings['zone_id'], $settings['api_key'], $settings['email'] ?? '', $sleep);
    }

    public function name(): string
    {
        return 'the Cloudflare zone';
    }

    public function purgeEverything(): void
    {
        // As the Souin patch: a scoped token is a bearer token; with an email, api_key is the Global API Key.
        $headers = '' === $this->email
            ? ['Authorization' => 'Bearer '.$this->apiKey]
            : ['X-Auth-Email' => $this->email, 'X-Auth-Key' => $this->apiKey];
        $url = 'https://api.cloudflare.com/client/v4/zones/'.rawurlencode($this->zoneId).'/purge_cache';

        $problem = '';
        for ($attempt = 1; $attempt <= self::ATTEMPTS; ++$attempt) {
            $wait = 0;
            try {
                $response = $this->client->request('POST', $url, ['headers' => $headers, 'json' => ['purge_everything' => true], 'timeout' => 30]);
                $status = $response->getStatusCode();
                if ($status >= 200 && $status < 300) {
                    return;
                }
                $problem = \sprintf('Cloudflare answered %d', $status);
                // 429 and 5xx are worth another try (Cloudflare limits purges per account); anything else is a bad token or zone.
                if (429 !== $status && $status < 500) {
                    break;
                }
                $wait = (int) ($response->getHeaders(false)['retry-after'][0] ?? 0);
            } catch (ExceptionInterface $e) {
                $problem = 'Cloudflare did not answer: '.$e->getMessage();
            }
            if ($attempt < self::ATTEMPTS) {
                ($this->sleep)(min(max($wait, 1), self::MAX_WAIT_SECONDS));
            }
        }

        throw new \RuntimeException($problem);
    }
}
