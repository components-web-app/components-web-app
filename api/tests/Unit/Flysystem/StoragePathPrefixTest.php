<?php

declare(strict_types=1);

namespace App\Tests\Unit\Flysystem;

use App\Flysystem\GoogleCloudStorageFactory;
use App\Flysystem\PathPrefixEnvVarProcessor;
use League\Flysystem\Config;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\DependencyInjection\Exception\RuntimeException;

// GCLOUD_PATH_PREFIX keeps an app's objects, and its orphan scan, inside one path of a shared bucket (#166).
class StoragePathPrefixTest extends TestCase
{
    public static function prefixes(): iterable
    {
        yield 'unset' => ['', ''];
        yield 'blank' => ['  ', ''];
        yield 'slashes only' => ['//', ''];
        yield 'bare' => ['review/my-branch', 'review/my-branch/'];
        yield 'leading and doubled slashes' => ['/review//my-branch/', 'review/my-branch/'];
        // The deploy's gcloud_path_prefix must agree with every case: bin/test/storage-prefix-parity.sh (#168).
        yield 'doubled trailing slash' => ['site-a//', 'site-a/'];
        yield 'surrounding whitespace' => [' site-a/ ', 'site-a/'];
        yield 'surrounding control whitespace' => ["\t\r\v\nsite-a/\n", 'site-a/'];
        yield 'inner space' => ['a b/c', 'a b/c/'];
        yield 'three dots' => ['...', '.../'];
        yield 'dots inside a segment' => ['a..b', 'a..b/'];
        yield 'hidden segment' => ['.hidden', '.hidden/'];
    }

    #[DataProvider('prefixes')]
    public function test_a_prefix_is_normalised(string $value, string $expected): void
    {
        self::assertSame($expected, PathPrefixEnvVarProcessor::normalise($value));
    }

    public static function refusedPrefixes(): iterable
    {
        yield 'climbing out' => ['review/../site', '..'];
        yield 'parent' => ['..', '..'];
        yield 'current' => ['.', '.'];
        yield 'inner current' => ['a/./b', '.'];
    }

    #[DataProvider('refusedPrefixes')]
    public function test_a_prefix_cannot_climb_out_of_its_path(string $value, string $segment): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage(sprintf('A storage path prefix cannot contain "%s": "%s".', $segment, $value));
        PathPrefixEnvVarProcessor::normalise($value);
    }

    public function test_the_adapter_stores_under_the_prefix(): void
    {
        $adapter = (new GoogleCloudStorageFactory(['project_id' => 'test'], 'bucket', 'http://gcs.invalid', 'review/x/'))();

        self::assertSame('https://storage.googleapis.com/bucket/review/x/a.png', $adapter->publicUrl('a.png', new Config()));
    }

    public function test_no_prefix_stores_at_the_bucket_root(): void
    {
        $adapter = (new GoogleCloudStorageFactory(['project_id' => 'test'], 'bucket', 'http://gcs.invalid'))();

        self::assertSame('https://storage.googleapis.com/bucket/a.png', $adapter->publicUrl('a.png', new Config()));
    }
}
