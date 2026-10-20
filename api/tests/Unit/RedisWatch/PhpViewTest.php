<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\RedisWatch\HttpPhpView;
use App\RedisWatch\PhpViewResult;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

/**
 * php's view of Redis (#85), read from Souin's Cache-Status on one API response.
 */
final class PhpViewTest extends TestCase
{
    /**
     * @return iterable<string, array{string, string}>
     */
    public static function cacheStatuses(): iterable
    {
        yield 'a hit from Redis' => ['Souin; hit; ttl=31557590; key=GET-http-localhost-/_api/_/site_config_parameters.jsonld; detail=REDIS', PhpViewResult::OK];
        yield 'a miss that was stored' => ['Souin; fwd=uri-miss; stored; key=GET-http-localhost-/_api/_/site_config_parameters.jsonld', PhpViewResult::OK];
        yield 'Redis unreachable' => ['Souin; fwd=uri-miss; key=GET-http-localhost-/_api/_/site_config_parameters.jsonld; detail=REDIS-INSERTION-ERROR', PhpViewResult::REDIS_ERROR];
        yield 'a bypass' => ['Souin; fwd=bypass; detail=EXCLUDED-REQUEST-URI', PhpViewResult::UNKNOWN];
        yield 'none' => ['', PhpViewResult::UNKNOWN];
    }

    #[DataProvider('cacheStatuses')]
    public function testReadsCacheStatus(string $cacheStatus, string $expected): void
    {
        self::assertSame($expected, PhpViewResult::fromCacheStatus($cacheStatus)->status);
    }

    public function testRequestsTheProbePathThroughTheGivenService(): void
    {
        $client = new MockHttpClient(static function (string $method, string $url, array $options): MockResponse {
            self::assertSame('GET', $method);
            self::assertSame('http://release-cwa/_api/_/site_config_parameters.jsonld', $url);

            return new MockResponse('{}', ['response_headers' => ['Cache-Status' => 'Souin; hit; detail=REDIS']]);
        });

        self::assertSame(PhpViewResult::OK, new HttpPhpView($client, 'http://release-cwa/')->check()->status);
    }

    public function testAnApiThatDoesNotAnswerIsUnknownNotDown(): void
    {
        $failing = new MockHttpClient([new MockResponse('', ['error' => 'Connection refused'])]);
        self::assertSame(PhpViewResult::UNKNOWN, new HttpPhpView($failing, 'http://release-cwa')->check()->status);

        $erroring = new MockHttpClient([new MockResponse('', ['http_code' => 503, 'response_headers' => ['Cache-Status' => 'Souin; detail=REDIS-INSERTION-ERROR']])]);
        self::assertSame(PhpViewResult::UNKNOWN, new HttpPhpView($erroring, 'http://release-cwa')->check()->status);
    }
}
