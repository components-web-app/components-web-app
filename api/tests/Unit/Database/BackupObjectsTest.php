<?php

declare(strict_types=1);

namespace App\Tests\Unit\Database;

use App\Database\BackupObjects;
use App\Database\PublicObjectProbe;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

// The deploy's database backups (#180): dated names, retention that touches only backups, and the public-bucket check.
class BackupObjectsTest extends TestCase
{
    public function test_names_are_dated_in_utc_and_sort_by_time(): void
    {
        $at = new \DateTimeImmutable('2026-10-20 01:02:03', new \DateTimeZone('Europe/London'));

        self::assertSame('site-a/database/rel/20261020-000203Z-abc1234.dump', BackupObjects::name('/site-a//database/rel', $at, 'abc1234'));
        self::assertSame('20261020-000203Z-main-x.dump', BackupObjects::name('', $at, 'Main X!'));
        self::assertSame('20261020-000203Z-backup.dump', BackupObjects::name('', $at, '***'));
    }

    public function test_a_directory_cannot_leave_its_path(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        BackupObjects::directory('site-a/../other');
    }

    public function test_only_the_oldest_backups_beyond_keep_expire(): void
    {
        $names = [
            'db/20261001-000000Z-a.dump',
            'db/20261003-000000Z-c.dump',
            'db/notes.txt',
            'db/nested/20250101-000000Z-x.dump',
            'db/20261002-000000Z-b.dump',
            'db/20260901-000000Z-old.dump',
            'other/20200101-000000Z-z.dump',
        ];

        self::assertSame(['db/20261001-000000Z-a.dump', 'db/20260901-000000Z-old.dump'], BackupObjects::expired($names, 'db', 2));
        self::assertSame([], BackupObjects::expired($names, 'db/', 10));
        // At least the newest is always kept.
        self::assertCount(3, BackupObjects::expired($names, 'db', 0));
    }

    /**
     * @return iterable<string, array{MockResponse, ?bool}>
     */
    public static function answers(): iterable
    {
        yield 'readable' => [new MockResponse('x', ['http_code' => 206]), true];
        yield 'readable, whole object' => [new MockResponse('x', ['http_code' => 200]), true];
        yield 'refused' => [new MockResponse('', ['http_code' => 403]), false];
        yield 'needs credentials' => [new MockResponse('', ['http_code' => 401]), false];
        yield 'unclear' => [new MockResponse('', ['http_code' => 500]), null];
        yield 'no connection' => [new MockResponse('', ['error' => 'down']), null];
    }

    #[DataProvider('answers')]
    public function test_the_probe_reads_without_credentials(MockResponse $response, ?bool $public): void
    {
        $client = new MockHttpClient($response);

        self::assertSame($public, new PublicObjectProbe($client)->isPublic('my-backups', 'site a/20261020-000203Z-x.dump'));
        self::assertSame('https://storage.googleapis.com/my-backups/site%20a/20261020-000203Z-x.dump', $response->getRequestUrl());
        self::assertSame('GET', $response->getRequestMethod());
        self::assertArrayNotHasKey('authorization', array_change_key_case($response->getRequestOptions()['normalized_headers'] ?? []));
    }
}
