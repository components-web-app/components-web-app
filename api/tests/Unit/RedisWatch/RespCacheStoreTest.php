<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\RedisWatch\RespCacheStore;
use PHPUnit\Framework\TestCase;

/**
 * The watch job reads Redis's address and password from Souin's own store block (#85), the chart's cwa.scaled.cacheStorage.
 */
final class RespCacheStoreTest extends TestCase
{
    public function testReadsTheChartsStoreBlock(): void
    {
        $block = "redis {\n\tconfiguration {\n\t\tAddrs release-cwa-redis:6379\n\t\tPassword s3cret\n\t\tDialTimeout 100ms\n\t\tMaxRetries -1\n\t}\n}";
        $store = RespCacheStore::fromSouinStorage($block, 2.0);

        self::assertNotNull($store);
        self::assertSame('s3cret', $store->password());
    }

    public function testAnyOtherStoreIsNotRedis(): void
    {
        self::assertNull(RespCacheStore::fromSouinStorage('', 2.0));
        self::assertNull(RespCacheStore::fromSouinStorage('otter', 2.0));
        self::assertNull(RespCacheStore::fromSouinStorage("badger {\n\tconfiguration {\n\t\tAddrs x:1\n\t}\n}", 2.0));
    }
}
