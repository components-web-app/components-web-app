<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\RedisWatch\CloudflareEdgeCache;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

/**
 * The watch job's Cloudflare purge after a flush (#85), from the same CADDY_CACHE_CDN_CONFIG Souin reads.
 */
final class CloudflareEdgeCacheTest extends TestCase
{
    public function testOnlyACompleteCloudflareConfigGivesAnEdgeCache(): void
    {
        $client = new MockHttpClient();
        self::assertNull(CloudflareEdgeCache::fromCdnConfig('', $client));
        self::assertNull(CloudflareEdgeCache::fromCdnConfig('strategy hard', $client));
        self::assertNull(CloudflareEdgeCache::fromCdnConfig("provider fastly\napi_key k\nzone_id z", $client));
        self::assertNull(CloudflareEdgeCache::fromCdnConfig("provider cloudflare\nzone_id z", $client));
        self::assertNotNull(CloudflareEdgeCache::fromCdnConfig("  provider cloudflare\n  api_key k\n  zone_id z\n  strategy hard\n", $client));
    }

    public function testAScopedTokenIsSentAsABearerToken(): void
    {
        $requests = [];
        $client = new MockHttpClient(static function (string $method, string $url, array $options) use (&$requests): MockResponse {
            $requests[] = [$method, $url, $options];

            return new MockResponse('{"success":true}');
        });

        CloudflareEdgeCache::fromCdnConfig("provider cloudflare\napi_key token123\nzone_id zone9\nstrategy hard", $client)?->purgeEverything();

        self::assertCount(1, $requests);
        [$method, $url, $options] = $requests[0];
        self::assertSame('POST', $method);
        self::assertSame('https://api.cloudflare.com/client/v4/zones/zone9/purge_cache', $url);
        self::assertSame('{"purge_everything":true}', $options['body']);
        self::assertContains('Authorization: Bearer token123', $options['headers']);
    }

    public function testAnEmailMeansTheGlobalApiKey(): void
    {
        $headers = [];
        $client = new MockHttpClient(static function (string $method, string $url, array $options) use (&$headers): MockResponse {
            $headers = $options['headers'];

            return new MockResponse('{"success":true}');
        });

        CloudflareEdgeCache::fromCdnConfig("provider cloudflare\napi_key globalkey\nemail ops@example.com\nzone_id z", $client)?->purgeEverything();

        self::assertContains('X-Auth-Email: ops@example.com', $headers);
        self::assertContains('X-Auth-Key: globalkey', $headers);
    }

    public function testRetriesARateLimitAfterRetryAfter(): void
    {
        $slept = [];
        $client = new MockHttpClient([
            new MockResponse('', ['http_code' => 429, 'response_headers' => ['Retry-After' => '7']]),
            new MockResponse('{"success":true}'),
        ]);

        new CloudflareEdgeCache($client, 'z', 'k', '', static function (int $seconds) use (&$slept): void { $slept[] = $seconds; })->purgeEverything();

        self::assertSame([7], $slept);
        self::assertSame(2, $client->getRequestsCount());
    }

    public function testABadTokenFailsAtOnce(): void
    {
        $client = new MockHttpClient([new MockResponse('', ['http_code' => 403])]);
        $edge = new CloudflareEdgeCache($client, 'z', 'k', '', static function (): void {});

        try {
            $edge->purgeEverything();
            self::fail('No exception');
        } catch (\RuntimeException $e) {
            self::assertSame('Cloudflare answered 403', $e->getMessage());
        }
        self::assertSame(1, $client->getRequestsCount());
    }

    public function testGivesUpAfterThreeFailures(): void
    {
        $client = new MockHttpClient([
            new MockResponse('', ['http_code' => 502]),
            new MockResponse('', ['http_code' => 502]),
            new MockResponse('', ['http_code' => 502]),
        ]);

        $this->expectExceptionObject(new \RuntimeException('Cloudflare answered 502'));
        try {
            new CloudflareEdgeCache($client, 'z', 'k', '', static function (): void {})->purgeEverything();
        } finally {
            self::assertSame(3, $client->getRequestsCount());
        }
    }
}
