<?php

declare(strict_types=1);

namespace App\Tests\Unit\Command;

use App\Command\PurgeEdgeCacheCommand;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Tester\CommandTester;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

/**
 * The deploy's edge-only purge (#218): one purge_everything to the configured zone, and a failure the deploy can see.
 */
final class PurgeEdgeCacheCommandTest extends TestCase
{
    private const CONFIG = "provider cloudflare\nzone_id zone-1\napi_key token-1\nstrategy hard";

    public function testPurgesEverythingInTheConfiguredZone(): void
    {
        $requests = [];
        $client = new MockHttpClient(static function (string $method, string $url, array $options) use (&$requests): MockResponse {
            $requests[] = [$method, $url, $options['body'] ?? ''];

            return new MockResponse('{"success":true}');
        });
        $tester = new CommandTester(new PurgeEdgeCacheCommand($client, self::CONFIG));

        self::assertSame(Command::SUCCESS, $tester->execute([]));
        self::assertCount(1, $requests);
        self::assertSame('POST', $requests[0][0]);
        self::assertSame('https://api.cloudflare.com/client/v4/zones/zone-1/purge_cache', $requests[0][1]);
        self::assertStringContainsString('purge_everything', $requests[0][2]);
        self::assertStringContainsString('Purged everything in the Cloudflare zone.', $tester->getDisplay());
    }

    public function testFailsWithoutACloudflareZone(): void
    {
        $tester = new CommandTester(new PurgeEdgeCacheCommand(new MockHttpClient(), ''));

        self::assertSame(Command::FAILURE, $tester->execute([]));
        self::assertStringContainsString('nothing purged', $tester->getDisplay());
    }

    public function testFailsWhenCloudflareRefuses(): void
    {
        $client = new MockHttpClient(new MockResponse('{"success":false}', ['http_code' => 403]));
        $tester = new CommandTester(new PurgeEdgeCacheCommand($client, self::CONFIG));

        self::assertSame(Command::FAILURE, $tester->execute([]));
        self::assertStringContainsString('Cloudflare answered 403', $tester->getDisplay());
    }
}
