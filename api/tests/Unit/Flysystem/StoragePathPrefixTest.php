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
    }

    #[DataProvider('prefixes')]
    public function test_a_prefix_is_normalised(string $value, string $expected): void
    {
        self::assertSame($expected, PathPrefixEnvVarProcessor::normalise($value));
    }

    public function test_a_prefix_cannot_climb_out_of_its_path(): void
    {
        $this->expectException(RuntimeException::class);
        PathPrefixEnvVarProcessor::normalise('review/../site');
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
